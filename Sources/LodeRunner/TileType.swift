/// Ported from `lodeRunner.def.js`'s tile constants (comment table above `EMPTY_T`).
public enum TileType: UInt8, Equatable, Codable, Sendable {
    case empty = 0x00
    case brick = 0x01
    case solid = 0x02
    case ladder = 0x03
    case bar = 0x04
    case trap = 0x05
    case hiddenLadder = 0x06
    case gold = 0x07
    case `guard` = 0x08
    case runner = 0x09
}

extension TileType {
    /// Map a level-map character to its authoring-intent `TileType`. Inverse of the
    /// canonical char shown in `lodeRunner.levelParse.js:LEGAL_LEVEL_CHARS`. Unknown
    /// characters (including `" "`) resolve to `.empty`, matching the JS parser's
    /// default-to-empty fallback.
    public init(levelChar: Character) {
        switch levelChar {
        case "#": self = .brick
        case "@": self = .solid
        case "H": self = .ladder
        case "-": self = .bar
        case "X": self = .trap
        case "S": self = .hiddenLadder
        case "$": self = .gold
        case "0": self = .guard
        case "&": self = .runner
        default: self = .empty
        }
    }

    /// The (base, current) split for this tile, ported from `parseLevelChar` in
    /// `lodeRunner.levelParse.js:19-44`. Most tiles have `base == current`; the
    /// exceptions carry authoring intent: `.hiddenLadder` and `.gold` sit as `base`
    /// with `.empty` current (walkable / awaits pickup); `.guard` and `.runner`
    /// occupy `current` over `.empty` base (mobile entity on open ground).
    public var levelSlot: LevelSlot {
        switch self {
        case .empty: return LevelSlot(base: .empty, current: .empty)
        case .brick: return LevelSlot(base: .brick, current: .brick)
        case .solid: return LevelSlot(base: .solid, current: .solid)
        case .ladder: return LevelSlot(base: .ladder, current: .ladder)
        case .bar: return LevelSlot(base: .bar, current: .bar)
        case .trap: return LevelSlot(base: .trap, current: .trap)
        case .hiddenLadder: return LevelSlot(base: .hiddenLadder, current: .empty)
        case .gold: return LevelSlot(base: .gold, current: .empty)
        case .guard: return LevelSlot(base: .empty, current: .guard)
        case .runner: return LevelSlot(base: .empty, current: .runner)
        }
    }
}
