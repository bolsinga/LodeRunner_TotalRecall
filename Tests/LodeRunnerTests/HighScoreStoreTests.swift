import Foundation
import Testing

@testable import LodeRunner

@Suite
@MainActor
struct HighScoreStoreTests {
    /// Fresh `UserDefaults` suite per test so writes stay isolated and can't
    /// pollute the developer's real `.standard` defaults.
    private func isolatedStore() -> (HighScoreStore, UserDefaults) {
        let suiteName = "loderunner-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (HighScoreStore(defaults: defaults), defaults)
    }

    @Test("bestScore returns nil for unrecorded levels")
    func bestScoreNilForUnrecorded() {
        let (store, _) = isolatedStore()
        #expect(store.bestScore(pack: .classic, levelIndex: 0) == nil)
        #expect(store.bestScore(pack: .revenge, levelIndex: 42) == nil)
    }

    @Test("recordScore writes a new best on the first write and returns true")
    func recordScoreFirstWrite() {
        let (store, _) = isolatedStore()
        #expect(store.recordScore(1500, pack: .classic, levelIndex: 0) == true)
        #expect(store.bestScore(pack: .classic, levelIndex: 0) == 1500)
    }

    @Test("recordScore only overwrites when the new score beats the previous best")
    func recordScoreGuardsAgainstLowerScores() {
        let (store, _) = isolatedStore()
        _ = store.recordScore(2000, pack: .classic, levelIndex: 0)
        #expect(store.recordScore(1500, pack: .classic, levelIndex: 0) == false)
        #expect(store.bestScore(pack: .classic, levelIndex: 0) == 2000)
        #expect(store.recordScore(2500, pack: .classic, levelIndex: 0) == true)
        #expect(store.bestScore(pack: .classic, levelIndex: 0) == 2500)
    }

    @Test("scores are keyed per-pack — writing one pack doesn't leak into another")
    func packsAreIsolated() {
        let (store, _) = isolatedStore()
        _ = store.recordScore(1000, pack: .classic, levelIndex: 5)
        #expect(store.bestScore(pack: .classic, levelIndex: 5) == 1000)
        #expect(store.bestScore(pack: .revenge, levelIndex: 5) == nil)
        #expect(store.bestScore(pack: .professional, levelIndex: 5) == nil)
    }

    @Test("recording a level index past the current end grows the array")
    func recordAtHigherIndexGrowsArray() {
        let (store, _) = isolatedStore()
        _ = store.recordScore(100, pack: .classic, levelIndex: 0)
        _ = store.recordScore(500, pack: .classic, levelIndex: 20)
        #expect(store.bestScore(pack: .classic, levelIndex: 0) == 100)
        #expect(store.bestScore(pack: .classic, levelIndex: 20) == 500)
        // Interior levels between 0 and 20 stay unrecorded, not zero.
        #expect(store.bestScore(pack: .classic, levelIndex: 10) == nil)
    }

    @Test("recording persists across store instances (round-trips through UserDefaults)")
    func recordPersistsAcrossInstances() {
        let (store, defaults) = isolatedStore()
        _ = store.recordScore(9999, pack: .fanBookMod, levelIndex: 3)

        let reopened = HighScoreStore(defaults: defaults)
        #expect(reopened.bestScore(pack: .fanBookMod, levelIndex: 3) == 9999)
    }

    @Test("reset clears every level for the pack, leaving other packs intact")
    func resetClearsSinglePack() {
        let (store, _) = isolatedStore()
        _ = store.recordScore(100, pack: .classic, levelIndex: 0)
        _ = store.recordScore(200, pack: .classic, levelIndex: 1)
        _ = store.recordScore(300, pack: .revenge, levelIndex: 0)

        store.reset(pack: .classic)
        #expect(store.bestScore(pack: .classic, levelIndex: 0) == nil)
        #expect(store.bestScore(pack: .classic, levelIndex: 1) == nil)
        #expect(store.bestScore(pack: .revenge, levelIndex: 0) == 300)
    }

    @Test("negative level indexes are rejected — recordScore is a no-op")
    func negativeIndexRejected() {
        let (store, _) = isolatedStore()
        #expect(store.recordScore(1000, pack: .classic, levelIndex: -1) == false)
        #expect(store.bestScore(pack: .classic, levelIndex: -1) == nil)
    }
}

@Suite
struct LevelPassSummaryBonusScoreTests {
    @Test("bonusScore matches the JS modern-mode formula (999 - time + gold + guards) × 100")
    func bonusScoreMatchesJSFormula() {
        // Perfect run: no time elapsed, all 12 gold, all 5 guards trapped.
        let perfect = LevelPassSummary(
            levelNumber: 1, goldCollected: 12, guardsTrapped: 5, secondsElapsed: 0)
        #expect(perfect.bonusScore == (999 + 12 + 5) * 100)  // 101_600

        // Mid-tier: half the time gone, half the gold.
        let mid = LevelPassSummary(
            levelNumber: 1, goldCollected: 6, guardsTrapped: 0, secondsElapsed: 500)
        #expect(mid.bonusScore == (999 - 500 + 6) * 100)  // 50_500

        // Full time expired: floor is `(gold + guards) * 100` (999-999 = 0).
        let expired = LevelPassSummary(
            levelNumber: 1, goldCollected: 8, guardsTrapped: 2, secondsElapsed: 999)
        #expect(expired.bonusScore == (8 + 2) * 100)  // 1_000
    }
}
