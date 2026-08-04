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
    @Environment(\.tileTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    /// Called when the runner runs out of lives. Callers embedded in a
    /// `NavigationStack` can leave this `nil` — the game-over overlay falls
    /// back to `@Environment(\.dismiss)`, which pops the destination. Callers
    /// that host GameView as an overlay-toggled child (e.g. `PackChooserView`
    /// with a pack-picker overlay) pass a closure that clears their own state
    /// so the picker re-appears.
    private let onExit: (() -> Void)?
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
        onExit: (() -> Void)? = nil,
        onLevelPassed: ((_ levelIndex: Int, _ score: Int) -> Int?)? = nil
    ) {
        _driver = State(initialValue: GameSessionDriver(session: session))
        self.onExit = onExit
        self.onLevelPassed = onLevelPassed
    }

    public var body: some View {
        // A single FittedBoardView for both playfield and HUD so they share
        // one uniform scale factor — matching the JS's single `mainStage`
        // canvas with everything at pixel coordinates, rather than laying
        // them out with independent SwiftUI frames.
        FittedBoardView(boardHeight: Self.combinedBoardHeight) {
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    LevelGridView(tiles: entityLessTiles(driver.session.simulation.slots))
                    if let dig = driver.session.simulation.digState {
                        DigSpriteView(digState: dig)
                    }
                    ForEach(Array(driver.session.simulation.fillStates.enumerated()), id: \.offset) { _, fill in
                        FillSpriteView(fillState: fill)
                    }
                    runnerView
                    ForEach(Array(driver.session.simulation.guards.enumerated()), id: \.offset) { index, guardState in
                        guardView(index: index, guardState: guardState)
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
                    if driver.session.phase == .gameOver {
                        // Analog to JS `showCoverPage()` at `main.js:1522`
                        // (the terminal step of the `GAME_OVER` state): after
                        // the flip finishes, hand control back to the caller
                        // (chooser overlay or NavigationStack pop).
                        GameOverOverlay(onFinished: {
                            if let onExit { onExit() } else { dismiss() }
                        })
                    }
                    // Level-pass scoring dialog — port of `levelPass.open()`
                    // at `main.js:1581`. Sits between the sim's `.finished`
                    // tick and the iris-close wipe so the count-up animates
                    // over the frozen last frame of the passed level.
                    if case .scoring(let summary) = driver.session.phase {
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
                    score: driver.session.score + driver.session.simulation.score,
                    lives: driver.session.lives,
                    level: driver.session.currentLevelIndex + 1
                )
            }
        }
        .background(Color.black)
        .keyboardInput(keyboard)
        .task {
            driver.input = keyboard
            sound.theme = theme
            driver.theme = theme
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
    private func entityLessTiles(_ slots: [[LevelSlot]]) -> [[TileType]] {
        slots.map { column in
            column.map { slot in
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
