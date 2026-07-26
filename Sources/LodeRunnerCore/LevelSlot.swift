public struct GridPoint: Equatable, Hashable, Codable, Sendable {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

/// One cell of a level's 28x16 grid.
///
/// `base` and `current` (the JS calls this field `act`, short for "active tile type")
/// are usually equal, but diverge for gold (`base = .gold`, `current = .empty` — nothing
/// blocks walking into the cell) and for guard/runner spawns (`base = .empty`,
/// `current = .guard`/`.runner` — the entity occupies otherwise-empty ground). Movement
/// code checks `current`; `base` is what a tile reverts to once its temporary occupant
/// (or a dug hole, in a later phase) is gone.
public struct LevelSlot: Equatable, Codable, Sendable {
    public var base: TileType
    public var current: TileType

    public init(base: TileType, current: TileType) {
        self.base = base
        self.current = current
    }
}
