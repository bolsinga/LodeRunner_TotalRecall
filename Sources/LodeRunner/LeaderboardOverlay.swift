import SwiftUI

/// Full-board leaderboard screen — a port of `drawHiScoreList` /
/// `showScoreTable` at `hiscore.js:61-237`. Unlike the port's other
/// system-font modal overlays, this one covers the *entire* board (same
/// footprint as `GameView`'s combined playfield + HUD) and renders every
/// character with the game's own glyph sheet (`TextRow`/`SpriteFrame`
/// over `SpriteSheetSpec.text`), matching the original arcade look instead
/// of a native dialog panel.
///
/// Layout constants below (column/row positions in tile units) are lifted
/// directly from `drawHiScoreList` (`hiscore.js:183-219`) and
/// `getNameStartPos` (`hiscore.js:175-181`).
///
/// Two modes:
/// - **Read-only**: `pendingScore == nil`. Table displays; CLOSE (or
///   Return) dismisses.
/// - **Name entry**: `pendingScore != nil`. The qualifying score is
///   spliced into the table at its landing rank (mirroring
///   `updateScoreInfo`'s immediate splice-before-naming at
///   `hiscore.js:142-159`) and that row shows an `ArcadeNameField` with a
///   blinking block cursor in place of the name column.
///
/// Deferred vs. the JS:
/// - **Music callbacks** (`endingMusicPlay/Stop` in JS) — no music yet.
/// - **Attract-mode auto-rotate** — no attract mode in the port.
/// - **Arrow-key character cycling** (`nextChar` in JS) — typed input only.
public struct LeaderboardOverlay: View {
    let pack: LevelPack
    let entries: [LeaderboardEntry]
    let pendingScore: PendingScore?
    /// True when this overlay is opened for a player who cleared the whole
    /// pack. Ports JS `hiscore.js:246,286`'s `winner` flag — gates the
    /// `endingMusic.mp3` playback so a plain game-over stays silent, and
    /// swaps the subtitle caption for a celebratory one.
    let isWinner: Bool
    /// Global sound toggle from the settings overlay. Muted overlays skip
    /// the ending music.
    let soundEnabled: Bool
    let onSubmit: (LeaderboardEntry?) -> Void

    @State private var nameInput: String = ""
    /// Drives the real (invisible) name-capture `TextField` in
    /// `nameCapture`. Set on appear rather than via `.focusOnAppear()` —
    /// that helper is a tvOS-only no-op elsewhere, and this field also
    /// needs a working *click*-to-focus fallback, which is why it's kept
    /// out of `FittedBoardView`'s scaled coordinate space entirely (see
    /// `nameCapture`'s doc comment).
    @FocusState private var isNameFieldFocused: Bool
    /// Sound player local to this overlay so the ending music's lifetime
    /// matches the overlay's — starts in `.task`, stops in `.onDisappear`.
    /// A fresh instance instead of an injected `SoundPlayer` because no
    /// other overlay on-screen at this moment plays audio.
    @State private var sound = SoundPlayer()
    @Environment(\.tileTheme) private var theme

    /// A qualifying score awaiting a name so it can be added to the
    /// leaderboard. Includes the level reached so the overlay can render
    /// the pending row inline with the same shape as saved entries.
    public struct PendingScore: Equatable, Sendable {
        public let score: Int
        public let levelReached: Int
        public init(score: Int, levelReached: Int) {
            self.score = score
            self.levelReached = levelReached
        }
    }

    public init(
        pack: LevelPack,
        entries: [LeaderboardEntry],
        pendingScore: PendingScore? = nil,
        isWinner: Bool = false,
        soundEnabled: Bool = true,
        onSubmit: @escaping (LeaderboardEntry?) -> Void
    ) {
        self.pack = pack
        self.entries = entries
        self.pendingScore = pendingScore
        self.isWinner = isWinner
        self.soundEnabled = soundEnabled
        self.onSubmit = onSubmit
    }

    public var body: some View {
        ZStack {
            // Full-window backdrop — outside `FittedBoardView` so it
            // covers the whole overlay area, not just the letterboxed
            // board-sized rect. `PackChooserView`'s underlying `gameLayer`
            // (exitBar + HUD) stays mounted (just `.disabled`) behind this
            // overlay, so without a backdrop sized to the *actual*
            // available space, its chrome peeks through the gaps left by
            // aspect-fit letterboxing.
            Color.black.ignoresSafeArea()
            // Sits *behind* the board content on purpose — see this
            // property's doc comment for why (SAVE/CLOSE need click
            // priority over this field's full-size hit area).
            nameCapture
            FittedBoardView(boardHeight: Self.boardHeight) {
                ZStack(alignment: .topLeading) {
                    glyphRow(pack.displayName.uppercased(), col: titleColumn, row: 0)
                    glyphRow(
                        isWinner ? "YOU WIN" : "LOCAL HIGH SCORES",
                        col: subtitleColumn, row: 1.5)
                    glyphRow("NO", col: 0.5, row: 3)
                    glyphRow("NAME", col: 7.75, row: 3)
                    glyphRow("LEVEL", col: 15.75, row: 3)
                    glyphRow("SCORE", col: 22, row: 3)
                    groundBar
                    table
                    footer
                }
            }
        }
        .task {
            // Ports `endingMusicPlay()` at `hiscore.js:246` — winner-only.
            // Sound-off honored via `SoundPlayer.isEnabled` (which guards
            // `play(_:)` internally) so the settings toggle mutes the
            // ending music too.
            sound.theme = theme
            sound.isEnabled = soundEnabled
            if isWinner {
                sound.play(.ending)
            }
            if pendingScore != nil {
                isNameFieldFocused = true
            }
        }
        .onDisappear {
            // `endingMusicStop()` at `hiscore.js:286`. Safe to call whether
            // or not the play fired.
            sound.stop(.ending)
        }
    }

    /// The *real* text-capture control — kept as a plain, unscaled sibling
    /// of `FittedBoardView` rather than living inside the tile-coordinate
    /// content (where an earlier version embedded it). Nesting an
    /// interactive `TextField` inside `FittedBoardView`'s `.scaleEffect` +
    /// several layers of tile-unit `.offset` broke both click hit-testing
    /// and this overlay's own `.focusOnAppear()`-based auto-focus (that
    /// helper is a tvOS-only no-op elsewhere) — the field never actually
    /// received focus or clicks on macOS/iOS. Splitting capture (here,
    /// full-size and invisible) from display (`ArcadeNameField`, purely
    /// visual, inside the scaled board content) fixes both: `.task` above
    /// grabs focus programmatically the moment the overlay appears
    /// (state-driven, so it works regardless of z-order).
    ///
    /// Placed *behind* the board content in `body`'s `ZStack` — its own
    /// full-size hit area would otherwise sit on top of, and swallow
    /// clicks meant for, the SAVE/CLOSE buttons rendered inside
    /// `FittedBoardView`. Focus assignment doesn't need click priority to
    /// work, so this ordering keeps both working: SAVE/CLOSE stay
    /// clickable, and the field is still focused (and typable) the moment
    /// the overlay appears.
    @ViewBuilder
    private var nameCapture: some View {
        if pendingScore != nil {
            TextField("", text: $nameInput)
                .focused($isNameFieldFocused)
                .textFieldStyle(.plain)
                .foregroundStyle(.clear)
                .tint(.clear)
                .autocorrectionDisabled()
                #if os(iOS) || os(tvOS)
                    .textInputAutocapitalization(.characters)
                #endif
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .focusEffectDisabled()
                .onSubmit(saveEntry)
                .onChange(of: nameInput) { _, newValue in
                    nameInput = ArcadeNameField.sanitize(
                        newValue, maxLength: LeaderboardEntry.maxNameLength)
                }
        }
    }

    // MARK: - Layout

    /// Board footprint this overlay covers. Roughly the same combined
    /// playfield + HUD height `GameView` uses (the JS draws the score
    /// screen over its *entire* canvas — `setScoreBackground` at
    /// `hiscore.js:169-173`, not just the playfield) but taller: matching
    /// `GameView`'s exact `(tilesY + 1)` height (17 rows) left no room for
    /// `footer`'s row, which sits at row 17.8 (`LeaderboardStore.slotCount`
    /// entries at 1.2 spacing starting at row 5, plus a 2-row gap). Content
    /// laid out past `boardHeight` doesn't get clipped by `FittedBoardView`
    /// (no `.clipped()`), but `FittedBoardView`'s *scale* is computed only
    /// from this declared height, so on a screen short enough that the
    /// scaled board fills the whole height (any phone in landscape), the
    /// footer rendered below the visible window entirely — CLOSE/SAVE were
    /// on-screen on a tall macOS window (where there's slack below the
    /// scaled board) but unreachable on a phone. 20 rows covers the
    /// footer's row (through 18.8) with a little breathing room below.
    private static let boardHeight = CGFloat(20 * TileGeometry.tileHeight)

    private var titleColumn: CGFloat {
        CGFloat(LevelGrid.tilesX - pack.displayName.count) / 2
    }

    private var subtitleColumn: CGFloat {
        let caption = isWinner ? "YOU WIN" : "LOCAL HIGH SCORES"
        return CGFloat(LevelGrid.tilesX - caption.count) / 2
    }

    /// Renders `text` as a glyph row positioned at `(col, row)` in tile
    /// units, matching `makeGlyphText(x, y, str, numberType)`'s `x = col *
    /// tileW, y = row * tileH` (`hiscore.js:51-59`).
    private func glyphRow(
        _ text: String, col: CGFloat, row: CGFloat, digitVariant: DigitVariant = .normal
    ) -> some View {
        TextRow(text, digitVariant: digitVariant)
            .offset(
                x: col * CGFloat(TileGeometry.tileWidth),
                y: row * CGFloat(TileGeometry.tileHeight)
            )
    }

    /// Horizontal ground-tile divider under the header row — port of the
    /// `for(x...) barTile` loop at `hiscore.js:197-204`. Drawn at native
    /// `ground.png` size (40×20), not a full tile height, matching the
    /// JS's `barTile.scaleX = barTile.scaleY = 1`.
    private var groundBar: some View {
        HStack(spacing: 0) {
            ForEach(0..<LevelGrid.tilesX, id: \.self) { _ in
                Image("\(theme.rawValue)/ground", bundle: .module)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: CGFloat(TileGeometry.tileWidth), height: 20)
            }
        }
        .offset(x: 0, y: 4.5 * CGFloat(TileGeometry.tileHeight))
    }

    private var table: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<LeaderboardStore.slotCount, id: \.self) { rank in
                row(rank)
            }
        }
    }

    /// 0-based rank the pending score would land at, mirroring
    /// `LeaderboardStore.insert`'s own `firstIndex(where: score <)` rule.
    private var pendingRank: Int? {
        guard let pendingScore else { return nil }
        return entries.firstIndex(where: { pendingScore.score > $0.score }) ?? entries.count
    }

    /// `entries` with the pending score spliced in (name still blank) and
    /// trimmed back to `slotCount` — same shift-and-drop behavior as
    /// `updateScoreInfo`'s splice at `hiscore.js:152-153`. Only the
    /// *shifted-down* real entries are read off this; the pending row
    /// itself renders live from `pendingScore`/`nameInput` instead.
    private var mergedEntries: [LeaderboardEntry] {
        guard let pendingScore, let rank = pendingRank, rank < entries.count else { return entries }
        var merged = entries
        merged.insert(
            LeaderboardEntry(score: pendingScore.score, name: "", levelReached: pendingScore.levelReached),
            at: rank)
        if merged.count > LeaderboardStore.slotCount {
            merged.removeLast(merged.count - LeaderboardStore.slotCount)
        }
        return merged
    }

    @ViewBuilder
    private func row(_ rank: Int) -> some View {
        let y = CGFloat(rank) * 1.2 + 5
        glyphRow(String(format: "%02d.", rank + 1), col: 0.25, row: y)
        if let pendingScore, rank == pendingRank {
            glyphRow(String(format: "%03d", pendingScore.levelReached), col: 16.75, row: y)
            glyphRow(String(format: "%07d", pendingScore.score), col: 21, row: y)
            let namePos =
                3.75 + CGFloat(LeaderboardEntry.maxNameLength - nameInput.count) / 2
            ArcadeNameField(text: nameInput)
                .offset(
                    x: namePos * CGFloat(TileGeometry.tileWidth),
                    y: y * CGFloat(TileGeometry.tileHeight)
                )
        } else {
            let entry = mergedEntries[rank]
            if entry.score > 0 {
                if !entry.name.isEmpty {
                    let namePos =
                        3.75 + CGFloat(LeaderboardEntry.maxNameLength - entry.name.count) / 2
                    glyphRow(entry.name, col: namePos, row: y, digitVariant: .blue)
                }
                glyphRow(String(format: "%03d", entry.levelReached), col: 16.75, row: y)
                glyphRow(String(format: "%07d", entry.score), col: 21, row: y)
            }
        }
    }

    /// SAVE (name-entry mode) / CLOSE (read-only mode) caption, rendered
    /// with the same glyph font rather than a system button — the JS has
    /// no equivalent (ENTER always commits, any key always closes), but a
    /// touch/click affordance is needed for platforms without a keyboard.
    @ViewBuilder
    private var footer: some View {
        if pendingScore != nil {
            footerButton(">SAVE<", action: saveEntry)
                .disabled(!isNameValid)
                .opacity(isNameValid ? 1 : 0.4)
        } else {
            footerButton(">CLOSE<", action: { onSubmit(nil) })
                .focusOnAppear()
                #if !os(tvOS)
                    .keyboardShortcut(.return, modifiers: [])
                #endif
        }
    }

    /// Builds the SAVE/CLOSE button with an explicit frame + tap shape
    /// sized to its own label, offsetting the *button* into position
    /// rather than offsetting the label inside it (the pattern every
    /// other `glyphRow` on this screen uses, since they're plain text with
    /// no hit-testing to get right). A `Button` whose label is an
    /// internally-offset `TextRow` reports an implicit, unreliable tap
    /// target once nested this deep inside `FittedBoardView`'s
    /// `GeometryReader` + `scaleEffect` transform — taps at the visually
    /// correct on-screen glyphs landed nowhere. Giving the button its own
    /// well-defined frame/`contentShape` and positioning *that* fixes it.
    private func footerButton(_ caption: String, action: @escaping () -> Void) -> some View {
        let row = CGFloat(LeaderboardStore.slotCount - 1) * 1.2 + 5 + 2
        let width = CGFloat(caption.count * TileGeometry.tileWidth)
        let height = CGFloat(TileGeometry.tileHeight)
        return Button(action: action) {
            TextRow(caption)
        }
        .buttonStyle(.plain)
        .frame(width: width, height: height)
        .contentShape(Rectangle())
        .offset(
            x: footerColumn(for: caption) * CGFloat(TileGeometry.tileWidth),
            y: row * CGFloat(TileGeometry.tileHeight)
        )
    }

    private func footerColumn(for caption: String) -> CGFloat {
        CGFloat(LevelGrid.tilesX - caption.count) / 2
    }

    /// Trim + validate: at least 1 non-whitespace character, at most
    /// `maxNameLength`. Simpler than the JS's "2+ chars, not all identical"
    /// rule at `hiscore.js:491-509` — for a solo port, the extra strictness
    /// isn't worth the UX friction.
    private var isNameValid: Bool {
        let trimmed = nameInput.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && trimmed.count <= LeaderboardEntry.maxNameLength
    }

    private func saveEntry() {
        guard isNameValid, let pending = pendingScore else { return }
        let trimmed = nameInput.trimmingCharacters(in: .whitespaces)
        onSubmit(
            LeaderboardEntry(
                score: pending.score, name: trimmed, levelReached: pending.levelReached))
    }
}

// MARK: - Preview

#Preview("Leaderboard — read-only", traits: .landscapeLeft) {
    LeaderboardOverlay(
        pack: .classic,
        entries: [
            LeaderboardEntry(score: 15000, name: "ALICE", levelReached: 42),
            LeaderboardEntry(score: 12500, name: "BOB", levelReached: 33),
            LeaderboardEntry(score: 9800, name: "CAROL", levelReached: 21),
        ]
            + Array(repeating: LeaderboardEntry.empty, count: 7),
        onSubmit: { _ in }
    )
    .environment(\.tileTheme, .apple2)
}

#Preview("Leaderboard — name entry", traits: .landscapeLeft) {
    LeaderboardOverlay(
        pack: .revenge,
        entries: [
            LeaderboardEntry(score: 15000, name: "ALICE", levelReached: 42),
            LeaderboardEntry(score: 12500, name: "BOB", levelReached: 33),
        ]
            + Array(repeating: LeaderboardEntry.empty, count: 8),
        pendingScore: LeaderboardOverlay.PendingScore(score: 13200, levelReached: 6),
        onSubmit: { _ in }
    )
    .environment(\.tileTheme, .c64)
}

#Preview("Leaderboard — winner", traits: .landscapeLeft) {
    LeaderboardOverlay(
        pack: .classic,
        entries: Array(repeating: LeaderboardEntry.empty, count: 10),
        pendingScore: LeaderboardOverlay.PendingScore(score: 4200, levelReached: 50),
        isWinner: true,
        onSubmit: { _ in }
    )
    .environment(\.tileTheme, .apple2)
}
