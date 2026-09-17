/// Merges two `RunnerInput` sources into one, so `GameView` can let players
/// switch between keyboard and gamepad without a mode toggle — mirrors the
/// JS's architecture, where gamepad and keyboard both drive the same global
/// `keyAction` (`gamepad.js:236-256` synthesizes the identical keydown/keyup
/// events the keyboard handler consumes) rather than being mutually
/// exclusive input sources.
///
/// `primary` wins whenever it's actively driving an action; otherwise this
/// falls back to `secondary`. `resetAction()`/`advanceTickIfNeeded()`
/// forward to both, since either source could be the one the driver's
/// dig-consumption or demo-tick logic needs to reach.
@MainActor
final class CombinedInput: RunnerInput {
    private let primary: any RunnerInput
    private let secondary: any RunnerInput

    init(primary: any RunnerInput, secondary: any RunnerInput) {
        self.primary = primary
        self.secondary = secondary
    }

    var currentAction: RunnerAction {
        let action = primary.currentAction
        return action != .stop ? action : secondary.currentAction
    }

    func resetAction() {
        primary.resetAction()
        secondary.resetAction()
    }

    func advanceTickIfNeeded() {
        primary.advanceTickIfNeeded()
        secondary.advanceTickIfNeeded()
    }
}
