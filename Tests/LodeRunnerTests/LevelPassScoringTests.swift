import Foundation
import Testing

@testable import LodeRunner

/// Tests around the level-pass scoring dialog port: the per-level counters
/// on `RunnerSimulation` (elapsed time, guards trapped) and the `.scoring`
/// waiting state on `GameSession` that carries the dialog's snapshot.
@Suite
@MainActor
struct LevelPassScoringTests {
    // MARK: - RunnerSimulation counters

    @Test("secondsElapsed increments once per 16 ticks and caps at 999")
    func secondsElapsedTicks() throws {
        // Flat floor so ticks are cheap no-ops for the counter check.
        let level = makeLevel(stamps: [(x: 5, y: 14, tile: .runner)])
        var sim = try RunnerSimulation(level: level)

        // First 15 ticks stay at 0 (sub-second accumulator hasn't overflowed).
        for _ in 0..<15 { sim.tick(.stop) }
        #expect(sim.secondsElapsed == 0)

        // Tick 16 flips the accumulator and bumps to 1.
        sim.tick(.stop)
        #expect(sim.secondsElapsed == 1)

        // After a total of 32 ticks we should be at 2.
        for _ in 0..<16 { sim.tick(.stop) }
        #expect(sim.secondsElapsed == 2)
    }

    @Test("secondsElapsed caps at 999 (MAX_TIME_COUNT)")
    func secondsElapsedCapsAt999() throws {
        // Manually drive many ticks would be slow; verify the cap logic by
        // running enough to hit 999 then adding more.
        let level = makeLevel(stamps: [(x: 5, y: 14, tile: .runner)])
        var sim = try RunnerSimulation(level: level)

        // 16 * 999 = 15984 ticks to reach 999.
        for _ in 0..<(16 * 999) { sim.tick(.stop) }
        #expect(sim.secondsElapsed == 999)
        // Additional ticks are clamped.
        for _ in 0..<32 { sim.tick(.stop) }
        #expect(sim.secondsElapsed == 999)
    }

    @Test("guardsTrappedCount bumps once per guard burial")
    func guardsTrappedCountBumps() throws {
        // Same burial staging as
        // `GuardSimulationTests.guardBuriedWhileInHoleScoresTwice`: a
        // dig-left at (25, 10) opens (24, 11), the guard walks in late
        // enough that the ~198-tick fill preempts the ~85-tick climb-out.
        var stamps: [(x: Int, y: Int, tile: TileType)] = [
            (x: 25, y: 10, tile: .runner),
            (x: 6, y: 10, tile: .guard),
        ]
        for x in 0..<LevelGrid.tilesX {
            stamps.append((x: x, y: 11, tile: .brick))
        }
        stamps.append((x: 24, y: 12, tile: .brick))
        let level = makeLevel(stamps: stamps)
        var sim = try RunnerSimulation(level: level)

        sim.tick(.digLeft)
        // Roll through dig + guard-walk + fill.
        for _ in 0..<500 {
            sim.tick(.stop)
            if sim.guardsTrappedCount > 0 { break }
        }
        #expect(sim.guardsTrappedCount == 1)
    }

    // MARK: - GameSession `.scoring` transition

    private func completableLevel(offsetX: Int) -> LevelParseResult {
        makeLevel(stamps: [
            (x: offsetX + 3, y: 1, tile: .runner),
            (x: offsetX + 4, y: 1, tile: .gold),
            (x: offsetX + 5, y: 0, tile: .ladder),
            (x: offsetX + 5, y: 1, tile: .ladder),
            (x: offsetX + 3, y: 2, tile: .brick),
            (x: offsetX + 4, y: 2, tile: .brick),
        ])
    }

    private let completeActions: [RunnerAction] =
        Array(repeating: .right, count: 8) + Array(repeating: .up, count: 5) + [.stop]

    @Test("level complete populates LevelPassSummary from the finishing sim")
    func summaryPopulated() throws {
        var session = try GameSession(levels: [
            completableLevel(offsetX: 0),
            completableLevel(offsetX: 10),
        ])
        session.beginPlay()
        for action in completeActions { try session.tick(action) }

        guard case .scoring(let summary) = session.phase else {
            Issue.record("expected .scoring, got \(session.phase)")
            return
        }
        // 1-based JS display index — 0-based currentLevelIndex was 0 at
        // completion, so this is level 1.
        #expect(summary.levelNumber == 1)
        // The single gold on completableLevel gets picked up en route.
        #expect(summary.goldCollected == 1)
        // No guards on this level.
        #expect(summary.guardsTrapped == 0)
        // 14 ticks of play (8 right + 5 up + 1 stop) is less than 16, so
        // the second-boundary hasn't crossed — secondsElapsed is still 0.
        #expect(summary.secondsElapsed == 0)
    }

    @Test("finalizeScoring advances .scoring → .transitioning(.levelAdvance)")
    func finalizeScoringAdvancesToTransitioning() throws {
        var session = try GameSession(levels: [
            completableLevel(offsetX: 0),
            completableLevel(offsetX: 10),
        ])
        session.beginPlay()
        for action in completeActions { try session.tick(action) }
        #expect({ if case .scoring = session.phase { return true } else { return false } }())

        session.finalizeScoring()
        #expect(session.phase == .transitioning(.levelAdvance))
    }

    @Test("finalizeScoring on the last level jumps directly to .won")
    func finalizeScoringOnLastLevelWins() throws {
        var session = try GameSession(levels: [completableLevel(offsetX: 0)])
        session.beginPlay()
        for action in completeActions { try session.tick(action) }
        guard case .scoring = session.phase else {
            Issue.record("expected .scoring, got \(session.phase)")
            return
        }

        session.finalizeScoring()
        #expect(session.phase == .won)
    }

    @Test("finalizeScoring is a no-op outside .scoring")
    func finalizeScoringNoOpOutsideScoring() throws {
        var session = try GameSession(levels: [completableLevel(offsetX: 0)])
        // Fresh session sits in `.playing`; finalize should not budge it.
        session.finalizeScoring()
        #expect(session.phase == .playing)
    }

    @Test("ticks during .scoring are no-ops — mirrors JS GAME_WAITING")
    func ticksDuringScoringAreNoOp() throws {
        var session = try GameSession(levels: [
            completableLevel(offsetX: 0),
            completableLevel(offsetX: 10),
        ])
        session.beginPlay()
        for action in completeActions { try session.tick(action) }
        guard case .scoring = session.phase else {
            Issue.record("expected .scoring, got \(session.phase)")
            return
        }

        let frozen = session
        try session.tick(.right)
        try session.tick(.digLeft)
        #expect(session == frozen)
    }

    // MARK: - Driver

    @Test("dismissScoring on the driver forwards to session.finalizeScoring")
    func driverDismissScoring() throws {
        let session = try GameSession(levels: [
            completableLevel(offsetX: 0),
            completableLevel(offsetX: 10),
        ])
        let input = StubDismissInput()
        let driver = GameSessionDriver(
            session: session, input: input, startInBornBlink: false)
        // Drive to .scoring via ticks (mirrors the driver's own tick loop).
        for action in completeActions {
            input.currentAction = action
            driver.tick()
        }
        #expect({ if case .scoring = driver.session.phase { return true } else { return false } }())

        driver.dismissScoring()
        #expect(driver.session.phase == .transitioning(.levelAdvance))
        // Held input is cleared on dismiss so a stuck key can't lift the
        // next `.starting` gate mid-transition.
        #expect(input.currentAction == .stop)
    }

    @Test("armScoringInput is a no-op outside .scoring")
    func driverArmScoringInputNoOpOutsideScoring() throws {
        let session = try GameSession(levels: [completableLevel(offsetX: 0)])
        let driver = GameSessionDriver(session: session, startInBornBlink: false)
        driver.armScoringInput()
        #expect(driver.scoringInputArmed == false)
    }
}

/// Test-only `RunnerInput`. Local copy so this suite doesn't depend on
/// `GameSessionDriverTests`'s file-private `StubInput`.
@MainActor
private final class StubDismissInput: RunnerInput {
    var currentAction: RunnerAction = .stop
    func resetAction() { currentAction = .stop }
}
