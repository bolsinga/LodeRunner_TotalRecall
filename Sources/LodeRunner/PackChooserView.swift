import SwiftUI

/// App root. Holds two orthogonal pieces of state:
///
/// - **`currentGame`** — the pack + theme + starting level of the game
///   session currently running under the surface (or nil before the first
///   game). Once set, `GameView` stays mounted continuously so the sim
///   preserves its state across menu opens.
/// - **`overlay`** — which modal is on top right now (cover splash, main
///   menu, settings, leaderboard, help, info, level picker) or nil for
///   "nothing on top, gameplay in focus".
///
/// The two are independent: opening the menu just sets `overlay = .menu`
/// and drives `GameView` into a paused state via `isPaused`. The sim
/// freezes exactly where it was; closing the menu resumes on the same
/// tick. Ports the JS `GAME_PAUSE` model at `main.js:1668-1670`.
///
/// The type name stays `PackChooserView` to keep `LodeRunnerApp`'s
/// `WindowGroup { PackChooserView() }` entry point unchanged. Lives in
/// the library rather than the app target so SwiftUI previews work —
/// executable targets need `ENABLE_DEBUG_DYLIB` to preview, which SwiftPM
/// can't set for us.
public struct PackChooserView: View {
    /// Which pack + theme + starting-level the running game session was
    /// built from. `nil` on first launch (before the cover splash
    /// dismisses into a session). `Hashable` so it feeds `.id(...)` on
    /// `GameView` to force a session rebuild whenever the selection
    /// changes (new pack, new theme, new start level, or same values
    /// re-picked from the menu = fresh game).
    private struct Selection: Equatable, Hashable {
        let pack: LevelPack
        let theme: Theme
        let startingLevelIndex: Int
    }

    /// Which overlay (if any) is on top of the current game.
    private enum Overlay: Equatable {
        /// Startup title splash. Also displayed with no `currentGame`
        /// underneath (plain black backdrop).
        case cover
        /// Main menu — same pack chooser as before, but now doubles as
        /// the JS `boardIcons.js` sidebar menu that pops over gameplay.
        case menu
        /// Per-level thumbnail picker.
        case levelPicker(pack: LevelPack, theme: Theme, levels: [LevelParseResult])
        /// Sound / speed / training settings.
        case settings(theme: Theme)
        /// Keyboard cheat-sheet.
        case help(theme: Theme)
        /// Per-pack facts.
        case info(pack: LevelPack, theme: Theme)
        /// Leaderboard, entered post-game-over (with `pending` name entry
        /// if the score qualified) or via the menu (`pending == nil`,
        /// read-only).
        case leaderboard(
            pack: LevelPack, theme: Theme,
            pending: LeaderboardOverlay.PendingScore?, isWinner: Bool)
    }

    @State private var currentGame: Selection?
    @State private var overlay: Overlay? = .cover

    /// Last committed pack + theme, persisted across app launches. First-
    /// launch defaults come from these `@AppStorage` fallbacks; the cover
    /// splash's onDismiss uses them to seed the initial game.
    @AppStorage(Self.lastPackKey) private var lastPack: LevelPack = .classic
    @AppStorage(Self.lastThemeKey) private var lastTheme: Theme = .apple2

    /// Per-pack per-level best scores (JS `modernScoreInfo`).
    @State private var highScoreStore = HighScoreStore()
    /// Per-pack top-10 leaderboard (JS `hiscore.js`).
    @State private var leaderboardStore = LeaderboardStore()

    /// Player settings — ported subset of `lodeRunner.settings.js`.
    @AppStorage(Self.soundEnabledKey) private var soundEnabled: Bool = true
    @AppStorage(Self.speedIndexKey) private var speedIndex: Int = GameSpeed.defaultIndex
    @AppStorage(Self.hudModeKey) private var hudMode: HUDMode = .classic

    static let soundEnabledKey = "loderunner_soundEnabled"
    static let speedIndexKey = "loderunner_speedIndex"
    static let hudModeKey = "loderunner_hudMode"

    /// Deliberate namespacing: prefix every port `@AppStorage` key with
    /// `loderunner_` so `UserDefaults` inspection reads cleanly. Same
    /// convention as the JS `STORAGE_PREFIX = "loderunner_"` at
    /// `def.js:178`.
    static let lastPackKey = "loderunner_lastPack"
    static let lastThemeKey = "loderunner_lastTheme"

    public init() {}

    public var body: some View {
        ZStack {
            gameLayer
            if let overlay {
                overlayView(overlay)
            }
        }
    }

    @ViewBuilder
    private var gameLayer: some View {
        if let currentGame, let session = Self.makeSession(
            for: currentGame.pack, startingLevelIndex: currentGame.startingLevelIndex)
        {
            GameView(
                session: session,
                soundEnabled: $soundEnabled,
                speedIndex: $speedIndex,
                hudMode: $hudMode,
                // Freeze the sim whenever any overlay is on top of us —
                // JS `main.js:1668-1670`'s `GAME_PAUSE`.
                isPaused: overlay != nil,
                onExit: { overlay = .menu },
                onLevelPassed: { levelIndex, score in
                    let previous = highScoreStore.bestScore(
                        pack: currentGame.pack, levelIndex: levelIndex)
                    highScoreStore.recordScore(
                        score, pack: currentGame.pack, levelIndex: levelIndex)
                    return previous
                },
                onGameOver: { finalScore, levelReached, isWinner in
                    let pending: LeaderboardOverlay.PendingScore? =
                        leaderboardStore.qualifies(
                            pack: currentGame.pack, score: finalScore)
                        ? LeaderboardOverlay.PendingScore(
                            score: finalScore, levelReached: levelReached)
                        : nil
                    overlay = .leaderboard(
                        pack: currentGame.pack, theme: currentGame.theme,
                        pending: pending, isWinner: isWinner)
                }
            )
            .environment(\.tileTheme, currentGame.theme)
            .id(currentGame)
        } else {
            // Cover splash or bootstrap. Plain black; the overlay covers
            // the whole frame.
            Color.black.ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func overlayView(_ overlay: Overlay) -> some View {
        switch overlay {
        case .cover:
            CoverOverlay(onDismiss: {
                // Cover → gameplay direct. Seed the game from the
                // persisted last pack/theme (fresh installs get Classic /
                // Apple II via the `@AppStorage` fallbacks).
                withAnimation(.easeInOut(duration: 0.4)) {
                    currentGame = Selection(
                        pack: lastPack, theme: lastTheme, startingLevelIndex: 0)
                    self.overlay = nil
                }
            })
            .transition(.opacity)
        case .menu:
            PackChooserOverlay(
                initialPack: lastPack,
                initialTheme: lastTheme,
                onPick: { pack, theme in
                    lastPack = pack
                    lastTheme = theme
                    currentGame = Selection(
                        pack: pack, theme: theme, startingLevelIndex: 0)
                    self.overlay = nil
                },
                onPickLevel: hudMode == .modern
                    ? { pack, theme in
                        lastPack = pack
                        lastTheme = theme
                        guard let levels = try? pack.load(), !levels.isEmpty else {
                            return
                        }
                        self.overlay = .levelPicker(
                            pack: pack, theme: theme, levels: levels)
                    }
                    : nil,
                onPickLeaderboard: { pack, theme in
                    lastPack = pack
                    lastTheme = theme
                    self.overlay = .leaderboard(
                        pack: pack, theme: theme, pending: nil, isWinner: false)
                },
                onPickSettings: { theme in
                    lastTheme = theme
                    self.overlay = .settings(theme: theme)
                },
                onPickHelp: { theme in
                    lastTheme = theme
                    self.overlay = .help(theme: theme)
                },
                onPickInfo: { pack, theme in
                    lastPack = pack
                    lastTheme = theme
                    self.overlay = .info(pack: pack, theme: theme)
                },
                // The pack chooser now doubles as a mid-game menu, so it
                // needs a way to close *without* starting a new game.
                // Only meaningful when a game is running underneath
                // (otherwise there's nowhere to return to); passing `nil`
                // hides the button on the pre-game path.
                onClose: currentGame != nil ? { self.overlay = nil } : nil
            )
        case .levelPicker(let pack, let theme, let levels):
            LevelSelectOverlay(
                levels: levels,
                onPick: { index in
                    currentGame = Selection(
                        pack: pack, theme: theme, startingLevelIndex: index)
                    self.overlay = nil
                },
                onClose: { self.overlay = .menu }
            )
            .environment(\.tileTheme, theme)
        case .settings(let theme):
            SettingsOverlay(
                soundEnabled: $soundEnabled,
                speedIndex: $speedIndex,
                hudMode: $hudMode,
                onClose: { self.overlay = .menu }
            )
            .environment(\.tileTheme, theme)
        case .help(let theme):
            HelpOverlay(onClose: { self.overlay = .menu })
                .environment(\.tileTheme, theme)
        case .info(let pack, let theme):
            InfoOverlay(pack: pack, onClose: { self.overlay = .menu })
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
                    // Post-game-over leaderboard returns straight into
                    // the menu so the player can PLAY again or pick a
                    // different pack. Menu-entered leaderboard returns
                    // to the menu it came from — same target either way.
                    self.overlay = .menu
                }
            )
            .environment(\.tileTheme, theme)
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
    /// Human-readable pack name for the chooser. The raw values
    /// (`"classic"`, `"fanBookMod"`, …) match the bundled file stems, so
    /// they're not display-friendly on their own.
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
