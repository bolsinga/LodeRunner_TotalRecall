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

    /// Clear any latched action back to `.stop`. Called by the driver when the
    /// sim reports `consumedDigInput` — the JS analog is `keyAction = ACT_STOP`
    /// at `runner.js:111`, which prevents a held dig key from re-firing once
    /// the hole finishes refilling.
    func resetAction()

    /// Called by the driver once per tick, immediately before it reads
    /// `currentAction`. Default no-op; `DemoInput` overrides to advance its
    /// scripted-keypress index. Analog of JS `playDemo` at `demo.js:85-95`,
    /// which runs inside the same tick as `moveRunner`'s `keyAction` read.
    func advanceTickIfNeeded()
}

extension RunnerInput {
    public func advanceTickIfNeeded() { }
}
