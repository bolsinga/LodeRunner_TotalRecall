import SwiftUI

/// Miniature render of a level for the level-select grid — analog to JS
/// `levelThumb.js:43-101`'s `renderLevelMapToCanvas`, which flattens the same
/// tile bitmaps onto a `THUMB_SCALE = 0.16` canvas.
///
/// Reuses `LevelGridView` at the natural pixel size and scales the whole
/// thing with `.scaleEffect`, so the tile art and the runner/guard still
/// frames (via `LevelSlot.displayTile`, which surfaces `.runner`/`.guard`
/// from `.current`) render at the same relative positions as gameplay.
public struct LevelThumbnailView: View {
    let level: LevelParseResult
    let scale: CGFloat

    public init(level: LevelParseResult, scale: CGFloat = 0.16) {
        self.level = level
        self.scale = scale
    }

    public var body: some View {
        LevelGridView(tiles: level.slots.map { $0.map(\.displayTile) })
            // Pin the grid at its natural size so `.scaleEffect` scales a
            // known-sized view. `LevelGridView`'s `TileCellView` children
            // have fixed frames, so if the outer `.frame` below proposed a
            // smaller size directly, the grid would overflow into layout
            // rather than compress — visible as content drifting to the
            // left of the intended thumbnail bounds.
            .frame(width: Self.naturalWidth, height: Self.naturalHeight)
            // `.scaleEffect` rescales rendered pixels but does not affect
            // layout. Anchor at `.topLeading` so the rendered content lands
            // in the same corner as the layout frame below.
            .scaleEffect(scale, anchor: .topLeading)
            // Report the *scaled* dimensions to the layout system so the
            // grid cells in `LevelSelectOverlay` size properly. Alignment
            // matches the scale anchor.
            .frame(
                width: Self.naturalWidth * scale,
                height: Self.naturalHeight * scale,
                alignment: .topLeading
            )
    }

    /// Natural pixel size of the playfield, matching JS `NO_OF_TILES_X *
    /// BASE_TILE_X` × `NO_OF_TILES_Y * BASE_TILE_Y`.
    private static let naturalWidth: CGFloat =
        CGFloat(LevelGrid.tilesX * TileGeometry.tileWidth)
    private static let naturalHeight: CGFloat =
        CGFloat(LevelGrid.tilesY * TileGeometry.tileHeight)
}

// MARK: - Preview

private func previewLevel() -> LevelParseResult {
    makeLevel(stamps: [
        (x: 3, y: 14, tile: .runner),
        (x: 10, y: 14, tile: .guard),
        (x: 17, y: 14, tile: .guard),
        (x: 6, y: 14, tile: .gold),
        (x: 15, y: 9, tile: .gold),
        (x: 20, y: 5, tile: .ladder), (x: 20, y: 6, tile: .ladder),
        (x: 20, y: 7, tile: .ladder), (x: 20, y: 8, tile: .ladder),
        (x: 20, y: 9, tile: .ladder), (x: 20, y: 10, tile: .ladder),
        (x: 12, y: 9, tile: .bar), (x: 13, y: 9, tile: .bar), (x: 14, y: 9, tile: .bar),
        (x: 8, y: 12, tile: .trap),
    ])
}

#Preview("Level thumbnail — Apple2") {
    LevelThumbnailView(level: previewLevel())
        .padding()
        .background(Color.black)
        .environment(\.tileTheme, .apple2)
}

#Preview("Level thumbnail — C64") {
    LevelThumbnailView(level: previewLevel())
        .padding()
        .background(Color.black)
        .environment(\.tileTheme, .c64)
}
