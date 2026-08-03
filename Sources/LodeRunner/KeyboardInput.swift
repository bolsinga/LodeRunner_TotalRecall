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
