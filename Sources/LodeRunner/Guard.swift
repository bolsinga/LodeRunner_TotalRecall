/// Ported from the guard-relevant `lodeRunner.def.js` `ACT_*` constants — a superset
/// of `RunnerAction` (guards never dig, but do enter/climb-out-of holes and respawn).
public enum GuardAction: String, Equatable, Codable, Sendable {
    case stop, left, right, up, down, fall, fallBar
    case inHole = "inhole"
    case climbOut = "climbout"
    case reborn
}

/// A guard's position and current action, ported from `guard[i]` in
/// `lodeRunner.guard.js`. Immutable and replaced wholesale each tick, matching
/// `Runner`'s design — sprite/shape/`lastLeftRight` fields are dropped entirely
/// (verified display-only by tracing every read).
public struct Guard: Equatable, Codable, Sendable {
    public let position: GridPoint
    public let xOffset: Int
    public let yOffset: Int
    public let action: GuardAction
    /// `0` = not carrying; `12...37` = carrying, counting down; `< 0` = just
    /// dropped, cooling down back toward `0` before it can pick up again.
    public let hasGold: Int
    /// Set once by `climbOut`: the row the guard fell into. Only meaningful while
    /// `action` is `.inHole` or `.climbOut`.
    public let holePos: GridPoint?

    public init(
        position: GridPoint, xOffset: Int = 0, yOffset: Int = 0,
        action: GuardAction = .stop, hasGold: Int = 0, holePos: GridPoint? = nil
    ) {
        self.position = position
        self.xOffset = xOffset
        self.yOffset = yOffset
        self.action = action
        self.hasGold = hasGold
        self.holePos = holePos
    }
}
