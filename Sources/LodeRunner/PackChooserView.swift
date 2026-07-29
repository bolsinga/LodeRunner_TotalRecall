import SwiftUI

/// Entry screen: pick a level pack and a theme, then push into `GameView`.
/// The five packs match the raw values of `LevelPack.allCases`, which are
/// the file stems for the bundled `Resources/Levels/<pack>.txt` files.
///
/// Lives in the library rather than the app target so SwiftUI previews work
/// — executable targets need `ENABLE_DEBUG_DYLIB` to preview, which SwiftPM
/// can't set for us.
public struct PackChooserView: View {
    @State private var theme: Theme = .apple2

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section("Level Pack") {
                    ForEach(LevelPack.allCases, id: \.self) { pack in
                        NavigationLink(pack.displayName, value: pack)
                    }
                }
                Section("Theme") {
                    Picker("Theme", selection: $theme) {
                        Text("Apple II").tag(Theme.apple2)
                        Text("Commodore 64").tag(Theme.c64)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Lode Runner")
            .navigationDestination(for: LevelPack.self) { pack in
                gameScreen(for: pack)
            }
        }
    }

    @ViewBuilder
    private func gameScreen(for pack: LevelPack) -> some View {
        if let session = Self.makeSession(for: pack) {
            GameView(session: session)
                .environment(\.tileTheme, theme)
                .navigationTitle(pack.displayName)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
        } else {
            ContentUnavailableView(
                "Failed to load \(pack.displayName)",
                systemImage: "exclamationmark.triangle")
        }
    }

    private static func makeSession(for pack: LevelPack) -> GameSession? {
        do {
            let levels = try pack.load()
            return try GameSession(levels: levels)
        } catch {
            return nil
        }
    }
}

extension LevelPack {
    /// Human-readable pack name for the chooser. The raw values (`"classic"`,
    /// `"fanBookMod"`, …) match the bundled file stems, so they're not
    /// display-friendly on their own.
    public var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .professional: return "Professional"
        case .revenge: return "Revenge"
        case .fanBookMod: return "Fan Book Mod"
        case .championship: return "Championship"
        }
    }
}

#Preview {
    PackChooserView()
}
