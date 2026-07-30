import SwiftUI

/// The centered "GAME OVER" banner that plays when the runner dies. A port of
/// `gameOverAnimation` at `lodeRunner.main.js:1091-1142`: draws the themed
/// `over.png` (356×48 in both themes) centered on the board over a black
/// backing rect, then runs the easeljs `scaleY` flip tween from lines
/// 1108-1121 — twelve linear segments (80/80/100/100/150/150/300/300/450/450/
/// 750/750 ms) that oscillate between +1 and -1 before settling at +1.
///
/// Rendered position matches JS `x = (NO_OF_TILES_X * tileWScale) / 2`,
/// `y = (NO_OF_TILES_Y * tileHScale) / 2` — the geometric center of the
/// playfield, with the banner's own center as its registration point (JS
/// `regX`/`regY` at lines 1097-1098). The banner is drawn at native size
/// (JS renders at `tileScale`, we render at logical `tileScale = 1`).
///
/// This view starts the flip animation the moment it appears. Callers gate
/// visibility on `RunnerPhase == .dead` — e.g. via a `ZStack` sibling that
/// only inserts `GameOverOverlay()` when the sim reports death.
public struct GameOverOverlay: View {
    @Environment(\.tileTheme) private var theme

    let boardWidth: CGFloat
    let boardHeight: CGFloat
    /// Fired when the flip tween's terminal `.wait(1500).call(...)` would run
    /// in the JS (`main.js:1140`) — or immediately on tap. Callers wire this
    /// to a navigation pop back to the chooser, our analog to the JS
    /// `showCoverPage()` at `main.js:1522`.
    let onFinished: () -> Void
    @State private var startDate = Date()

    public init(
        boardWidth: CGFloat = CGFloat(LevelGrid.tilesX * TileGeometry.tileWidth),
        boardHeight: CGFloat = CGFloat(LevelGrid.tilesY * TileGeometry.tileHeight),
        onFinished: @escaping () -> Void = {}
    ) {
        self.boardWidth = boardWidth
        self.boardHeight = boardHeight
        self.onFinished = onFinished
    }

    public var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(startDate)
            let scaleY = Self.scaleY(atElapsedSeconds: elapsed)
            ZStack {
                Rectangle()
                    .fill(Color.black)
                    .frame(width: Self.bannerWidth + 2, height: Self.bannerHeight + 2)
                Image("\(theme.rawValue)/over", bundle: .module)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: Self.bannerWidth, height: Self.bannerHeight)
                    .scaleEffect(x: 1, y: scaleY, anchor: .center)
            }
            .position(x: boardWidth / 2, y: boardHeight / 2)
        }
        .frame(width: boardWidth, height: boardHeight, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture { onFinished() }
        .task {
            try? await Task.sleep(for: .milliseconds(Int(Self.totalDurationSeconds * 1000)))
            onFinished()
        }
    }

    /// Total flip + terminal-wait duration in seconds — matches the sum of
    /// `flipSegments` (3660 ms) plus the JS's `.wait(1500)` at `main.js:1139`.
    static let totalDurationSeconds: Double =
        flipSegments.reduce(0) { $0 + $1.ms } / 1000 + 1.5

    /// Native pixel size of `over.png` — identical for both themes.
    private static let bannerWidth: CGFloat = 356
    private static let bannerHeight: CGFloat = 48

    /// The JS tween schedule from `lodeRunner.main.js:1108-1121`. Each entry is
    /// `(duration_ms, endScaleY)`; the sequence starts at scaleY = +1 and each
    /// segment linearly tweens to `endScaleY` — matching easeljs's default
    /// `Tween.get(...).to({scaleY: v}, ms)` behavior.
    private static let flipSegments: [(ms: Double, to: Double)] = [
        (80, -1), (80, 1),
        (100, -1), (100, 1),
        (150, -1), (150, 1),
        (300, -1), (300, 1),
        (450, -1), (450, 1),
        (750, -1), (750, 1),
    ]

    /// Y-scale at a given elapsed time — linear interpolation across
    /// `flipSegments`, holding at +1 once the sequence completes (matching the
    /// JS's terminal `.wait(1500).call(...)` where the banner sits idle before
    /// `gameState` transitions to `GAME_OVER`).
    static func scaleY(atElapsedSeconds elapsed: TimeInterval) -> Double {
        var remainingMs = max(0, elapsed) * 1000
        var from: Double = 1
        for segment in flipSegments {
            if remainingMs <= segment.ms {
                let progress = segment.ms > 0 ? remainingMs / segment.ms : 1
                return from + (segment.to - from) * progress
            }
            remainingMs -= segment.ms
            from = segment.to
        }
        return from
    }
}

// MARK: - Preview

private struct GameOverPreview: View {
    var body: some View {
        FittedBoardView {
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(
                        width: CGFloat(LevelGrid.tilesX * TileGeometry.tileWidth),
                        height: CGFloat(LevelGrid.tilesY * TileGeometry.tileHeight)
                    )
                GameOverOverlay()
            }
        }
        .border(Color.gray)
    }
}

#Preview("Game over — Apple2", traits: .landscapeLeft) {
    GameOverPreview().environment(\.tileTheme, .apple2)
}

#Preview("Game over — C64", traits: .landscapeLeft) {
    GameOverPreview().environment(\.tileTheme, .c64)
}
