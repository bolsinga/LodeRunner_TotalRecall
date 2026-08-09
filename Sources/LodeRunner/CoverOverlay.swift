import SwiftUI

/// Title / cover splash — ports `showCoverPage()` at `lodeRunner.main.js:224`
/// plus the fade-in tweens for the `signet.png` and `remake.png` badges from
/// `lodeRunner.preload.js:353-373`. Shown once on app launch before the
/// pack chooser overlay takes over.
///
/// Layout:
/// - `cover.png` fills the playfield area (JS's 1120×768 canvas).
/// - `signet.png` — 80×80 badge, lower-right (JS `SIGNET_UNDER_X = 30`,
///   `SIGNET_UNDER_Y = 30` insets from the bottom-right).
/// - `remake.png` — 350×155 badge, rotated -5° (JS `preload.js:369-373`),
///   positioned in the center-right area.
///
/// Both badges fade in with linear tweens (JS `signet` 0.8→1.0 over 500ms,
/// `remake` 0.6→1.0 over 800ms). Any tap or key press dismisses; the
/// splash auto-dismisses after `Self.autoDismissSeconds`, matching the
/// JS's `waitIdleDemo(3000)` idle timer at `main.js:243`.
///
/// Deferred vs. the JS: the attract-mode auto-demo that fires when
/// `waitIdleDemo` elapses is out of scope (no demo player in the port).
/// Here the timer just dismisses into the pack chooser.
public struct CoverOverlay: View {
    let onDismiss: () -> Void
    @State private var signetOpacity: Double = Self.signetStartOpacity
    @State private var remakeOpacity: Double = Self.remakeStartOpacity

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            // `cover.png` at its native 1120×768 aspect. `FittedBoardView`
            // handles the letterboxing so the cover always fills the same
            // space as the playfield.
            FittedBoardView(
                boardWidth: Self.coverWidth, boardHeight: Self.coverHeight
            ) {
                ZStack(alignment: .topLeading) {
                    Image("cover", bundle: .module)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: Self.coverWidth, height: Self.coverHeight)
                    remakeBadge
                    signetBadge
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .task {
            // Fade tweens — JS `preload.js:359,371` uses `tweenGet().to({alpha})`.
            withAnimation(.linear(duration: Self.signetFadeSeconds)) {
                signetOpacity = 1.0
            }
            withAnimation(.linear(duration: Self.remakeFadeSeconds)) {
                remakeOpacity = 1.0
            }
            // Auto-dismiss timer, JS `main.js:243`'s `waitIdleDemo(3000)`.
            try? await Task.sleep(for: .seconds(Self.autoDismissSeconds))
            onDismiss()
        }
    }

    private var signetBadge: some View {
        Image("signet", bundle: .module)
            .resizable()
            .interpolation(.none)
            .frame(width: Self.signetSize, height: Self.signetSize)
            .opacity(signetOpacity)
            .offset(
                x: Self.coverWidth - Self.signetSize - Self.signetInset,
                y: Self.coverHeight - Self.signetSize - Self.signetInset
            )
    }

    private var remakeBadge: some View {
        Image("remake", bundle: .module)
            .resizable()
            .interpolation(.none)
            .frame(width: Self.remakeSize.width, height: Self.remakeSize.height)
            .rotationEffect(.degrees(Self.remakeRotationDegrees))
            .opacity(remakeOpacity)
            // JS positions this at (372, 130) in canvas coords
            // (`preload.js:369-370`), which sits center-right of the cover.
            .offset(x: Self.remakeOffset.width, y: Self.remakeOffset.height)
    }

    // MARK: - Constants (JS `preload.js`)

    /// Cover art native dimensions (`image/cover.png`).
    static let coverWidth: CGFloat = 1120
    static let coverHeight: CGFloat = 768

    /// Signet badge: 80×80, 30 px from the bottom-right — JS `preload.js:356`,
    /// `SIGNET_UNDER_X = SIGNET_UNDER_Y = 30`.
    static let signetSize: CGFloat = 80
    static let signetInset: CGFloat = 30
    static let signetStartOpacity: Double = 0.8
    static let signetFadeSeconds: Double = 0.5

    /// Remake badge: 350×155, tilted -5° at (372, 130) — JS `preload.js:369-373`.
    static let remakeSize: CGSize = CGSize(width: 350, height: 155)
    static let remakeOffset: CGSize = CGSize(width: 372, height: 130)
    static let remakeRotationDegrees: Double = -5
    static let remakeStartOpacity: Double = 0.6
    static let remakeFadeSeconds: Double = 0.8

    /// JS `main.js:243` — 3000 ms idle-before-demo. In the port with no
    /// demo, we just dismiss into the pack chooser.
    static let autoDismissSeconds: Double = 3.0
}

// MARK: - Preview

#Preview("Cover overlay") {
    CoverOverlay(onDismiss: {})
}
