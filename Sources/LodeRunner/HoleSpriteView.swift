import SwiftUI

/// Renders the double-tall dig-in-progress sprite over a `DigState`. The
/// animation frame is derived from the sim's tick-count progression: 11 sim
/// ticks (the `digAnimationFrameCount` private constant in
/// `RunnerSimulation.swift`, matching the JS `digHoleLeft`/`Right` animation
/// duration at DIG_SPEED × 11) map to 8 hole-sheet frames. The overlay sits at
/// `pos.x * tileWidth`, `pos.y * tileHeight` — 40×88, spanning the runner's
/// row and the brick row below.
public struct DigSpriteView: View {
    let digState: DigState

    public init(digState: DigState) {
        self.digState = digState
    }

    public var body: some View {
        let baseFrame = digState.direction == .digLeft ? 0 : 8
        // Map sim's 11-tick dig duration onto the 8-frame sheet animation. Clamp
        // to the last frame if we somehow overshoot before `digComplete` fires.
        let progressFrame = min(digState.frameIndex * 8 / 11, 7)
        HoleFrame(baseFrame + progressFrame)
            .offset(
                x: CGFloat(digState.pos.x * TileGeometry.tileWidth),
                y: CGFloat(digState.pos.y * TileGeometry.tileHeight)
            )
    }
}

/// Renders the single-tile refill sprite over a `FillState`. The sim's
/// `frameIndex` (0-3) maps 1:1 onto hole-sheet frames 16-19 — same fill stages
/// the JS's `fillHole` animation uses (`lodeRunner.preload.js:514-517`). The
/// per-stage sim tick duration is `fillFrameDurations = [166, 8, 8, 4]` in
/// `RunnerSimulation.swift`, which corresponds to the JS's 45-repeat-then-fill
/// pattern.
public struct FillSpriteView: View {
    let fillState: FillState

    public init(fillState: FillState) {
        self.fillState = fillState
    }

    public var body: some View {
        HoleFrame(16 + fillState.frameIndex)
            .offset(
                x: CGFloat(fillState.position.x * TileGeometry.tileWidth),
                y: CGFloat(fillState.position.y * TileGeometry.tileHeight)
            )
    }
}

// MARK: - Preview

private func digPreviewSimulation() throws -> RunnerSimulation {
    // Runner spawn at (5, 14) — bottom floor bricks at row 15 come from
    // makeLevel's auto-fill, so digRight is immediately valid and the cycle
    // can loop.
    let level = resolveLevelMap(
        makeLevel(stamps: [
            (x: 5, y: 14, tile: .runner),
        ]))
    return try RunnerSimulation(level: level)
}

private struct DiggingRunnerPreview: View {
    @State private var driver: SimulationDriver

    init() {
        let sim = try! digPreviewSimulation()
        _driver = State(initialValue: SimulationDriver(simulation: sim))
    }

    var body: some View {
        FittedBoardView {
            ZStack(alignment: .topLeading) {
                LevelGridView(tiles: driver.simulation.slots.map { $0.map(\.current) })
                RunnerSpriteView(
                    runner: driver.simulation.runner,
                    appearance: driver.runnerAppearance
                )
                if let digState = driver.simulation.digState {
                    DigSpriteView(digState: digState)
                }
                ForEach(Array(driver.simulation.fillStates.enumerated()), id: \.offset) { _, fill in
                    FillSpriteView(fillState: fill)
                }
            }
        }
        .background(Color.gray.opacity(0.2))
        .border(Color.gray)
        .task {
            driver.currentAction = .digRight
            await driver.run()
        }
    }
}

#Preview("Digging runner — Apple2", traits: .landscapeLeft) {
    DiggingRunnerPreview().environment(\.tileTheme, .apple2)
}

#Preview("Digging runner — C64", traits: .landscapeLeft) {
    DiggingRunnerPreview().environment(\.tileTheme, .c64)
}
