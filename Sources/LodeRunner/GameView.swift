import SwiftUI

/// Composed live game screen: playfield on top (level grid, dig/fill
/// overlays, runner + guards + reborn guards), HUD row underneath — matching
/// the JS's `infoY = (NO_OF_TILES_Y * BASE_TILE_Y + GROUND_TILE_Y) * tileScale`
/// at `lodeRunner.main.js:656`, which anchors `SCORE`/`MEN`/`LEVEL` below the
/// playfield. Plus the three transition overlays (`LevelStartOverlay`,
/// `LevelPassOverlay`, `GameOverOverlay`). Owns a `GameSessionDriver` and a
/// `KeyboardInput`, so it's the first place in the port where all
/// previously-shipped pieces run together against a real 30 Hz tick loop.
///
/// Corresponds to the outer `PLAY_CLASSIC` frame at `lodeRunner.main.js`'s
/// mainTick / draw split — sim work goes through the driver, transition art
/// is layered as ZStack siblings gated on `simulation.phase` / `session.phase`.
public struct GameView: View {
    @State private var driver: GameSessionDriver
    @State private var keyboard = KeyboardInput()
    @State private var sound = SoundPlayer()
    /// Present in demo mode. Held in `@State` (rather than reconstructed
    /// per render) so the driver keeps a stable reference across body
    /// re-evaluations while playback runs.
    @State private var demoInput: DemoInput?
    @Environment(\.tileTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    /// Called when the runner runs out of lives. Callers embedded in a
    /// `NavigationStack` can leave this `nil` — the game-over overlay falls
    /// back to `@Environment(\.dismiss)`, which pops the destination. Callers
    /// that host GameView as an overlay-toggled child (e.g. `PackChooserView`
    /// with a pack-picker overlay) pass a closure that clears their own state
    /// so the picker re-appears.
    ///
    /// Callers that also want to route into a leaderboard overlay before
    /// clearing state can provide `onGameOver` instead — when set, it fires
    /// with the final score + 1-based level reached and `onExit` is *not*
    /// called (the leaderboard host takes over the return path).
    private let onExit: (() -> Void)?
    private let onGameOver: ((_ finalScore: Int, _ levelReached: Int, _ isWinner: Bool) -> Void)?
    /// Bindings to the host's persisted `@AppStorage` values. Bindings
    /// (not plain values) so in-game hotkeys can mutate them — the Ctrl+S
    /// / Ctrl+minus / Ctrl+= / Ctrl+T tips shortcuts flip these and the
    /// change propagates back up to the pack chooser's SettingsOverlay.
    @Binding private var soundEnabled: Bool
    @Binding private var speedIndex: Int
    @Binding private var hudMode: HUDMode

    /// Local controller for the "SOUND ON", "FAST", "TRAINING OFF"…
    /// flash-messages that appear when a hotkey mutates a setting.
    /// Ports JS `showTipsText` at `main.js:993`.
    @State private var tips = TipsController()

    /// Whether gameplay is paused. Host toggles this when an overlay
    /// (menu, settings, leaderboard…) opens over the running game so
    /// the sim freezes instead of ticking beneath the modal.
    private let isPaused: Bool
    /// Fires when the player taps the top-right grid icon. Analog of JS
    /// `boardIcons.js:96,125-140`'s `chooseLevel()` which pops the level
    /// picker. Only shown when Training is on (`hudMode == .modern`);
    /// `nil` hides the button entirely.
    private let onOpenLevelPicker: (() -> Void)?
    /// When non-nil, this GameView is the demo-playback screen for the
    /// given record. Ports the JS `PLAY_DEMO_ONCE` mode at `main.js:82`.
    /// Presence swaps the driver's input from `KeyboardInput` to a
    /// `DemoInput` created here, and enables the "any-key stops demo"
    /// keyboard hook (JS `anyKeyStopDemo` at `demo.js:273-280`).
    private let demoRecord: DemoRecord?
    /// Fires when demo playback ends — either the recorded run finished,
    /// the runner died, the player pressed any key, or the player tapped
    /// the stop-demo button. Non-nil only in demo mode. Composition layer
    /// clears its demo state and reverts to the underlying Training game.
    private let onDemoEnd: (() -> Void)?
    /// 0-based level indices with a bundled demo for the running pack.
    /// Used only in Training mode to gate the "watch demo" button on the
    /// current level having a recording. Empty set = button never shows.
    /// JS `boardIcons.js:159`'s `curDemoLevelIsVaild()` disable path.
    private let demoLevelIndices: Set<Int>
    /// Fires when the player taps the "watch demo" button. Receives the
    /// current 0-based level index so the host can look up the right
    /// record. Nil hides the button (used when Training is off).
    private let onStartDemo: ((_ levelIndex: Int) -> Void)?
    /// Optional per-level score lookup + record hook. Called with the just-
    /// finished level's 0-based index and its per-level `bonusScore`; return
    /// value is the *previous* best for that level (so `LevelPassDialog` can
    /// show it as HI-SCORE), or `nil` if there's no prior record. `nil`
    /// closure disables score persistence and the HI-SCORE row entirely —
    /// useful for tests and standalone previews that don't own a store.
    private let onLevelPassed: ((_ levelIndex: Int, _ score: Int) -> Int?)?

    /// Cached "hi-score before this level's completion", captured at the
    /// `.scoring` entry via the `onLevelPassed` hook so the dialog can show
    /// it without dividing responsibility over who reads the store when.
    @State private var pendingPreviousBest: Int?
    /// Guard so `onLevelPassed` fires exactly once per `.scoring` phase
    /// (the phase equality check in `.onChange` won't cover level-1 →
    /// level-1 re-entries after game over on the same level).
    @State private var lastRecordedLevelNumber: Int?

    public init(
        session: GameSession,
        soundEnabled: Binding<Bool> = .constant(true),
        speedIndex: Binding<Int> = .constant(GameSpeed.defaultIndex),
        hudMode: Binding<HUDMode> = .constant(.classic),
        isPaused: Bool = false,
        onExit: (() -> Void)? = nil,
        onLevelPassed: ((_ levelIndex: Int, _ score: Int) -> Int?)? = nil,
        onGameOver: ((_ finalScore: Int, _ levelReached: Int, _ isWinner: Bool) -> Void)? = nil,
        onOpenLevelPicker: (() -> Void)? = nil,
        demoRecord: DemoRecord? = nil,
        onDemoEnd: (() -> Void)? = nil,
        demoLevelIndices: Set<Int> = [],
        onStartDemo: ((_ levelIndex: Int) -> Void)? = nil
    ) {
        _driver = State(initialValue: GameSessionDriver(session: session))
        _soundEnabled = soundEnabled
        _speedIndex = speedIndex
        _hudMode = hudMode
        self.isPaused = isPaused
        self.onExit = onExit
        self.onLevelPassed = onLevelPassed
        self.onGameOver = onGameOver
        self.onOpenLevelPicker = onOpenLevelPicker
        self.demoRecord = demoRecord
        self.onDemoEnd = onDemoEnd
        self.demoLevelIndices = demoLevelIndices
        self.onStartDemo = onStartDemo
    }

    public var body: some View {
        VStack(spacing: 0) {
            exitBar
            gameBody
        }
        .overlay(TipsOverlay(controller: tips))
        .background(hotkeyButtons)
        .background(Color.black)
        .keyboardInput(keyboard)
        .task {
            if let demoRecord {
                let di = DemoInput(record: demoRecord)
                demoInput = di
                driver.input = di
                // JS `anyKeyStopDemo` (`demo.js:273-280`): every key press
                // routes to `stopDemoAndPlay`. Route the same way here so
                // any keyboard input during playback tears the demo down.
                keyboard.onAnyKeyPress = { [onDemoEnd] in onDemoEnd?() }
            } else {
                driver.input = keyboard
                keyboard.onAnyKeyPress = nil
            }
            sound.theme = theme
            sound.isEnabled = soundEnabled
            driver.theme = theme
            driver.tickPeriod = GameSpeed.tickPeriod(for: speedIndex)
            driver.isPaused = isPaused
            driver.soundHandler = { [sound] effect in
                // Landing/death/level-pass all cut the fall clip in the JS
                // (`runner.js:269,286`, `main.js:1465,1615,1621`). fall.mp3 is
                // ~4s, so without this it rings well past the actual fall.
                switch effect {
                case .down, .dead, .pass: sound.stop(.fall)
                default: break
                }
                sound.play(effect)
            }
            await driver.run()
        }
        .onChange(of: theme) { _, newValue in
            sound.theme = newValue
            driver.theme = newValue
        }
        .onChange(of: soundEnabled) { _, newValue in
            sound.isEnabled = newValue
        }
        .onChange(of: speedIndex) { _, newValue in
            driver.tickPeriod = GameSpeed.tickPeriod(for: newValue)
        }
        .onChange(of: isPaused) { _, newValue in
            driver.isPaused = newValue
        }
        .onChange(of: driver.session.phase) { _, newValue in
            // Fire the score-record hook exactly once at each `.scoring`
            // entry. Compare against `lastRecordedLevelNumber` because
            // successive attempts of the same level would produce the same
            // phase value on retry — SwiftUI's `.onChange` wouldn't
            // otherwise re-fire.
            if case .scoring(let summary) = newValue,
                lastRecordedLevelNumber != summary.levelNumber
            {
                lastRecordedLevelNumber = summary.levelNumber
                pendingPreviousBest = onLevelPassed?(
                    summary.levelNumber - 1, summary.bonusScore)
            } else if case .playing = newValue {
                // Reset the once-per-scoring guard so the *next* level's
                // pass fires the hook. Also clear the cached previous best
                // so a stale value can't leak into the next dialog.
                pendingPreviousBest = nil
                lastRecordedLevelNumber = nil
            }
            // Demo mode: any terminal-ish phase ends playback. `.scoring`
            // = level passed, `.gameOver` = died with 1 life, `.won` =
            // pack cleared. JS equivalents fire `stopDemoAndPlay` at
            // `demo.js:282` from the same events.
            if demoRecord != nil {
                switch newValue {
                case .scoring, .gameOver, .won:
                    onDemoEnd?()
                default:
                    break
                }
            }
        }
    }

    /// Slim strip above the game frame. Hamburger menu on the left (JS
    /// settings toggle at `boardIcons.js:8`); training-mode-only board
    /// icons on the right (JS `boardIcons.js:148-170` — the grid opens
    /// the level picker, and a play/stop demo icon would sit next to it
    /// once attract-mode demos are ported). Sits outside the
    /// `FittedBoardView` so it doesn't compete with gameplay pixels.
    private var exitBar: some View {
        HStack {
            Button {
                triggerExit()
            } label: {
                Text("☰")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.yellow)
                    .frame(width: 34, height: 26)
                    .overlay(Rectangle().stroke(Color.yellow, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Menu")

            Spacer()

            // Training-only board icons (JS `boardIcons.js:150,154`:
            // `training = (playMode == PLAY_MODERN)` gates visibility).
            // Also stays visible in demo mode (`watching` in
            // `boardIcons.js:151,158`) so the stop-demo button has a home.
            if hudMode == .modern || demoRecord != nil {
                if let onOpenLevelPicker {
                    Button(action: onOpenLevelPicker) {
                        // Same 2×2 grid glyph as the JS `SVG_GRID` at
                        // `boardIcons.js:18-26`, dropped into a monospaced
                        // caption instead of an SVG since the port has no
                        // themed icon layer yet.
                        Text("⊞")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(.yellow)
                            .frame(width: 34, height: 26)
                            .overlay(Rectangle().stroke(Color.yellow, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Choose level")
                }
                demoButton
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black)
    }

    /// Play (▶) / Stop (■) demo icon. Always visible in Training mode
    /// (or while a demo is running); enabled whenever the pack has any
    /// bundled recording. Clicking hands the current level index to the
    /// host, which finds the nearest valid demo — matching JS
    /// `getValidDemoLevel` at `demo.js:202-207` — so the player doesn't
    /// have to first navigate onto a demo-having level.
    @ViewBuilder
    private var demoButton: some View {
        if demoRecord != nil, let onDemoEnd {
            iconButton("■", label: "Stop demo", enabled: true, action: onDemoEnd)
        } else if let onStartDemo {
            let hasAnyDemo = !demoLevelIndices.isEmpty
            iconButton("▶", label: "Watch demo", enabled: hasAnyDemo) {
                onStartDemo(driver.session.currentLevelIndex)
            }
        }
    }

    private func iconButton(
        _ glyph: String, label: String, enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(glyph)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(enabled ? .yellow : .white.opacity(0.35))
                .frame(width: 34, height: 26)
                .overlay(
                    Rectangle().stroke(
                        enabled ? Color.yellow : Color.white.opacity(0.35),
                        lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    /// User-initiated menu open: unmounts the current game session and
    /// returns to the pack chooser overlay (which now doubles as the
    /// menu, per JS `boardIcons.js`'s hamburger flow). Also fires on
    /// Ctrl+R from `hotkeyButtons`.
    private func triggerExit() {
        if let onExit {
            onExit()
        } else {
            dismiss()
        }
    }

    private var gameBody: some View {
        // A single FittedBoardView for both playfield and HUD so they share
        // one uniform scale factor — matching the JS's single `mainStage`
        // canvas with everything at pixel coordinates, rather than laying
        // them out with independent SwiftUI frames.
        FittedBoardView(boardHeight: Self.combinedBoardHeight) {
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    LevelGridView(tiles: entityLessTiles(
                        driver.session.simulation.slots,
                        fillStates: driver.session.simulation.fillStates))
                    if let dig = driver.session.simulation.digState {
                        DigSpriteView(digState: dig)
                    }
                    runnerView
                    ForEach(Array(driver.session.simulation.guards.enumerated()), id: \.offset) { index, guardState in
                        guardView(index: index, guardState: guardState)
                    }
                    // Fill sprites render *above* runner + guards so the
                    // player sees bricks refilling around whoever's still in
                    // the hole. Matches the JS `moveChild2Top(fillHoleObj)`
                    // pass at `runner.js:636`, which lifts every active fill
                    // sprite over the entity layer each tick.
                    ForEach(Array(driver.session.simulation.fillStates.enumerated()), id: \.offset) { _, fill in
                        FillSpriteView(fillState: fill)
                    }
                    // Initial-level opening reveal (`armBornBlink` path) and
                    // mid-game post-transition opening reveal share the same
                    // JS `openingScreen` (`main.js:1304-1319`).
                    if driver.session.simulation.phase == .starting
                        || driver.transitionPhase == .opening {
                        LevelStartOverlay()
                    }
                    // Mid-game closing wipe over the last frame of the old
                    // level (`main.js:1195-1206`). Driven by the driver's
                    // transition state, not the sim's own `.finished` phase,
                    // because the sim now sits in that terminal state until
                    // `finalizeTransition()` fires at fully-black.
                    if driver.transitionPhase == .closing {
                        LevelPassOverlay()
                    }
                    if driver.session.phase == .gameOver, demoRecord == nil {
                        // Analog to JS `showCoverPage()` at `main.js:1522`
                        // (the terminal step of the `GAME_OVER` state): after
                        // the flip finishes, hand control back to the caller.
                        // `onGameOver` wins over `onExit` — the leaderboard
                        // host takes over the return path so it can show a
                        // hi-score screen before clearing state.
                        // Demo mode skips the flip: the phase change fires
                        // `onDemoEnd` directly in `.onChange(of: session.phase)`.
                        GameOverOverlay(onFinished: {
                            if let onGameOver {
                                onGameOver(
                                    driver.session.score,
                                    driver.session.currentLevelIndex + 1,
                                    /* isWinner: */ false)
                            } else if let onExit {
                                onExit()
                            } else {
                                dismiss()
                            }
                        })
                    }
                    // Session `.won` — JS `main.js:1659-1665` skips the
                    // GAME_OVER flip and routes straight to the leaderboard
                    // with `winner: 1`. Same path here; `onGameOver` fires
                    // immediately, no overlay needed.
                    if driver.session.phase == .won, demoRecord == nil {
                        Color.clear.task {
                            onGameOver?(
                                driver.session.score,
                                driver.session.levels.count,
                                /* isWinner: */ true)
                        }
                    }
                    // Level-pass scoring dialog — port of `levelPass.open()`
                    // at `main.js:1581`. Sits between the sim's `.finished`
                    // tick and the iris-close wipe so the count-up animates
                    // over the frozen last frame of the passed level.
                    // Demo mode skips the dialog: `.scoring` fires `onDemoEnd`
                    // directly and the demo unmounts before the count-up.
                    if case .scoring(let summary) = driver.session.phase,
                        demoRecord == nil
                    {
                        LevelPassDialog(
                            summary: summary,
                            hiScore: pendingPreviousBest,
                            onSound: { [sound] effect in sound.play(effect) },
                            onReady: { driver.armScoringInput() },
                            onDismiss: { driver.dismissScoring() }
                        )
                    }
                }
                ScoreHUD(
                    mode: hudMode,
                    score: driver.session.score + driver.session.simulation.score,
                    lives: driver.session.lives,
                    level: driver.session.currentLevelIndex + 1,
                    // Modern-HUD stats are all per-level, matching JS's
                    // `curGetGold`/`curGuardDeadNo`/`curTime` at
                    // `main.js:664,84` (reset each level in
                    // `initModernVariable`). Gold collected = the level's
                    // starting gold count minus what's still on the board.
                    goldCollected: currentLevelGoldCount
                        - driver.session.simulation.goldRemaining,
                    guardsTrapped: driver.session.simulation.guardsTrappedCount,
                    secondsElapsed: driver.session.simulation.secondsElapsed
                )
            }
        }
    }

    @ViewBuilder
    private var runnerView: some View {
        let sprite = RunnerSpriteView(
            runner: driver.session.simulation.runner,
            appearance: driver.runnerAppearance
        )
        if driver.session.simulation.phase == .starting {
            sprite.runnerBornBlink()
        } else {
            sprite
        }
    }

    @ViewBuilder
    private func guardView(index: Int, guardState: Guard) -> some View {
        if let reborn = driver.session.simulation.rebornGuards.first(where: { $0.guardIndex == index }) {
            GuardRebornSpriteView(guardState: guardState, rebornState: reborn)
        } else {
            GuardSpriteView(
                guardState: guardState,
                appearance: driver.guardAppearances[index],
                sheet: GuardSpriteView.sheet(forHasGold: guardState.hasGold)
            )
        }
    }

    /// Hidden Button carriers for the in-game keyboard shortcuts that
    /// mutate persisted settings + flash a tip. SwiftUI's
    /// `.keyboardShortcut` only attaches to `Button`s; parking them in
    /// `.hidden()` inside a `.background` view keeps them focusable-for-
    /// shortcuts without contributing anything visible.
    ///
    /// Ports JS `key.js` toggles at:
    /// - Ctrl+S — sound (`key.js:66`, tip "SOUND ON/OFF" @ 1500 ms)
    /// - Ctrl+minus — slower (`key.js:206-208`, tip = speed label)
    /// - Ctrl+= — faster (same handler with `+1` delta)
    /// - Ctrl+T — training / HUD mode (JS `settings.js:147`; the JS's
    ///   Training toggle only lives in the settings modal there, but a
    ///   hotkey feels right in the port since we already have Ctrl+S)
    private var hotkeyButtons: some View {
        Group {
            Button("") {
                soundEnabled.toggle()
                tips.show(soundEnabled ? "SOUND ON" : "SOUND OFF")
            }
            .keyboardShortcut("s", modifiers: .control)

            Button("") {
                speedIndex = max(0, speedIndex - 1)
                tips.show(GameSpeed.label(for: speedIndex))
            }
            .keyboardShortcut("-", modifiers: .control)

            Button("") {
                speedIndex = min(GameSpeed.stepCount - 1, speedIndex + 1)
                tips.show(GameSpeed.label(for: speedIndex))
            }
            .keyboardShortcut("=", modifiers: .control)

            Button("") {
                hudMode = (hudMode == .modern) ? .classic : .modern
                tips.show(hudMode == .modern ? "TRAINING ON" : "TRAINING OFF")
            }
            .keyboardShortcut("t", modifiers: .control)

            // Ctrl+R — abort game, back to pack chooser (JS `key.js:93`
            // "End game — back to demo"). Routes through `onExit`, not
            // `onGameOver`, so a user-cancelled run doesn't hit the
            // leaderboard.
            Button("") {
                triggerExit()
            }
            .keyboardShortcut("r", modifiers: .control)
        }
        .hidden()
    }

    /// Starting gold count on the current level. Read directly from
    /// `session.levels[currentLevelIndex]` — the parse-time count doesn't
    /// change during play, so pairing it with `simulation.goldRemaining`
    /// gives the number the runner has picked up so far.
    private var currentLevelGoldCount: Int {
        let idx = driver.session.currentLevelIndex
        guard driver.session.levels.indices.contains(idx) else { return 0 }
        return driver.session.levels[idx].goldCount
    }

    /// Playfield rows + one HUD row. Matches the JS layout where `infoY` sits
    /// directly below the playfield (`main.js:656`); the JS's extra
    /// `GROUND_TILE_Y` strip between them is a display detail we skip so the
    /// HUD sits flush against the board.
    private static let combinedBoardHeight = CGFloat(
        (LevelGrid.tilesY + 1) * TileGeometry.tileHeight
    )

    /// Same entity-strip pass as `SimulationDriver`'s preview: replace
    /// `.runner`/`.guard` with `.base` so `TileCellView`'s static entity tile
    /// doesn't ghost behind the overlaid sprite views during mid-tile motion,
    /// and let `LevelSlot.displayTile` handle everything else (including the
    /// `.gold` `.base`/`.empty` `.current` split).
    ///
    /// Cells with an active `FillState` render as `.empty` even when an
    /// entity is standing there — otherwise the base `.brick` would draw
    /// behind the runner/guard, hiding the refilling hole. The overlaid
    /// `FillSpriteView`s render the actual fill frames on top.
    private func entityLessTiles(
        _ slots: [[LevelSlot]],
        fillStates: [FillState]
    ) -> [[TileType]] {
        let fillCells = Set(fillStates.map { $0.position })
        return slots.enumerated().map { x, column in
            column.enumerated().map { y, slot in
                if fillCells.contains(GridPoint(x: x, y: y)) {
                    return .empty
                }
                if slot.current == .runner || slot.current == .guard {
                    return slot.base
                }
                return slot.displayTile
            }
        }
    }
}

// MARK: - Preview

/// Full 150-level classic pack, loaded from the bundled `Levels/classic.txt`
/// so the preview shows the real game rather than a synthetic layout.
private func previewSession() throws -> GameSession {
    try GameSession(levels: LevelPack.classic.load())
}

#Preview("Game view — Apple2", traits: .landscapeLeft) {
    GameView(session: try! previewSession()).environment(\.tileTheme, .apple2)
}

#Preview("Game view — C64", traits: .landscapeLeft) {
    GameView(session: try! previewSession()).environment(\.tileTheme, .c64)
}
