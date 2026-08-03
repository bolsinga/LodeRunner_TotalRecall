import SwiftUI

/// Hardware-keyboard `RunnerInput`. Held keys persist as the current action (no
/// key-up clears state) to match the JS default at `lodeRunner.key.js:322` where
/// `handleKeyUp` returns without touching `keyAction` unless the repeat-mode
/// toggle is on.
///
/// v1 key map (trimmed from the JS's fuller alias set at `pressKey` /
/// `lodeRunner.key.js:211-270`):
///
///   - left:      ←,  A
///   - right:     →,  D
///   - up:        ↑,  W
///   - down:      ↓,  S
///   - dig left:  Z
///   - dig right: X
@Observable @MainActor
public final class KeyboardInput: RunnerInput {
    public private(set) var currentAction: RunnerAction = .stop

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
        default: return nil
        }
    }

    /// Consume a key-down and update `currentAction` if the key is bound.
    /// Returns `.handled` when a `RunnerAction` was set, `.ignored` otherwise —
    /// so unbound keys (menu shortcuts etc.) pass through to other handlers.
    @discardableResult
    public func handle(_ press: KeyPress) -> KeyPress.Result {
        guard let action = action(for: press.key) else { return .ignored }
        currentAction = action
        return .handled
    }

    public func resetAction() {
        currentAction = .stop
    }
}

/// The `keyboardInput(_:)` modifier as a proper `ViewModifier`, so the
/// `@FocusState` can live inside — a plain `View` extension can't own state,
/// which is why an earlier version required the user to click the window
/// before any key press registered. Setting `isFocused = true` inside
/// `.onAppear` steals focus at first render, matching how macOS games
/// normally behave.
private struct KeyboardInputModifier: ViewModifier {
    let input: KeyboardInput
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focusable()
            .focusEffectDisabled()
            .focused($isFocused)
            .onAppear { isFocused = true }
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
