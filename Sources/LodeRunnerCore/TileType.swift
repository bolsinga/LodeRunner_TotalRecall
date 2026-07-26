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
