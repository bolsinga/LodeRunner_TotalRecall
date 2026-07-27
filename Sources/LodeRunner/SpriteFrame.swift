import SwiftUI

/// Describes a uniform-grid sprite sheet: the base asset name (theme prefix is
/// added at render time), the pixel size of one frame, and the column/row count.
/// Frame indices count left-to-right, top-to-bottom — matching CreateJS's
/// `SpriteSheet` with `regX:0, regY:0` in `lodeRunner.preload.js`.
public struct SpriteSheetSpec: Sendable {
    public let assetName: String
    public let frameWidth: Int
    public let frameHeight: Int
    public let columns: Int
    public let rows: Int

    public init(assetName: String, frameWidth: Int, frameHeight: Int, columns: Int, rows: Int) {
        self.assetName = assetName
        self.frameWidth = frameWidth
        self.frameHeight = frameHeight
        self.columns = columns
        self.rows = rows
    }

    public var frameCount: Int { columns * rows }

    /// 27-frame runner sheet (40x44 @ 9x3). Layout ported from
    /// `createRunnerSpriteSheet` in `lodeRunner.preload.js`.
    public static let runner = SpriteSheetSpec(
        assetName: "runner",
        frameWidth: TileGeometry.tileWidth,
        frameHeight: TileGeometry.tileHeight,
        columns: 9,
        rows: 3
    )

    /// 33-frame guard sheet (40x44 @ 11x3). Layout ported from
    /// `createGuardObj("guard")` in `lodeRunner.preload.js`.
    public static let `guard` = SpriteSheetSpec(
        assetName: "guard",
        frameWidth: TileGeometry.tileWidth,
        frameHeight: TileGeometry.tileHeight,
        columns: 11,
        rows: 3
    )

    /// Red-hat guard sheet — same frame layout as `guard`
    /// (`createGuardObj("redhat")`).
    public static let redhat = SpriteSheetSpec(
        assetName: "redhat",
        frameWidth: TileGeometry.tileWidth,
        frameHeight: TileGeometry.tileHeight,
        columns: 11,
        rows: 3
    )

    /// 60-frame glyph atlas (40x44 @ 10x6) used for score/HUD text — mapping to
    /// characters lives in `lodeRunner.preload.js`'s `textData` animations.
    public static let text = SpriteSheetSpec(
        assetName: "text",
        frameWidth: TileGeometry.tileWidth,
        frameHeight: TileGeometry.tileHeight,
        columns: 10,
        rows: 6
    )
}

/// Renders one frame of a themed sprite sheet at its native pixel size. Slicing
/// is done by drawing the full sheet at its natural dimensions, offsetting it so
/// the requested frame's origin lands at (0,0), then clipping to a single frame.
/// The active `Theme` selects the sheet PNG the same way `TileCellView` does
/// (`\(theme.rawValue)/\(assetName)`). This view is stateless — animation is
/// driven by updating `index` from outside.
public struct SpriteFrame: View {
    @Environment(\.tileTheme) private var theme

    let sheet: SpriteSheetSpec
    let index: Int

    public init(sheet: SpriteSheetSpec, index: Int) {
        self.sheet = sheet
        self.index = index
    }

    public var body: some View {
        let col = index % sheet.columns
        let row = index / sheet.columns
        Image("\(theme.rawValue)/\(sheet.assetName)", bundle: .module)
            .resizable()
            .interpolation(.none)
            .frame(
                width: CGFloat(sheet.frameWidth * sheet.columns),
                height: CGFloat(sheet.frameHeight * sheet.rows)
            )
            .offset(
                x: -CGFloat(col * sheet.frameWidth),
                y: -CGFloat(row * sheet.frameHeight)
            )
            .frame(
                width: CGFloat(sheet.frameWidth),
                height: CGFloat(sheet.frameHeight),
                alignment: .topLeading
            )
            .clipped()
    }
}

private struct SpriteSheetGrid: View {
    let sheet: SpriteSheetSpec

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.fixed(CGFloat(sheet.frameWidth)), spacing: 4),
            count: sheet.columns)
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 4) {
            ForEach(0..<sheet.frameCount, id: \.self) { i in
                VStack(spacing: 2) {
                    SpriteFrame(sheet: sheet, index: i)
                        .background(Color.gray.opacity(0.2))
                        .border(Color.gray)
                    Text("\(i)").font(.caption2)
                }
            }
        }
    }
}

private struct RunnerAnimationsRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(RunnerAnimation.allCases, id: \.self) { animation in
                VStack(spacing: 4) {
                    AnimatedSprite(
                        sheet: .runner,
                        frames: animation.frames,
                        framesPerSecond: animation.framesPerSecond
                    )
                    .background(Color.gray.opacity(0.2))
                    .border(Color.gray)
                    Text(animation.rawValue).font(.caption2)
                }
            }
        }
    }
}

private struct GuardAnimationsRow: View {
    let sheet: SpriteSheetSpec

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(GuardAnimation.allCases, id: \.self) { animation in
                VStack(spacing: 4) {
                    AnimatedSprite(
                        sheet: sheet,
                        frames: animation.frames,
                        framesPerSecond: animation.framesPerSecond
                    )
                    .background(Color.gray.opacity(0.2))
                    .border(Color.gray)
                    Text(animation.rawValue).font(.caption2)
                }
            }
        }
    }
}

private struct SheetAndAnimations<Animations: View>: View {
    let sheet: SpriteSheetSpec
    @ViewBuilder let animations: () -> Animations

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 16) {
                SpriteSheetGrid(sheet: sheet)
                Divider()
                animations()
            }
            .padding()
        }
    }
}

#Preview("Runner — Apple2") {
    SheetAndAnimations(sheet: .runner) { RunnerAnimationsRow() }
        .environment(\.tileTheme, .apple2)
}

#Preview("Runner — C64") {
    SheetAndAnimations(sheet: .runner) { RunnerAnimationsRow() }
        .environment(\.tileTheme, .c64)
}

#Preview("Guard — Apple2") {
    SheetAndAnimations(sheet: .guard) { GuardAnimationsRow(sheet: .guard) }
        .environment(\.tileTheme, .apple2)
}

#Preview("Guard — C64") {
    SheetAndAnimations(sheet: .guard) { GuardAnimationsRow(sheet: .guard) }
        .environment(\.tileTheme, .c64)
}

#Preview("Redhat — Apple2") {
    SheetAndAnimations(sheet: .redhat) { GuardAnimationsRow(sheet: .redhat) }
        .environment(\.tileTheme, .apple2)
}

#Preview("Redhat — C64") {
    SheetAndAnimations(sheet: .redhat) { GuardAnimationsRow(sheet: .redhat) }
        .environment(\.tileTheme, .c64)
}

#Preview("Text — Apple2") {
    ScrollView { SpriteSheetGrid(sheet: .text).padding() }
        .environment(\.tileTheme, .apple2)
}

#Preview("Text — C64") {
    ScrollView { SpriteSheetGrid(sheet: .text).padding() }
        .environment(\.tileTheme, .c64)
}
