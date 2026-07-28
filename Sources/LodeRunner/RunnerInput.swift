/// Source of the next `RunnerAction` for `SimulationDriver` to consume. Polled once
/// per tick, matching the JS's `keyRunnerAction` global read by `playGame`
/// (`lodeRunner.main.js:907` → `processInputKeyState`).
///
/// Concrete conformers are per-platform (`KeyboardInput` for macOS / hardware-
/// keyboard iPad, later a gamepad/touch variant); the driver stays platform-agnostic
/// and only ever sees this protocol.
@MainActor
public protocol RunnerInput: AnyObject {
    /// The action that would be applied if the sim ticked right now. Reads are
    /// non-mutating — the input source holds this state internally, updated
    /// asynchronously by its platform's event stream.
    var currentAction: RunnerAction { get }
}
