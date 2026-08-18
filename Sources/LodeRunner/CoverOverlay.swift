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
/// Both badges fade in with linear tweens. JS's start alphas of 0.8/0.6
/// produce nearly-imperceptible fades in practice — the port stretches
/// them to a full 0.0→1.0 range so the animation actually reads. Durations
/// (500 ms / 800 ms) still match JS `preload.js:361,373`. Any tap or key
/// press dismisses; the splash auto-dismisses after
/// `Self.autoDismissSeconds`, matching JS `waitIdleDemo(3000)` at
/// `main.js:243`.
///
/// When `onIdle` is set, the timer fires attract-mode demo playback via
/// that callback instead of auto-dismissing — matching JS
/// `waitIdleDemo(3000)` at `main.js:243`, which enters PLAY_AUTO on
/// timeout. When `onIdle` is nil the cover behaves as before (tap or
/// timer both dismiss into the pack chooser); useful for the Preview
/// and any host that doesn't wire the attract flow.
public struct CoverOverlay: View {
    let onDismiss: () -> Void
    let onIdle: (() -> Void)?
    @State private var signetOpacity: Double = Self.signetStartOpacity
    @State private var remakeOpacity: Double = Self.remakeStartOpacity

    public init(onDismiss: @escaping () -> Void, onIdle: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
        self.onIdle = onIdle
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
                    // Rainbow gradient behind the cover art — JS
                    // `preload.js:87-98` (`TitleBackground.draw` after
                    // `.rainbow = true` at `preload.js:350`). Without
                    // this, the cover's transparent "LODE RUNNER"
                    // lettering fell on the black backdrop and read as
                    // solid black.
                    Self.rainbowGradient
                        .frame(width: Self.coverWidth, height: Self.coverHeight)
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
            withAnimation(.linear(duration: Self.signetFadeSeconds)) {
                signetOpacity = 1.0
            }
            withAnimation(.linear(duration: Self.remakeFadeSeconds)) {
                remakeOpacity = 1.0
            }
        }
        .task(id: "cover-idle-timer") {
            // JS `main.js:243` `waitIdleDemo(3000)`. `.task(id:)` with a
            // stable non-view identifier makes SwiftUI restart the task
            // ONLY when the id changes — never on transient view
            // lifecycle events (window mount, size class settling). A
            // clean 3 s wait, then fire the idle handler. On cancellation
            // (the view truly went away, e.g. user tapped and phase
            // changed) the sleep throws and we return without firing.
            do {
                try await Task.sleep(for: .seconds(Self.autoDismissSeconds))
            } catch {
                return
            }
            // Attract-mode host uses `onIdle` to start a demo instead of
            // dismissing. Without it, keep the old behavior (dismiss).
            if let onIdle {
                onIdle()
            } else {
                onDismiss()
            }
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
            // `.animation(value:)` on the opacity change is redundant with
            // the `withAnimation` in `.onAppear`, but it's belt-and-braces
            // against the case where SwiftUI's `withAnimation` batching
            // decides the initial render is the "before" state and skips
            // the transition.
            .animation(.linear(duration: Self.signetFadeSeconds), value: signetOpacity)
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
            .animation(.linear(duration: Self.remakeFadeSeconds), value: remakeOpacity)
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
    /// JS starts at 0.8 — barely perceptible against 1.0. Port starts at 0.
    static let signetStartOpacity: Double = 0.0
    static let signetFadeSeconds: Double = 0.5

    /// Remake badge: 350×155, tilted -5° at (372, 130) — JS `preload.js:369-373`.
    static let remakeSize: CGSize = CGSize(width: 350, height: 155)
    /// Top-left of the remake badge, in board coordinates.
    static let remakeTopLeft: CGSize = CGSize(width: 372, height: 130)
    static let remakeRotationDegrees: Double = -5
    /// JS starts at 0.6 — subtle. Port starts at 0 for a visible fade-in.
    static let remakeStartOpacity: Double = 0.0
    static let remakeFadeSeconds: Double = 0.8

    /// JS `main.js:243` — 3000 ms idle-before-demo. In the port with no
    /// demo, we just dismiss into the pack chooser.
    static let autoDismissSeconds: Double = 3.0

    /// Rainbow linear gradient rendered behind the cover art. Ports
    /// `TitleBackground.draw` at `preload.js:87-98`:
    /// colors `["#FF0000", "#FF7F00", "#FFFF00", "#00FF00", "#0000FF",
    /// "#4B0082", "#8B00FF"]` at stops `[0, .14, .28, .42, .56, .70, .84]`,
    /// direction from `(0, h/5)` to `(w*6/5, h*2/5)` (`preload.js:90`).
    /// SwiftUI's UnitPoint is normalized, so the JS pixel coords map to
    /// `(0, 0.2)` → `(1.2, 0.4)`. `x=1.2` is outside `[0,1]` — SwiftUI
    /// extrapolates the gradient axis, matching how HTML canvas handles
    /// out-of-bounds gradient endpoints.
    static let rainbowGradient = LinearGradient(
        stops: [
            .init(color: Color(red: 1.0, green: 0.0, blue: 0.0), location: 0.0),
            .init(color: Color(red: 1.0, green: 0.5, blue: 0.0), location: 0.14),
            .init(color: Color(red: 1.0, green: 1.0, blue: 0.0), location: 0.28),
            .init(color: Color(red: 0.0, green: 1.0, blue: 0.0), location: 0.42),
            .init(color: Color(red: 0.0, green: 0.0, blue: 1.0), location: 0.56),
            .init(color: Color(red: 0.29, green: 0.0, blue: 0.51), location: 0.70),
            .init(color: Color(red: 0.55, green: 0.0, blue: 1.0), location: 0.84),
        ],
        startPoint: UnitPoint(x: 0.0, y: 0.2),
        endPoint: UnitPoint(x: 1.2, y: 0.4)
    )
}

// MARK: - Preview

#Preview("Cover overlay") {
    CoverOverlay(onDismiss: {})
}
