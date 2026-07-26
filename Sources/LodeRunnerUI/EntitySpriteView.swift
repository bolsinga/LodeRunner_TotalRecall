import LodeRunnerCore
import SwiftUI

/// Renders a runner as an animated sprite positioned by tile + subtile offsets.
/// Position math matches `lodeRunner.runner.js:277-278`
/// (`sprite.x = x * tileW + xOffset`, ignoring the JS's `tileScale` — the port
/// draws at 1x). The animation is derived from `RunnerAnimation.forRunner`; when
/// that returns `nil` (`.stop`), falls back to the theme's static `runner1`
/// image the way `TileCellView` does.
public struct RunnerSpriteView: View {
    let runner: Runner
    let facing: RunnerAction
    let baseTile: TileType

    public init(runner: Runner, facing: RunnerAction, baseTile: TileType) {
        self.runner = runner
        self.facing = facing
        self.baseTile = baseTile
    }

    public var body: some View {
        EntitySprite(
            animation: RunnerAnimation.forRunner(
                action: runner.action, baseTile: baseTile, facing: facing
            ),
            sheet: .runner,
            idleAsset: "runner1",
            position: runner.position,
            xOffset: runner.xOffset,
            yOffset: runner.yOffset
        )
    }
}

/// Renders a guard as an animated sprite, same absolute-position math as
/// `RunnerSpriteView`. `sheet` is `.guard` by default and `.redhat` when the
/// guard is one of the champLevel red-hat variants — same asset switch the JS
/// makes via `guard.sprite` picked in `lodeRunner.preload.js:496-497`.
public struct GuardSpriteView: View {
    let guardState: Guard
    let facing: GuardAction
    let baseTile: TileType
    let sheet: SpriteSheetSpec

    public init(
        guardState: Guard, facing: GuardAction, baseTile: TileType,
        sheet: SpriteSheetSpec = .guard
    ) {
        self.guardState = guardState
        self.facing = facing
        self.baseTile = baseTile
        self.sheet = sheet
    }

    public var body: some View {
        EntitySprite(
            animation: GuardAnimation.forGuard(
                action: guardState.action, baseTile: baseTile, facing: facing
            ),
            sheet: sheet,
            idleAsset: "guard1",
            position: guardState.position,
            xOffset: guardState.xOffset,
            yOffset: guardState.yOffset
        )
    }
}

private struct EntitySprite<Animation>: View
where Animation: RawRepresentable, Animation.RawValue == String {
    @Environment(\.tileTheme) private var theme

    let animation: Animation?
    let sheet: SpriteSheetSpec
    let idleAsset: String
    let position: GridPoint
    let xOffset: Int
    let yOffset: Int

    var body: some View {
        Group {
            if let animation, let frames = frameSequence(for: animation) {
                AnimatedSprite(
                    sheet: sheet,
                    frames: frames.indices,
                    framesPerSecond: frames.framesPerSecond
                )
            } else {
                Image("\(theme.rawValue)/\(idleAsset)", bundle: .module)
                    .resizable()
                    .frame(
                        width: CGFloat(sheet.frameWidth),
                        height: CGFloat(sheet.frameHeight))
            }
        }
        .offset(
            x: CGFloat(position.x * sheet.frameWidth + xOffset),
            y: CGFloat(position.y * sheet.frameHeight + yOffset)
        )
    }

    private struct FrameSequence {
        let indices: [Int]
        let framesPerSecond: Double
    }

    private func frameSequence(for animation: Animation) -> FrameSequence? {
        if let runner = animation as? RunnerAnimation {
            return FrameSequence(indices: runner.frames, framesPerSecond: runner.framesPerSecond)
        }
        if let guardAnim = animation as? GuardAnimation {
            return FrameSequence(
                indices: guardAnim.frames, framesPerSecond: guardAnim.framesPerSecond)
        }
        return nil
    }
}

// MARK: - Preview

private func previewLevel() -> LevelParseResult {
    var cells = Array(repeating: Character(" "), count: LevelGrid.tileCount)
    // Solid floor row and a couple of platforms
    for x in 0..<LevelGrid.tilesX {
        cells[(LevelGrid.tilesY - 1) * LevelGrid.tilesX + x] = "#"
    }
    // A bar spanning a few columns
    for x in 10...14 {
        cells[9 * LevelGrid.tilesX + x] = "-"
    }
    // A ladder
    for y in 9...14 {
        cells[y * LevelGrid.tilesX + 20] = "H"
    }
    return resolveLevelMap(String(cells))
}

private struct EntitySpritePreview: View {
    var body: some View {
        let level = previewLevel()
        let runningRunner = Runner(
            position: GridPoint(x: 3, y: 14), xOffset: 0, yOffset: 0, action: .right)
        let barGuard = Guard(
            position: GridPoint(x: 12, y: 9), xOffset: 0, yOffset: 0, action: .left)
        let fallingGuard = Guard(
            position: GridPoint(x: 6, y: 5), xOffset: 0, yOffset: 20, action: .fall)

        FittedBoardView {
            ZStack(alignment: .topLeading) {
                LevelGridView(tiles: level.slots.map { $0.map(\.current) })
                RunnerSpriteView(
                    runner: runningRunner, facing: .right,
                    baseTile: level.slots[3][14].base)
                GuardSpriteView(
                    guardState: barGuard, facing: .left,
                    baseTile: level.slots[12][9].base)
                GuardSpriteView(
                    guardState: fallingGuard, facing: .left,
                    baseTile: level.slots[6][5].base)
            }
        }
        .background(Color.gray.opacity(0.2))
        .border(Color.gray)
    }
}

#Preview("Entities — Apple2", traits: .landscapeLeft) {
    EntitySpritePreview().environment(\.tileTheme, .apple2)
}

#Preview("Entities — C64", traits: .landscapeLeft) {
    EntitySpritePreview().environment(\.tileTheme, .c64)
}
