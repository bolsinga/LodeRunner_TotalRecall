/// Grid dimensions, ported from `lodeRunner.def.js`'s `NO_OF_TILES_X`/`NO_OF_TILES_Y`.
public enum LevelGrid {
    public static let tilesX = 28
    public static let tilesY = 16
    public static let tileCount = tilesX * tilesY  // 448
}

/// Ported from `lodeRunner.levelParse.js`'s `LEGAL_LEVEL_CHARS`.
public let legalLevelChars = " #@H-XS$0&"

/// The JS supports two legacy AI versions (1/2, `MAX_OLD_GUARD=6`) alongside the current
/// one (`AI_VERSION = 4`, `MAX_NEW_GUARD=5`). This port only ever targets AI version 4
/// behavior, so there is a single guard limit rather than a version-selected one.
public let maxGuardCount = 5

public struct LevelParseResult: Equatable, Codable, Sendable {
    public var slots: [[LevelSlot]]  // [x][y], 28 x 16
    public var goldCount: Int
    public var runnerCount: Int
    public var guardCount: Int
    public var rawGuardCount: Int
    public var culledGuardCount: Int
    public var culledRunnerCount: Int
    public var runner: GridPoint?
    public var guards: [GridPoint]

    public init(
        slots: [[LevelSlot]], goldCount: Int, runnerCount: Int, guardCount: Int,
        rawGuardCount: Int, culledGuardCount: Int, culledRunnerCount: Int,
        runner: GridPoint?, guards: [GridPoint]
    ) {
        self.slots = slots
        self.goldCount = goldCount
        self.runnerCount = runnerCount
        self.guardCount = guardCount
        self.rawGuardCount = rawGuardCount
        self.culledGuardCount = culledGuardCount
        self.culledRunnerCount = culledRunnerCount
        self.runner = runner
        self.guards = guards
    }
}

/// Map one level character to base/current tile types.
/// Ported from `parseLevelChar` in `lodeRunner.levelParse.js:19-44` (dropping the JS's
/// `kind` field: it's a deterministic function of `base`/`current` and adds no
/// information a caller can't already get from those two). Unknown characters follow the
/// original's default-to-empty fallback.
public func parseLevelChar(_ char: Character) -> (base: TileType, current: TileType) {
    switch char {
    case "#":  // Normal Brick
        return (.brick, .brick)
    case "@":  // Solid Brick
        return (.solid, .solid)
    case "H":  // Ladder
        return (.ladder, .ladder)
    case "-":  // Line of rope
        return (.bar, .bar)
    case "X":  // False brick
        return (.trap, .trap)
    case "S":  // Ladder appears at end of level
        return (.hiddenLadder, .empty)
    case "$":  // Gold chest
        return (.gold, .empty)
    case "0":  // Guard
        return (.empty, .guard)
    case "&":  // Player
        return (.empty, .runner)
    default:  // " " and any unknown character
        return (.empty, .empty)
    }
}

/// Resolve a flat 448-character level string the same way `buildLevelMap` does for
/// base/current tiles, including guard culling (first excess guards in row-major scan
/// order are demoted; the last `maxGuardCount` survive) and first-`&`-wins runner
/// demotion. Ported from `resolveLevelMap` in `lodeRunner.levelParse.js:72-151`, with the
/// JS's `maxGuardLimit` parameter dropped in favor of the fixed `maxGuardCount`.
public func resolveLevelMap(_ levelMap: String) -> LevelParseResult {
    resolveLevelMap(levelMap, maxGuardLimit: maxGuardCount)
}

/// Raw inventory parse: no guard culling at all (still demotes extra runners), mirroring
/// the JS's `parseLevelMap`/`Number.POSITIVE_INFINITY` variant. Used for editor/inventory
/// introspection where every declared guard should be counted.
public func parseLevelMap(_ levelMap: String) -> LevelParseResult {
    resolveLevelMap(levelMap, maxGuardLimit: .max)
}

private func resolveLevelMap(_ levelMap: String, maxGuardLimit: Int) -> LevelParseResult {
    precondition(
        levelMap.count == LevelGrid.tileCount,
        "levelMap must be exactly \(LevelGrid.tileCount) characters, got \(levelMap.count)")

    let chars = Array(levelMap)

    // Pass 1: count all '0' characters (mirrors resolveLevelMap's first loop).
    var mapGuardCount = chars.reduce(into: 0) { count, char in
        if char == "0" { count += 1 }
    }
    let rawGuardCount = mapGuardCount

    // Pass 2: row-major (y outer, x inner) resolve, applying culling/demotion.
    var slots = Array(
        repeating: Array(
            repeating: LevelSlot(base: .empty, current: .empty),
            count: LevelGrid.tilesY),
        count: LevelGrid.tilesX)

    var goldCount = 0
    var runnerCount = 0
    var guardCount = 0
    var culledGuardCount = 0
    var culledRunnerCount = 0
    var runnerPlaced = false
    var runner: GridPoint?
    var guards: [GridPoint] = []

    var index = 0
    for y in 0..<LevelGrid.tilesY {
        for x in 0..<LevelGrid.tilesX {
            let (base, current) = parseLevelChar(chars[index])
            index += 1
            var resolvedCurrent = current

            if current == .guard {
                mapGuardCount -= 1
                if mapGuardCount >= maxGuardLimit {
                    resolvedCurrent = .empty  // demoted - no spawn
                    culledGuardCount += 1
                } else {
                    guardCount += 1
                    guards.append(GridPoint(x: x, y: y))
                }
            } else if current == .runner {
                if runnerPlaced {
                    resolvedCurrent = .empty  // demoted - no spawn
                    culledRunnerCount += 1
                } else {
                    runnerPlaced = true
                    runnerCount = 1
                    runner = GridPoint(x: x, y: y)
                }
            } else if base == .gold {
                goldCount += 1
            }

            slots[x][y] = LevelSlot(base: base, current: resolvedCurrent)
        }
    }

    assert(mapGuardCount == 0, "mapGuardCount design error")

    return LevelParseResult(
        slots: slots,
        goldCount: goldCount,
        runnerCount: runnerCount,
        guardCount: guardCount,
        rawGuardCount: rawGuardCount,
        culledGuardCount: culledGuardCount,
        culledRunnerCount: culledRunnerCount,
        runner: runner,
        guards: guards)
}
