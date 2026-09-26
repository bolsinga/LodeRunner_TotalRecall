import Testing

@testable import LodeRunner

@Suite
@MainActor
struct GamepadInputTests {
    @Test("sticky mode (default): releasing the active button stops the action")
    func stickyModeReleaseStops() {
        let input = GamepadInput()
        #expect(input.repeatActionsEnabled == false)
        input.handle(.right, pressed: true)
        #expect(input.currentAction == .right)
        input.handle(.right, pressed: false)
        #expect(input.currentAction == .stop)
    }

    @Test("sticky mode: releasing a superseded button is a no-op")
    func stickyModeReleaseOfSupersededButtonIsNoOp() {
        let input = GamepadInput()
        input.handle(.right, pressed: true)
        input.handle(.down, pressed: true)  // supersedes .right
        #expect(input.currentAction == .down)
        input.handle(.right, pressed: false)
        #expect(input.currentAction == .down)  // unaffected — .right is stale
    }

    @Test("repeat mode: release is ignored, action persists past release")
    func repeatModeIgnoresRelease() {
        let input = GamepadInput()
        input.repeatActionsEnabled = true
        input.handle(.right, pressed: true)
        #expect(input.currentAction == .right)
        input.handle(.right, pressed: false)
        #expect(input.currentAction == .right)  // still latched
    }

    @Test("repeat mode: a new button overrides the persisted action")
    func repeatModeNewButtonOverrides() {
        let input = GamepadInput()
        input.repeatActionsEnabled = true
        input.handle(.right, pressed: true)
        input.handle(.right, pressed: false)  // ignored, still .right
        input.handle(.up, pressed: true)
        #expect(input.currentAction == .up)
    }

    @Test("resetAction clears heldAction, so a stale release is a no-op")
    func resetActionClearsHeldAction() {
        let input = GamepadInput()
        input.handle(.right, pressed: true)
        input.resetAction()
        #expect(input.currentAction == .stop)
        input.handle(.right, pressed: false)
        #expect(input.currentAction == .stop)
    }

    @Test("isEnabled == false reports .stop regardless of button state")
    func disabledReportsStop() {
        let input = GamepadInput()
        input.handle(.right, pressed: true)
        #expect(input.currentAction == .right)
        input.isEnabled = false
        #expect(input.currentAction == .stop)
        // Re-enabling resumes the still-held button rather than requiring
        // a fresh press — matches JS's `toggleGamepadMode`, which doesn't
        // reset `lastButtonState` on toggle (`gamepad.js:136-141`).
        input.isEnabled = true
        #expect(input.currentAction == .right)
    }

    // MARK: - microGamepad (Siri Remote) dig buttons

    @Test("auto mode (default): buttonA digs in the last-faced direction")
    func microAutoDigFacesLastDirection() {
        let input = GamepadInput()
        #expect(input.microGamepadSplitDigButtons == false)
        input.handle(.left, pressed: true)
        input.handle(.left, pressed: false)  // release before digging — see below
        input.handleMicroButtonA(pressed: true)
        #expect(input.currentAction == .digLeft)
        input.handleMicroButtonA(pressed: false)
        #expect(input.currentAction == .stop)

        input.handle(.right, pressed: true)
        input.handle(.right, pressed: false)
        input.handleMicroButtonA(pressed: true)
        #expect(input.currentAction == .digRight)
    }

    @Test("auto mode: defaults to digRight before any direction is pressed")
    func microAutoDigDefaultsRight() {
        let input = GamepadInput()
        input.handleMicroButtonA(pressed: true)
        #expect(input.currentAction == .digRight)
    }

    @Test("auto mode: buttonX is unbound (it's the Play/Pause button)")
    func microAutoModeIgnoresButtonX() {
        let input = GamepadInput()
        input.handleMicroButtonX(pressed: true)
        #expect(input.currentAction == .stop)
    }

    @Test("changing the split setting mid-press doesn't strand the held action")
    func microButtonAReleaseUsesPressTimeAction() {
        let input = GamepadInput()
        input.handle(.right, pressed: true)  // facing = .digRight
        input.handle(.right, pressed: false)
        input.handleMicroButtonA(pressed: true)
        #expect(input.currentAction == .digRight)
        // Flip the setting while A is still physically held — recomputing
        // fresh at release time would ask for .digLeft (split mode's fixed
        // mapping), which doesn't match what's actually latched (.digRight),
        // silently stranding it forever. The cached press-time action must
        // be released instead.
        input.microGamepadSplitDigButtons = true
        input.handleMicroButtonA(pressed: false)
        #expect(input.currentAction == .stop)
    }

    @Test("split mode: buttonA digs left, buttonX digs right")
    func microSplitModeMapsAToLeftXToRight() {
        let input = GamepadInput()
        input.microGamepadSplitDigButtons = true
        input.handleMicroButtonA(pressed: true)
        #expect(input.currentAction == .digLeft)
        input.handleMicroButtonA(pressed: false)
        #expect(input.currentAction == .stop)

        input.handleMicroButtonX(pressed: true)
        #expect(input.currentAction == .digRight)
        input.handleMicroButtonX(pressed: false)
        #expect(input.currentAction == .stop)
    }

    // MARK: - microGamepad ring click digs in its own direction

    @Test("a ring click (dpad direction + buttonA firing together) digs in that direction")
    func microRingClickDigsInClickedDirection() {
        let input = GamepadInput()
        // The ring's shared click sensor reports the dpad direction a
        // moment before buttonA, same as real hardware — see
        // `GamepadInputTests`'s trace-derived rationale in
        // `handleMicroButtonA`.
        input.handleMicroDpadValueChanged(x: -0.8, y: -0.2)  // ring's left zone
        input.handleMicroButtonA(pressed: true)
        #expect(input.currentAction == .digLeft)
        input.handleMicroButtonA(pressed: false)
        input.handleMicroDpadValueChanged(x: 0.0, y: 0.0)

        input.handleMicroDpadValueChanged(x: 0.7, y: -0.1)  // ring's right zone
        input.handleMicroButtonA(pressed: true)
        #expect(input.currentAction == .digRight)
    }

    // MARK: - microGamepad dpad dominant-axis resolution

    @Test("centered (both axes within the deadzone) reports no direction")
    func microDpadCenteredIsNoDirection() {
        let input = GamepadInput()
        input.handleMicroDpadValueChanged(x: 0.1, y: -0.1)
        #expect(input.currentAction == .stop)
    }

    @Test("a diagonal touch resolves to whichever axis has the larger magnitude")
    func microDpadDiagonalResolvesToDominantAxis() {
        let input = GamepadInput()
        // Mostly-left touch with a little vertical drift — the exact
        // shape of touch that, before resolving a single dominant axis,
        // used to fire both .left and .up simultaneously.
        input.handleMicroDpadValueChanged(x: -0.6, y: 0.2)
        #expect(input.currentAction == .left)

        input.handleMicroDpadValueChanged(x: 0.2, y: 0.6)
        #expect(input.currentAction == .up)
    }

    @Test("vertical bias compensates for the circular touch surface being harder to reach top/bottom than side-to-side")
    func microDpadVerticalBiasFavorsUpDown() {
        let input = GamepadInput()
        // Same magnitude on both axes: without the bias this would tie
        // toward left/right (`>=`); with it, the scaled-up y wins.
        input.handleMicroDpadValueChanged(x: 0.35, y: 0.3)
        #expect(input.currentAction == .up)
    }

    @Test("returning to center releases the active direction")
    func microDpadReturnToCenterReleases() {
        let input = GamepadInput()
        input.handleMicroDpadValueChanged(x: -0.6, y: 0.0)
        #expect(input.currentAction == .left)
        input.handleMicroDpadValueChanged(x: 0.0, y: 0.0)
        #expect(input.currentAction == .stop)
    }

    @Test("switching directions releases the old one before engaging the new one")
    func microDpadSwitchingDirectionsReleasesOld() {
        let input = GamepadInput()
        input.handleMicroDpadValueChanged(x: -0.6, y: 0.0)
        #expect(input.currentAction == .left)
        input.handleMicroDpadValueChanged(x: 0.6, y: 0.0)
        #expect(input.currentAction == .right)
    }

    @Test("standing still (centered dpad), buttonA digs in the last-faced direction")
    func microButtonADigsWhenDpadCentered() {
        let input = GamepadInput()
        input.handleMicroDpadValueChanged(x: -0.6, y: 0.0)  // face left
        input.handleMicroDpadValueChanged(x: 0.0, y: 0.0)  // release, centered
        input.handleMicroButtonA(pressed: true)
        #expect(input.currentAction == .digLeft)
    }

    // MARK: - Menu button

    @Test("menu button fires onMenuButtonPressed on press, not release")
    func menuButtonFiresOnPressOnly() {
        let input = GamepadInput()
        var fireCount = 0
        input.onMenuButtonPressed = { fireCount += 1 }
        input.handleMenuButton(pressed: true)
        #expect(fireCount == 1)
        input.handleMenuButton(pressed: false)
        #expect(fireCount == 1)
    }
}
