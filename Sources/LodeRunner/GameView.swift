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

    public init(session: GameSession) {
        _driver = State(initialValue: GameSessionDriver(session: session))
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
                        // the flip finishes, dismiss back to `PackChooserView`.
                        GameOverOverlay(onFinished: { dismiss() })
                    }
                    // Level-pass scoring dialog — port of `levelPass.open()`
                    // at `main.js:1581`. Sits between the sim's `.finished`
                    // tick and the iris-close wipe so the count-up animates
                    // over the frozen last frame of the passed level.
                    if case .scoring(let summary) = driver.session.phase {
                        LevelPassDialog(
                            summary: summary,
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
