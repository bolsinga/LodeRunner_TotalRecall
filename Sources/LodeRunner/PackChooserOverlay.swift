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
        onPickInfo: ((LevelPack, Theme) -> Void)? = nil
    ) {
        _selectedPack = State(initialValue: initialPack)
        _selectedTheme = State(initialValue: initialTheme)
        self.onPick = onPick
        self.onPickLevel = onPickLevel
        self.onPickLeaderboard = onPickLeaderboard
        self.onPickSettings = onPickSettings
        self.onPickHelp = onPickHelp
        self.onPickInfo = onPickInfo
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("LODE RUNNER")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(.yellow)
                packList
                Divider().background(Color.white.opacity(0.3))
                themePicker
                actionButtons
            }
            .padding(24)
            .background(Color.black)
            .overlay(Rectangle().stroke(Color.white, lineWidth: 1))
        }
    }

    private var packList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LEVEL PACK")
                .font(.system(size: 12, design: .monospaced))
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
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var themePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THEME")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
            // Custom two-button toggle. SwiftUI's `.segmented` picker
            // renders in the standard macOS chrome — which both clipped
            // "Commodore 64" (the segment splits width evenly regardless
            // of label length) and stood out visually against the black-
            // and-yellow monospaced panel. Building it out of plain
            // `Button`s lets each label size to its own text and matches
            // the PLAY button's styling.
            HStack(spacing: 8) {
                themeButton("Apple II", theme: .apple2)
                themeButton("Commodore 64", theme: .c64)
            }
        }
    }

    private func themeButton(_ label: String, theme: Theme) -> some View {
        let isSelected = selectedTheme == theme
        return Button {
            selectedTheme = theme
        } label: {
            Text(label)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(isSelected ? .black : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.yellow : Color.clear)
                .overlay(
                    Rectangle().stroke(
                        isSelected ? Color.yellow : Color.white.opacity(0.5),
                        lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var actionButtons: some View {
        // Two rows so the button count stays readable at six. First row =
        // "start a game" actions (PLAY / SELECT LEVEL); second row =
        // "explore state" actions (LEADERBOARD / SETTINGS / HELP / INFO).
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                actionButton("PLAY", filled: true) {
                    onPick(selectedPack, selectedTheme)
                }
                .keyboardShortcut(.return, modifiers: [])
                if let onPickLevel {
                    actionButton("SELECT LEVEL", filled: false) {
                        onPickLevel(selectedPack, selectedTheme)
                    }
                }
            }
            HStack(spacing: 12) {
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
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(filled ? .black : .yellow)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(filled ? Color.yellow : Color.clear)
                .overlay(Rectangle().stroke(Color.yellow, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Pack chooser overlay") {
    PackChooserOverlay(onPick: { _, _ in })
        .frame(width: 700, height: 500)
        .background(Color.gray.opacity(0.3))
}
