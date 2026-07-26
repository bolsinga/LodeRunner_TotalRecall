import Testing

@testable import LodeRunnerCore

@Suite
struct LevelParserTests {
    // MARK: - parseLevelChar (ported from test/level-integrity.test.js)

    private struct LegalCharCase: Sendable {
        let char: Character
        let base: TileType
        let current: TileType
    }

    @Test(
        "parseLevelChar maps each legal tile char to documented base/current",
        arguments: [
            LegalCharCase(char: " ", base: .empty, current: .empty),
            LegalCharCase(char: "#", base: .brick, current: .brick),
            LegalCharCase(char: "@", base: .solid, current: .solid),
            LegalCharCase(char: "H", base: .ladder, current: .ladder),
            LegalCharCase(char: "-", base: .bar, current: .bar),
            LegalCharCase(char: "X", base: .trap, current: .trap),
            LegalCharCase(char: "S", base: .hiddenLadder, current: .empty),
            LegalCharCase(char: "$", base: .gold, current: .empty),
            LegalCharCase(char: "0", base: .empty, current: .guard),
            LegalCharCase(char: "&", base: .empty, current: .runner),
        ]
    )
    private func parseLevelCharMapsLegalChars(_ testCase: LegalCharCase) {
        let result = parseLevelChar(testCase.char)
        #expect(result.base == testCase.base)
        #expect(result.current == testCase.current)
    }

    @Test("parseLevelChar falls back to empty for an unknown character")
    func parseLevelCharUnknownFallsBack() {
        let result = parseLevelChar("?")
        #expect(result.base == .empty)
        #expect(result.current == .empty)
    }

    // MARK: - resolveLevelMap culling (ported from test/level-map-culling.test.js)

    /// Build a blank 28x16 level, then stamp entities at [x,y] positions, matching the JS
    /// test helper `makeLevel`. Always fills the bottom row with bricks so the string looks
    /// valid; culling logic itself doesn't care about geometry.
    private func makeLevel(stamps: [(x: Int, y: Int, ch: Character)]) -> String {
        var cells = Array(repeating: Character(" "), count: LevelGrid.tileCount)
        for stamp in stamps {
            cells[stamp.y * LevelGrid.tilesX + stamp.x] = stamp.ch
        }
        for x in 0..<LevelGrid.tilesX {
            let index = (LevelGrid.tilesY - 1) * LevelGrid.tilesX + x
            if cells[index] == " " {
                cells[index] = "#"
            }
        }
        return String(cells)
    }

    @Test("keeps all guards when raw count == maxGuardCount (5)")
    func keepsAllGuardsAtLimit() {
        var stamps: [(x: Int, y: Int, ch: Character)] = (0..<5).map { (x: $0, y: 0, ch: "0") }
        stamps.append((x: 10, y: 0, ch: "&"))
        let result = resolveLevelMap(makeLevel(stamps: stamps))

        #expect(result.rawGuardCount == 5)
        #expect(result.guardCount == 5)
        #expect(result.culledGuardCount == 0)
        #expect(result.guards.count == 5)
        for point in result.guards {
            #expect(result.slots[point.x][point.y].current == .guard)
        }
    }

    @Test("culls the first excess guard in row-major order (6 guards, max=5)")
    func cullsFirstExcessGuard() {
        // Six guards at (0..5, y=0); first in scan order is (0,0).
        var stamps: [(x: Int, y: Int, ch: Character)] = (0..<6).map { (x: $0, y: 0, ch: "0") }
        stamps.append((x: 10, y: 0, ch: "&"))
        let result = resolveLevelMap(makeLevel(stamps: stamps))

        #expect(result.rawGuardCount == 6)
        #expect(result.culledGuardCount == 1)
        #expect(result.guardCount == 5)

        let demoted = result.slots[0][0]
        #expect(demoted.base == .empty)
        #expect(demoted.current == .empty)

        #expect(result.guards == (1...5).map { GridPoint(x: $0, y: 0) })
        for point in result.guards {
            #expect(result.slots[point.x][point.y].current == .guard)
        }
    }

    @Test("first '&' wins; a later '&' is demoted to empty current-tile")
    func firstRunnerWins() {
        let result = resolveLevelMap(
            makeLevel(stamps: [
                (x: 3, y: 2, ch: "&"),
                (x: 7, y: 5, ch: "&"),
                (x: 1, y: 0, ch: "0"),
            ]))

        #expect(result.runnerCount == 1)
        #expect(result.culledRunnerCount == 1)
        #expect(result.runner == GridPoint(x: 3, y: 2))
        #expect(result.slots[3][2].current == .runner)

        #expect(result.slots[7][5].current == .empty)
    }

    @Test("culling order follows row-major scan (earlier row culled before later)")
    func cullingFollowsRowMajorOrder() {
        // 6 guards: five on row 0, one on row 1 - with max=5, only (0,0) culled.
        var stamps: [(x: Int, y: Int, ch: Character)] = (0..<5).map { (x: $0, y: 0, ch: "0") }
        stamps.append((x: 0, y: 1, ch: "0"))
        stamps.append((x: 10, y: 2, ch: "&"))
        let result = resolveLevelMap(makeLevel(stamps: stamps))

        #expect(result.culledGuardCount == 1)
        #expect(result.slots[0][0].current == .empty)
        #expect(result.slots[0][1].current == .guard)
        #expect(result.guards.contains(GridPoint(x: 0, y: 1)))
    }

    @Test("a shorter-than-expected levelMap reads as space-padded instead of trapping")
    func shortLevelMapPadsInsteadOfTrapping() {
        let result = resolveLevelMap(String(repeating: "#", count: 10))
        #expect(result.slots[0][0].current == .brick)
        #expect(result.slots[LevelGrid.tilesX - 1][LevelGrid.tilesY - 1].current == .empty)
    }

    @Test("a longer-than-expected levelMap reads as truncated instead of trapping")
    func longLevelMapTruncatesInsteadOfTrapping() {
        let result = resolveLevelMap(String(repeating: "#", count: LevelGrid.tileCount + 100))
        #expect(result.slots[0][0].current == .brick)
        #expect(result.slots[LevelGrid.tilesX - 1][LevelGrid.tilesY - 1].current == .brick)
    }

    // MARK: - resolveLevelMap against real shipped levels
    //
    // Hand-copied (verbatim, programmatically extracted, not retyped) from
    // lodeRunner.v.classic.js, levels 1, 8, 80 and 113. Not a general level-pack loader -
    // see the `lr-leveltool` executable target for that.

    // `static`, not just `private`: `@Test(arguments:)` below references these
    // without `self`, the same restriction as a default parameter expression.
    private static let classicLevel1 =
        "                  S             $             S         #######H#######   S                H----------S    $           H    ##H   #######H##       H    ##H          H       0 H    ##H       $0 H  ##H#####    ########H#######  H                 H         H           0     H       #########H##########H                H          H              $ H----------H   $       H######         #######H    H         &  $         H############################"

    private static let classicLevel8 =
        "           S    S                      S    S              $ 0   H#S    S#H   0 $   H#####H--H#S    S#H--H#####HH#   #H   #S    S#   H#   #HH#   #H   #S    S#   H#   #HH# $ #H   #S    S#   H# $ #HH#####H   #S    S#   H#####HH#   #H   #S    S#   H#   #HH#   #H---#H####H#---H#   #HH#   #   H#H    H#H   #   #HH#0$ #   H#H  $0H#H   # $0#HH##X##   H#@@@@@@#H   ##X##HH     X  H        H  X     HH      X0H    &   H X      H############################"

    private static let classicLevel80 =
        "      -----------$          @@@@@@   ##     #@@@@@@#H   @------  $$     #      #H   @H      ###X    # 0   $#H   @H$$    $  $    ######X#H   @@@@H $ #X##          0HH       H       $   $   0-- H       H     #@@@@@@@@@#-- H       H$0 $ #0     $  #   H       H####H######X####   H        #  #H              H        #  #H              H        #$$#H              H        ##X#H              H            H    0  &      H   ###@@@@@###@@@@###@@@@###@@@"

    private static let classicLevel113 =
        "S                           S                           ###############H## $      &     0     0    H##X#@@@@@@@H$  HHHHHHHHHHH H           H#$ H  HHHHHHHH H $ $ H#####H #$H  H        H #S# ######H  #H  H$ $ $ $  H #        H   #$ H#X#X#X# H     0$ $ $H    # H         H    #H####H      H H H H  H      H           H         H     H 0          H H H   H      #####H        H H H   H          H    0    $S#   H   0       H############################"

    @Test("classic level 1: gold/runner/guard counts and runner position")
    func classicLevel1Counts() {
        let result = resolveLevelMap(Self.classicLevel1)
        #expect(result.goldCount == 6)
        #expect(result.runnerCount == 1)
        #expect(result.guardCount == 3)
        #expect(result.runner == GridPoint(x: 14, y: 14))
    }

    private struct SixGuardCase: Sendable {
        let name: String
        let level: String
    }

    @Test(
        "shipped classic levels with 6 guards: cull 1 under maxGuardCount",
        arguments: [
            SixGuardCase(name: "classic 8", level: classicLevel8),
            SixGuardCase(name: "classic 80", level: classicLevel80),
            SixGuardCase(name: "classic 113", level: classicLevel113),
        ]
    )
    private func sixGuardLevelsCullOne(_ testCase: SixGuardCase) {
        let result = resolveLevelMap(testCase.level)
        #expect(result.rawGuardCount == 6)
        #expect(result.guardCount == 5)
        #expect(result.culledGuardCount == 1)
        #expect(result.runnerCount == 1)
    }

    @Test("classic level 8: first culled guard position is stable")
    func classicLevel8FirstCulledGuardPosition() {
        let result = resolveLevelMap(Self.classicLevel8)
        // A culled guard is a '0' in the raw source whose resolved slot didn't make it into
        // `result.guards` - `LevelSlot` itself no longer remembers the original character.
        let sourceChars = Array(Self.classicLevel8)
        var firstCulled: GridPoint?
        outer: for y in 0..<LevelGrid.tilesY {
            for x in 0..<LevelGrid.tilesX {
                guard sourceChars[y * LevelGrid.tilesX + x] == "0" else { continue }
                if !result.guards.contains(GridPoint(x: x, y: y)) {
                    firstCulled = GridPoint(x: x, y: y)
                    break outer
                }
            }
        }
        // Snapshot - update only if intentional culling-order change.
        #expect(firstCulled == GridPoint(x: 5, y: 2))
    }
}
