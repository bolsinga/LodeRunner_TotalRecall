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
/// information a caller can't already get from those two). Kept as a public tuple
/// entry point for parity with the JS API and for its dedicated tests; the actual
/// mapping lives on `TileType.levelSlot`.
public func parseLevelChar(_ char: Character) -> (base: TileType, current: TileType) {
    let slot = TileType(levelChar: char).levelSlot
    return (slot.base, slot.current)
}

/// Resolve a flat 448-character level string the same way `buildLevelMap` does for
/// base/current tiles, including guard culling (first excess guards in row-major scan
/// order are demoted; the last `maxGuardCount` survive) and first-`&`-wins runner
/// demotion. Ported from `resolveLevelMap` in `lodeRunner.levelParse.js:72-151`, with the
/// JS's `maxGuardLimit` parameter dropped in favor of the fixed `maxGuardCount`.
public func resolveLevelMap(_ levelMap: String) -> LevelParseResult {
    resolveLevelMap(tiles(from: levelMap), maxGuardLimit: maxGuardCount)
}

/// Raw inventory parse: no guard culling at all (still demotes extra runners), mirroring
/// the JS's `parseLevelMap`/`Number.POSITIVE_INFINITY` variant. Used for editor/inventory
/// introspection where every declared guard should be counted.
public func parseLevelMap(_ levelMap: String) -> LevelParseResult {
    resolveLevelMap(tiles(from: levelMap), maxGuardLimit: .max)
}

/// Tile-native form of `resolveLevelMap`, used by `makeLevel(stamps:)` so previews
/// and simulation/session tests can build a `LevelParseResult` without ever
/// touching a raw level string. Same culling / first-runner-wins semantics.
func resolveLevelMap(tiles: [TileType]) -> LevelParseResult {
    resolveLevelMap(tiles, maxGuardLimit: maxGuardCount)
}

/// Convert a level string to its row-major tile array, padding to
/// `LevelGrid.tileCount` with `.empty` (a shorter map reads as implicitly space-
/// padded; a longer one is truncated).
private func tiles(from levelMap: String) -> [TileType] {
    let chars = Array(levelMap)
    return (0..<LevelGrid.tileCount).map { index in
        index < chars.count ? TileType(levelChar: chars[index]) : .empty
    }
}

private func resolveLevelMap(_ tiles: [TileType], maxGuardLimit: Int) -> LevelParseResult {
    func tile(at index: Int) -> TileType {
        index < tiles.count ? tiles[index] : .empty
    }

    // Pass 1: count all guards (mirrors resolveLevelMap's first loop).
    var mapGuardCount = (0..<LevelGrid.tileCount).reduce(into: 0) { count, index in
        if tile(at: index) == .guard { count += 1 }
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
            let slot = tile(at: index).levelSlot
            index += 1
            var resolvedCurrent = slot.current

            if slot.current == .guard {
                mapGuardCount -= 1
                if mapGuardCount >= maxGuardLimit {
                    resolvedCurrent = .empty  // demoted - no spawn
                    culledGuardCount += 1
                } else {
                    guardCount += 1
                    guards.append(GridPoint(x: x, y: y))
                }
            } else if slot.current == .runner {
                if runnerPlaced {
                    resolvedCurrent = .empty  // demoted - no spawn
                    culledRunnerCount += 1
                } else {
                    runnerPlaced = true
                    runnerCount = 1
                    runner = GridPoint(x: x, y: y)
                }
            } else if slot.base == .gold {
                goldCount += 1
            }

            slots[x][y] = LevelSlot(base: slot.base, current: resolvedCurrent)
        }
    }

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
