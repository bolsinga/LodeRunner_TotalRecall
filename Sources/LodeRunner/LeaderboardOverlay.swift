import SwiftUI

/// Top-10 leaderboard modal — ports the JS `showScoreTable` UI at
/// `hiscore.js:172-238`. Renders a scrollable per-pack table (rank, name,
/// level reached, score) in the same black/yellow monospaced style as
/// `LevelPassDialog` and `PackChooserOverlay`.
///
/// Two modes:
/// - **Read-only**: `pendingScore == nil`. Table displays, dismiss via tap
///   or Return.
/// - **Name entry**: `pendingScore != nil`. Table is shown with a name
///   input row inline; SAVE commits the entry via `onSubmit(name)`.
///
/// The JS's A-Z/0-9 arrow-key cycler is intentionally *not* ported —
/// SwiftUI's native `TextField` gives macOS-appropriate editing without
/// re-implementing keyboard handling from scratch. Name length is capped
/// at `LeaderboardEntry.maxNameLength` (JS `MAX_HISCORE_NAME_LENGTH`).
///
/// Deferred vs. the JS:
/// - **Music callbacks** (`endingMusicPlay/Stop` in JS) — no music yet.
/// - **Attract-mode auto-rotate** — no attract mode in the port.
/// - **Blinking cursor animation** — SwiftUI `TextField` shows its own.
public struct LeaderboardOverlay: View {
    let pack: LevelPack
    let entries: [LeaderboardEntry]
    let pendingScore: PendingScore?
    /// True when this overlay is opened for a player who cleared the whole
    /// pack. Ports JS `hiscore.js:246,286`'s `winner` flag — gates the
    /// `endingMusic.mp3` playback so a plain game-over stays silent.
    let isWinner: Bool
    /// Global sound toggle from the settings overlay. Muted overlays skip
    /// the ending music.
    let soundEnabled: Bool
    let onSubmit: (LeaderboardEntry?) -> Void

    @State private var nameInput: String = ""
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
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 12) {
                Text(isWinner ? "YOU WIN!" : "HIGH SCORES")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(isWinner ? .green : .yellow)
                Text(pack.displayName.uppercased())
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                table
                footer
            }
            .padding(24)
            .background(Color.black)
            .overlay(Rectangle().stroke(Color.white, lineWidth: 1))
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
        }
        .onDisappear {
            // `endingMusicStop()` at `hiscore.js:286`. Safe to call whether
            // or not the play fired.
            sound.stop(.ending)
        }
    }

    private var table: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
            GridRow {
                Text("#").foregroundStyle(.white.opacity(0.5))
                Text("NAME").foregroundStyle(.white.opacity(0.5))
                Text("LVL").foregroundStyle(.white.opacity(0.5))
                Text("SCORE").foregroundStyle(.white.opacity(0.5))
            }
            .font(.system(size: 10, design: .monospaced))
            ForEach(Array(entries.enumerated()), id: \.offset) { rank, entry in
                row(rank: rank, entry: entry)
            }
        }
    }

    @ViewBuilder
    private func row(rank: Int, entry: LeaderboardEntry) -> some View {
        let isEmpty = entry == .empty
        GridRow {
            Text(String(format: "%2d.", rank + 1))
                .foregroundStyle(.yellow.opacity(isEmpty ? 0.3 : 1))
            if isEmpty {
                Text("---").foregroundStyle(.white.opacity(0.3))
                Text("---").foregroundStyle(.white.opacity(0.3))
                Text("---").foregroundStyle(.white.opacity(0.3))
            } else {
                Text(entry.name).foregroundStyle(.white)
                Text(String(format: "%03d", entry.levelReached)).foregroundStyle(.white)
                Text(String(format: "%07d", entry.score)).foregroundStyle(.yellow)
            }
        }
        .font(.system(size: 14, design: .monospaced))
    }

    @ViewBuilder
    private var footer: some View {
        if let pendingScore {
            VStack(spacing: 8) {
                Divider().background(Color.white.opacity(0.3))
                Text("NEW HIGH SCORE!")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
                Text(
                    "LEVEL \(String(format: "%03d", pendingScore.levelReached)) — "
                        + "\(String(format: "%07d", pendingScore.score))"
                )
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.yellow)
                HStack(spacing: 8) {
                    TextField("NAME", text: $nameInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(width: 200)
                        .overlay(Rectangle().stroke(Color.white.opacity(0.5), lineWidth: 1))
                        .onSubmit(saveEntry)
                        .onChange(of: nameInput) { _, newValue in
                            // Enforce the JS 12-char cap (`def.js:170`).
                            if newValue.count > LeaderboardEntry.maxNameLength {
                                nameInput = String(newValue.prefix(LeaderboardEntry.maxNameLength))
                            }
                        }
                    Button(action: saveEntry) {
                        Text("SAVE")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.yellow)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: [])
                    .disabled(!isNameValid)
                }
            }
        } else {
            Button {
                onSubmit(nil)
            } label: {
                Text("CLOSE")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                    .overlay(Rectangle().stroke(Color.yellow, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [])
        }
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

#Preview("Leaderboard — read-only") {
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
    .frame(width: 500, height: 500)
}

#Preview("Leaderboard — name entry") {
    LeaderboardOverlay(
        pack: .revenge,
        entries: Array(repeating: LeaderboardEntry.empty, count: 10),
        pendingScore: LeaderboardOverlay.PendingScore(score: 4200, levelReached: 6),
        onSubmit: { _ in }
    )
    .frame(width: 500, height: 500)
}
