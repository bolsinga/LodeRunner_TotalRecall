/// Tile pixel geometry, ported from `lodeRunner.def.js`'s `BASE_TILE_X`/`BASE_TILE_Y`
/// and `lodeRunner.main.js`'s `W2`/`H2`/`W4`/`H4`/`maxTileX`/`maxTileY`. Every value
/// here is load-bearing for the runner's own movement math (tile-boundary-crossing
/// arithmetic, the gold-pickup proximity check, edge-of-grid bounds checks) — not
/// added speculatively for guard movement, though guard movement (a later phase) does
/// reuse these same tile-size constants.
public enum TileGeometry {
    public static let tileWidth = 40
    public static let tileHeight = 44

    public static let halfTileWidth = tileWidth / 2  // 20
    public static let halfTileHeight = tileHeight / 2  // 22

    public static let quarterTileWidth = tileWidth / 4  // 10
    public static let quarterTileHeight = tileHeight / 4  // 11

    public static let maxTileX = LevelGrid.tilesX - 1  // 27
    public static let maxTileY = LevelGrid.tilesY - 1  // 15
}
