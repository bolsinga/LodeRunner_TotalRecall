import Testing

@testable import LodeRunner

@Suite
struct TileAssetNameTests {
    @Test(".hiddenLadder renders using the empty asset, not the visible hladder graphic")
    func hiddenLadderRendersAsEmpty() {
        // Regression: the port's `hladder` PNG is a visible white ladder authored
        // for `lodeRunner.edit.js:31` (the editor's tile palette). At gameplay
        // time the JS uses the ladder bitmap with `alpha:0` instead
        // (`buildLevelMap:571-572`). If a runner/guard sprite is drawn over a
        // hidden-ladder cell, `entityLessTiles` returns `slot.base` (bypassing
        // `displayTile`), and the visible white ladder used to bleed through
        // the sprite's transparent frames — the "flash of ladder behind a
        // reborn guard" reported on revenge level 1.
        #expect(TileType.hiddenLadder.assetName == "empty")
    }

    @Test(".ladder still maps to the visible ladder asset — the `showHideLaddr` reveal path")
    func ladderStillRendersAsLadder() {
        // Sanity check that the fix doesn't accidentally invisible-ify real
        // ladders. `showHideLaddr` converts `.hiddenLadder → .ladder` in
        // `RunnerSimulation.swift:462-472` (JS `runner.js:357-372`) at
        // `goldComplete`; from that point on the cell should visibly show a
        // ladder.
        #expect(TileType.ladder.assetName == "ladder")
    }

    @Test(".trap renders as brick, not as the distinctive editor `trap` graphic")
    func trapRendersAsBrick() {
        // Regression: the port's `trap.png` is a distinctive false-brick
        // authored for `lodeRunner.edit.js` (the editor palette). At
        // gameplay time the JS picks the brick bitmap for `TRAP_T` at
        // `themeScreen.js:59-60`; the JS only reveals a distinct trap
        // look transiently when the runner is falling *through* it, via
        // a temporary `alpha:0.5` at `runner.js:299`. Rendering trap as
        // its editor graphic leaks the trap positions to the player
        // before they've stepped on the cell — the "I can see the fall-
        // through bricks on classic level 2" report.
        #expect(TileType.trap.assetName == "brick")
    }

    @Test(".brick still maps to the visible brick asset")
    func brickStillRendersAsBrick() {
        // Sanity check that the trap-as-brick collapse doesn't disturb
        // real bricks — they need to stay solid-looking regardless.
        #expect(TileType.brick.assetName == "brick")
    }
}
