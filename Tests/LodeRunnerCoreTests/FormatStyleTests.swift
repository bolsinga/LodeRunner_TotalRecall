import Testing

@testable import LodeRunnerCore

@Test("TileType.FormatStyle renders each tile as its documented single character")
func tileTypeFormatsToSingleCharacter() {
    #expect(TileType.empty.formatted() == " ")
    #expect(TileType.brick.formatted() == "#")
    #expect(TileType.solid.formatted() == "@")
    #expect(TileType.ladder.formatted() == "H")
    #expect(TileType.bar.formatted() == "-")
    #expect(TileType.trap.formatted() == "X")
    #expect(TileType.hiddenLadder.formatted() == "S")
    #expect(TileType.gold.formatted() == "$")
    #expect(TileType.guard.formatted() == "0")
    #expect(TileType.runner.formatted() == "&")
}

@Test("TileType formats identically via the default and the explicit .tile style")
func tileTypeDefaultMatchesExplicitStyle() {
    #expect(TileType.ladder.formatted() == TileType.ladder.formatted(.tile))
}

@Test("[[TileType]].FormatStyle renders a row-major block of text")
func tileGridFormatsRowMajor() {
    // 3 columns x 2 rows: [x][y].
    let grid: [[TileType]] = [
        [.brick, .empty],
        [.runner, .ladder],
        [.gold, .solid],
    ]
    #expect(grid.formatted() == "#&$\n H@")
    #expect(grid.formatted(.tileGrid) == grid.formatted())
}

@Test("[[TileType]].FormatStyle renders an empty grid as an empty string")
func tileGridFormatsEmptyGrid() {
    let grid: [[TileType]] = []
    #expect(grid.formatted() == "")
}
