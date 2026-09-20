import SwiftUI

/// Level-pack + theme picker rendered as a ZStack overlay on top of the game
/// board — analog to `LevelPassDialog`'s modal panel style. Replaces the
/// pre-inversion `PackChooserView` sidebar-list layout: the game view is now
/// the app's root and the picker is a modal that pops up before the first
/// session and after game-over.
///
/// The picker owns its own working selection (`selectedPack` / `selectedTheme`)
/// and only reports back via `onPick` when the user commits — matching the
/// JS `menu.js` flow where the menu's internal state is only merged into
/// `curTheme` / `playMode` on click.
public struct PackChooserOverlay: View {
    let onPick: (LevelPack, Theme) -> Void
    /// Optional callback fired when the user taps SELECT LEVEL. When set, the
    /// button is visible; when `nil`, only PLAY is shown. Callers wire this
    /// to their `LevelSelectOverlay` routing.
    let onPickLevel: ((LevelPack, Theme) -> Void)?
    /// Optional callback fired when the user taps LEADERBOARD. When set,
    /// the button is visible and taps route into `LeaderboardOverlay` in
    /// read-only view mode.
    let onPickLeaderboard: ((LevelPack, Theme) -> Void)?
    /// Optional callback fired when the user taps SETTINGS. When set, the
    /// button is visible; the callback receives the current theme so the
    /// host can seed its settings-overlay phase.
    let onPickSettings: ((Theme) -> Void)?
    /// Optional callback fired when the user taps HELP. When set, the
    /// button is visible; the callback receives the current theme.
    let onPickHelp: ((Theme) -> Void)?
    /// Optional callback fired when the user taps INFO. Receives the
    /// current pack + theme so the host can render the right facts.
    let onPickInfo: ((LevelPack, Theme) -> Void)?
    /// Optional callback fired when the user taps RESUME, receiving the
    /// currently-selected theme. Only rendered when set — meaningful only
    /// when a game is running underneath the menu (so there's something
    /// to return to). Analog of dismissing the JS `boardIcons.js` sidebar
    /// without picking a new mode.
    ///
    /// Unlike the level-pack selection (which RESUME silently discards —
    /// switching packs mid-session doesn't make sense without restarting),
    /// the theme is purely cosmetic, so RESUME applies it live to the
    /// already-running session instead of requiring NEW GAME.
    let onClose: ((Theme) -> Void)?

    @State private var selectedPack: LevelPack
    @State private var selectedTheme: Theme

    public init(
        initialPack: LevelPack = .classic,
        initialTheme: Theme = .apple2,
        onPick: @escaping (LevelPack, Theme) -> Void,
        onPickLevel: ((LevelPack, Theme) -> Void)? = nil,
        onPickLeaderboard: ((LevelPack, Theme) -> Void)? = nil,
        onPickSettings: ((Theme) -> Void)? = nil,
        onPickHelp: ((Theme) -> Void)? = nil,
        onPickInfo: ((LevelPack, Theme) -> Void)? = nil,
        onClose: ((Theme) -> Void)? = nil
    ) {
        _selectedPack = State(initialValue: initialPack)
        _selectedTheme = State(initialValue: initialTheme)
        self.onPick = onPick
        self.onPickLevel = onPickLevel
        self.onPickLeaderboard = onPickLeaderboard
        self.onPickSettings = onPickSettings
        self.onPickHelp = onPickHelp
        self.onPickInfo = onPickInfo
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 10) {
                Text("LODE RUNNER")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.yellow)
                packList
                Divider().background(Color.white.opacity(0.3))
                actionButtons
            }
            .padding(14)
            .background(Color.black)
            .overlay(Rectangle().stroke(Color.white, lineWidth: OverlayChrome.borderWidth))
        }
    }

    private var packList: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("LEVEL PACK")
                .font(.system(size: OverlayChrome.secondaryLabelFontSize, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
            ForEach(LevelPack.allCases, id: \.self) { pack in
                Button {
                    selectedPack = pack
                } label: {
                    HStack(spacing: 8) {
                        Text(selectedPack == pack ? "▶" : "  ")
                            .monospaced()
                            .foregroundStyle(.yellow)
                        Text(pack.displayName)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Single-icon toggle showing the *active* theme's logo — tapping
    /// swaps to the other theme, and the icon swaps to match. Ports the
    /// original `themeIconClass` behavior from the pre-DOM-dialog history
    /// (`lodeRunner.iconClass.js`'s `updateThemeImage`/`mouseClick`): one
    /// tappable icon whose bitmap always reflects `curTheme`, rather than
    /// two side-by-side selectable buttons.
    ///
    /// Sized to match `actionButton`'s height so it can sit inline in the
    /// PLAY / SELECT LEVEL row instead of its own labeled section — that
    /// extra section (with its own "THEME" header) was what pushed the
    /// panel too tall to fit on iPhone without scrolling.
    private var themeToggleButton: some View {
        Button {
            selectedTheme = selectedTheme == .apple2 ? .c64 : .apple2
        } label: {
            Image(selectedTheme == .apple2 ? "apple2" : "commodore64", bundle: .module)
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 23)
                .padding(4)
                .overlay(
                    Rectangle().stroke(
                        Color.white.opacity(0.5), lineWidth: OverlayChrome.borderWidth)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            selectedTheme == .apple2
                ? "Apple II theme, double tap to switch to Commodore 64"
                : "Commodore 64 theme, double tap to switch to Apple II")
    }

    private var actionButtons: some View {
        // Two rows so the button count stays readable. First row =
        // "start / resume a game" (RESUME / PLAY / SELECT LEVEL) plus the
        // theme toggle, which doesn't need its own section; second row =
        // "explore state" (LEADERBOARD / SETTINGS / HELP / INFO).
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                if let onClose {
                    actionButton("RESUME", filled: true) {
                        onClose(selectedTheme)
                    }
                    .focusOnAppear()
                    #if !os(tvOS)
                    .keyboardShortcut(.escape, modifiers: [])
                    #endif
                    actionButton("NEW GAME", filled: false) {
                        onPick(selectedPack, selectedTheme)
                    }
                } else {
                    // Pre-game path: no session to resume, so PLAY is the
                    // primary. Return key still starts a new game.
                    actionButton("PLAY", filled: true) {
                        onPick(selectedPack, selectedTheme)
                    }
                    .focusOnAppear()
                    #if !os(tvOS)
                    .keyboardShortcut(.return, modifiers: [])
                    #endif
                }
                if let onPickLevel {
                    actionButton("SELECT LEVEL", filled: false) {
                        onPickLevel(selectedPack, selectedTheme)
                    }
                }
                themeToggleButton
            }
            HStack(spacing: 10) {
                if let onPickLeaderboard {
                    actionButton("LEADERBOARD", filled: false) {
                        onPickLeaderboard(selectedPack, selectedTheme)
                    }
                }
                if let onPickSettings {
                    actionButton("SETTINGS", filled: false) {
                        onPickSettings(selectedTheme)
                    }
                }
                if let onPickHelp {
                    actionButton("HELP", filled: false) {
                        onPickHelp(selectedTheme)
                    }
                }
                if let onPickInfo {
                    actionButton("INFO", filled: false) {
                        onPickInfo(selectedPack, selectedTheme)
                    }
                }
            }
        }
    }

    /// Shared button chrome for PLAY and SELECT LEVEL. `filled` picks the
    /// primary (yellow background, black text) vs. secondary (outlined,
    /// yellow text) styling.
    private func actionButton(
        _ title: String, filled: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(
                    .system(
                        size: OverlayChrome.buttonFontSize, weight: .bold, design: .monospaced)
                )
                .foregroundStyle(filled ? .black : .yellow)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(filled ? Color.yellow : Color.clear)
                .overlay(Rectangle().stroke(Color.yellow, lineWidth: OverlayChrome.borderWidth))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Pack chooser overlay — Apple2") {
    PackChooserOverlay(onPick: { _, _ in })
        .frame(width: 700, height: 500)
        .background(Color.gray.opacity(0.3))
}

#Preview("Pack chooser overlay — C64") {
    PackChooserOverlay(initialTheme: .c64, onPick: { _, _ in })
        .frame(width: 700, height: 500)
        .background(Color.gray.opacity(0.3))
}
