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
///   - `extendedGamepad` (MFi/console controllers): D-pad or left
///     thumbstick → up / down / left / right; button A → dig left;
///     button B → dig right.
///   - `microGamepad` (the Siri Remote — tvOS only in practice, but the
///     profile check itself isn't platform-gated): touch-surface `dpad` →
///     up / down / left / right, same as above. Only two real buttons
///     exist, so digging is a `microGamepadSplitDigButtons`-controlled
///     choice — see that property.
///
/// A controller reporting `extendedGamepad` wins if it reports both (real
/// hardware never does; this just fixes the precedence).
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

    /// tvOS Settings row, "SPLIT DIG BUTTONS" — only meaningful for
    /// `microGamepad` controllers (the Siri Remote), which have just two
    /// real buttons (A, X). **Off** (default): a single "auto" dig via
    /// `buttonA` — digs whichever direction the runner last faced
    /// (`facingDigAction`), leaving `buttonX` unbound, since it's
    /// physically the Play/Pause button on 1st/2nd-gen Siri Remotes
    /// (`GCInputMicroGamepadButtonX`'s docs) and hijacking it isn't free.
    /// **On**: `buttonA`/`buttonX` split into dig-left/dig-right, matching
    /// the `extendedGamepad` A/B convention, at the cost of overloading
    /// Play/Pause.
    public var microGamepadSplitDigButtons: Bool = false

    /// The action currently latching `rawAction`, so a release can tell
    /// "this is the button driving the action" apart from "an already-
    /// superseded button" — same role as `KeyboardInput.heldKey`, keyed by
    /// `RunnerAction` directly since every gamepad control this port reads
    /// maps 1:1 to a distinct action.
    private var heldAction: RunnerAction?

    /// Which dig direction `microGamepad`'s `buttonA` fires in "auto" mode
    /// — the direction the runner last faced. Updated by every `.left`/
    /// `.right` press regardless of source (D-pad, thumbstick, ...), so it
    /// stays correct even for controllers that never touch this at all.
    private var facingDigAction: RunnerAction = .digRight

    /// `buttonA`'s dig action in "auto" mode depends on `facingDigAction`,
    /// which can change while the button is held (if the runner also
    /// presses a direction). Caching the press-time action and reusing it
    /// verbatim for the matching release avoids a mismatched
    /// `handle(_:pressed:false)` call that would never clear `heldAction`.
    private var microButtonADigAction: RunnerAction?

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
        if let gamepad = controller.extendedGamepad {
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
        } else if let micro = controller.microGamepad {
            bind(micro.dpad.up, to: .up)
            bind(micro.dpad.down, to: .down)
            bind(micro.dpad.left, to: .left)
            bind(micro.dpad.right, to: .right)
            bindMicroGamepadDigButtons(micro)
        }
    }

    private func bindMicroGamepadDigButtons(_ micro: GCMicroGamepad) {
        micro.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            MainActor.assumeIsolated {
                self?.handleMicroButtonA(pressed: pressed)
            }
        }
        micro.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
            MainActor.assumeIsolated {
                self?.handleMicroButtonX(pressed: pressed)
            }
        }
    }

    /// Module-internal (not `private`) for the same testability reason as
    /// `handle(_:pressed:)`.
    func handleMicroButtonA(pressed: Bool) {
        if pressed {
            let action: RunnerAction = microGamepadSplitDigButtons ? .digLeft : facingDigAction
            microButtonADigAction = action
            handle(action, pressed: true)
        } else if let action = microButtonADigAction {
            handle(action, pressed: false)
            microButtonADigAction = nil
        }
    }

    func handleMicroButtonX(pressed: Bool) {
        guard microGamepadSplitDigButtons else { return }
        handle(.digRight, pressed: pressed)
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
            switch action {
            case .left: facingDigAction = .digLeft
            case .right: facingDigAction = .digRight
            default: break
            }
        } else if !repeatActionsEnabled, heldAction == action {
            rawAction = .stop
            heldAction = nil
        }
    }

    public func resetAction() {
        rawAction = .stop
        heldAction = nil
        microButtonADigAction = nil
    }
}
