import Testing

@testable import LodeRunner

@Suite
struct SoundEffectTests {
    @Test("every effect ships an mp3 in the Apple2 bundle")
    func apple2AssetsShip() {
        for effect in SoundEffect.allCases {
            #expect(SoundPlayer.resourceURL(theme: .apple2, effect: effect) != nil,
                "missing Apple2 asset for .\(effect.rawValue)")
        }
    }

    @Test("every effect ships an mp3 in the C64 bundle")
    func c64AssetsShip() {
        for effect in SoundEffect.allCases {
            #expect(SoundPlayer.resourceURL(theme: .c64, effect: effect) != nil,
                "missing C64 asset for .\(effect.rawValue)")
        }
    }

    @Test("effect raw values match the shipped filenames (no snake_case drift)")
    func rawValuesMatchFilenames() {
        let expected: Set<String> = [
            "born", "dead", "dig", "down", "fall", "getGold", "pass", "trap",
        ]
        #expect(Set(SoundEffect.allCases.map(\.rawValue)) == expected)
    }
}
