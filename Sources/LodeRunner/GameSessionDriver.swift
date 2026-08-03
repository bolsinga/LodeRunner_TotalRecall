import Observation
import SwiftUI

/// Session-level counterpart to `SimulationDriver`: ticks a `GameSession` at
/// 30 Hz, threading input, appearance snapshots, and the pre-play born-blink
/// handoff. Ported from the `PLAY_CLASSIC` slice of `playGame` at
/// `lodeRunner.main.js:855-916` — the switch on `gameState` that dispatches
/// to per-tick work while the session is `GAME_PLAYING`, plus the
/// `GAME_START → GAME_PLAYING` transition (`main.js:1298-1306`) triggered
/// here when the first non-`.stop` input arrives.
/// Which half of the level-transition iris wipe is currently on screen —
/// `nil` when no transition is in flight. Ported from the JS `closingScreen`
/// / `openingScreen` pair (`main.js:1195-1230,1304-1319`), which frame the
/// `newLevel()` swap on every regular death respawn and level advance.
public enum LevelTransitionPhase: Equatable, Sendable {
    case closing
    case opening
}

@Observable @MainActor
public final class GameSessionDriver {
    public private(set) var session: GameSession
    public private(set) var runnerAppearance: RunnerAppearance
    public private(set) var guardAppearances: [GuardAppearance]
    /// Iris state for the composition layer. `run()` drives it around the
    /// `session.finalizeTransition()` call so the closing wipe covers the old
    /// level, the swap happens at fully-black, and the opening wipe reveals
    /// the new level — matching `main.js:1195-1230,1304-1319`.
    public private(set) var transitionPhase: LevelTransitionPhase?

    /// Live input source, polled once per `tick()`.
    public var input: (any RunnerInput)?

    /// Optional sound sink. `tick()` compares session state before/after the
    /// tick and invokes this for each detected event — the composition
    /// layer typically wires it to `SoundPlayer.play(_:)`. Kept as a closure
    /// (not a `SoundPlayer` reference) so tests can spy on triggers without
    /// booting AVFoundation.
    public var soundHandler: ((SoundEffect) -> Void)?

    /// Active theme. Currently only affects which `goldFinish` variant fires
    /// on the last-gold reveal — Apple2 has one shared clip, C64 has six
    /// per-level ones (JS `runner.js:331-333`). The composition layer keeps
    /// this in sync with the theme it drives `SoundPlayer.theme` from.
    public var theme: Theme = .apple2

    /// 30 Hz to match the JS default (`lodeRunner.preload.js:242`), same as
    /// `SimulationDriver`.
    public let tickPeriod: Duration = .microseconds(1_000_000 / 30)

    /// Iris close/open duration each — matches the JS `CLOSE_SCREEN_SPEED = 35`
    /// at 5 ms/step (`lodeRunner.def.js:148`, `main.js:1205,1314`) ≈ 175 ms
    /// per half. Same nominal value as `LevelPassOverlay.jsCloseDurationSeconds`
    /// / `LevelStartOverlay.jsOpenDurationSeconds`, held here as the single
    /// source of truth for the wait between `run()`'s state transitions.
    public let wipeDurationSeconds: Double = 5.0 * 35 / 1000

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
            if case .transitioning = session.phase {
                await runLevelTransition()
                continue
            }
            try? await Task.sleep(for: tickPeriod)
        }
    }

    /// Drive one full iris cycle around a pending sim swap. The tick loop is
    /// paused for the whole cycle — matches the JS's `GAME_WAITING` gate at
    /// `main.js:1479-1480,1499-1500`, which parks the state machine while
    /// `newLevel()`'s `closingScreen`/`openingScreen` recursion runs.
    private func runLevelTransition() async {
        transitionPhase = .closing
        try? await Task.sleep(for: .milliseconds(Int(wipeDurationSeconds * 1000)))
        performTransitionSwap()
        transitionPhase = .opening
        try? await Task.sleep(for: .milliseconds(Int(wipeDurationSeconds * 1000)))
        transitionPhase = nil
    }

    /// Everything the driver does at the "iris fully closed" instant, factored
    /// out so tests can invoke it without going through the async sleep in
    /// `runLevelTransition`. Ports the swap side of `newLevel()` at
    /// `main.js:1207-1230` plus the `keyAction = ACT_STOP` reset inside
    /// `beginPlay` at `main.js:1355` — which prevents a still-held direction
    /// key from lifting the fresh sim's `.starting` gate before the player
    /// gets to see the blink.
    func performTransitionSwap() {
        try? session.finalizeTransition()
        input?.resetAction()
        // The fresh sim's runner is `.stop` at spawn, so `RunnerAnimation
        // .forRunner` returns nil (JS `runner.shape` unchanged — freeze
        // semantics at `runner.js:267-275`) and `refreshAppearances` would
        // leave `lastAnimation` pointing at the previous level's last pose.
        // Match the JS's per-level re-init at `main.js:515` (`initVariable`
        // → new sprite from scratch) by dropping back to defaults before
        // the first refresh.
        runnerAppearance = RunnerAppearance()
        guardAppearances = Array(
            repeating: GuardAppearance(), count: session.simulation.guards.count)
        refreshAppearances()
    }

    /// One tick — hand off from `.starting` on first input, advance the
    /// session, fire sound triggers, refresh appearances. Exposed so callers
    /// can step deterministically without the async loop.
    public func tick() {
        let action = input?.currentAction ?? .stop
        if session.simulation.phase == .starting, action != .stop {
            session.beginPlay()
        }
        let snapshot = TickSnapshot(session: session)
        // `session.tick` can throw only when it re-inits a level (`try
        // RunnerSimulation(level:)` in `handleDeath`/`handleLevelComplete`),
        // which requires a `.runner` stamp. Shipped levels satisfy that, so
        // this is effectively infallible at runtime; a future GameView error
        // affordance can surface it if we ever need to.
        try? session.tick(action)
        // Mirror `runner.js:111` (`keyAction = ACT_STOP;`): if `moveRunner`
        // reached the dig case this tick, clear the input so a held dig key
        // doesn't fire again the moment the hole refills.
        if session.simulation.consumedDigInput {
            input?.resetAction()
        }
        fireSoundEvents(before: snapshot)
        refreshAppearances()
    }

    /// Diff session state before/after a tick and fire sound triggers for
    /// each detected event.
    private func fireSoundEvents(before: TickSnapshot) {
        guard let soundHandler else { return }
        let sim = session.simulation
        // Gold pickup — `runner.js:310`, fires per pickup so a single
        // decrement is enough to distinguish from goldRemaining reads that
        // happen for other reasons (there are none — only pickup mutates it).
        if sim.goldRemaining < before.goldRemaining {
            soundHandler(.getGold)
        }
        // Last-gold reveal flourish — `runner.js:329-334`. Fires on the
        // `!goldComplete → goldComplete` edge, but only when the runner isn't
        // already at row 0 (JS `runner.pos.y > 0`; otherwise the level-pass
        // sound is about to fire and the JS suppresses this).
        if !before.goldComplete, sim.goldComplete, sim.runner.position.y > 0 {
            soundHandler(SoundEffect.goldFinish(
                for: theme, levelIndex: session.currentLevelIndex))
        }
        // Dig start — `runner.js:496`. Fire once on the nil → non-nil edge.
        if !before.hasDigState, sim.digState != nil {
            soundHandler(.dig)
        }
        // Runner death — `main.js:1467`. Detect via `session.lives`
        // decreasing rather than sim.phase == .dead because GameSession
        // immediately replaces the sim with a fresh `.playing` one on retry,
        // so sim.phase never stays `.dead` across a tick boundary.
        if session.lives < before.lives {
            soundHandler(.dead)
        }
        // Level pass — `main.js:1534`. `passedLevelCount` is the right signal
        // for the same reason as `lives`: sim.phase transitions to
        // `.finished` inside GameSession.tick then gets replaced.
        if session.passedLevelCount > before.passedLevelCount {
            soundHandler(.pass)
        }

        // The remaining events sample sim state after the tick. Skip them if
        // the sim was replaced this tick (death or level advance): GameSession
        // seeds a fresh sim with `runner.action == .stop` and empty
        // shake/reborn queues, which would look like spurious edges.
        let simReplaced =
            session.lives < before.lives
            || session.passedLevelCount > before.passedLevelCount
        guard !simReplaced else { return }

        // Runner starts falling — `runner.js:289`, `soundPlay(soundFall)`.
        // Edge into `.fall`.
        if before.runnerAction != .fall, sim.runner.action == .fall {
            soundHandler(.fall)
        }
        // Runner lands — `runner.js:270,287`, `themeSoundPlay("down")`. Edge
        // out of `.fall`.
        if before.runnerAction == .fall, sim.runner.action != .fall {
            soundHandler(.down)
        }
        // Guard trapped in hole — `guard.js:245`. `enqueueShake` (the only
        // path that appends to `shakingGuards`) fires exactly when the guard
        // lands in the hole, so a new index in the set is the trap edge.
        let nowShaking = Set(sim.shakingGuards.map(\.guardIndex))
        if !nowShaking.subtracting(before.shakingGuardIDs).isEmpty {
            soundHandler(.trap)
        }
        // Guard reborn — `guard.js:913`. `guardReborn` appends to
        // `rebornGuards` when a buried guard respawns; new index = the edge.
        let nowReborn = Set(sim.rebornGuards.map(\.guardIndex))
        if !nowReborn.subtracting(before.rebornGuardIDs).isEmpty {
            soundHandler(.born)
        }
    }

    private struct TickSnapshot {
        let goldRemaining: Int
        let goldComplete: Bool
        let hasDigState: Bool
        let lives: Int
        let passedLevelCount: Int
        let runnerAction: RunnerAction
        let shakingGuardIDs: Set<Int>
        let rebornGuardIDs: Set<Int>

        init(session: GameSession) {
            goldRemaining = session.simulation.goldRemaining
            goldComplete = session.simulation.goldComplete
            hasDigState = session.simulation.digState != nil
            lives = session.lives
            passedLevelCount = session.passedLevelCount
            runnerAction = session.simulation.runner.action
            shakingGuardIDs = Set(session.simulation.shakingGuards.map(\.guardIndex))
            rebornGuardIDs = Set(session.simulation.rebornGuards.map(\.guardIndex))
        }
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
