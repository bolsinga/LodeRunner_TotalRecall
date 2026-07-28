import Observation
import SwiftUI

/// Session-level counterpart to `SimulationDriver`: ticks a `GameSession` at
/// 30 Hz, threading input, appearance snapshots, and the pre-play born-blink
/// handoff. Ported from the `PLAY_CLASSIC` slice of `playGame` at
/// `lodeRunner.main.js:855-916` — the switch on `gameState` that dispatches
/// to per-tick work while the session is `GAME_PLAYING`, plus the
/// `GAME_START → GAME_PLAYING` transition (`main.js:1298-1306`) triggered
/// here when the first non-`.stop` input arrives.
@Observable @MainActor
public final class GameSessionDriver {
    public private(set) var session: GameSession
    public private(set) var runnerAppearance: RunnerAppearance
    public private(set) var guardAppearances: [GuardAppearance]

    /// Live input source, polled once per `tick()`.
    public var input: (any RunnerInput)?

    /// 30 Hz to match the JS default (`lodeRunner.preload.js:242`), same as
    /// `SimulationDriver`.
    public let tickPeriod: Duration = .microseconds(1_000_000 / 30)

    private var isRunning = false

    public init(
        session: GameSession,
        input: (any RunnerInput)? = nil,
        startInBornBlink: Bool = true
    ) {
        var seeded = session
        if startInBornBlink { seeded.armBornBlink() }
        self.session = seeded
        self.runnerAppearance = RunnerAppearance()
        self.guardAppearances = Array(
            repeating: GuardAppearance(), count: seeded.simulation.guards.count)
        self.input = input
    }

    /// Runs the tick loop until the enclosing task is cancelled. Attach via
    /// `.task { await driver.run() }` in a SwiftUI view.
    public func run() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        while !Task.isCancelled {
            tick()
            try? await Task.sleep(for: tickPeriod)
        }
    }

    /// One tick — hand off from `.starting` on first input, advance the
    /// session, refresh appearances. Exposed so callers can step
    /// deterministically without the async loop.
    public func tick() {
        let action = input?.currentAction ?? .stop
        if session.simulation.phase == .starting, action != .stop {
            session.beginPlay()
        }
        // `session.tick` can throw only when it re-inits a level (`try
        // RunnerSimulation(level:)` in `handleDeath`/`handleLevelComplete`),
        // which requires a `.runner` stamp. Shipped levels satisfy that, so
        // this is effectively infallible at runtime; a future GameView error
        // affordance can surface it if we ever need to.
        try? session.tick(action)
        refreshAppearances()
    }

    private func refreshAppearances() {
        let sim = session.simulation
        let runner = sim.runner
        let runnerBase = sim.slots[runner.position.x][runner.position.y].base
        runnerAppearance.update(with: runner, baseTile: runnerBase)
        if guardAppearances.count != sim.guards.count {
            guardAppearances = Array(
                repeating: GuardAppearance(), count: sim.guards.count)
        }
        for i in sim.guards.indices {
            let g = sim.guards[i]
            let baseTile = sim.slots[g.position.x][g.position.y].base
            guardAppearances[i].update(with: g, baseTile: baseTile)
        }
    }
}
