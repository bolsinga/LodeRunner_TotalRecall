import Testing

@testable import LodeRunner

@Suite
@MainActor
struct GuardSpriteSheetTests {
    @Test("Guards without gold render with the default guard sheet")
    func emptyHandedUsesGuardSheet() {
        #expect(GuardSpriteView.sheet(forHasGold: 0).assetName == "guard")
    }

    @Test("Guards carrying gold render with the redhat sheet")
    func carryingGoldUsesRedhatSheet() {
        // Any positive `hasGold` value swaps the sheet — ports the JS's
        // `if(redhatMode) guard.sprite.spriteSheet = redhatData` at
        // `guard.js:378`, gated on `hasGold > 0` per `guard.js:355-364`.
        for hasGold in [1, 12, 25, 37] {
            #expect(GuardSpriteView.sheet(forHasGold: hasGold).assetName == "redhat")
        }
    }
}
