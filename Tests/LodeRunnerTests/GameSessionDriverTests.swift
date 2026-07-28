import Foundation
import Testing

@testable import LodeRunner

@Suite
@MainActor
struct GameSessionDriverTests {
    private func level() -> LevelParseResult {
        makeLevel(stamps: [(x: 5, y: 14, tile: .runner)])
    }

    @Test("init arms .starting by default; tick no-ops until an input arrives")
    func initArmsStartingAndTicksNoOp() throws {
        let session = try GameSession(levels: [level()])
        let input = StubInput(currentAction: .stop)
        let driver = GameSessionDriver(session: session, input: input)

        #expect(driver.session.simulation.phase == .starting)

        // .stop keeps us in .starting.
        for _ in 0..<3 { driver.tick() }
        #expect(driver.session.simulation.phase == .starting)
        #expect(driver.session.simulation.runner.position == GridPoint(x: 5, y: 14))
        #expect(driver.session.simulation.runner.xOffset == 0)

        // First non-.stop input performs the born-blink handoff and moves the runner
        // in the same tick.
        input.currentAction = .right
        driver.tick()
        #expect(driver.session.simulation.phase == .playing)
        #expect(driver.session.simulation.runner.xOffset == 8)
    }

    @Test("startInBornBlink: false leaves the sim in .playing (opt-out path)")
    func startInBornBlinkFalse() throws {
        let session = try GameSession(levels: [level()])
        let input = StubInput(currentAction: .right)
        let driver = GameSessionDriver(
            session: session, input: input, startInBornBlink: false)

        #expect(driver.session.simulation.phase == .playing)
        driver.tick()
        #expect(driver.session.simulation.runner.xOffset == 8)
    }

    @Test("guardAppearances length tracks the level's guard count")
    func guardAppearancesMatchGuardCount() throws {
        let multiGuard = makeLevel(stamps: [
            (x: 5, y: 14, tile: .runner),
            (x: 8, y: 14, tile: .guard),
            (x: 12, y: 14, tile: .guard),
        ])
        let session = try GameSession(levels: [multiGuard])
        let driver = GameSessionDriver(session: session)
        #expect(driver.guardAppearances.count == driver.session.simulation.guards.count)
        #expect(driver.guardAppearances.count == 2)
    }

    @Test("gold pickup fires .getGold once per gold tile")
    func getGoldFiresOnPickup() throws {
        // Runner at (5, 14) on the auto-fill floor; a gold tile at (6, 14) is
        // one step to the right — walk into it.
        let level = makeLevel(stamps: [
            (x: 5, y: 14, tile: .runner),
            (x: 6, y: 14, tile: .gold),
        ])
        let session = try GameSession(levels: [level])
        let input = StubInput(currentAction: .right)
        let driver = GameSessionDriver(
            session: session, input: input, startInBornBlink: false)
        let sink = EffectSink()
        driver.soundHandler = { sink.record($0) }

        // Walk right until the gold is picked up (goldRemaining goes 1 → 0).
        for _ in 0..<10 {
            driver.tick()
            if driver.session.simulation.goldRemaining == 0 { break }
        }
        #expect(driver.session.simulation.goldRemaining == 0)
        #expect(sink.effects.filter { $0 == .getGold }.count == 1)
    }

    @Test("dig start fires .dig on the digState nil → non-nil edge")
    func digFiresOnDigStart() throws {
        // A brick tile at (4, 15) — one tile down-left of the runner at
        // (5, 14) — is the target for a digLeft.
        let level = makeLevel(stamps: [(x: 5, y: 14, tile: .runner)])
        let session = try GameSession(levels: [level])
        let input = StubInput(currentAction: .digLeft)
        let driver = GameSessionDriver(
            session: session, input: input, startInBornBlink: false)
        let sink = EffectSink()
        driver.soundHandler = { sink.record($0) }

        driver.tick()  // digState nil → non-nil this tick
        #expect(driver.session.simulation.digState != nil)
        #expect(sink.effects.contains(.dig))

        // A follow-up .stop tick keeps the dig in progress but must NOT
        // re-fire .dig — the trigger is edge-detected, not level-triggered.
        input.currentAction = .stop
        let priorCount = sink.effects.filter { $0 == .dig }.count
        driver.tick()
        #expect(sink.effects.filter { $0 == .dig }.count == priorCount)
    }

    @Test("runner death fires .dead via session.lives decreasing")
    func deadFiresOnDeath() throws {
        // Guard adjacent to the runner on the auto-fill floor — walk right
        // into the guard for a same-tile collision.
        let level = makeLevel(stamps: [
            (x: 5, y: 14, tile: .runner),
            (x: 6, y: 14, tile: .guard),
        ])
        let session = try GameSession(levels: [level])
        let input = StubInput(currentAction: .right)
        let driver = GameSessionDriver(
            session: session, input: input, startInBornBlink: false)
        let sink = EffectSink()
        driver.soundHandler = { sink.record($0) }

        let startingLives = driver.session.lives
        // Loop until either lives drops or we cap iterations — enough ticks
        // for the guard's slower step to catch up.
        for _ in 0..<40 {
            driver.tick()
            if driver.session.lives < startingLives { break }
        }
        #expect(driver.session.lives < startingLives)
        #expect(sink.effects.contains(.dead))
    }

    @Test("level pass fires .pass via passedLevelCount incrementing")
    func passFiresOnLevelComplete() throws {
        // Same "walk right onto gold, climb ladder to row 0" shape used in
        // GameSessionTests. `completeCurrentLevel` is inlined here to avoid
        // depending on that test suite's private helper.
        let level = makeLevel(stamps: [
            (x: 3, y: 1, tile: .runner),
            (x: 4, y: 1, tile: .gold),
            (x: 5, y: 0, tile: .ladder),
            (x: 5, y: 1, tile: .ladder),
            (x: 3, y: 2, tile: .brick),
            (x: 4, y: 2, tile: .brick),
        ])
        // Two-level session so completing level 0 advances into level 1
        // instead of tripping the win branch (which we exercise separately).
        let session = try GameSession(levels: [level, level])
        let input = StubInput(currentAction: .stop)
        let driver = GameSessionDriver(
            session: session, input: input, startInBornBlink: false)
        let sink = EffectSink()
        driver.soundHandler = { sink.record($0) }

        let actions: [RunnerAction] =
            Array(repeating: .right, count: 8)
            + Array(repeating: .up, count: 5)
            + [.stop]
        for action in actions {
            input.currentAction = action
            driver.tick()
        }
        #expect(driver.session.passedLevelCount == 1)
        #expect(sink.effects.filter { $0 == .pass }.count == 1)
        // Gold on the completed level should have fired exactly once, too.
        #expect(sink.effects.filter { $0 == .getGold }.count == 1)
    }
}

/// Records `SoundEffect` invocations from the driver's `soundHandler`. Kept
/// as a class so the closure captures a reference rather than a copy.
@MainActor
private final class EffectSink {
    var effects: [SoundEffect] = []
    func record(_ effect: SoundEffect) { effects.append(effect) }
}

/// Test-only `RunnerInput` — flip `currentAction` between `driver.tick()`
/// calls to drive scripted scenarios deterministically.
@MainActor
private final class StubInput: RunnerInput {
    var currentAction: RunnerAction
    init(currentAction: RunnerAction) {
        self.currentAction = currentAction
    }
}
