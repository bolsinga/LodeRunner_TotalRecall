import SwiftUI

/// Hardware-keyboard `RunnerInput`. Held keys persist as the current action (no
/// key-up clears state) to match the JS default at `lodeRunner.key.js:322` where
/// `handleKeyUp` returns without touching `keyAction` unless the repeat-mode
/// toggle is on.
///
/// Key map, ported from `pressKey` at `lodeRunner.key.js:211-270`:
///
///   - left:      ←,  A,  J
///   - right:     →,  D,  L
///   - up:        ↑,  W,  I
///   - down:      ↓,  S,  K
///   - dig left:  Z,  Y (QWERTZ dig-left), U, Q, ,
///   - dig right: X,  O,  E,  .
///
/// The JS-parity alias set (J/L/I/K, Y/U/Q/comma, O/E/period) is macOS-only:
/// the port targets macOS as the hardware-keyboard surface. iOS's soft
/// keyboard doesn't map to these ergonomics — that platform's input surface
/// is deferred to a future on-screen d-pad — so we ship just the primary
/// keys (arrows + WASD + Z/X) there.
@Observable @MainActor
public final class KeyboardInput: RunnerInput {
    public private(set) var currentAction: RunnerAction = .stop

    /// Fires on every key press this input observes (bound or unbound).
    /// Set by `GameView` during demo playback to route "any key stops demo"
    /// — JS `anyKeyStopDemo` at `demo.js:273-280`, which routes every
    /// keydown to `stopDemoAndPlay`. Cleared back to `nil` outside demo
    /// mode so normal gameplay isn't disturbed. Not part of `RunnerInput`
    /// because non-keyboard inputs (`DemoInput`, future gamepad) have no
    /// "any key" concept.
    public var onAnyKeyPress: (() -> Void)?

    public init() {}

    /// Map a `KeyEquivalent` to its `RunnerAction`, or `nil` if the key isn't
    /// bound. Separate from `.onKeyPress` handling so it's usable without a
    /// live SwiftUI event (e.g. unit tests or on-screen d-pad drivers later).
    public func action(for key: KeyEquivalent) -> RunnerAction? {
        switch key {
        case .leftArrow, "a", "A": return .left
        case .rightArrow, "d", "D": return .right
        case .upArrow, "w", "W": return .up
        case .downArrow, "s", "S": return .down
        case "z", "Z": return .digLeft
        case "x", "X": return .digRight
        default: break
        }
        #if os(macOS)
        // JS-parity extended aliases (`key.js:215-245`). Kept macOS-only so
        // iOS hardware-keyboard users get a lean map — nudge if you want the
        // aliases everywhere.
        switch key {
        case "j", "J": return .left
        case "l", "L": return .right
        case "i", "I": return .up
        case "k", "K": return .down
        case "y", "Y", "u", "U", "q", "Q", ",": return .digLeft
        case "o", "O", "e", "E", ".": return .digRight
        default: break
        }
        #endif
        return nil
    }

    /// Consume a key-down and update `currentAction` if the key is bound.
    /// Returns `.handled` when a `RunnerAction` was set, `.ignored` otherwise —
    /// so unbound keys (menu shortcuts etc.) pass through to other handlers.
    @discardableResult
    public func handle(_ press: KeyPress) -> KeyPress.Result {
        // Fire the "any key" hook first (demo-stop path). Set independently
        // of the bound-key lookup so keys that would normally be `.ignored`
        // (letters, numbers) still terminate a running demo.
        onAnyKeyPress?()
        guard let action = action(for: press.key) else { return .ignored }
        currentAction = action
        return .handled
    }

    public func resetAction() {
        currentAction = .stop
    }
}

/// The `keyboardInput(_:)` modifier as a proper `ViewModifier`, so the
/// `@FocusState` can live inside — a plain `View` extension can't own state.
///
/// On macOS the initial focus grab is timing-sensitive: `NavigationStack`
/// pushes GameView while its own outer container is still the first
/// responder, so a `.onAppear { isFocused = true }` fires while SwiftUI is
/// mid-transition and gets clobbered. Retrying across a handful of runloop
/// hops (via `.task`, which runs after appear, plus repeated setters with
/// small delays) covers the transition without needing an AppKit bridge.
/// Also uses `.defaultFocus`, which SwiftUI honors on the *first* render
/// of a focusable view — the fast-path when NavigationStack cooperates.
private struct KeyboardInputModifier: ViewModifier {
    let input: KeyboardInput
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focusable()
            .focusEffectDisabled()
            .focused($isFocused)
            .defaultFocus($isFocused, true)
            .task {
                // Re-assert focus across the NavigationStack push
                // transition. Six attempts at 50 ms is 300 ms total —
                // long enough to outlast the animation, short enough
                // that the user can't type past it.
                for _ in 0..<6 {
                    isFocused = true
                    try? await Task.sleep(for: .milliseconds(50))
                }
            }
            .onKeyPress(phases: [.down, .repeat]) { press in
                input.handle(press)
            }
    }
}

extension View {
    /// Attach a `KeyboardInput` to this view: makes it focusable, gives it
    /// focus at first appear (so hardware keys register without a prior
    /// click), and pipes key events into `input`. Apply near the top of the
    /// game view hierarchy so the game surface keeps focus.
    ///
    /// Only `.down` and `.repeat` phases are observed (matching the JS default
    /// where held keys persist); `.up` is intentionally ignored so releasing a
    /// key keeps the runner moving until the next direction change.
    public func keyboardInput(_ input: KeyboardInput) -> some View {
        modifier(KeyboardInputModifier(input: input))
    }
}
