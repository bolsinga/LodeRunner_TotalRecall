import SwiftUI

/// Aspect-fit-scales a fixed board-sized view into any available space, so the
/// full `LevelGrid.tilesX * TileGeometry.tileWidth` × `LevelGrid.tilesY *
/// TileGeometry.tileHeight` (1120 × 704 pt) board fits within a phone screen —
/// in either orientation — without scrolling. Sprites lose pixel-perfect 1x
/// scale in exchange for full-board visibility; use the sheet/animation
/// previews (`SpriteFrame.swift`, `SpriteAnimation.swift`) for pixel-scale
/// inspection.
public struct FittedBoardView<Content: View>: View {
    let boardWidth: CGFloat
    let boardHeight: CGFloat
    let content: Content

    public init(
        boardWidth: CGFloat = CGFloat(LevelGrid.tilesX * TileGeometry.tileWidth),
        boardHeight: CGFloat = CGFloat(LevelGrid.tilesY * TileGeometry.tileHeight),
        @ViewBuilder content: () -> Content
    ) {
        self.boardWidth = boardWidth
        self.boardHeight = boardHeight
        self.content = content()
    }

    public var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / boardWidth, geo.size.height / boardHeight)
            content
                .frame(width: boardWidth, height: boardHeight, alignment: .topLeading)
                .scaleEffect(scale, anchor: .topLeading)
        }
    }
}
