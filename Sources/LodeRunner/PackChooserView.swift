import SwiftUI

/// App root: hosts `GameView` as the always-present base and floats
/// `PackChooserOverlay` on top before the first session and after game-over.
///
/// This inverts the pre-existing NavigationStack layout (chooser as root, game
/// as pushed destination) so the game surface is always the visual base —
/// same pattern as the level-pass scoring dialog, which pops over the frozen
/// last frame of the passed level.
///
/// The type name stays `PackChooserView` to keep `LodeRunnerApp`'s
/// `WindowGroup { PackChooserView() }` entry point unchanged. Lives in the
/// library rather than the app target so SwiftUI previews work — executable
/// targets need `ENABLE_DEBUG_DYLIB` to preview, which SwiftPM can't set for
/// us.
public struct PackChooserView: View {
    /// Committed pack + theme, or `nil` while the chooser overlay is up.
    /// `nil` on first launch and again after game-over — both entry points
    /// route through the same overlay.
    @State private var selection: Selection?

    public init() {}

    public var body: some View {
        ZStack {
            gameLayer
            if selection == nil {
                PackChooserOverlay(
                    initialPack: lastSelection?.pack ?? .classic,
                    initialTheme: lastSelection?.theme ?? .apple2,
                    onPick: { pack, theme in
                        let picked = Selection(pack: pack, theme: theme)
                        lastSelection = picked
                        selection = picked
                    }
                )
            }
        }
    }

    /// Sticky "last committed" selection so the overlay re-opens on
    /// game-over with the player's previous choice pre-selected — small
    /// polish that keeps the "try again" flow one tap. Separate from
    /// `selection` because the latter is `nil` whenever the overlay is up.
    @State private var lastSelection: Selection?

    @ViewBuilder
    private var gameLayer: some View {
        if let selection, let session = Self.makeSession(for: selection.pack) {
            GameView(
                session: session,
                onExit: { self.selection = nil }
            )
            .environment(\.tileTheme, selection.theme)
            // `id` forces a fresh GameView (and thus a fresh
            // `GameSessionDriver`) whenever the pack or theme changes — same
            // effect the pre-inversion NavigationStack push had, without
            // relying on navigation for the identity.
            .id(selection)
        } else if selection != nil {
            // Session couldn't be built (level pack failed to load) — surface
            // it instead of silently falling back to the overlay.
            ContentUnavailableView(
                "Failed to load level pack",
                systemImage: "exclamationmark.triangle"
            )
        } else {
            // Base layer while the chooser is up. Kept minimal so the
            // overlay pops crisply over a plain black backdrop rather than
            // a stale/attract-mode board.
            Color.black.ignoresSafeArea()
        }
    }

    /// Bundled pack + theme identity threaded through `.id(...)` on the
    /// GameView so switching options re-creates the session cleanly.
    private struct Selection: Equatable, Hashable {
        let pack: LevelPack
        let theme: Theme
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
