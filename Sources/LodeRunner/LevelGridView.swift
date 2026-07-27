import SwiftUI

/// Renders a full level's terrain as a fixed `LevelGrid.tilesX` x `LevelGrid.tilesY`
/// grid of `TileCellView`s. Takes a plain `[[TileType]]` (the same `[x][y]` shape as
/// `RunnerSimulation.slots.map { $0.map(\.current) }`) rather than a `RunnerSimulation`
/// directly, keeping this view decoupled from anything beyond "what tile is at each
/// position" — ticking/animation is a later step.
public struct LevelGridView: View {
    let tiles: [[TileType]]

    public init(tiles: [[TileType]]) {
        self.tiles = tiles
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<LevelGrid.tilesY, id: \.self) { y in
                HStack(spacing: 0) {
                    ForEach(0..<LevelGrid.tilesX, id: \.self) { x in
                        TileCellView(tiles[x][y])
                    }
                }
            }
        }
    }
}

private func previewLevel() -> LevelParseResult {
    makeLevel(stamps: [
        (x: 3, y: 14, tile: .runner),
        (x: 10, y: 14, tile: .guard),
        (x: 6, y: 14, tile: .gold),
        (x: 15, y: 9, tile: .gold),
        (x: 20, y: 5, tile: .ladder), (x: 20, y: 6, tile: .ladder), (x: 20, y: 7, tile: .ladder),
        (x: 20, y: 8, tile: .ladder), (x: 20, y: 9, tile: .ladder), (x: 20, y: 10, tile: .ladder),
        (x: 20, y: 11, tile: .ladder), (x: 20, y: 12, tile: .ladder), (x: 20, y: 13, tile: .ladder),
        (x: 12, y: 9, tile: .bar), (x: 13, y: 9, tile: .bar), (x: 14, y: 9, tile: .bar),
        (x: 15, y: 9, tile: .bar), (x: 16, y: 9, tile: .bar),
        (x: 8, y: 12, tile: .trap),
        (x: 5, y: 10, tile: .solid), (x: 6, y: 10, tile: .solid), (x: 7, y: 10, tile: .solid),
    ])
}

#Preview("Apple2", traits: .landscapeLeft) {
    FittedBoardView {
        LevelGridView(tiles: previewLevel().slots.map { $0.map(\.current) })
    }
    .environment(\.tileTheme, .apple2)
    .background(Color.gray.opacity(0.2))
    .border(Color.gray)
}

#Preview("C64", traits: .landscapeLeft) {
    FittedBoardView {
        LevelGridView(tiles: previewLevel().slots.map { $0.map(\.current) })
    }
    .environment(\.tileTheme, .c64)
    .background(Color.gray.opacity(0.2))
    .border(Color.gray)
}
