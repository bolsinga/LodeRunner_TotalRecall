import LodeRunnerCore

private func character(for tile: TileType) -> Character {
    switch tile {
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

/// Render the simulation's `current` tiles (what's actually there right now, not the
/// permanent terrain) as a 28x16 grid of characters, one line per row.
func renderAscii(_ simulation: RunnerSimulation) -> String {
    var lines: [String] = []
    for y in 0..<LevelGrid.tilesY {
        var line = ""
        for x in 0..<LevelGrid.tilesX {
            line.append(character(for: simulation.slots[x][y].current))
        }
        lines.append(line)
    }
    return lines.joined(separator: "\n")
}
