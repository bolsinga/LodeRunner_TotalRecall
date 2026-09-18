import SwiftUI

extension View {
    /// Forces focus onto this view the moment it appears. tvOS-only (a
    /// no-op elsewhere) — the tvOS focus engine doesn't reassign focus on
    /// its own when a new overlay mounts as a `ZStack` sibling over
    /// `PackChooserView`'s game layer: whatever had focus before (now
    /// `.disabled` and visually covered) just stays latched, and D-pad
    /// presses go nowhere. Every overlay needs one sensible default-focus
    /// target — its primary action button — so the remote has somewhere
    /// to land as soon as the overlay opens.
    ///
    /// Mirrors `KeyboardInputModifier`'s own initial-focus-grab pattern
    /// (`KeyboardInput.swift`) rather than `.defaultFocus(_:_:)`, which
    /// only kicks in when a scene has *no* current focus at all — it won't
    /// steal focus away from an already-focused (if now-disabled) element
    /// elsewhere in the same scene.
    func focusOnAppear() -> some View {
        modifier(FocusOnAppearModifier())
    }
}

private struct FocusOnAppearModifier: ViewModifier {
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        #if os(tvOS)
        content
            .focused($isFocused)
            .task {
                isFocused = true
            }
        #else
        content
        #endif
    }
}
