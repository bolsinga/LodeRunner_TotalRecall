import SwiftUI

/// App root: hosts `GameView` as the always-present base and floats one of two
/// overlays on top — `PackChooserOverlay` (pack + theme picker) before the
/// first session, and `LevelSelectOverlay` (per-level thumbnail grid) when
/// the player asks for a specific starting level.
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
    /// The three overlay-drives states this view can be in. Kept as a single
    /// enum so exactly one overlay is showing at a time (or none, when a
    /// session is playing).
    private enum Phase: Equatable {
        case pickingPack
        case pickingLevel(pack: LevelPack, theme: Theme, levels: [LevelParseResult])
        case playing(Selection)
    }

    /// Committed pack + theme + starting-level identity for a live session.
    /// Threaded through `.id(...)` on GameView so switching packs, themes, or
    /// level indices re-creates the session cleanly.
    private struct Selection: Equatable, Hashable {
        let pack: LevelPack
        let theme: Theme
        let startingLevelIndex: Int
    }

    @State private var phase: Phase = .pickingPack

    /// Sticky "last committed" pack + theme so the overlay re-opens on
    /// game-over with the player's previous choice pre-selected — small
    /// polish that keeps the "try again" flow one tap.
    @State private var lastPack: LevelPack = .classic
    @State private var lastTheme: Theme = .apple2

    public init() {}

    public var body: some View {
        ZStack {
            gameLayer
            overlayLayer
        }
    }

    @ViewBuilder
    private var gameLayer: some View {
        if case .playing(let selection) = phase {
            if let session = Self.makeSession(
                for: selection.pack, startingLevelIndex: selection.startingLevelIndex)
            {
                GameView(
                    session: session,
                    onExit: { phase = .pickingPack }
                )
                .environment(\.tileTheme, selection.theme)
                .id(selection)
            } else {
                ContentUnavailableView(
                    "Failed to load level pack",
                    systemImage: "exclamationmark.triangle"
                )
            }
        } else {
            // Base layer while an overlay is up. Kept minimal so the overlay
            // pops crisply over a plain black backdrop rather than a stale/
            // attract-mode board.
            Color.black.ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var overlayLayer: some View {
        switch phase {
        case .pickingPack:
            PackChooserOverlay(
                initialPack: lastPack,
                initialTheme: lastTheme,
                onPick: { pack, theme in
                    lastPack = pack
                    lastTheme = theme
                    phase = .playing(
                        Selection(pack: pack, theme: theme, startingLevelIndex: 0))
                },
                onPickLevel: { pack, theme in
                    lastPack = pack
                    lastTheme = theme
                    // Load the pack up-front so the grid can show thumbnails.
                    // A failure surfaces via `gameLayer`'s
                    // `ContentUnavailableView` fallback on next play.
                    guard let levels = try? pack.load(), !levels.isEmpty else {
                        return
                    }
                    phase = .pickingLevel(pack: pack, theme: theme, levels: levels)
                }
            )
        case .pickingLevel(let pack, let theme, let levels):
            LevelSelectOverlay(
                levels: levels,
                onPick: { index in
                    phase = .playing(
                        Selection(pack: pack, theme: theme, startingLevelIndex: index))
                },
                onClose: {
                    phase = .pickingPack
                }
            )
            .environment(\.tileTheme, theme)
        case .playing:
            EmptyView()
        }
    }

    private static func makeSession(
        for pack: LevelPack, startingLevelIndex: Int
    ) -> GameSession? {
        do {
            let levels = try pack.load()
            return try GameSession(
                levels: levels, startingLevelIndex: startingLevelIndex)
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
