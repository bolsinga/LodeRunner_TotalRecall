import Foundation
import Testing

@testable import LodeRunner

@Suite
@MainActor
struct LeaderboardStoreTests {
    /// Fresh `UserDefaults` suite per test so writes stay isolated.
    private func isolatedStore() -> (LeaderboardStore, UserDefaults) {
        let suiteName = "loderunner-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (LeaderboardStore(defaults: defaults), defaults)
    }

    @Test("fresh pack: entries() returns 10 empty slots")
    func freshPackEntries() {
        let (store, _) = isolatedStore()
        let table = store.entries(pack: .classic)
        #expect(table.count == 10)
        #expect(table.allSatisfy { $0 == LeaderboardEntry.empty })
    }

    @Test("qualifies: any positive score qualifies against an empty table")
    func qualifiesEmptyTable() {
        let (store, _) = isolatedStore()
        #expect(store.qualifies(pack: .classic, score: 1) == true)
        #expect(store.qualifies(pack: .classic, score: 999_999) == true)
    }

    @Test("qualifies: zero or negative scores never qualify")
    func qualifiesNonPositive() {
        let (store, _) = isolatedStore()
        #expect(store.qualifies(pack: .classic, score: 0) == false)
        #expect(store.qualifies(pack: .classic, score: -100) == false)
    }

    @Test("insert lands the entry at the correct rank + trims to slotCount")
    func insertPlacesAndTrims() {
        let (store, _) = isolatedStore()
        // Seed the table with 10 entries of descending scores 1000, 900, ..., 100.
        for i in 0..<10 {
            let score = 1000 - i * 100
            _ = store.insert(
                LeaderboardEntry(score: score, name: "P\(i)", levelReached: 1),
                pack: .classic)
        }
        // Insert a new record in the middle.
        let rank = store.insert(
            LeaderboardEntry(score: 550, name: "MID", levelReached: 5),
            pack: .classic)
        #expect(rank == 5)  // 1000, 900, 800, 700, 600, [550], 500...

        let table = store.entries(pack: .classic)
        #expect(table.count == 10)
        #expect(table[5].name == "MID")
        #expect(table[5].score == 550)
        // The old #10 (score 100) got pushed off.
        #expect(table.contains(where: { $0.score == 100 }) == false)
    }

    @Test("insert: new top score lands at rank 0")
    func insertNewTop() {
        let (store, _) = isolatedStore()
        _ = store.insert(
            LeaderboardEntry(score: 500, name: "X", levelReached: 1), pack: .classic)
        let rank = store.insert(
            LeaderboardEntry(score: 1_000, name: "TOP", levelReached: 3), pack: .classic)
        #expect(rank == 0)
        #expect(store.entries(pack: .classic).first?.name == "TOP")
    }

    @Test("insert: sub-cutoff score doesn't qualify, returns nil, doesn't mutate")
    func insertSubCutoffRejected() {
        let (store, _) = isolatedStore()
        for i in 0..<10 {
            _ = store.insert(
                LeaderboardEntry(score: 1000 - i, name: "P\(i)", levelReached: 1),
                pack: .classic)
        }
        // Cutoff is score 991. Try to insert with score 500 (below cutoff).
        let before = store.entries(pack: .classic)
        let rank = store.insert(
            LeaderboardEntry(score: 500, name: "LOW", levelReached: 1), pack: .classic)
        #expect(rank == nil)
        #expect(store.entries(pack: .classic) == before)
    }

    @Test("insert: zero-score entry never qualifies")
    func insertZeroScoreRejected() {
        let (store, _) = isolatedStore()
        let rank = store.insert(
            LeaderboardEntry(score: 0, name: "ZERO", levelReached: 1), pack: .classic)
        #expect(rank == nil)
    }

    @Test("entries are per-pack — one pack's writes don't leak into another")
    func packsAreIsolated() {
        let (store, _) = isolatedStore()
        _ = store.insert(
            LeaderboardEntry(score: 5_000, name: "X", levelReached: 12), pack: .classic)
        #expect(store.entries(pack: .classic).first?.score == 5_000)
        #expect(store.entries(pack: .revenge).allSatisfy { $0 == .empty })
    }

    @Test("entries persist across store instances (round-trip through UserDefaults)")
    func entriesPersistAcrossInstances() {
        let (store, defaults) = isolatedStore()
        _ = store.insert(
            LeaderboardEntry(score: 8_888, name: "PERSIST", levelReached: 7),
            pack: .professional)

        let reopened = LeaderboardStore(defaults: defaults)
        #expect(reopened.entries(pack: .professional).first?.score == 8_888)
        #expect(reopened.entries(pack: .professional).first?.name == "PERSIST")
    }

    @Test("reset clears the pack, leaves others alone")
    func resetIsPerPack() {
        let (store, _) = isolatedStore()
        _ = store.insert(
            LeaderboardEntry(score: 100, name: "A", levelReached: 1), pack: .classic)
        _ = store.insert(
            LeaderboardEntry(score: 200, name: "B", levelReached: 2), pack: .revenge)

        store.reset(pack: .classic)
        #expect(store.entries(pack: .classic).allSatisfy { $0 == .empty })
        #expect(store.entries(pack: .revenge).first?.score == 200)
    }
}
