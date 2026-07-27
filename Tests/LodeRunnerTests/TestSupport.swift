@testable import LodeRunner

/// Build a blank 28x16 level, then stamp entities/terrain at [x,y] positions. Always
/// fills the bottom row with bricks so the string looks valid.
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

/// TileType-stamp overload. Same round-trip through `resolveLevelMap` as the
/// Character-based version, but call sites read as `tile: .ladder` instead of
/// `ch: "H"`. Kept out of the parser tests, which need the raw-character path.
func makeLevel(stamps: [(x: Int, y: Int, tile: TileType)]) -> String {
    makeLevel(stamps: stamps.map { (x: $0.x, y: $0.y, ch: $0.tile.stampChar) })
}

extension TileType {
    fileprivate var stampChar: Character {
        switch self {
        case .empty: return " "
        case .brick: return "#"
        case .solid: return "@"
        case .ladder: return "H"
        case .bar: return "-"
        case .trap: return "X"
        case .hiddenLadder: return "S"
        case .gold: return "$"
        case .guard: return "0"
        case .runner: return "&"
        }
    }
}
