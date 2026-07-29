import Testing

@testable import LodeRunner

@Suite
struct LevelPackTests {
    @Test("every shipped pack loads and returns the expected level count")
    func allPacksLoadWithExpectedCounts() throws {
        let expected: [LevelPack: Int] = [
            .classic: 150,
            .professional: 150,
            .revenge: 17,
            .fanBookMod: 66,
            .championship: 51,
        ]
        for pack in LevelPack.allCases {
            let levels = try pack.load()
            #expect(levels.count == expected[pack], "\(pack.rawValue) level count")
            #expect(levels.allSatisfy { $0.runner != nil }, "\(pack.rawValue) every level has a runner spawn")
        }
    }

    @Test("classic level 1 has the shape a fresh session can start from")
    func classicLevelOneBootsAFreshSession() throws {
        let levels = try LevelPack.classic.load()
        let session = try GameSession(levels: levels)
        #expect(session.simulation.goldRemaining > 0)
        #expect(session.currentLevelIndex == 0)
    }
}
