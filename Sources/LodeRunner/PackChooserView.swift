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
        /// Per-level thumbnail picker. `returnTo` decides where the
        /// close-X button lands: `.menu` when opened via the menu's
        /// SELECT LEVEL button, `.game` when opened via the training-
        /// mode grid button on the game surface (JS `boardIcons.js:96`).
        case levelPicker(
            pack: LevelPack, theme: Theme,
            levels: [LevelParseResult], returnTo: LevelPickerReturn)
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

    /// Where the level picker's close-X button routes to.
    private enum LevelPickerReturn: Equatable {
        /// Back to the pause menu (level picker opened from the menu).
        case menu
        /// Back to running gameplay (opened from the training-mode grid
        /// button, so the player expects RESUME semantics).
        case game
    }

    @State private var currentGame: Selection?
    @State private var overlay: Overlay? = .cover

    /// The active demo playback session, if any. Owns the record being
    /// played, the pack + theme the demo runs under, and the 0-based
    /// level index the underlying Training game was on so we can restart
    /// there when the demo ends. Rendered by `gameLayer` in preference to
    /// `currentGame`; while non-nil, the Training game is unmounted (its
    /// state is lost, matching JS `stopDemoAndPlay` at `demo.js:282-296`
    /// which calls `selectGame` to start a fresh session). Its own
    /// separate state pair (rather than an `Overlay` case) because a demo
    /// runs an actual `GameView`, not a modal.
    private struct DemoState: Equatable {
        let record: DemoRecord
        let pack: LevelPack
        let theme: Theme
        let returnToLevelIndex: Int
    }
    @State private var demoState: DemoState?

    /// 0-based level index of the most recently watched demo. Advances
    /// the seed for the *next* click's `nextValidDemo(startingAt:)` so
    /// repeated ▶ presses cycle through the pack's demos in order rather
    /// than replaying the same one. `nil` before the first watch and
    /// after any "fresh Training start" reset (new game, level picker,
    /// hudMode toggle, cover dismiss). The seed picks the higher of
    /// `lastDemoLevelIndex + 1` and Training's own currentLevelIndex so
    /// Training progression past the last-watched level still gets
    /// picked up.
    @State private var lastDemoLevelIndex: Int?

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
        .onChange(of: hudMode) { _, _ in
            // JS `settings.setMode()` at `settings.js:147` restarts the
            // game whenever Training is toggled — flipping the mode calls
            // `classicPlay(0)` or `modernPlay(0)`, both of which route
            // through `startGame()` and pick up the target mode's *own*
            // persisted `curLevel` (JS keeps separate `classicInfo` vs.
            // `modernInfo` progress buckets). The port has a single
            // `currentGame` selection, so the closest equivalent is:
            // rebuild it at level 0 when the mode toggles mid-game.
            // Matches the "challenge starts at 1 and progresses" line at
            // `settings.js:412`.
            // Also tears down any running demo — the Training toggle also
            // implies "start fresh" for the demo case.
            demoState = nil
            lastDemoLevelIndex = nil
            guard let running = currentGame else { return }
            currentGame = Selection(
                pack: running.pack, theme: running.theme, startingLevelIndex: 0)
        }
    }

    @ViewBuilder
    private var gameLayer: some View {
        if let demoState, let session = Self.makeDemoSession(demoState) {
            // Demo playback screen. Runs on top of nothing — the underlying
            // Training game is unmounted while `demoState != nil`. Fresh
            // GameView per record so its @State (driver, keyboard, demo
            // input) all rebuild cleanly per demo.
            GameView(
                session: session,
                soundEnabled: $soundEnabled,
                speedIndex: $speedIndex,
                hudMode: $hudMode,
                isPaused: overlay != nil,
                onExit: { overlay = .menu },
                demoRecord: demoState.record,
                onDemoEnd: {
                    // Restart Training at the level the player was on when
                    // they hit "Watch demo" — JS `stopDemoAndPlay` at
                    // `demo.js:282-296` reads Training's persisted curLevel
                    // and re-enters `PLAY_MODERN`. Fresh `Selection` so
                    // `.id(...)` triggers a clean remount.
                    self.currentGame = Selection(
                        pack: demoState.pack, theme: demoState.theme,
                        startingLevelIndex: demoState.returnToLevelIndex)
                    self.demoState = nil
                }
            )
            .environment(\.tileTheme, demoState.theme)
            .id(demoState.record.levelNumber)
        } else if let currentGame, let session = Self.makeSession(
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
                },
                // Wired only when Training is on so GameView shows the
                // grid button (JS `boardIcons.js:150,158`). Opening the
                // picker pauses the game (via `overlay != nil`); the
                // close-X returns straight to gameplay.
                onOpenLevelPicker: hudMode == .modern
                    ? {
                        guard let levels = try? currentGame.pack.load(),
                              !levels.isEmpty
                        else { return }
                        overlay = .levelPicker(
                            pack: currentGame.pack, theme: currentGame.theme,
                            levels: levels, returnTo: .game)
                    }
                    : nil,
                // Training-mode-only demo button. Set to the pack's
                // demo-level set so GameView can enable/disable the icon
                // based on whether the pack ships any demos at all; the
                // actual level to play is picked by `onStartDemo` via
                // `nextValidDemo` (JS `getValidDemoLevel`).
                demoLevelIndices: hudMode == .modern
                    ? DemoData.demoLevelIndices(for: currentGame.pack)
                    : [],
                onStartDemo: hudMode == .modern
                    ? { levelIndex in
                        // Advance through the pack's demos on repeated
                        // clicks. Seed = whichever is higher: the last-
                        // watched demo's level + 1, or Training's current
                        // level. `nextValidDemo` then wraps forward.
                        // Ports the JS `getValidDemoLevel` (`demo.js:202-207`)
                        // + `getNextDemoLevel` (`demo.js:209-214`) pair —
                        // JS bumps `curLevel` past just-watched demos so
                        // the next lookup lands on a different record.
                        let seed = max(levelIndex, (lastDemoLevelIndex ?? -1) + 1)
                        guard let record = DemoData.nextValidDemo(
                            for: currentGame.pack, startingAt: seed)
                        else { return }
                        demoState = DemoState(
                            record: record, pack: currentGame.pack,
                            theme: currentGame.theme,
                            returnToLevelIndex: levelIndex)
                        lastDemoLevelIndex = record.levelIndex
                    }
                    : nil
            )
            .environment(\.tileTheme, currentGame.theme)
            .id(currentGame)
        } else {
            // Cover splash or bootstrap. Plain black; the overlay covers
            // the whole frame.
            Color.black.ignoresSafeArea()
        }
    }

    /// Build a demo `GameSession` at the record's level, with only 1 life
    /// (JS `getAutoDemoLevel`/`initDemoInfo` at `demo.js:22,148`) and a
    /// `DemoScript` seeded from the record's `goldDrops` + `bornPositions`.
    private static func makeDemoSession(_ demo: DemoState) -> GameSession? {
        do {
            let levels = try demo.pack.load()
            guard levels.indices.contains(demo.record.levelIndex) else { return nil }
            return try GameSession(
                levels: levels,
                startingLevelIndex: demo.record.levelIndex,
                initialLives: 1,
                demoScript: DemoScript(record: demo.record))
        } catch {
            return nil
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
                    demoState = nil
                    lastDemoLevelIndex = nil
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
                    demoState = nil
                    lastDemoLevelIndex = nil
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
                            pack: pack, theme: theme,
                            levels: levels, returnTo: .menu)
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
        case .levelPicker(let pack, let theme, let levels, let returnTo):
            LevelSelectOverlay(
                levels: levels,
                onPick: { index in
                    demoState = nil
                    lastDemoLevelIndex = nil
                    currentGame = Selection(
                        pack: pack, theme: theme, startingLevelIndex: index)
                    self.overlay = nil
                },
                onClose: {
                    self.overlay = (returnTo == .menu) ? .menu : nil
                }
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
