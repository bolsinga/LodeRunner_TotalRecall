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

    @State private var selectedPack: LevelPack
    @State private var selectedTheme: Theme

    public init(
        initialPack: LevelPack = .classic,
        initialTheme: Theme = .apple2,
        onPick: @escaping (LevelPack, Theme) -> Void
    ) {
        _selectedPack = State(initialValue: initialPack)
        _selectedTheme = State(initialValue: initialTheme)
        self.onPick = onPick
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
                playButton
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
            Picker("Theme", selection: $selectedTheme) {
                Text("Apple II").tag(Theme.apple2)
                Text("Commodore 64").tag(Theme.c64)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)
        }
    }

    private var playButton: some View {
        Button {
            onPick(selectedPack, selectedTheme)
        } label: {
            Text("PLAY")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(Color.yellow)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.return, modifiers: [])
    }
}

// MARK: - Preview

#Preview("Pack chooser overlay") {
    PackChooserOverlay(onPick: { _, _ in })
        .frame(width: 700, height: 500)
        .background(Color.gray.opacity(0.3))
}
