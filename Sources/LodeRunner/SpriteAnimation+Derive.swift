
extension RunnerAnimation {
    /// Ports the `newShape` derivation from `lodeRunner.runner.js:127-259` and the
    /// dig-shape assignment from `digHole` (`lodeRunner.runner.js:480-492`). The
    /// Swift `Runner` deliberately drops the JS's `shape`/`lastLeftRight` fields
    /// (see `Runner.swift:20`), so the caller supplies `facing` — the last
    /// `.left` or `.right` the runner took, equivalent to `runner.lastLeftRight`.
    ///
    /// Returns `nil` for `.stop`: the JS calls `runner.sprite.stop()` in that
    /// case and leaves `runner.shape` unchanged (`runner.js:267-275`), so the
    /// display should freeze on whatever animation was last playing rather than
    /// pick a new one. Callers wanting an idle image can substitute
    /// `runner1`/`guard1` from the theme, matching `TileCellView`.
    ///
    /// - Parameters:
    ///   - action: the runner's current `RunnerAction`.
    ///   - baseTile: `slots[x][y].base` at the runner's position. Only relevant
    ///     for `.left`/`.right`, which pick `barLeft`/`barRight` on `.bar` else
    ///     `runLeft`/`runRight` (`runner.js:238-239, 258-259`).
    ///   - facing: last `.left` or `.right` action taken. Selects orientation
    ///     for `.fall`/`.fallBar` (`runner.js:211-216`). Any value other than
    ///     `.left` is treated as right-facing, matching JS's `else` branches.
    public static func forRunner(
        action: RunnerAction, baseTile: TileType, facing: RunnerAction
    ) -> RunnerAnimation? {
        switch action {
        case .up, .down:
            return .runUpDn
        case .left:
            return baseTile == .bar ? .barLeft : .runLeft
        case .right:
            return baseTile == .bar ? .barRight : .runRight
        case .fall:
            return facing == .left ? .fallLeft : .fallRight
        case .fallBar:
            return facing == .left ? .barLeft : .barRight
        case .digLeft:
            return .digLeft
        case .digRight:
            return .digRight
        case .stop:
            return nil
        }
    }
}

extension GuardAnimation {
    /// Ports the `newShape` derivation from `lodeRunner.guard.js:70-322` plus the
    /// out-of-band shape assignments in `guardReborn` (`guard.js:891-897`) and
    /// `climbOut` (`guard.js:522-525`). Same `facing` contract as
    /// `RunnerAnimation.forRunner`.
    ///
    /// **In-hole shake orientation**: JS picks `shakeRight`/`shakeLeft` from the
    /// *previous* shape (`guard.js:243-244`: `curShape == "fallRight"` →
    /// `shakeRight`, else `shakeLeft`). When `previous` is supplied we match
    /// that exactly; when it isn't we fall back to `facing`, which produces the
    /// same answer in the paths that lead to `.inHole` (the guard is always
    /// falling before entering the hole).
    public static func forGuard(
        action: GuardAction, baseTile: TileType, facing: GuardAction,
        previous: GuardAnimation? = nil
    ) -> GuardAnimation? {
        switch action {
        case .up, .down, .climbOut:
            return .runUpDn
        case .left:
            return baseTile == .bar ? .barLeft : .runLeft
        case .right:
            return baseTile == .bar ? .barRight : .runRight
        case .fall:
            return facing == .left ? .fallLeft : .fallRight
        case .fallBar:
            return facing == .left ? .barLeft : .barRight
        case .inHole:
            if let previous {
                return previous == .fallRight ? .shakeRight : .shakeLeft
            }
            return facing == .left ? .shakeLeft : .shakeRight
        case .reborn:
            return .reborn
        case .stop:
            return nil
        }
    }
}
