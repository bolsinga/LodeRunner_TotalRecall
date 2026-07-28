import Testing

@testable import LodeRunner

@Suite
struct LevelSlotTests {
    @Test("displayTile returns .gold when base is .gold (current is .empty until picked up)")
    func displayTileGoldFromBase() {
        let slot = LevelSlot(base: .gold, current: .empty)
        #expect(slot.displayTile == .gold)
    }

    @Test("displayTile returns .current for the ordinary base==current tiles")
    func displayTileMirrorsCurrentForNonGold() {
        let cases: [(base: TileType, current: TileType, expected: TileType)] = [
            (.empty, .empty, .empty),
            (.brick, .brick, .brick),
            (.solid, .solid, .solid),
            (.ladder, .ladder, .ladder),
            (.bar, .bar, .bar),
            (.trap, .trap, .trap),
        ]
        for c in cases {
            #expect(LevelSlot(base: c.base, current: c.current).displayTile == c.expected)
        }
    }

    @Test("displayTile hides a hiddenLadder while its current is still .empty")
    func displayTileHiddenLadderStaysHidden() {
        let slot = LevelSlot(base: .hiddenLadder, current: .empty)
        #expect(slot.displayTile == .empty)
    }

    @Test("displayTile shows entity in .current when base is .empty")
    func displayTileEntityFromCurrent() {
        #expect(LevelSlot(base: .empty, current: .runner).displayTile == .runner)
        #expect(LevelSlot(base: .empty, current: .guard).displayTile == .guard)
    }

    @Test("displayTile prefers gold when an entity is standing on a gold cell")
    func displayTileGoldWinsUnderEntity() {
        #expect(LevelSlot(base: .gold, current: .runner).displayTile == .gold)
        #expect(LevelSlot(base: .gold, current: .guard).displayTile == .gold)
    }
}
