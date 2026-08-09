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
    /// Overlay states. Exactly one overlay is showing at a time (or none,
    /// when a session is playing).
    private enum Phase: Equatable {
        /// One-time title/cover splash on first render. Dismisses on tap or
        /// after 3 s (JS `main.js:224,243`). Falls through to `.pickingPack`.
        case cover
        case pickingPack
        case pickingLevel(pack: LevelPack, theme: Theme, levels: [LevelParseResult])
        case playing(Selection)
        /// Post-game leaderboard. `pending` non-nil ⇒ the score qualified
        /// and name entry is up; nil ⇒ read-only view from the chooser.
        /// `isWinner` gates the ending music (JS `hiscore.js:246,286`).
        case leaderboard(
            pack: LevelPack, theme: Theme,
            pending: LeaderboardOverlay.PendingScore?, isWinner: Bool)
        /// Sound + speed settings modal. Ported from `lodeRunner.settings.js`.
        case settings(theme: Theme)
    }

    /// Committed pack + theme + starting-level identity for a live session.
    /// Threaded through `.id(...)` on GameView so switching packs, themes, or
    /// level indices re-creates the session cleanly.
    private struct Selection: Equatable, Hashable {
        let pack: LevelPack
        let theme: Theme
        let startingLevelIndex: Int
    }

    @State private var phase: Phase = .cover

    /// Last committed pack + theme, persisted across app launches. Written
    /// on every commit from the pack chooser, so relaunching the app
    /// re-selects whatever the player had going. Ports the JS's
    /// `getThemeMode`/`setThemeMode` (`storage.js:456,467`) and last-play
    /// bookkeeping — kept minimal for this port (single pack + single
    /// theme; no per-player accounts or version dropdown).
    @AppStorage(Self.lastPackKey) private var lastPack: LevelPack = .classic
    @AppStorage(Self.lastThemeKey) private var lastTheme: Theme = .apple2

    /// Per-pack per-level best scores. Ported from JS `modernScoreInfo`
    /// (`storage.js:150,189`) — record on level pass, read at dialog open
    /// to populate the HI-SCORE row.
    @State private var highScoreStore = HighScoreStore()

    /// Per-pack top-10 leaderboard. Ported from JS `hiscore.js`. Consulted
    /// on game-over to decide whether to prompt for a name; also readable
    /// via the pack chooser's LEADERBOARD button.
    @State private var leaderboardStore = LeaderboardStore()

    /// Player settings — ported subset of `lodeRunner.settings.js`. Sound
    /// on/off gates every `SoundPlayer.play(_:)` call (via
    /// `SoundPlayer.isEnabled`); `speedIndex` picks the `GameSpeed` step
    /// and drives `GameSessionDriver.tickPeriod` live.
    @AppStorage(Self.soundEnabledKey) private var soundEnabled: Bool = true
    @AppStorage(Self.speedIndexKey) private var speedIndex: Int = GameSpeed.defaultIndex
    /// HUD layout: `.classic` (SCORE/MEN/LEVEL) or `.modern` (@/#/TIME).
    /// Analog of JS `setLastPlayMode` at `menu.js:50` — persists across
    /// launches; the settings overlay's HUD row toggles.
    @AppStorage(Self.hudModeKey) private var hudMode: HUDMode = .classic

    static let soundEnabledKey = "loderunner_soundEnabled"
    static let speedIndexKey = "loderunner_speedIndex"
    static let hudModeKey = "loderunner_hudMode"

    /// Deliberate namespacing: prefix every port `@AppStorage` key with
    /// `loderunner_` so `UserDefaults` inspection reads cleanly and there's
    /// zero chance of colliding with unrelated app defaults. Same convention
    /// as the JS `STORAGE_PREFIX = "loderunner_"` at `def.js:178`.
    static let lastPackKey = "loderunner_lastPack"
    static let lastThemeKey = "loderunner_lastTheme"

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
                    soundEnabled: soundEnabled,
                    speedIndex: speedIndex,
                    hudMode: hudMode,
                    onExit: { phase = .pickingPack },
                    onLevelPassed: { levelIndex, score in
                        // Read the pre-existing best (for the dialog's
                        // HI-SCORE row) before recording, so we don't
                        // return the value we just wrote.
                        let previous = highScoreStore.bestScore(
                            pack: selection.pack, levelIndex: levelIndex)
                        highScoreStore.recordScore(
                            score, pack: selection.pack, levelIndex: levelIndex)
                        return previous
                    },
                    onGameOver: { finalScore, levelReached, isWinner in
                        // Route into the leaderboard overlay. Non-qualifying
                        // scores still get to see the standings before
                        // returning to the pack chooser — matching JS
                        // `hiscore.js:showScoreTable`, which always renders
                        // the table on GAME_OVER and gates only the name
                        // input on qualification.
                        let pending: LeaderboardOverlay.PendingScore? =
                            leaderboardStore.qualifies(
                                pack: selection.pack, score: finalScore)
                            ? LeaderboardOverlay.PendingScore(
                                score: finalScore, levelReached: levelReached)
                            : nil
                        phase = .leaderboard(
                            pack: selection.pack, theme: selection.theme,
                            pending: pending, isWinner: isWinner)
                    }
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
        case .cover:
            CoverOverlay(onDismiss: {
                // Cross-fade the cover → pack chooser transition so the
                // switch doesn't hard-cut. JS itself hard-cuts to attract
                // mode (`main.js:243`), but the port dismisses into the
                // pack chooser instead, and the abrupt swap read as a
                // "flash" during playtesting.
                withAnimation(.easeInOut(duration: 0.4)) {
                    phase = .pickingPack
                }
            })
            .transition(.opacity)
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
                },
                onPickLeaderboard: { pack, theme in
                    lastPack = pack
                    lastTheme = theme
                    phase = .leaderboard(
                        pack: pack, theme: theme, pending: nil, isWinner: false)
                },
                onPickSettings: { theme in
                    lastTheme = theme
                    phase = .settings(theme: theme)
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
        case .settings(let theme):
            SettingsOverlay(
                soundEnabled: $soundEnabled,
                speedIndex: $speedIndex,
                hudMode: $hudMode,
                onClose: { phase = .pickingPack }
            )
            .environment(\.tileTheme, theme)
        case .leaderboard(let pack, let theme, let pending, let isWinner):
            LeaderboardOverlay(
                pack: pack,
                entries: leaderboardStore.entries(pack: pack),
                pendingScore: pending,
                isWinner: isWinner,
                soundEnabled: soundEnabled,
                onSubmit: { entry in
                    if let entry {
                        leaderboardStore.insert(entry, pack: pack)
                    }
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
