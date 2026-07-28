/// Ported from the subset of `lodeRunner.def.js`'s `ACT_*` constants the runner ever
/// actually uses (`ACT_IN_HOLE`/`ACT_CLIMB_OUT`/`ACT_REBORN` are guard-only).
///
/// `String`-backed (lowercase raw values) so callers can round-trip an action through
/// a name — e.g. `RunnerAction(rawValue: "fallbar")` — without a separate lookup table.
public enum RunnerAction: String, Equatable, Codable, Sendable {
    case stop, left, right, up, down, fall
    case fallBar = "fallbar"
    case digLeft = "digleft"
    case digRight = "digright"
}

public enum RunnerPhase: Equatable, Codable, Sendable {
    /// Pre-play "waiting for first input" state. Ported from `GAME_START` in
    /// `lodeRunner.main.js:41` (constant) / `1296, 1306, 1419-1422` (blink +
    /// transition on keypress). `tick(_:)` no-ops in this phase — call
    /// `RunnerSimulation.beginPlay()` (the port of `beginPlay` at
    /// `lodeRunner.main.js:1298-1306`) to advance to `.playing`. Only entered
    /// by composition-layer code that wants the born-blink pause; direct
    /// `RunnerSimulation(level:)` starts in `.playing` for backward
    /// compatibility with the CLI + existing tests.
    case starting
    case playing
    case finished  // reached row 0, exactly centered, with all gold collected
    case dead  // buried: a dug hole finished refilling while the runner stood in it
}

/// The runner's position and current action, ported from `runner.pos`/`runner.action`
/// in `lodeRunner.runner.js` (sprite/shape fields dropped — display-only).
public struct Runner: Equatable, Codable, Sendable {
    public let position: GridPoint
    public let xOffset: Int
    public let yOffset: Int
    public let action: RunnerAction

    public init(position: GridPoint, xOffset: Int, yOffset: Int, action: RunnerAction) {
        self.position = position
        self.xOffset = xOffset
        self.yOffset = yOffset
        self.action = action
    }
}
