import LodeRunnerCore
import SwiftUI

/// Renders one frame from the themed `hole.png` sprite sheet. Unlike the
/// uniform-grid sheets (`runner`, `guard`, `redhat`, `text`), the hole sheet
/// mixes two frame sizes: 8 double-tall (40×88) dig-left frames + 8 double-tall
/// dig-right frames + 4 single-tile (40×44) fill frames, per the explicit
/// `frames: [[x, y, w, h], …]` table in `lodeRunner.preload.js:492-517`. That's
/// why this doesn't reuse `SpriteFrame` — a `SpriteSheetSpec` can't describe a
/// non-uniform layout.
///
/// Slicing uses the same "draw full sheet + offset + clip" trick as
/// `SpriteFrame`, sized against the sheet's known 360×176 dimensions.
public struct HoleFrame: View {
    @Environment(\.tileTheme) private var theme

    public let index: Int

    public init(_ index: Int) {
        self.index = index
    }

    public var body: some View {
        let rect = Self.frameRects[index]
        Image("\(theme.rawValue)/hole", bundle: .module)
            .resizable()
            .interpolation(.none)
            .frame(width: Self.sheetWidth, height: Self.sheetHeight)
            .offset(x: -rect.origin.x, y: -rect.origin.y)
            .frame(width: rect.size.width, height: rect.size.height, alignment: .topLeading)
            .clipped()
    }

    /// The pixel-perfect rectangle each hole-sheet frame occupies. Order matches
    /// the JS `frames` array literally: 0-7 dig-left, 8-15 dig-right, 16-19
    /// fill. `frameRects[i].size` differs between dig (40×88) and fill (40×44).
    public static let frameRects: [CGRect] = {
        let w = CGFloat(TileGeometry.tileWidth)
        let h = CGFloat(TileGeometry.tileHeight)
        return [
            // dig hole left — frames 0-7: [col*40, 0, 40, 88]
            CGRect(x: 0 * w, y: 0, width: w, height: h * 2),
            CGRect(x: 1 * w, y: 0, width: w, height: h * 2),
            CGRect(x: 2 * w, y: 0, width: w, height: h * 2),
            CGRect(x: 3 * w, y: 0, width: w, height: h * 2),
            CGRect(x: 4 * w, y: 0, width: w, height: h * 2),
            CGRect(x: 5 * w, y: 0, width: w, height: h * 2),
            CGRect(x: 6 * w, y: 0, width: w, height: h * 2),
            CGRect(x: 7 * w, y: 0, width: w, height: h * 2),
            // dig hole right — frames 8-15: [col*40, 88, 40, 88]
            CGRect(x: 0 * w, y: h * 2, width: w, height: h * 2),
            CGRect(x: 1 * w, y: h * 2, width: w, height: h * 2),
            CGRect(x: 2 * w, y: h * 2, width: w, height: h * 2),
            CGRect(x: 3 * w, y: h * 2, width: w, height: h * 2),
            CGRect(x: 4 * w, y: h * 2, width: w, height: h * 2),
            CGRect(x: 5 * w, y: h * 2, width: w, height: h * 2),
            CGRect(x: 6 * w, y: h * 2, width: w, height: h * 2),
            CGRect(x: 7 * w, y: h * 2, width: w, height: h * 2),
            // fill hole — frames 16-19
            CGRect(x: 7 * w, y: h * 2, width: w, height: h),  // 16
            CGRect(x: 8 * w, y: h * 1, width: w, height: h),  // 17
            CGRect(x: 8 * w, y: 0, width: w, height: h),      // 18
            CGRect(x: 8 * w, y: h * 3, width: w, height: h),  // 19
        ]
    }()

    private static let sheetWidth: CGFloat = 9 * CGFloat(TileGeometry.tileWidth)
    private static let sheetHeight: CGFloat = 4 * CGFloat(TileGeometry.tileHeight)
}

/// Frame-index sequences for `HoleFrame`, ported from the `holeData`
/// `createjs.SpriteSheet` animations at `lodeRunner.preload.js:520-533`.
///
/// `fillHole` is deliberately non-uniform: 45 repeats of frame 16 (the fresh
/// hole) followed by `[17, 17, 18, 18, 19]` — the 45-frame stall is the JS's
/// "delay fill time for champLevel, 2014/04/12" (also encoded in the Swift sim
/// as `fillFrameDurations = [166, 8, 8, 4]` in `RunnerSimulation.swift`, but
/// those are sim-tick counts, not sprite-animation frames).
public enum HoleAnimation: String, CaseIterable, Sendable {
    case digHoleLeft
    case digHoleRight
    case fillHole

    public var frames: [Int] {
        switch self {
        case .digHoleLeft: Array(0...7)
        case .digHoleRight: Array(8...15)
        case .fillHole:
            Array(repeating: 16, count: 45) + [17, 17, 18, 18, 19]
        }
    }

    /// `DIG_SPEED = 0.68` / `FILL_SPEED = 0.24` × the 30 FPS ticker
    /// (`lodeRunner.preload.js:1-3`).
    public var framesPerSecond: Double {
        switch self {
        case .digHoleLeft, .digHoleRight: 30.0 * 0.68
        case .fillHole: 30.0 * 0.24
        }
    }
}

// MARK: - Preview

private struct HoleFramesGrid: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dig hole left — frames 0–7 (40×88)").font(.caption)
            HStack(spacing: 4) {
                ForEach(0...7, id: \.self) { i in
                    VStack(spacing: 2) {
                        HoleFrame(i)
                            .background(Color.gray.opacity(0.2))
                            .border(Color.gray)
                        Text("\(i)").font(.caption2)
                    }
                }
            }

            Text("Dig hole right — frames 8–15 (40×88)").font(.caption)
            HStack(spacing: 4) {
                ForEach(8...15, id: \.self) { i in
                    VStack(spacing: 2) {
                        HoleFrame(i)
                            .background(Color.gray.opacity(0.2))
                            .border(Color.gray)
                        Text("\(i)").font(.caption2)
                    }
                }
            }

            Text("Fill hole — frames 16–19 (40×44)").font(.caption)
            HStack(spacing: 4) {
                ForEach(16...19, id: \.self) { i in
                    VStack(spacing: 2) {
                        HoleFrame(i)
                            .background(Color.gray.opacity(0.2))
                            .border(Color.gray)
                        Text("\(i)").font(.caption2)
                    }
                }
            }
        }
        .padding()
    }
}

#Preview("Hole frames — Apple2") {
    ScrollView([.horizontal, .vertical]) {
        HoleFramesGrid()
    }
    .environment(\.tileTheme, .apple2)
}

#Preview("Hole frames — C64") {
    ScrollView([.horizontal, .vertical]) {
        HoleFramesGrid()
    }
    .environment(\.tileTheme, .c64)
}
