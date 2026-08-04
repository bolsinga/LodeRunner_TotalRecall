import Foundation
import Observation

/// Per-pack per-level best-score persistence. Analog of the JS's
/// `modernScoreInfo` bookkeeping at `storage.js:150,189` (a flat array
/// indexed by level, one array per pack). Backed by `UserDefaults` under
/// keys of the form `loderunner_bestScores_<pack>` — matches the pattern
/// `PackChooserView` uses for `@AppStorage` keys.
///
/// A record fires only on level pass, and only when the new score exceeds
/// the previous best for that (pack, levelIndex) — matching how JS's
/// `updateModernScoreInfo` guards the write.
@Observable @MainActor
public final class HighScoreStore {
    private let defaults: UserDefaults

    /// Test seam. Production callers use the default `.standard`
    /// suite; tests can inject an isolated suite so their writes don't
    /// pollute the developer's real defaults.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Best recorded score for `(pack, levelIndex)`, or `nil` if the
    /// player has never completed that level in this pack. `nil` (not `0`)
    /// so callers can distinguish "no data yet" from "recorded a zero".
    public func bestScore(pack: LevelPack, levelIndex: Int) -> Int? {
        let table = load(pack: pack)
        guard levelIndex >= 0, levelIndex < table.count else { return nil }
        let value = table[levelIndex]
        return value >= 0 ? value : nil
    }

    /// Record `score` for `(pack, levelIndex)`. No-op unless the new
    /// score strictly beats the previous best — same guard JS uses at
    /// `storage.js:189`. Returns `true` when a new record was written.
    @discardableResult
    public func recordScore(_ score: Int, pack: LevelPack, levelIndex: Int) -> Bool {
        guard levelIndex >= 0 else { return false }
        var table = load(pack: pack)
        // Grow the array to fit — sentinel `-1` marks "unplayed" entries so
        // absence is distinguishable from a genuine 0.
        if levelIndex >= table.count {
            table.append(contentsOf: repeatElement(-1, count: levelIndex - table.count + 1))
        }
        if table[levelIndex] < 0 || score > table[levelIndex] {
            table[levelIndex] = score
            save(pack: pack, table: table)
            return true
        }
        return false
    }

    /// Wipe every recorded high score for `pack`. Handy for a future
    /// "reset progress" affordance; not currently wired to any UI.
    public func reset(pack: LevelPack) {
        defaults.removeObject(forKey: Self.storageKey(pack: pack))
    }

    // MARK: - Storage layout

    private func load(pack: LevelPack) -> [Int] {
        guard let data = defaults.data(forKey: Self.storageKey(pack: pack)) else {
            return []
        }
        return (try? JSONDecoder().decode([Int].self, from: data)) ?? []
    }

    private func save(pack: LevelPack, table: [Int]) {
        guard let data = try? JSONEncoder().encode(table) else { return }
        defaults.set(data, forKey: Self.storageKey(pack: pack))
    }

    /// Prefix + pack raw value. Matches the JS `STORAGE_PREFIX` +
    /// `modernScore<n>` shape (`def.js:178`, `storage.js:150`), swapped to
    /// the pack's string identifier since the port doesn't have JS's
    /// numeric `playData` catalog.
    static func storageKey(pack: LevelPack) -> String {
        "loderunner_bestScores_\(pack.rawValue)"
    }
}
