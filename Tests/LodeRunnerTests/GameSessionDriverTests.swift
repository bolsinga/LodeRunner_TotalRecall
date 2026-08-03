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

    @Test("last-gold reveal fires theme-specific goldFinish sound")
    func goldFinishFiresOnLastGoldReveal() throws {
        // Walk-into-gold at (5, 14). Picking up the only piece triggers
        // `showHideLaddr`, which in the JS at `runner.js:329-334` also fires
        // `soundPlay("goldFinish"...)` — the shared clip for Apple2, one of
        // six for C64.
        let level = makeLevel(stamps: [
            (x: 5, y: 14, tile: .runner),
            (x: 6, y: 14, tile: .gold),
        ])

        // Apple2 → single shared clip.
        do {
            let session = try GameSession(levels: [level])
            let input = StubInput(currentAction: .right)
            let driver = GameSessionDriver(
                session: session, input: input, startInBornBlink: false)
            driver.theme = .apple2
            let sink = EffectSink()
            driver.soundHandler = { sink.record($0) }
            for _ in 0..<10 {
                driver.tick()
                if driver.session.simulation.goldComplete { break }
            }
            #expect(sink.effects.contains(.goldFinish))
            #expect(sink.effects.filter { $0 == .goldFinish }.count == 1)
        }

        // C64 → one of the six per-level clips (level 0 → .goldFinish1).
        do {
            let session = try GameSession(levels: [level])
            let input = StubInput(currentAction: .right)
            let driver = GameSessionDriver(
                session: session, input: input, startInBornBlink: false)
            driver.theme = .c64
            let sink = EffectSink()
            driver.soundHandler = { sink.record($0) }
            for _ in 0..<10 {
                driver.tick()
                if driver.session.simulation.goldComplete { break }
            }
            #expect(sink.effects.contains(.goldFinish1))
            #expect(!sink.effects.contains(.goldFinish))  // Apple2's clip must not fire
        }
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

    @Test("runner fall fires .fall on takeoff and .down on landing")
    func fallAndDownFireOnRunnerFallCycle() throws {
        // Runner one row above the auto-brick floor. First tick: action
        // .stop → .fall (fires .fall). Enough later ticks: runner lands on
        // (5, 14) with .brick below and action leaves .fall (fires .down).
        let level = makeLevel(stamps: [(x: 5, y: 13, tile: .runner)])
        let session = try GameSession(levels: [level])
        let input = StubInput(currentAction: .stop)
        let driver = GameSessionDriver(
            session: session, input: input, startInBornBlink: false)
        let sink = EffectSink()
        driver.soundHandler = { sink.record($0) }

        for _ in 0..<20 {
            driver.tick()
            if sink.effects.contains(.down) { break }
        }
        // .fall is edge-detected (nothing → .fall) so a fall cycle fires it
        // exactly once, not on every tick spent airborne.
        #expect(sink.effects.filter { $0 == .fall }.count == 1)
        #expect(sink.effects.contains(.down))
    }

    @Test("guard trap fires .trap; buried guard fires .born on rebirth")
    func trapAndBornFireAcrossHoleLifecycle() throws {
        // Runner at (4, 13), guard far right at (22, 13). Row 14 is all
        // brick so both walk row 13 (with brick support below); row 15 is
        // the usual auto-brick. Runner digs right → hole opens at (5, 14)
        // at t=11; fill completes ~186 ticks later at t≈197.
        //
        // The guard has to walk 17 tiles left at ~8 ticks/tile before it
        // can reach column 5, so it falls into the hole at t≈140 — firing
        // .trap via the shakingGuards delta. Guard shake runs 66 ticks
        // (ends t≈206), so the guard is still inside the hole cell at
        // t≈197 when the fill completes: `fillComplete` sees `.guard` at
        // the cell, calls `guardReborn`, which appends to `rebornGuards`
        // and fires .born. Runner stays at (4, 13); guard falls at column
        // 5 before crossing into column 4, so no collision-death.
        var stamps: [(x: Int, y: Int, tile: TileType)] = [
            (x: 4, y: 13, tile: .runner),
            (x: 22, y: 13, tile: .guard),
        ]
        for x in 0..<LevelGrid.tilesX {
            stamps.append((x: x, y: 14, tile: .brick))
        }
        let level = makeLevel(stamps: stamps)
        let session = try GameSession(levels: [level])
        let input = StubInput(currentAction: .digRight)
        let driver = GameSessionDriver(
            session: session, input: input, startInBornBlink: false)
        let sink = EffectSink()
        driver.soundHandler = { sink.record($0) }

        driver.tick()  // t=0: kick off the dig.
        input.currentAction = .stop
        for _ in 0..<300 {
            driver.tick()
            if sink.effects.contains(.born) { break }
        }
        #expect(sink.effects.contains(.trap))
        #expect(sink.effects.contains(.born))
    }

    @Test("post-transition finalize resets input so the born-blink actually blinks")
    func transitionResetsInputForBornBlink() throws {
        // Kill the runner with a still-held `.right`, then run the driver's
        // synchronous transition swap (`performTransitionSwap`, the iris-
        // fully-closed hook). Ports the JS `keyAction = ACT_STOP` reset at
        // `main.js:1355` inside `beginPlay`: without it, the latched
        // direction would lift the fresh sim's `.starting` gate on the next
        // tick and skip the blink entirely.
        let level = makeLevel(stamps: [
            (x: 5, y: 14, tile: .runner),
            (x: 6, y: 14, tile: .guard),
        ])
        let session = try GameSession(levels: [level])
        let input = StubInput(currentAction: .right)
        let driver = GameSessionDriver(
            session: session, input: input, startInBornBlink: false)

        for _ in 0..<40 {
            driver.tick()
            if case .transitioning = driver.session.phase { break }
        }
        #expect(driver.session.phase == .transitioning(.death))
        #expect(input.currentAction == .right)  // still latched from before death

        // Do the swap the async transition would perform at the iris-closed
        // instant. Verifies the fresh sim is `.starting` and the input was
        // reset (so `.stop` ticks are no-ops and the runner sits blinking).
        driver.performTransitionSwap()
        #expect(driver.session.phase == .playing)
        #expect(driver.session.simulation.phase == .starting)
        #expect(input.currentAction == .stop)
        #expect(input.resetCount == 1)
    }

    @Test("dig action is one-shot: held dig key doesn't re-fire after the hole refills")
    func digInputResetsAfterConsumption() throws {
        // Ports `runner.js:111` (`keyAction = ACT_STOP;`) — a dig is consumed
        // exactly when `moveRunner` reaches the dig case, whether or not
        // `ok2Dig` succeeds. Without the reset, a held `.digLeft` fires a
        // second dig the moment the first hole refills.
        let level = makeLevel(stamps: [
            (x: 5, y: 14, tile: .runner),
            (x: 4, y: 15, tile: .brick),  // diggable tile down-left of the runner
        ])
        let session = try GameSession(levels: [level])
        let input = StubInput(currentAction: .digLeft)
        let driver = GameSessionDriver(
            session: session, input: input, startInBornBlink: false)

        // First tick: sim reaches the dig case, sets consumedDigInput, the
        // driver resets the input. The user-visible signal is: (a) a dig
        // started, and (b) the input latched back to `.stop`.
        driver.tick()
        #expect(driver.session.simulation.digState != nil)
        #expect(input.currentAction == .stop)
        #expect(input.resetCount == 1)

        // Even if the caller re-latches `.digLeft` mid-dig (simulating a held
        // key or a fresh press), a new dig doesn't queue up once the first
        // completes and refills — because the driver keeps resetting the
        // input every time moveRunner sees the dig case.
        input.currentAction = .digLeft
        for _ in 0..<400 {
            driver.tick()
        }
        // After the fill completes, the sim should be back to no active dig,
        // and no second dig should have been started while the input was
        // ".stop" throughout the fill window.
        #expect(driver.session.simulation.digState == nil)
        #expect(driver.session.simulation.fillStates.isEmpty)
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

    @Test("performTransitionSwap resets appearances so the previous level's pose doesn't ghost in")
    func performTransitionSwapResetsAppearances() throws {
        // Same completable shape used above, laid out twice so completing
        // level 0 routes into `.scoring` and then `.transitioning
        // (.levelAdvance)` (rather than the terminal `.won` branch, which
        // never fires the swap).
        let level = makeLevel(stamps: [
            (x: 3, y: 1, tile: .runner),
            (x: 4, y: 1, tile: .gold),
            (x: 5, y: 0, tile: .ladder),
            (x: 5, y: 1, tile: .ladder),
            (x: 3, y: 2, tile: .brick),
            (x: 4, y: 2, tile: .brick),
        ])
        let session = try GameSession(levels: [level, level])
        let input = StubInput(currentAction: .stop)
        let driver = GameSessionDriver(
            session: session, input: input, startInBornBlink: false)

        // Drive to level pass. The last runner action is `.up` (climbing the
        // ladder to row 0), which caches `.runUpDn` in the appearance.
        let actions: [RunnerAction] =
            Array(repeating: .right, count: 8)
            + Array(repeating: .up, count: 5)
            + [.stop]
        for action in actions {
            input.currentAction = action
            driver.tick()
        }
        #expect(driver.runnerAppearance.lastAnimation == .runUpDn)
        // Level completion now parks in `.scoring` first (the level-pass
        // dialog animates over the frozen last frame). Dismissing the
        // dialog drops us into `.transitioning(.levelAdvance)`, which is
        // what `performTransitionSwap` expects.
        driver.dismissScoring()
        #expect(driver.session.phase == .transitioning(.levelAdvance))

        // At the iris-fully-closed instant the sim swap fires. The fresh
        // sim's runner is `.stop` at spawn — `RunnerAnimation.forRunner`
        // returns nil for `.stop`, so without the explicit reset the
        // appearance would still cache `.runUpDn` from the previous level.
        driver.performTransitionSwap()

        #expect(driver.session.simulation.runner.position == GridPoint(x: 3, y: 1))
        #expect(driver.runnerAppearance == RunnerAppearance())
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
    /// Number of times `resetAction()` was invoked — lets tests observe the
    /// driver's post-tick dig-consume behavior.
    private(set) var resetCount: Int = 0

    init(currentAction: RunnerAction) {
        self.currentAction = currentAction
    }

    func resetAction() {
        currentAction = .stop
        resetCount += 1
    }
}
