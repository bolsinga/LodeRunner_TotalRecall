import Foundation
import Observation

/// One entry on a pack's top-N leaderboard. Ports the JS `{s, n, l}`
/// object at `hiscore.js:129-131`: total score, player name (up to
/// `maxNameLength` chars), and the level reached at game-over (1-based
/// for display, matching JS `curLevel`).
public struct LeaderboardEntry: Equatable, Codable, Sendable, Identifiable {
    public let score: Int
    public let name: String
    public let levelReached: Int

    public init(score: Int, name: String, levelReached: Int) {
        self.score = score
        self.name = name
        self.levelReached = levelReached
    }

    /// `Identifiable` for `ForEach` in the overlay. Empty-slot rows aren't
    /// distinguishable by any single field on their own; combine everything
    /// to keep IDs unique across ties.
    public var id: String { "\(score)|\(name)|\(levelReached)" }

    /// JS `MAX_HISCORE_NAME_LENGTH = 12` at `def.js:170`.
    public static let maxNameLength = 12
    /// JS empty-slot placeholder — score/level 0 with a blank name. Callers
    /// can render these as "———" or filter them out.
    public static let empty = LeaderboardEntry(score: 0, name: "", levelReached: 0)
}

/// Per-pack top-10 leaderboard persistence. Ports `getHiScoreInfo` /
/// `setHiScoreInfo` at `hiscore.js:119,137` — one JSON array per pack,
/// keyed `loderunner_leaderboard_<pack>`. Matches the JS's guarantee that
/// the table always has exactly `Self.slotCount` entries in descending
/// score order.
///
/// `HighScoreStore` (`bestScore(pack:levelIndex:)`) is a separate concern —
/// per-level bests for the level-pass dialog. Both live under the
/// `loderunner_` prefix but never share the same key.
@Observable @MainActor
public final class LeaderboardStore {
    private let defaults: UserDefaults

    /// Test seam — inject an isolated `UserDefaults` suite so writes stay
    /// out of `.standard`.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Current top-`slotCount` for `pack`, always exactly `slotCount`
    /// entries, sorted descending by score. Missing slots are filled with
    /// `LeaderboardEntry.empty`.
    public func entries(pack: LevelPack) -> [LeaderboardEntry] {
        let stored = load(pack: pack)
        return Self.pad(stored)
    }

    /// True if `score` would land in the top `slotCount` for `pack`. Non-
    /// positive scores never qualify — matches JS `hiscore.js:146` (`score
    /// > 0` guard) so a zero-score game-over doesn't prompt a name entry.
    public func qualifies(pack: LevelPack, score: Int) -> Bool {
        guard score > 0 else { return false }
        let table = entries(pack: pack)
        // Table is descending; the last (lowest) entry is the cutoff.
        return score > table[Self.slotCount - 1].score
    }

    /// Insert `entry` into `pack`'s leaderboard if it qualifies. Returns
    /// the 0-based rank at which it landed, or `nil` if it didn't qualify
    /// (score too low, empty name, etc). The stored array is capped at
    /// `slotCount` — inserting shifts the tail off the end.
    @discardableResult
    public func insert(_ entry: LeaderboardEntry, pack: LevelPack) -> Int? {
        guard entry.score > 0 else { return nil }
        var table = entries(pack: pack)
        guard entry.score > table[Self.slotCount - 1].score else { return nil }
        // Find insertion index: first slot whose score < entry.score.
        let insertAt = table.firstIndex(where: { $0.score < entry.score }) ?? table.endIndex
        table.insert(entry, at: insertAt)
        // Trim back to slotCount.
        if table.count > Self.slotCount {
            table.removeLast(table.count - Self.slotCount)
        }
        save(pack: pack, table: table)
        return insertAt
    }

    /// Wipe every leaderboard entry for `pack`. Handy for a future
    /// "reset progress" affordance.
    public func reset(pack: LevelPack) {
        defaults.removeObject(forKey: Self.storageKey(pack: pack))
    }

    // MARK: - Constants + storage layout

    /// JS `MAX_HISCORE_RECORD = 10` at `def.js:169`.
    public static let slotCount = 10

    private func load(pack: LevelPack) -> [LeaderboardEntry] {
        guard let data = defaults.data(forKey: Self.storageKey(pack: pack)) else {
            return []
        }
        return (try? JSONDecoder().decode([LeaderboardEntry].self, from: data)) ?? []
    }

    private func save(pack: LevelPack, table: [LeaderboardEntry]) {
        guard let data = try? JSONEncoder().encode(table) else { return }
        defaults.set(data, forKey: Self.storageKey(pack: pack))
    }

    private static func pad(_ table: [LeaderboardEntry]) -> [LeaderboardEntry] {
        if table.count >= slotCount { return Array(table.prefix(slotCount)) }
        return table + Array(repeating: .empty, count: slotCount - table.count)
    }

    /// `loderunner_leaderboard_<pack>` — mirrors JS `STORAGE_HISCORE_INFO`
    /// concatenated with a `playData` id (`hiscore.js:119`). Uses the pack's
    /// string identifier since the port has no numeric `playData` catalog.
    static func storageKey(pack: LevelPack) -> String {
        "loderunner_leaderboard_\(pack.rawValue)"
    }
}
