import LodeRunnerCore
import SwiftUI

/// The circular-wipe transition that closes the screen when the runner passes
/// a level. A port of `closingScreen` at `lodeRunner.main.js:1177-1206`, which
/// draws a black shape composed of two arcs (`main.js:1181-1182`) — an inner
/// circle at `(cycX, cycY)` radius `r` drawn CCW, plus an outer circle at
/// `cycMaxRadius` drawn CW. The two-arc trick relies on the even-odd fill rule
/// to punch a circular hole of radius `r` through an otherwise-solid black
/// disc, so as `r` shrinks the visible playfield collapses to a shrinking
/// vignette.
///
/// - `cycX`/`cycY` — board center, matching `main.js:1148-1149`.
/// - `cycMaxRadius` — half-diagonal of the board (`sqrt(cycX² + cycY²)`),
///   `main.js:1150`.
/// - Close duration — `CLOSE_SCREEN_SPEED = 35` steps at 5 ms each
///   (`lodeRunner.def.js:148`, `main.js:1187`) = 175 ms nominal. This
///   implementation interpolates linearly over that duration rather than
///   emitting 35 discrete steps, since a 60 Hz SwiftUI refresh can't resolve
///   5 ms increments anyway.
///
/// Callers gate visibility on `RunnerPhase == .finished`; the overlay starts
/// wiping the moment it appears. The `openingScreen` half of the JS transition
/// (`main.js:1279-1294`) is the reverse-direction reveal into the next level
/// — a separate concern deferred to a follow-up alongside a level-advance flow.
public struct LevelPassOverlay: View {
    let boardWidth: CGFloat
    let boardHeight: CGFloat
    let closeDurationSeconds: Double
    @State private var startDate = Date()

    public init(
        boardWidth: CGFloat = CGFloat(LevelGrid.tilesX * TileGeometry.tileWidth),
        boardHeight: CGFloat = CGFloat(LevelGrid.tilesY * TileGeometry.tileHeight),
        closeDurationSeconds: Double = Self.jsCloseDurationSeconds
    ) {
        self.boardWidth = boardWidth
        self.boardHeight = boardHeight
        self.closeDurationSeconds = closeDurationSeconds
    }

    public var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(startDate)
            let radius = Self.radius(
                atElapsedSeconds: elapsed,
                maxRadius: maxRadius,
                closeDurationSeconds: closeDurationSeconds
            )
            PassScreenMask(radius: radius, width: boardWidth, height: boardHeight)
        }
    }

    /// Half-diagonal of the board — the JS `cycMaxRadius` at `main.js:1150`
    /// (`sqrt(cycX² + cycY²)`, where `cycX`/`cycY` are half the board extent).
    private var maxRadius: Double {
        let cx = Double(boardWidth) / 2
        let cy = Double(boardHeight) / 2
        return (cx * cx + cy * cy).squareRoot()
    }

    /// JS nominal close duration: `CLOSE_SCREEN_SPEED = 35` iterations at 5 ms
    /// per iteration = 175 ms. Callers can override via `init` for previews or
    /// tests where a slower wipe is easier to observe.
    public static let jsCloseDurationSeconds: Double = 5.0 * 35 / 1000

    /// Radius of the still-visible circular window at `elapsed` seconds — falls
    /// linearly from `maxRadius` to 0 across `closeDurationSeconds`, then holds
    /// at 0 (fully black).
    static func radius(
        atElapsedSeconds elapsed: TimeInterval,
        maxRadius: Double,
        closeDurationSeconds: Double
    ) -> Double {
        guard elapsed > 0 else { return maxRadius }
        let progress = min(elapsed / closeDurationSeconds, 1)
        return maxRadius * (1 - progress)
    }
}

/// The rect-minus-circle Canvas drawing shared by `LevelPassOverlay.body` and
/// its preview. Extracted so the preview can render a static mid-wipe frame at
/// a pinned radius — `TimelineView`-driven elapsed time is nondeterministic
/// across `RenderPreview` snapshots.
private struct PassScreenMask: View {
    let radius: Double
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Canvas { ctx, size in
            var path = Path(CGRect(origin: .zero, size: size))
            if radius > 0 {
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                path.addEllipse(
                    in: CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                )
            }
            ctx.fill(path, with: .color(.black), style: FillStyle(eoFill: true))
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Preview

/// Static mid-wipe snapshot using a pinned radius — bypasses `TimelineView`'s
/// nondeterministic elapsed time so `RenderPreview` always shows the same
/// black-corners-closing frame. Live scrubbing lives in the sibling preview.
private struct LevelPassMidWipePreview: View {
    var body: some View {
        let boardW = CGFloat(LevelGrid.tilesX * TileGeometry.tileWidth)
        let boardH = CGFloat(LevelGrid.tilesY * TileGeometry.tileHeight)
        let maxR = (Double(boardW) * Double(boardW) / 4
            + Double(boardH) * Double(boardH) / 4).squareRoot()
        FittedBoardView {
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color.orange.opacity(0.3))
                    .frame(width: boardW, height: boardH)
                PassScreenMask(radius: maxR * 0.6, width: boardW, height: boardH)
            }
        }
        .border(Color.gray)
    }
}

private struct LevelPassLivePreview: View {
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
                LevelPassOverlay(closeDurationSeconds: 2.0)
            }
        }
        .border(Color.gray)
    }
}

#Preview("Level pass — mid-wipe (static)", traits: .landscapeLeft) {
    LevelPassMidWipePreview()
}

#Preview("Level pass — Live (2s wipe)", traits: .landscapeLeft) {
    LevelPassLivePreview()
}
