import SwiftUI
import Testing

@testable import LodeRunner

@Suite
@MainActor
struct KeyboardInputTests {
    // Both-platform mappings — primary keys shipped on every platform.
    @Test("primary keys map to the expected RunnerAction")
    func primaryKeysMap() {
        let input = KeyboardInput()
        #expect(input.action(for: .leftArrow) == .left)
        #expect(input.action(for: "a") == .left)
        #expect(input.action(for: "A") == .left)
        #expect(input.action(for: .rightArrow) == .right)
        #expect(input.action(for: "d") == .right)
        #expect(input.action(for: .upArrow) == .up)
        #expect(input.action(for: "w") == .up)
        #expect(input.action(for: .downArrow) == .down)
        #expect(input.action(for: "s") == .down)
        #expect(input.action(for: "z") == .digLeft)
        #expect(input.action(for: "x") == .digRight)
    }

    @Test("unbound keys return nil")
    func unboundKeysReturnNil() {
        let input = KeyboardInput()
        #expect(input.action(for: "b") == nil)
        #expect(input.action(for: "1") == nil)
        #expect(input.action(for: " ") == nil)
        #expect(input.action(for: .tab) == nil)
    }

    // JS-parity extended alias set — macOS only. On iOS these fall through
    // to `nil`, matching the intent that hardware-keyboard users on iPad
    // still work with arrows/WASD/Z/X, but the extended JS aliases are
    // reserved for macOS.
    #if os(macOS)
    @Test("extended aliases on macOS — J/L/I/K + Y/U/Q/comma + O/E/period")
    func extendedAliasesMacOS() {
        let input = KeyboardInput()
        // Movement aliases from `key.js:215-232`.
        #expect(input.action(for: "j") == .left)
        #expect(input.action(for: "J") == .left)
        #expect(input.action(for: "l") == .right)
        #expect(input.action(for: "i") == .up)
        #expect(input.action(for: "k") == .down)
        // Dig aliases from `key.js:234-245`. `Y` covers QWERTZ dig-left
        // (JS comment at line 235).
        #expect(input.action(for: "y") == .digLeft)
        #expect(input.action(for: "u") == .digLeft)
        #expect(input.action(for: "q") == .digLeft)
        #expect(input.action(for: ",") == .digLeft)
        #expect(input.action(for: "o") == .digRight)
        #expect(input.action(for: "e") == .digRight)
        #expect(input.action(for: ".") == .digRight)
    }
    #else
    @Test("extended aliases are NOT bound on iOS")
    func extendedAliasesUnboundOniOS() {
        let input = KeyboardInput()
        for c: Character in ["j", "l", "i", "k", "y", "u", "q", ",", "o", "e", "."] {
            #expect(input.action(for: KeyEquivalent(c)) == nil)
        }
    }
    #endif

    // MARK: - repeatActionsEnabled (Ctrl+K)

    @Test("sticky mode (default): releasing the active key stops the action")
    func stickyModeReleaseStops() {
        let input = KeyboardInput()
        #expect(input.repeatActionsEnabled == false)
        #expect(input.handle(key: "d", phase: .down) == .handled)
        #expect(input.currentAction == .right)
        #expect(input.handle(key: "d", phase: .up) == .handled)
        #expect(input.currentAction == .stop)
    }

    @Test("sticky mode: releasing a superseded key is a no-op")
    func stickyModeReleaseOfSupersededKeyIsNoOp() {
        let input = KeyboardInput()
        input.handle(key: "d", phase: .down)  // right
        input.handle(key: "s", phase: .down)  // down — supersedes "d"
        #expect(input.currentAction == .down)
        #expect(input.handle(key: "d", phase: .up) == .ignored)
        #expect(input.currentAction == .down)  // unaffected — "d" is stale
    }

    @Test("repeat mode: key-up is ignored, action persists past release")
    func repeatModeIgnoresKeyUp() {
        let input = KeyboardInput()
        input.repeatActionsEnabled = true
        input.handle(key: "d", phase: .down)
        #expect(input.currentAction == .right)
        #expect(input.handle(key: "d", phase: .up) == .ignored)
        #expect(input.currentAction == .right)  // still latched
    }

    @Test("repeat mode: a new key overrides the persisted action")
    func repeatModeNewKeyOverrides() {
        let input = KeyboardInput()
        input.repeatActionsEnabled = true
        input.handle(key: "d", phase: .down)
        input.handle(key: "d", phase: .up)  // ignored, still .right
        input.handle(key: "w", phase: .down)
        #expect(input.currentAction == .up)
    }

    @Test("resetAction clears heldKey, so a stale key-up is ignored")
    func resetActionClearsHeldKey() {
        let input = KeyboardInput()
        input.handle(key: "d", phase: .down)
        input.resetAction()
        #expect(input.currentAction == .stop)
        #expect(input.handle(key: "d", phase: .up) == .ignored)
        #expect(input.currentAction == .stop)
    }
}
