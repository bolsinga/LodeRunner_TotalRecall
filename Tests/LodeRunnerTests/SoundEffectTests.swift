import Testing

@testable import LodeRunner

@Suite
struct SoundEffectTests {
    @Test("every common-to-both-themes effect ships in both bundles")
    func commonEffectsShip() {
        for effect in SoundEffect.commonToBothThemes {
            #expect(SoundPlayer.resourceURL(theme: .apple2, effect: effect) != nil,
                "missing Apple2 asset for .\(effect.rawValue)")
            #expect(SoundPlayer.resourceURL(theme: .c64, effect: effect) != nil,
                "missing C64 asset for .\(effect.rawValue)")
        }
    }

    @Test("Apple2 ships goldFinish; the six C64 variants do not exist there")
    func apple2GoldFinishSplit() {
        #expect(SoundPlayer.resourceURL(theme: .apple2, effect: .goldFinish) != nil)
        for effect in Self.c64GoldFinishVariants {
            #expect(SoundPlayer.resourceURL(theme: .apple2, effect: effect) == nil,
                "Apple2 shouldn't ship .\(effect.rawValue) — the C64-only per-level clips")
        }
    }

    @Test("C64 ships goldFinish1..6; the shared Apple2 goldFinish does not exist there")
    func c64GoldFinishSplit() {
        for effect in Self.c64GoldFinishVariants {
            #expect(SoundPlayer.resourceURL(theme: .c64, effect: effect) != nil,
                "missing C64 asset for .\(effect.rawValue)")
        }
        #expect(SoundPlayer.resourceURL(theme: .c64, effect: .goldFinish) == nil)
    }

    @Test("effect raw values match the shipped filenames (no snake_case drift)")
    func rawValuesMatchFilenames() {
        let expected: Set<String> = [
            "born", "dead", "dig", "down", "fall", "getGold", "pass", "trap",
            "goldFinish", "goldFinish1", "goldFinish2", "goldFinish3",
            "goldFinish4", "goldFinish5", "goldFinish6",
            "scoreBell", "scoreCount", "scoreEnding",
        ]
        #expect(Set(SoundEffect.allCases.map(\.rawValue)) == expected)
    }

    @Test("SoundEffect.goldFinish(for:levelIndex:) mirrors the JS selector")
    func goldFinishSelector() {
        // Apple2 always returns the single shared clip regardless of level.
        for levelIndex in 0..<7 {
            #expect(SoundEffect.goldFinish(for: .apple2, levelIndex: levelIndex) == .goldFinish)
        }
        // C64 picks by `((curLevel - 1) % 6) + 1` — our `levelIndex` is the
        // 0-based analog of `curLevel - 1`.
        let expected: [SoundEffect] = [
            .goldFinish1, .goldFinish2, .goldFinish3,
            .goldFinish4, .goldFinish5, .goldFinish6,
        ]
        for i in 0..<12 {
            #expect(SoundEffect.goldFinish(for: .c64, levelIndex: i) == expected[i % 6])
        }
    }

    private static let c64GoldFinishVariants: [SoundEffect] = [
        .goldFinish1, .goldFinish2, .goldFinish3,
        .goldFinish4, .goldFinish5, .goldFinish6,
    ]
}
