import SwiftUI

/// Frame-index sequences for `SpriteSheetSpec.runner`, ported from the
/// `runnerData` `createjs.SpriteSheet` animations in `lodeRunner.preload.js`.
/// Each `frames` array plays back in order; looping/one-shot semantics are the
/// caller's concern (the animation driver isn't wired up yet).
public enum RunnerAnimation: String, CaseIterable, Sendable {
    case runRight
    case runLeft
    case runUpDn
    case barRight
    case barLeft
    case digRight
    case digLeft
    case fallRight
    case fallLeft

    public var frames: [Int] {
        switch self {
        case .runRight: [0, 1, 2]
        case .runLeft: [3, 4, 5]
        case .runUpDn: [6, 7]
        case .barRight: [18, 19, 19, 20, 20]
        case .barLeft: [21, 22, 22, 23, 23]
        case .digRight: [24]
        case .digLeft: [25]
        case .fallRight: [8]
        case .fallLeft: [26]
        }
    }

    /// `RUNNER_SPEED = 0.65` (frames advanced per tick) × the default
    /// `createjs.Ticker.setFPS(30)` from `lodeRunner.preload.js`. All runner
    /// animations share this rate in the JS source.
    public var framesPerSecond: Double { 30.0 * 0.65 }
}

/// Frame-index sequences for `SpriteSheetSpec.guard` / `SpriteSheetSpec.redhat`
/// (both share the same sheet layout), ported from `createGuardObj` in
/// `lodeRunner.preload.js`.
public enum GuardAnimation: String, CaseIterable, Sendable {
    case runRight
    case runLeft
    case runUpDn
    case barRight
    case barLeft
    case reborn
    case fallRight
    case fallLeft
    case shakeRight
    case shakeLeft

    public var frames: [Int] {
        switch self {
        case .runRight: [0, 1, 2]
        case .runLeft: [3, 4, 5]
        case .runUpDn: [6, 7]
        case .barRight: [22, 23, 23, 24, 24]
        case .barLeft: [25, 26, 26, 27, 27]
        case .reborn: [28, 28, 29]
        case .fallRight: [8]
        case .fallLeft: [30]
        case .shakeRight: [8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 9, 10, 9, 10, 8]
        case .shakeLeft: [30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 31, 32, 31, 32, 30]
        }
    }

    /// `GUARD_SPEED = 0.3` × the default 30 FPS ticker (`lodeRunner.preload.js`).
    /// Applies to both `SpriteSheetSpec.guard` and `.redhat`.
    public var framesPerSecond: Double { 30.0 * 0.3 }
}

private struct AnimationStrip<Label: StringProtocol>: View {
    let sheet: SpriteSheetSpec
    let name: Label
    let frames: [Int]

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Text(name).font(.caption).frame(width: 80, alignment: .leading)
            ForEach(Array(frames.enumerated()), id: \.offset) { _, index in
                VStack(spacing: 2) {
                    SpriteFrame(sheet: sheet, index: index)
                        .background(Color.gray.opacity(0.2))
                        .border(Color.gray)
                    Text("\(index)").font(.caption2)
                }
            }
        }
    }
}

private struct RunnerAnimationList: View {
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(RunnerAnimation.allCases, id: \.self) { animation in
                    AnimationStrip(
                        sheet: .runner,
                        name: animation.rawValue,
                        frames: animation.frames
                    )
                }
            }
            .padding()
        }
    }
}

private struct GuardAnimationList: View {
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(GuardAnimation.allCases, id: \.self) { animation in
                    AnimationStrip(
                        sheet: .guard,
                        name: animation.rawValue,
                        frames: animation.frames
                    )
                }
            }
            .padding()
        }
    }
}

#Preview("Runner animations — Apple2") {
    RunnerAnimationList().environment(\.tileTheme, .apple2)
}

#Preview("Runner animations — C64") {
    RunnerAnimationList().environment(\.tileTheme, .c64)
}

#Preview("Guard animations — Apple2") {
    GuardAnimationList().environment(\.tileTheme, .apple2)
}

#Preview("Guard animations — C64") {
    GuardAnimationList().environment(\.tileTheme, .c64)
}
