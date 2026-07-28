import SwiftUI

/// The circular-wipe transition that opens the screen when a level begins. A
/// port of `openingScreen` at `lodeRunner.main.js:1279-1294`, which draws the
/// same black-rect-minus-circle mask as `closingScreen` (`LevelPassOverlay`)
/// but with `r` growing from a small starting value up to `cycMaxRadius`
/// instead of shrinking to 0 — so the playfield reveals from a dot in the
/// middle outward.
///
/// - `cycX`/`cycY` — board center, `main.js:1148-1149`.
/// - `cycMaxRadius` — half-diagonal of the board, `main.js:1150`.
/// - Open duration — matches `CLOSE_SCREEN_SPEED = 35` at 5 ms each
///   (`lodeRunner.def.js:148`, `main.js:1289`), nominally 175 ms. Linear
///   interpolation over that duration, same rationale as `LevelPassOverlay`:
///   60 Hz SwiftUI refresh can't resolve 5 ms steps.
///
/// Callers show this at the moment a level starts (`initForPlay` /
/// `beginPlay` in `main.js:1273/1298`); when the wipe completes the overlay
/// naturally draws nothing, so keeping it in the view hierarchy costs no
/// visible ink.
public struct LevelStartOverlay: View {
    let boardWidth: CGFloat
    let boardHeight: CGFloat
    let openDurationSeconds: Double
    @State private var startDate = Date()

    public init(
        boardWidth: CGFloat = CGFloat(LevelGrid.tilesX * TileGeometry.tileWidth),
        boardHeight: CGFloat = CGFloat(LevelGrid.tilesY * TileGeometry.tileHeight),
        openDurationSeconds: Double = Self.jsOpenDurationSeconds
    ) {
        self.boardWidth = boardWidth
        self.boardHeight = boardHeight
        self.openDurationSeconds = openDurationSeconds
    }

    public var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(startDate)
            let radius = Self.radius(
                atElapsedSeconds: elapsed,
                maxRadius: maxRadius,
                openDurationSeconds: openDurationSeconds
            )
            CircularWipeMask(radius: radius, width: boardWidth, height: boardHeight)
        }
    }

    /// Half-diagonal of the board — the JS `cycMaxRadius` at `main.js:1150`.
    private var maxRadius: Double {
        let cx = Double(boardWidth) / 2
        let cy = Double(boardHeight) / 2
        return (cx * cx + cy * cy).squareRoot()
    }

    /// JS nominal open duration: same 175 ms as `closingScreen` — the JS's
    /// `openingScreen` steps `cycDiff` at 5 ms from `cycDiff*2` up to
    /// `cycMaxRadius` (`main.js:1287-1288`), matching the closing counterpart
    /// within one step.
    public static let jsOpenDurationSeconds: Double = 5.0 * 35 / 1000

    /// Radius of the still-visible circular window at `elapsed` seconds — rises
    /// linearly from 0 to `maxRadius` across `openDurationSeconds`, then holds
    /// at `maxRadius` (fully open, mask fully transparent).
    static func radius(
        atElapsedSeconds elapsed: TimeInterval,
        maxRadius: Double,
        openDurationSeconds: Double
    ) -> Double {
        guard elapsed > 0 else { return 0 }
        let progress = min(elapsed / openDurationSeconds, 1)
        return maxRadius * progress
    }
}

// MARK: - Preview

/// Static mid-open snapshot using a pinned radius — bypasses `TimelineView`'s
/// nondeterministic elapsed time so `RenderPreview` always shows the same
/// black-corners-opening frame. Live scrubbing lives in the sibling preview.
private struct LevelStartMidOpenPreview: View {
    var body: some View {
        let boardW = CGFloat(LevelGrid.tilesX * TileGeometry.tileWidth)
        let boardH = CGFloat(LevelGrid.tilesY * TileGeometry.tileHeight)
        let maxR = (Double(boardW) * Double(boardW) / 4
            + Double(boardH) * Double(boardH) / 4).squareRoot()
        FittedBoardView {
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color.orange.opacity(0.3))
                    .frame(width: boardW, height: boardH)
                CircularWipeMask(radius: maxR * 0.4, width: boardW, height: boardH)
            }
        }
        .border(Color.gray)
    }
}

private struct LevelStartLivePreview: View {
    var body: some View {
        FittedBoardView {
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.orange.opacity(0.3))
                    .frame(
                        width: CGFloat(LevelGrid.tilesX * TileGeometry.tileWidth),
                        height: CGFloat(LevelGrid.tilesY * TileGeometry.tileHeight)
                    )
                // Slower than the JS's 175 ms so Live scrubbing is legible.
                LevelStartOverlay(openDurationSeconds: 2.0)
            }
        }
        .border(Color.gray)
    }
}

#Preview("Level start — mid-open (static)", traits: .landscapeLeft) {
    LevelStartMidOpenPreview()
}

#Preview("Level start — Live (2s open)", traits: .landscapeLeft) {
    LevelStartLivePreview()
}
