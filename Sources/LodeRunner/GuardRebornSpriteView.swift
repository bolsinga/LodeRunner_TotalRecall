import SwiftUI

/// Renders a guard mid-respawn at the correct static sprite frame for its
/// `RebornState.frameIndex`. A port of `processReborn`'s
/// `curGuard.sprite.gotoAndStop(rebornFrame[curFrameIdx])` at
/// `lodeRunner.guard.js:940, 959`: the JS holds a single frame per step
/// and only advances when the sim tick counter crosses the per-frame
/// threshold (`rebornTime = [6, 2]` at `guard.js:927`). The visible frame
/// is therefore entirely sim-driven — no SwiftUI-side animation timer —
/// which is why this view uses a static `SpriteFrame` rather than
/// `AnimatedSprite`.
///
/// Frame schedule (matching `rebornFrame` at `guard.js:926`):
/// - `frameIndex == 0` → sprite frame 28, held for 6 sim ticks
/// - `frameIndex == 1` → sprite frame 29, held for 2 sim ticks
///
/// Callers show this instead of `GuardSpriteView` when they've located a
/// matching `RebornState` for the guard — typically by looking up the guard
/// index in `RunnerSimulation.rebornGuards`. Once the sim removes the
/// `RebornState` (transitioning the guard back to `.fall`), callers switch
/// back to `GuardSpriteView`.
public struct GuardRebornSpriteView: View {
    let guardState: Guard
    let rebornState: RebornState
    let sheet: SpriteSheetSpec

    public init(
        guardState: Guard, rebornState: RebornState,
        sheet: SpriteSheetSpec = .guard
    ) {
        self.guardState = guardState
        self.rebornState = rebornState
        self.sheet = sheet
    }

    public var body: some View {
        SpriteFrame(
            sheet: sheet,
            index: Self.frameIndex(forRebornStep: rebornState.frameIndex)
        )
        .offset(
            x: CGFloat(guardState.position.x * sheet.frameWidth + guardState.xOffset),
            y: CGFloat(guardState.position.y * sheet.frameHeight + guardState.yOffset)
        )
    }

    /// JS `rebornFrame = [28, 29]` at `lodeRunner.guard.js:926`. Indexed by
    /// `RebornState.frameIndex`. Clamps out-of-range values to the last frame
    /// — the sim removes the state before `frameIndex` reaches
    /// `jsRebornFrames.count`, so this is defensive only.
    public static let jsRebornFrames: [Int] = [28, 29]

    static func frameIndex(forRebornStep step: Int) -> Int {
        let clamped = max(0, min(step, jsRebornFrames.count - 1))
        return jsRebornFrames[clamped]
    }
}

// MARK: - Preview

private struct GuardRebornSpritePreview: View {
    var body: some View {
        let step0Guard = Guard(
            position: GridPoint(x: 6, y: 1), xOffset: 0, yOffset: 0, action: .reborn)
        let step0State = RebornState(guardIndex: 0, frameIndex: 0, frameTime: 0)

        let step1Guard = Guard(
            position: GridPoint(x: 14, y: 1), xOffset: 0, yOffset: 0, action: .reborn)
        let step1State = RebornState(guardIndex: 1, frameIndex: 1, frameTime: 0)

        FittedBoardView {
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(
                        width: CGFloat(LevelGrid.tilesX * TileGeometry.tileWidth),
                        height: CGFloat(LevelGrid.tilesY * TileGeometry.tileHeight)
                    )
                GuardRebornSpriteView(guardState: step0Guard, rebornState: step0State)
                GuardRebornSpriteView(guardState: step1Guard, rebornState: step1State)
            }
        }
        .border(Color.gray)
    }
}

#Preview("Guard reborn — Apple2", traits: .landscapeLeft) {
    GuardRebornSpritePreview().environment(\.tileTheme, .apple2)
}

#Preview("Guard reborn — C64", traits: .landscapeLeft) {
    GuardRebornSpritePreview().environment(\.tileTheme, .c64)
}
