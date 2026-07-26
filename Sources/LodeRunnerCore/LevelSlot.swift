/// Descriptive classification of a level cell, ported from the JS's `kind` string field
/// (`lodeRunner.levelParse.js`). Distinct from `TileType`: `kind` records what the cell
/// *represents* (e.g. "gold", "guard") even after culling forces its `current` tile type
/// back to `.empty`.
public enum LevelSlotKind: String, Equatable, Codable, Sendable {
    case empty
    case brick
    case solid
    case ladder
    case rope
    case trap
    case hladder
    case gold
    case `guard`
    case runner
}

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
    /// Single character, matching JS's `levelMap.charAt(index)`.
    public var char: String
    public var kind: LevelSlotKind

    public init(base: TileType, current: TileType, char: String, kind: LevelSlotKind) {
        self.base = base
        self.current = current
        self.char = char
        self.kind = kind
    }
}
