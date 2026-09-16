import Testing

@testable import LodeRunner

@Suite
@MainActor
struct GuardSpriteSheetTests {
    @Test("Guards without gold render with the default guard sheet, regardless of the setting")
    func emptyHandedUsesGuardSheet() {
        #expect(GuardSpriteView.sheet(forHasGold: 0, redhatModeEnabled: true).assetName == "guard")
        #expect(GuardSpriteView.sheet(forHasGold: 0, redhatModeEnabled: false).assetName == "guard")
    }

    @Test("Guards carrying gold render with the redhat sheet when the mode is on")
    func carryingGoldUsesRedhatSheetWhenEnabled() {
        // Any positive `hasGold` value swaps the sheet — ports the JS's
        // `if(redhatMode) guard.sprite.spriteSheet = redhatData` at
        // `guard.js:378`, gated on `hasGold > 0` per `guard.js:355-364`.
        for hasGold in [1, 12, 25, 37] {
            #expect(
                GuardSpriteView.sheet(forHasGold: hasGold, redhatModeEnabled: true).assetName
                    == "redhat")
        }
    }

    @Test("Guards carrying gold still render as a plain guard when the mode is off")
    func carryingGoldUsesGuardSheetWhenDisabled() {
        for hasGold in [1, 12, 25, 37] {
            #expect(
                GuardSpriteView.sheet(forHasGold: hasGold, redhatModeEnabled: false).assetName
                    == "guard")
        }
    }
}
