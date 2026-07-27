
/// Display-side state that reconstructs the two fields the JS embedded in
/// `runner`/`guard` but the Swift sim intentionally dropped as display-only
/// (see `Runner.swift:20`, `Guard.swift:12`):
///
/// - `facing`: the last `.left` or `.right` action the entity took. The JS
///   updates this only when `action == ACT_LEFT || ACT_RIGHT`
///   (`lodeRunner.runner.js:293`); the value survives across other actions.
/// - `lastAnimation`: the most recent non-nil result of the animation
///   derivation. Preserved across `.stop` ticks (JS `runner.sprite.stop()`
///   freezes on the current shape — `runner.js:273`), and used by the
///   caller to freeze rendering on a single frame while stopped. Also used by
///   `GuardAnimation.forGuard`'s shake-orientation path as the `previous`
///   input.
///
/// A tick driver — the eventual Swift equivalent of `createjs.Ticker`'s
/// `mainTick` — will `update(with:baseTile:)` each `RunnerAppearance` /
/// `GuardAppearance` once per sim tick.
public struct RunnerAppearance: Equatable, Sendable {
    public private(set) var facing: RunnerAction
    public private(set) var lastAnimation: RunnerAnimation

    public init(facing: RunnerAction = .right, lastAnimation: RunnerAnimation = .runRight) {
        self.facing = facing
        self.lastAnimation = lastAnimation
    }

    /// Consume a fresh `Runner` snapshot: update `facing` if the new action is
    /// `.left`/`.right` (`runner.js:293`), and update `lastAnimation` if the
    /// derivation produces one (`runner.js:280-283`). Both fields are
    /// preserved when the action is `.stop` — this is the intentional
    /// non-update the JS performs in that branch.
    public mutating func update(with runner: Runner, baseTile: TileType) {
        switch runner.action {
        case .left: facing = .left
        case .right: facing = .right
        default: break
        }
        if let newAnimation = RunnerAnimation.forRunner(
            action: runner.action, baseTile: baseTile, facing: facing
        ) {
            lastAnimation = newAnimation
        }
    }
}

public struct GuardAppearance: Equatable, Sendable {
    public private(set) var facing: GuardAction
    public private(set) var lastAnimation: GuardAnimation

    public init(facing: GuardAction = .right, lastAnimation: GuardAnimation = .runRight) {
        self.facing = facing
        self.lastAnimation = lastAnimation
    }

    /// Same contract as `RunnerAppearance.update` but ported from
    /// `lodeRunner.guard.js:342-350`. Feeds `lastAnimation` back into
    /// `GuardAnimation.forGuard` as `previous` so `.inHole` gets the correct
    /// shake orientation (`guard.js:243-244`).
    public mutating func update(with guardState: Guard, baseTile: TileType) {
        switch guardState.action {
        case .left: facing = .left
        case .right: facing = .right
        default: break
        }
        if let newAnimation = GuardAnimation.forGuard(
            action: guardState.action, baseTile: baseTile, facing: facing,
            previous: lastAnimation
        ) {
            lastAnimation = newAnimation
        }
    }
}
