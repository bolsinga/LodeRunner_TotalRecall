import SwiftUI

/// Cycles a `SpriteFrame` through a frame-index sequence at a fixed rate. Uses
/// `TimelineView(.periodic:)` so the redraw schedule is driven by SwiftUI's own
/// timeline (works even when the preview isn't in Live mode) and the step is
/// derived from wall-clock time — no explicit `@State` step or async task loop.
public struct AnimatedSprite: View {
    let sheet: SpriteSheetSpec
    let frames: [Int]
    let framesPerSecond: Double

    public init(sheet: SpriteSheetSpec, frames: [Int], framesPerSecond: Double) {
        self.sheet = sheet
        self.frames = frames
        self.framesPerSecond = framesPerSecond
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / max(framesPerSecond, 0.001))) { context in
            SpriteFrame(sheet: sheet, index: frameIndex(at: context.date))
        }
    }

    private func frameIndex(at date: Date) -> Int {
        guard !frames.isEmpty else { return 0 }
        let step = Int(floor(date.timeIntervalSinceReferenceDate * framesPerSecond))
        let wrapped = ((step % frames.count) + frames.count) % frames.count
        return frames[wrapped]
    }
}

#Preview("Runner runRight — Apple2") {
    AnimatedSprite(
        sheet: .runner,
        frames: RunnerAnimation.runRight.frames,
        framesPerSecond: RunnerAnimation.runRight.framesPerSecond
    )
    .background(Color.gray.opacity(0.2))
    .border(Color.gray)
    .environment(\.tileTheme, .apple2)
    .padding()
}

#Preview("Guard runLeft — C64") {
    AnimatedSprite(
        sheet: .guard,
        frames: GuardAnimation.runLeft.frames,
        framesPerSecond: GuardAnimation.runLeft.framesPerSecond
    )
    .background(Color.gray.opacity(0.2))
    .border(Color.gray)
    .environment(\.tileTheme, .c64)
    .padding()
}
