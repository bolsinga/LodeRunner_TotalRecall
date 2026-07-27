/// Build a blank 28x16 level, stamp `TileType` values at [x,y] positions, and fill
/// the bottom row with bricks so the resulting string parses cleanly through
/// `resolveLevelMap`. Used by SwiftUI previews and, via `@testable import`, by the
/// simulation/session tests — the one place a raw level string still gets built by
/// hand outside the parser itself.
func makeLevel(stamps: [(x: Int, y: Int, tile: TileType)]) -> String {
    var cells = Array(repeating: Character(" "), count: LevelGrid.tileCount)
    for stamp in stamps {
        cells[stamp.y * LevelGrid.tilesX + stamp.x] = stamp.tile.levelChar
    }
    for x in 0..<LevelGrid.tilesX {
        let index = (LevelGrid.tilesY - 1) * LevelGrid.tilesX + x
        if cells[index] == " " {
            cells[index] = "#"
        }
    }
    return String(cells)
}

extension TileType {
    /// Reverse of `parseLevelChar`, single-valued: each `TileType` maps back to the
    /// canonical character it would parse from. `.hiddenLadder` uses `S` (base), not
    /// the `H` a `.ladder` uses.
    fileprivate var levelChar: Character {
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
