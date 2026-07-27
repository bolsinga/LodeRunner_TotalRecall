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

/// Build a blank 28x16 level, then stamp entities/terrain at [x,y] positions — the
/// same small-level convention used throughout this package's tests, for preview
/// purposes only.
private func makeLevel(stamps: [(x: Int, y: Int, ch: Character)]) -> String {
    var cells = Array(repeating: Character(" "), count: LevelGrid.tileCount)
    for stamp in stamps {
        cells[stamp.y * LevelGrid.tilesX + stamp.x] = stamp.ch
    }
    for x in 0..<LevelGrid.tilesX {
        let index = (LevelGrid.tilesY - 1) * LevelGrid.tilesX + x
        if cells[index] == " " {
            cells[index] = "#"
        }
    }
    return String(cells)
}

private func previewLevel() -> LevelParseResult {
    resolveLevelMap(
        makeLevel(stamps: [
            (x: 3, y: 14, ch: "&"),
            (x: 10, y: 14, ch: "0"),
            (x: 6, y: 14, ch: "$"),
            (x: 15, y: 9, ch: "$"),
            (x: 20, y: 5, ch: "H"), (x: 20, y: 6, ch: "H"), (x: 20, y: 7, ch: "H"),
            (x: 20, y: 8, ch: "H"), (x: 20, y: 9, ch: "H"), (x: 20, y: 10, ch: "H"),
            (x: 20, y: 11, ch: "H"), (x: 20, y: 12, ch: "H"), (x: 20, y: 13, ch: "H"),
            (x: 12, y: 9, ch: "-"), (x: 13, y: 9, ch: "-"), (x: 14, y: 9, ch: "-"),
            (x: 15, y: 9, ch: "-"), (x: 16, y: 9, ch: "-"),
            (x: 8, y: 12, ch: "X"),
            (x: 5, y: 10, ch: "@"), (x: 6, y: 10, ch: "@"), (x: 7, y: 10, ch: "@"),
        ]))
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
