import Foundation
import Testing

@testable import LodeRunner

@Suite
struct GameSessionTests {
    /// Same shape as `RunnerSimulationTests.reachingTopWithAllGoldWins` (walk right
    /// onto gold, then climb a ladder to row 0), shifted by `offsetX` so distinct
    /// levels are distinguishable by spawn position. `completeActions` is the exact
    /// already-verified sequence that finishes it: 8 ticks right reaches the gold and
    /// the ladder's base, 5 ticks up reaches row 0 centered, and one more tick (any
    /// action) is needed for the finish-check — which runs at the *start* of the next
    /// tick against the position the previous tick left — to actually fire.
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

    private func completeCurrentLevel(_ session: inout GameSession) throws {
        for action in completeActions {
            try session.tick(action)
        }
        // Level complete now parks the session in `.transitioning(.levelAdvance)`
        // pending the composition layer's iris close/open. Tests operate on the
        // post-swap state, so finalize inline.
        try session.finalizeTransition()
    }

    @Test("init: starting lives/score/level/phase, and empty levels throws")
    func initialState() throws {
        let level = makeLevel(stamps: [(x: 5, y: 14, tile: .runner)])
        let session = try GameSession(levels: [level])

        #expect(session.lives == 5)
        #expect(session.score == 0)
        #expect(session.currentLevelIndex == 0)
        #expect(session.passedLevelCount == 0)
        #expect(session.phase == .playing)
        #expect(session.simulation.runner.position == GridPoint(x: 5, y: 14))

        #expect(throws: GameSessionError.noLevels) {
            try GameSession(levels: [])
        }
    }

    @Test("death with lives remaining retries the same level fresh")
    func deathWithLivesRemainingRetries() throws {
        let deathLevel = makeLevel(stamps: [
            (x: 5, y: 14, tile: .runner),
            (x: 6, y: 14, tile: .guard),
        ])
        var session = try GameSession(levels: [deathLevel])

        for _ in 0..<10 {
            try session.tick(.right)
            if session.lives < 5 { break }
        }
        #expect(session.phase == .transitioning(.death))
        try session.finalizeTransition()

        #expect(session.lives == 4)
        #expect(session.score == 0)
        #expect(session.phase == .playing)
        #expect(session.currentLevelIndex == 0)
        #expect(session.simulation.phase == .playing)
        #expect(session.simulation.runner.position == GridPoint(x: 5, y: 14))
        #expect(session.simulation.runner.xOffset == 0)
        #expect(session.simulation.runner.yOffset == 0)
    }

    @Test("death at the last life ends the session")
    func deathAtLastLifeEndsSession() throws {
        let deathLevel = makeLevel(stamps: [
            (x: 5, y: 14, tile: .runner),
            (x: 6, y: 14, tile: .guard),
        ])
        var session = try GameSession(levels: [deathLevel])

        // Each death now parks in `.transitioning(.death)`; the caller finalizes
        // to drop lives and swap the sim, matching how `GameSessionDriver.run`
        // drives it around the iris wipe.
        for _ in 0..<200 {
            if case .transitioning = session.phase {
                try session.finalizeTransition()
            }
            if session.phase == .gameOver { break }
            try session.tick(.right)
        }
        #expect(session.phase == .gameOver)
        #expect(session.lives == 0)

        let frozen = session
        try session.tick(.right)
        #expect(session == frozen)
    }

    @Test("level complete advances to the next level and scores the completion bonus")
    func levelCompleteAdvancesAndScores() throws {
        var session = try GameSession(levels: [
            completableLevel(offsetX: 0),
            completableLevel(offsetX: 10),
        ])

        try completeCurrentLevel(&session)

        #expect(session.score == 1750)  // 250 (gold pickup) + 1500 (completion bonus).
        #expect(session.lives == 6)
        #expect(session.passedLevelCount == 1)
        #expect(session.currentLevelIndex == 1)
        #expect(session.phase == .playing)
        #expect(session.simulation.runner.position == GridPoint(x: 13, y: 1))
    }

    @Test("lives cap at 100")
    func livesCapAt100() throws {
        var session = try GameSession(levels: Array(repeating: completableLevel(offsetX: 0), count: 150))

        for _ in 0..<120 { try completeCurrentLevel(&session) }

        #expect(session.lives == 100)
        #expect(session.phase == .playing)
        #expect(session.passedLevelCount == 120)
    }

    @Test("winning: completing the only level wraps and wins immediately")
    func completingOnlyLevelWins() throws {
        var session = try GameSession(levels: [completableLevel(offsetX: 0)])

        try completeCurrentLevel(&session)

        #expect(session.phase == .won)
        #expect(session.currentLevelIndex == 0)
        #expect(session.passedLevelCount == 1)

        let frozen = session
        try session.tick(.stop)
        #expect(session == frozen)
    }

    @Test("death parks in .transitioning until finalize; sim frozen mid-death")
    func deathParksInTransitioningUntilFinalize() throws {
        let deathLevel = makeLevel(stamps: [
            (x: 5, y: 14, tile: .runner),
            (x: 6, y: 14, tile: .guard),
        ])
        var session = try GameSession(levels: [deathLevel])

        for _ in 0..<10 {
            try session.tick(.right)
            if case .transitioning = session.phase { break }
        }
        // Bookkeeping applied at the transition edge; sim swap deferred.
        #expect(session.phase == .transitioning(.death))
        #expect(session.lives == 4)
        #expect(session.simulation.phase == .dead)

        // Additional ticks are no-ops while transitioning — matches JS
        // `GAME_WAITING` at `main.js:1479-1480`.
        let frozen = session
        try session.tick(.right)
        #expect(session == frozen)

        try session.finalizeTransition()
        #expect(session.phase == .playing)
        #expect(session.simulation.phase == .playing)
    }

    @Test("level complete parks in .transitioning(.levelAdvance) until finalize")
    func levelCompleteParksInTransitioning() throws {
        var session = try GameSession(levels: [
            completableLevel(offsetX: 0),
            completableLevel(offsetX: 10),
        ])

        for action in completeActions {
            try session.tick(action)
        }
        #expect(session.phase == .transitioning(.levelAdvance))
        #expect(session.passedLevelCount == 1)
        #expect(session.currentLevelIndex == 1)

        try session.finalizeTransition()
        #expect(session.phase == .playing)
        #expect(session.simulation.runner.position == GridPoint(x: 13, y: 1))
    }

    @Test("GameSession round-trips through JSON")
    func codableRoundTrip() throws {
        var session = try GameSession(levels: [
            completableLevel(offsetX: 0),
            completableLevel(offsetX: 10),
        ])
        try completeCurrentLevel(&session)

        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(GameSession.self, from: data)
        #expect(decoded == session)
    }
}
