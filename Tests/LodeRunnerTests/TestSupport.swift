@testable import LodeRunner

/// Character-based level builder for the parser tests: those tests specifically
/// exercise the char → tile parse path, so they can't go through the shared
/// TileType-based `makeLevel(stamps:)` in the library. Always fills the bottom row
/// with bricks so the string looks valid.
func makeLevel(stamps: [(x: Int, y: Int, ch: Character)]) -> String {
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
