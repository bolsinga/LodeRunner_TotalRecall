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
///   - `GCDirectionalGamepad` (2nd-gen+ Siri Remote, tvOS only in
///     practice): clicking the outer ring's cardinal d-pad → up / down /
///     left / right; the inner-ring center button digs, as a
///     `microGamepadSplitDigButtons`-controlled choice — see that
///     property. Older remotes aren't supported for gameplay.
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
    /// the Siri Remote, whose dig buttons are the center button and
    /// Play/Pause (X). **Off** (default): a single "auto" dig via the
    /// center button — digs whichever direction the runner last faced
    /// (`facingDigAction`), leaving `buttonX` unbound, since it's
    /// physically the Play/Pause button on 1st/2nd-gen Siri Remotes
    /// (`GCInputMicroGamepadButtonX`'s docs) and hijacking it isn't free.
    /// **On**: `buttonA`/`buttonX` split into dig-left/dig-right, matching
    /// the `extendedGamepad` A/B convention, at the cost of overloading
    /// Play/Pause.
    public var microGamepadSplitDigButtons: Bool = false

    /// Fires when the player presses the controller's Menu button. On
    /// tvOS, once `GameControllerEventHost` sets `GCEventViewController
    /// .controllerUserInteractionEnabled = false` during live gameplay,
    /// the focus engine can no longer reach `GameView`'s own on-screen
    /// exitBar button — this is the only remaining way back to the pause
    /// menu. Bound for both `extendedGamepad` and `microGamepad` (the
    /// Siri Remote — first-gen "Menu" / second-gen "Back" per
    /// `GCInputMicroGamepadButtonMenu`'s docs).
    public var onMenuButtonPressed: (() -> Void)?

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

            gamepad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
                MainActor.assumeIsolated {
                    self?.handleMenuButton(pressed: pressed)
                }
            }
        } else if let micro = controller.microGamepad, micro is GCDirectionalGamepad {
            // 2nd-gen-and-later Siri Remote (needs the Directional Gamepad
            // capability + `GCSupportsMultipleMicroGamepads`, otherwise the
            // system hands back a plain analog micro gamepad). Its outer
            // ring is an 8-way *digital* cardinal d-pad: clicking a zone
            // is a real, mutually-exclusive, holdable button press, so
            // there's no touch-position thresholding to tune. The inner
            // ring's click is a separate center button, so a dig never
            // shares a sensor with a direction. Older remotes aren't
            // supported for gameplay.
            let profile = controller.physicalInputProfile
            if let cardinal = profile.dpads[GCInputDirectionalCardinalDpad] {
                bind(cardinal.up, to: .up)
                bind(cardinal.down, to: .down)
                bind(cardinal.left, to: .left)
                bind(cardinal.right, to: .right)
            }
            profile.buttons[GCInputDirectionalCenterButton]?.pressedChangedHandler = {
                [weak self] _, _, pressed in
                MainActor.assumeIsolated {
                    self?.handleMicroButtonA(pressed: pressed)
                }
            }
            micro.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
                MainActor.assumeIsolated {
                    self?.handleMicroButtonX(pressed: pressed)
                }
            }
            micro.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
                MainActor.assumeIsolated {
                    self?.handleMenuButton(pressed: pressed)
                }
            }
        }
    }

    /// Module-internal (not `private`) for the same testability reason as
    /// `handle(_:pressed:)`. Fires only on press, not release — matches
    /// how a single button tap should open the menu exactly once.
    func handleMenuButton(pressed: Bool) {
        guard pressed else { return }
        onMenuButtonPressed?()
    }

    /// Module-internal (not `private`) for the same testability reason as
    /// `handle(_:pressed:)`.
    func handleMicroButtonA(pressed: Bool) {
        if pressed {
            // Center button: split mode digs left; otherwise digs whichever
            // direction the runner last faced.
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
