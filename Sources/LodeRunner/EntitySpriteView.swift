import SwiftUI

/// Renders a runner as an animated sprite positioned by tile + subtile offsets.
/// Position math matches `lodeRunner.runner.js:277-278` (`sprite.x = x * tileW +
/// xOffset`, ignoring the JS's `tileScale` — the port draws at 1x). Animation
/// state comes from a `RunnerAppearance`: its `lastAnimation` drives the
/// visible frame sequence, matching the JS's `runner.shape`. When
/// `runner.action == .stop`, the view freezes on the animation's first frame —
/// approximating `runner.sprite.stop()` from `runner.js:273`.
public struct RunnerSpriteView: View {
    let runner: Runner
    let appearance: RunnerAppearance

    public init(runner: Runner, appearance: RunnerAppearance) {
        self.runner = runner
        self.appearance = appearance
    }

    public var body: some View {
        EntitySprite(
            frames: appearance.lastAnimation.frames,
            framesPerSecond: appearance.lastAnimation.framesPerSecond,
            isPlaying: runner.action != .stop,
            sheet: .runner,
            position: runner.position,
            xOffset: runner.xOffset,
            yOffset: runner.yOffset
        )
    }
}

/// Renders a guard as an animated sprite, same absolute-position math as
/// `RunnerSpriteView`. `sheet` is `.guard` by default and `.redhat` when the
/// guard is a champLevel red-hat variant — same asset switch the JS makes via
/// `guard.sprite` picked in `lodeRunner.preload.js:496-497`.
public struct GuardSpriteView: View {
    let guardState: Guard
    let appearance: GuardAppearance
    let sheet: SpriteSheetSpec

    public init(
        guardState: Guard, appearance: GuardAppearance,
        sheet: SpriteSheetSpec = .guard
    ) {
        self.guardState = guardState
        self.appearance = appearance
        self.sheet = sheet
    }

    public var body: some View {
        EntitySprite(
            frames: appearance.lastAnimation.frames,
            framesPerSecond: appearance.lastAnimation.framesPerSecond,
            isPlaying: guardState.action != .stop,
            sheet: sheet,
            position: guardState.position,
            xOffset: guardState.xOffset,
            yOffset: guardState.yOffset
        )
    }

    /// Picks the guard's sprite sheet based on gold-carry state, matching
    /// `guardWearRedhat` / `guardRemoveRedhat` at `lodeRunner.guard.js:376-385`.
    /// Carrying gold (`hasGold > 0`) draws with the red-hat sheet; empty-handed
    /// guards use the default. The JS gates this on a `redhatMode` toggle at
    /// `key.js:131,172` which defaults to on — we mirror that default and
    /// defer the toggle to a future settings surface.
    public static func sheet(forHasGold hasGold: Int) -> SpriteSheetSpec {
        hasGold > 0 ? .redhat : .guard
    }
}

private struct EntitySprite: View {
    let frames: [Int]
    let framesPerSecond: Double
    let isPlaying: Bool
    let sheet: SpriteSheetSpec
    let position: GridPoint
    let xOffset: Int
    let yOffset: Int

    var body: some View {
        Group {
            if isPlaying {
                AnimatedSprite(sheet: sheet, frames: frames, framesPerSecond: framesPerSecond)
            } else {
                SpriteFrame(sheet: sheet, index: frames.first ?? 0)
            }
        }
        .offset(
            x: CGFloat(position.x * sheet.frameWidth + xOffset),
            y: CGFloat(position.y * sheet.frameHeight + yOffset)
        )
    }
}

// MARK: - Preview

private func previewLevel() -> LevelParseResult {
    // Bottom floor comes from makeLevel's auto-fill of row 15.
    var stamps: [(x: Int, y: Int, tile: TileType)] = []
    for x in 10...14 {
        stamps.append((x: x, y: 9, tile: .bar))
    }
    for y in 9...14 {
        stamps.append((x: 20, y: y, tile: .ladder))
    }
    return makeLevel(stamps: stamps)
}

/// Manually construct appearances that reflect specific action histories so we
/// can visually verify facing + last-animation caching without a tick driver:
/// the running runner cycles right, the stopped runner freezes on frame 0 of
/// its cached `runRight` last-animation (JS `sprite.stop()`), the bar guard
/// hangs left, the falling guard was last heading left before the fall.
private struct EntitySpritePreview: View {
    var body: some View {
        let level = previewLevel()
        let runningRunner = Runner(
            position: GridPoint(x: 3, y: 14), xOffset: 0, yOffset: 0, action: .right)
        let runnerAppearance = RunnerAppearance(facing: .right, lastAnimation: .runRight)

        // Stopped runner: action is .stop but the appearance's cached
        // lastAnimation is .runRight — the sprite view freezes on frame 0 of
        // runRight rather than cycling.
        let stoppedRunner = Runner(
            position: GridPoint(x: 24, y: 14), xOffset: 0, yOffset: 0, action: .stop)
        let stoppedRunnerAppearance = RunnerAppearance(facing: .right, lastAnimation: .runRight)

        let barGuard = Guard(
            position: GridPoint(x: 12, y: 9), xOffset: 0, yOffset: 0, action: .left)
        let barGuardAppearance = GuardAppearance(facing: .left, lastAnimation: .barLeft)

        let fallingGuard = Guard(
            position: GridPoint(x: 6, y: 5), xOffset: 0, yOffset: 20, action: .fall)
        let fallingGuardAppearance = GuardAppearance(facing: .left, lastAnimation: .fallLeft)

        FittedBoardView {
            ZStack(alignment: .topLeading) {
                LevelGridView(tiles: level.slots.map { $0.map(\.displayTile) })
                RunnerSpriteView(runner: runningRunner, appearance: runnerAppearance)
                RunnerSpriteView(runner: stoppedRunner, appearance: stoppedRunnerAppearance)
                GuardSpriteView(guardState: barGuard, appearance: barGuardAppearance)
                GuardSpriteView(guardState: fallingGuard, appearance: fallingGuardAppearance)
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
