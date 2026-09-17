import GameController
import Observation

/// Hardware-gamepad `RunnerInput`. Ports the JS's button-polling loop
/// (`gamepadRequestState`, `lodeRunner.gamepad.js:143-217`), which
/// translates physical D-pad/stick/button state into synthesized
/// keydown/keyup events fed into the *same* key-state machine the keyboard
/// drives (`sendKeyDown`/`sendKeyUp` → `sendGameKeyDown`/`sendGameKeyUp`,
/// `gamepad.js:236-256`) — including whatever sticky/repeat mode is active.
///
/// This port reimplements that same sticky/repeat decision independently
/// (mirroring `KeyboardInput`'s `heldKey`/`repeatActionsEnabled` logic)
/// rather than routing synthetic events through `KeyboardInput` itself —
/// consistent with this codebase's existing precedent of `DemoInput` also
/// reimplementing rather than sharing plumbing with `KeyboardInput`, even
/// though the JS's `playDemo` also calls the shared `pressKey`.
///
/// Button map (this port's own choice — the JS's SNES-labeled diagram
/// `image/gamepad-snes.svg` doesn't correspond 1:1 to `GCExtendedGamepad`'s
/// abstract Xbox-style profile, so there's no byte-exact mapping to
/// preserve):
///
///   - D-pad or left thumbstick: up / down / left / right
///   - Button A: dig left
///   - Button B: dig right
///
/// Only `extendedGamepad`-profile controllers (MFi/console controllers) are
/// handled; the `microGamepad` profile (e.g. the first-generation Siri
/// Remote) is out of scope until this package targets tvOS — see
/// `Package.swift`'s `platforms`, which lists only iOS and macOS today.
@Observable @MainActor
public final class GamepadInput: RunnerInput {
    /// `Ctrl+J` setting (mirrors JS `gamepadMode`, `key.js:130` — default
    /// **on**, `storage.js:459-462`). When off, `currentAction` always
    /// reports `.stop` regardless of physical controller state, but button
    /// tracking underneath keeps running so re-enabling mid-press doesn't
    /// misfire.
    public var isEnabled: Bool = true

    public var currentAction: RunnerAction { isEnabled ? rawAction : .stop }
    private var rawAction: RunnerAction = .stop

    /// Mirrors `KeyboardInput.repeatActionsEnabled` — the JS drives gamepad
    /// button releases through the identical `processInputKeyState`
    /// dispatch as keyboard releases (`gamepad.js:197-204`), so the same
    /// toggle applies here too.
    public var repeatActionsEnabled: Bool = false

    /// The action currently latching `rawAction`, so a release can tell
    /// "this is the button driving the action" apart from "an already-
    /// superseded button" — same role as `KeyboardInput.heldKey`, keyed by
    /// `RunnerAction` directly since every gamepad control this port reads
    /// maps 1:1 to a distinct action.
    private var heldAction: RunnerAction?

    private var connectObserver: NSObjectProtocol?
    private var disconnectObserver: NSObjectProtocol?

    public init() {
        attachAllControllers()
        // Tokens are retained in `connectObserver`/`disconnectObserver` for
        // as long as this instance lives; NotificationCenter automatically
        // un-registers a block-based observer when its token deallocates,
        // so no explicit `deinit`/`removeObserver` is needed (and a
        // `@MainActor` class's `deinit` can't touch actor-isolated state
        // synchronously anyway).
        connectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect, object: nil, queue: .main
        ) { [weak self] _ in
            // Ignore the notification's `object` (the newly-connected
            // `GCController`) and just rescan `controllers()` instead of
            // extracting it — `GCController` isn't `Sendable`, and pulling
            // it out of the notification would mean carrying a non-
            // `Sendable` value across the closure literal's isolation
            // boundary. `queue: .main` above guarantees this fires on the
            // main queue/actor already, hence `assumeIsolated` rather than
            // an async hop.
            MainActor.assumeIsolated {
                self?.attachAllControllers()
            }
        }
        disconnectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.resetAction()
            }
        }
    }

    private func attachAllControllers() {
        GCController.controllers().forEach(attach)
    }

    private func attach(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }

        bind(gamepad.dpad.up, to: .up)
        bind(gamepad.dpad.down, to: .down)
        bind(gamepad.dpad.left, to: .left)
        bind(gamepad.dpad.right, to: .right)

        bind(gamepad.leftThumbstick.up, to: .up)
        bind(gamepad.leftThumbstick.down, to: .down)
        bind(gamepad.leftThumbstick.left, to: .left)
        bind(gamepad.leftThumbstick.right, to: .right)

        bind(gamepad.buttonA, to: .digLeft)
        bind(gamepad.buttonB, to: .digRight)
    }

    private func bind(_ button: GCControllerButtonInput, to action: RunnerAction) {
        button.pressedChangedHandler = { [weak self] _, _, pressed in
            // `handlerQueue` defaults to the main queue (`GCDevice.handlerQueue`),
            // so this really is already on the main actor — see the note in
            // `init` about why `assumeIsolated` over an async hop.
            MainActor.assumeIsolated {
                self?.handle(action, pressed: pressed)
            }
        }
    }

    /// The phase-decision logic behind `attach`'s handlers, exposed
    /// (module-internal, not `private`) so tests can drive it directly
    /// without a real `GCController` — mirrors why `KeyboardInput` exposes
    /// `handle(key:phase:)` for the same reason.
    func handle(_ action: RunnerAction, pressed: Bool) {
        if pressed {
            rawAction = action
            heldAction = action
        } else if !repeatActionsEnabled, heldAction == action {
            rawAction = .stop
            heldAction = nil
        }
    }

    public func resetAction() {
        rawAction = .stop
        heldAction = nil
    }
}
