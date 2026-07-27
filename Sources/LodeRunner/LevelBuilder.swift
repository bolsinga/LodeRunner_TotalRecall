/// Build a 28x16 level directly from `TileType` stamps, feeding the tile-native
/// `resolveLevelMap(tiles:)` engine so no raw level string is involved. The bottom
/// row is auto-filled with bricks (any position not otherwise stamped) so callers
/// get a valid floor for free.
///
/// Used by SwiftUI previews and, via `@testable import`, by the simulation/session
/// tests — the only paths that construct a `LevelParseResult` outside the parser
/// itself.
func makeLevel(stamps: [(x: Int, y: Int, tile: TileType)]) -> LevelParseResult {
    var tiles = Array(repeating: TileType.empty, count: LevelGrid.tileCount)
    for x in 0..<LevelGrid.tilesX {
        tiles[(LevelGrid.tilesY - 1) * LevelGrid.tilesX + x] = .brick
    }
    for stamp in stamps {
        tiles[stamp.y * LevelGrid.tilesX + stamp.x] = stamp.tile
    }
    return resolveLevelMap(tiles: tiles)
}
