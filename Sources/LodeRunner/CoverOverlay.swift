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
            // space as the playfield. The board is a 1120×768 layout box;
            // badges are positioned inside via `.position(x:y:)` so the
            // math reads as absolute board-coordinates rather than delta
            // offsets from the top-left corner.
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
                .frame(width: Self.coverWidth, height: Self.coverHeight)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .onAppear {
            // Fade tweens — JS `preload.js:359,371` uses `tweenGet().to({alpha})`.
            // Kept in `.onAppear` (not `.task`) because SwiftUI may cycle the
            // task on window-mount transitions and we don't want the animation
            // to restart every re-render.
            withAnimation(.linear(duration: Self.signetFadeSeconds)) {
                signetOpacity = 1.0
            }
            withAnimation(.linear(duration: Self.remakeFadeSeconds)) {
                remakeOpacity = 1.0
            }
        }
        .task {
            // Auto-dismiss timer, JS `main.js:243`'s `waitIdleDemo(3000)`.
            // If the task is cancelled (window remount, phase change race),
            // `Task.sleep` throws — we must return WITHOUT calling
            // `onDismiss()`. The old `try?` swallowed the cancellation and
            // fell through to dismiss, which made the cover flash by on
            // launch instead of waiting the full duration.
            do {
                try await Task.sleep(for: .seconds(Self.autoDismissSeconds))
            } catch {
                return
            }
            onDismiss()
        }
    }

    private var signetBadge: some View {
        // JS `preload.js:357-358`: badge's top-left at `(BASE_SCREEN_X -
        // SIGNET_UNDER_X - width, BASE_SCREEN_Y - SIGNET_UNDER_Y -
        // height)`. `.position(x:y:)` in SwiftUI takes the *center* of
        // the view, so we add half the badge size to the JS top-left.
        let centerX = Self.coverWidth - Self.signetInset - Self.signetSize / 2
        let centerY = Self.coverHeight - Self.signetInset - Self.signetSize / 2
        return Image("signet", bundle: .module)
            .resizable()
            .interpolation(.none)
            .frame(width: Self.signetSize, height: Self.signetSize)
            .opacity(signetOpacity)
            .position(x: centerX, y: centerY)
    }

    private var remakeBadge: some View {
        // JS `preload.js:367-370`: top-left at (372, 130), rotation around
        // top-left (JS `regX/regY` default to 0). SwiftUI's
        // `.rotationEffect` rotates around the frame center by default;
        // pass `anchor: .topLeading` to match the JS pivot.
        let centerX = Self.remakeTopLeft.width + Self.remakeSize.width / 2
        let centerY = Self.remakeTopLeft.height + Self.remakeSize.height / 2
        return Image("remake", bundle: .module)
            .resizable()
            .interpolation(.none)
            .frame(width: Self.remakeSize.width, height: Self.remakeSize.height)
            .rotationEffect(.degrees(Self.remakeRotationDegrees), anchor: .topLeading)
            .opacity(remakeOpacity)
            .position(x: centerX, y: centerY)
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
    /// Top-left of the remake badge, in board coordinates.
    static let remakeTopLeft: CGSize = CGSize(width: 372, height: 130)
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
