import SwiftUI

/// Blinks the wrapped view's opacity between 1 and 0 while the runner is
/// waiting for its first player input, matching the classic pre-play flash.
/// A port of `startBlinkTimer` at `lodeRunner.main.js:1296, 1306, 1419-1422`:
/// during `GAME_START` the JS increments `startBlinkTimer` every mainTick and
/// flips `runner.sprite.visible` on the 8th, then resets to 0.
///
/// - Toggle cadence — 8 mainTicks at `speedMode[2] = 23` FPS (the default
///   "normal" speed at `main.js:42, 45`) = 8/23 s ≈ 348 ms per visibility
///   state. Interpolated over wall-clock elapsed time rather than reproducing
///   the discrete tick counter, since SwiftUI's timeline doesn't share the
///   sim's tick boundary.
///
/// Callers gate this on `RunnerPhase.starting` — the port of JS `GAME_START`.
/// The composition layer applies this modifier while `simulation.phase ==
/// .starting` and removes it once input drives `simulation.beginPlay()` (the
/// port of `beginPlay` at `main.js:1298-1306`, which sets
/// `runner.sprite.visible = true` and `startBlinkTimer = 0`). The sprite
/// starts visible and only turns invisible after the first toggle period
/// elapses.
public struct RunnerBornBlink: ViewModifier {
    let togglePeriodSeconds: Double
    @State private var startDate = Date()

    public init(togglePeriodSeconds: Double = Self.jsBlinkTogglePeriodSeconds) {
        self.togglePeriodSeconds = togglePeriodSeconds
    }

    public func body(content: Content) -> some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(startDate)
            content.opacity(
                Self.isVisible(
                    atElapsedSeconds: elapsed,
                    togglePeriodSeconds: togglePeriodSeconds
                ) ? 1 : 0
            )
        }
    }

    /// JS nominal blink cadence: 8 mainTicks at `speedMode[2] = 23` FPS
    /// (`main.js:42, 45, 1419`) = 8/23 s ≈ 347.83 ms per visibility state.
    public static let jsBlinkTogglePeriodSeconds: Double = 8.0 / 23.0

    /// Sprite visibility at `elapsed` seconds — starts visible (matching
    /// `beginPlay`'s `runner.sprite.visible = true` at `main.js:1305`) and
    /// flips every `togglePeriodSeconds`.
    static func isVisible(
        atElapsedSeconds elapsed: TimeInterval,
        togglePeriodSeconds: TimeInterval
    ) -> Bool {
        guard togglePeriodSeconds > 0, elapsed >= 0 else { return true }
        let toggles = Int((elapsed / togglePeriodSeconds).rounded(.down))
        return toggles.isMultiple(of: 2)
    }
}

extension View {
    /// Wrap this view in `RunnerBornBlink`, toggling its opacity between 1 and
    /// 0 every 8 mainTicks at 23 FPS (~348 ms). Apply on the runner sprite view
    /// during the pre-play waiting-for-input phase.
    public func runnerBornBlink(
        togglePeriodSeconds: Double = RunnerBornBlink.jsBlinkTogglePeriodSeconds
    ) -> some View {
        modifier(RunnerBornBlink(togglePeriodSeconds: togglePeriodSeconds))
    }
}

// MARK: - Preview

private struct RunnerBornBlinkPreview: View {
    var body: some View {
        let runner = Runner(
            position: GridPoint(x: 3, y: 14), xOffset: 0, yOffset: 0, action: .stop
        )
        let appearance = RunnerAppearance(facing: .right, lastAnimation: .runRight)
        FittedBoardView {
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(
                        width: CGFloat(LevelGrid.tilesX * TileGeometry.tileWidth),
                        height: CGFloat(LevelGrid.tilesY * TileGeometry.tileHeight)
                    )
                RunnerSpriteView(runner: runner, appearance: appearance)
                    .runnerBornBlink()
            }
        }
        .border(Color.gray)
    }
}

#Preview("Runner born blink — Apple2", traits: .landscapeLeft) {
    RunnerBornBlinkPreview().environment(\.tileTheme, .apple2)
}

#Preview("Runner born blink — C64", traits: .landscapeLeft) {
    RunnerBornBlinkPreview().environment(\.tileTheme, .c64)
}
