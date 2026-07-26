import Foundation
import Testing

@testable import LodeRunnerCore

/// Build a blank 28x16 level, then stamp entities/terrain at [x,y] positions, matching
/// phase 1's `makeLevel` test helper. Always fills the bottom row with bricks so the
/// string looks valid.
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

@Test("initial state matches the level's runner spawn")
func initialStateMatchesSpawn() {
    let level = resolveLevelMap(
        makeLevel(stamps: [
            (x: 5, y: 10, ch: "&"),
            (x: 8, y: 10, ch: "$"),
            (x: 9, y: 10, ch: "$"),
        ]))
    let sim = RunnerSimulation(level: level)

    #expect(sim.runner.position == GridPoint(x: 5, y: 10))
    #expect(sim.runner.xOffset == 0)
    #expect(sim.runner.yOffset == 0)
    #expect(sim.runner.action == .stop)
    #expect(sim.phase == .playing)
    #expect(sim.goldRemaining == level.goldCount)
    #expect(sim.goldRemaining == 2)
    #expect(sim.goldComplete == false)
    #expect(sim.digState == nil)
    #expect(sim.fillStates.isEmpty)
}

@Test("walking right on open floor: 3 ticks crosses one tile boundary")
func walkingRightCrossesTileBoundary() {
    let level = resolveLevelMap(makeLevel(stamps: [(x: 5, y: 14, ch: "&")]))
    var sim = RunnerSimulation(level: level)

    sim.tick(.right)
    #expect(sim.runner.xOffset == 8)
    #expect(sim.runner.position.x == 5)

    sim.tick(.right)
    #expect(sim.runner.xOffset == 16)
    #expect(sim.runner.position.x == 5)

    sim.tick(.right)
    #expect(sim.runner.position.x == 6)
    #expect(sim.runner.xOffset == -16)
    #expect(sim.slots[5][14].current == .empty)
    #expect(sim.slots[6][14].current == .runner)
}

@Test("blocked by a wall: offset stays clamped at 0, action resolves to .stop")
func blockedByWallStaysClamped() {
    let level = resolveLevelMap(
        makeLevel(stamps: [
            (x: 5, y: 14, ch: "&"),
            (x: 6, y: 14, ch: "#"),
        ]))
    var sim = RunnerSimulation(level: level)

    for _ in 0..<3 {
        sim.tick(.right)
        #expect(sim.runner.xOffset == 0)
        #expect(sim.runner.position.x == 5)
        #expect(sim.runner.action == .stop)
    }
}

@Test("falling: lands on solid ground one tile below")
func fallingLandsOnFloor() {
    let level = resolveLevelMap(
        makeLevel(stamps: [
            (x: 5, y: 10, ch: "&"),
            (x: 5, y: 12, ch: "#"),
        ]))
    var sim = RunnerSimulation(level: level)

    for _ in 0..<5 {
        sim.tick(.stop)
    }
    #expect(sim.runner.position == GridPoint(x: 5, y: 11))
    #expect(sim.runner.yOffset == 0)
    #expect(sim.runner.action == .fall)

    sim.tick(.stop)
    #expect(sim.runner.position == GridPoint(x: 5, y: 11))
    #expect(sim.runner.yOffset == 0)
}

@Test("walking onto a ladder column, then climbing up one tile")
func walkOntoLadderThenClimb() {
    let level = resolveLevelMap(
        makeLevel(stamps: [
            (x: 4, y: 10, ch: "&"),
            (x: 4, y: 11, ch: "#"),
            (x: 5, y: 5, ch: "H"),
            (x: 5, y: 6, ch: "H"),
            (x: 5, y: 7, ch: "H"),
            (x: 5, y: 8, ch: "H"),
            (x: 5, y: 9, ch: "H"),
            (x: 5, y: 10, ch: "H"),
            (x: 5, y: 11, ch: "H"),
        ]))
    var sim = RunnerSimulation(level: level)

    for _ in 0..<3 { sim.tick(.right) }
    #expect(sim.runner.position == GridPoint(x: 5, y: 10))
    #expect(sim.runner.xOffset == -16)
    #expect(sim.slots[5][10].base == .ladder)

    for _ in 0..<3 { sim.tick(.up) }
    #expect(sim.runner.position == GridPoint(x: 5, y: 9))
    #expect(sim.runner.xOffset == 0)
    #expect(sim.runner.yOffset == 17)
    #expect(sim.runner.action == .up)
    #expect(sim.slots[5][10].current == .ladder)
    #expect(sim.slots[5][9].current == .runner)
}

@Test("falling onto a bar transitions to hanging, then drop-through on down")
func barHangAndDrop() {
    let level = resolveLevelMap(
        makeLevel(stamps: [
            (x: 5, y: 8, ch: "&"),
            (x: 5, y: 9, ch: "-"),
        ]))
    var sim = RunnerSimulation(level: level)

    for _ in 0..<5 { sim.tick(.stop) }
    #expect(sim.runner.position == GridPoint(x: 5, y: 9))
    #expect(sim.runner.yOffset == 0)
    #expect(sim.runner.action == .fallBar)

    sim.tick(.down)
    #expect(sim.runner.action == .fall)
    #expect(sim.runner.yOffset == 9)
    #expect(sim.runner.position == GridPoint(x: 5, y: 9))
}

@Test("picking up the last gold sets goldComplete and reveals hidden ladders")
func goldPickupRevealsHiddenLadders() {
    let level = resolveLevelMap(
        makeLevel(stamps: [
            (x: 5, y: 14, ch: "&"),
            (x: 6, y: 14, ch: "$"),
            (x: 10, y: 5, ch: "S"),
        ]))
    var sim = RunnerSimulation(level: level)
    #expect(sim.goldRemaining == 1)

    for _ in 0..<5 { sim.tick(.right) }

    #expect(sim.goldRemaining == 0)
    #expect(sim.goldComplete == true)
    #expect(sim.slots[6][14].base == .empty)
    #expect(sim.slots[10][5].base == .ladder)
    #expect(sim.slots[10][5].current == .ladder)
}

@Test("reaching row 0 centered with all gold collected wins")
func reachingTopWithAllGoldWins() {
    let level = resolveLevelMap(
        makeLevel(stamps: [
            (x: 3, y: 1, ch: "&"),
            (x: 4, y: 1, ch: "$"),
            (x: 5, y: 0, ch: "H"),
            (x: 5, y: 1, ch: "H"),
            (x: 3, y: 2, ch: "#"),
            (x: 4, y: 2, ch: "#"),
        ]))
    var sim = RunnerSimulation(level: level)

    for _ in 0..<8 { sim.tick(.right) }
    #expect(sim.goldComplete == true)
    #expect(sim.runner.position == GridPoint(x: 5, y: 1))

    for _ in 0..<5 { sim.tick(.up) }
    #expect(sim.runner.position == GridPoint(x: 5, y: 0))
    #expect(sim.runner.yOffset == 0)
    #expect(sim.phase == .playing)

    sim.tick(.stop)
    #expect(sim.phase == .finished)
}

@Test("digging: completes after 11 ticks, hole refills after 186 more")
func diggingHappyPath() {
    let level = resolveLevelMap(
        makeLevel(stamps: [
            (x: 5, y: 10, ch: "&"),
            (x: 4, y: 11, ch: "#"),
            (x: 5, y: 11, ch: "#"),
        ]))
    var sim = RunnerSimulation(level: level)

    sim.tick(.digLeft)
    #expect(sim.digState != nil)
    #expect(sim.digState?.pos == GridPoint(x: 4, y: 10))
    #expect(sim.runner.action == .digLeft)

    for _ in 0..<11 { sim.tick(.stop) }
    #expect(sim.digState == nil)
    #expect(sim.slots[4][11].current == .empty)
    #expect(sim.slots[4][11].base == .brick)
    #expect(sim.fillStates.count == 1)

    for _ in 0..<186 { sim.tick(.stop) }
    #expect(sim.fillStates.isEmpty)
    #expect(sim.slots[4][11].current == .brick)
    #expect(sim.phase == .playing)
}

@Test("digging + burial: standing in a hole when it refills is fatal")
func diggingBurialDeath() {
    let level = resolveLevelMap(
        makeLevel(stamps: [
            (x: 5, y: 10, ch: "&"),
            (x: 4, y: 11, ch: "#"),
            (x: 5, y: 11, ch: "#"),
            (x: 4, y: 12, ch: "#"),
        ]))
    var sim = RunnerSimulation(level: level)

    sim.tick(.digLeft)
    for _ in 0..<11 { sim.tick(.stop) }  // dig completes
    for _ in 0..<3 { sim.tick(.left) }  // cross into column 4, over the open hole
    #expect(sim.runner.position == GridPoint(x: 4, y: 10))

    for _ in 0..<183 { sim.tick(.stop) }  // fall into the hole, rest, then fillComplete buries it
    #expect(sim.phase == .dead)
    #expect(sim.slots[4][11].current == .brick)
}

@Test("ok2Dig rejects a non-brick target, an occupied column, and a gold-based target")
func ok2DigRejections() {
    // (a) diagonal target isn't a brick (it's empty)
    let notBrick = resolveLevelMap(
        makeLevel(stamps: [
            (x: 5, y: 10, ch: "&"),
            (x: 5, y: 11, ch: "#"),
        ]))
    var sim1 = RunnerSimulation(level: notBrick)
    sim1.tick(.digLeft)
    #expect(sim1.digState == nil)
    #expect(sim1.runner.action == .stop)

    // (b) target column is occupied (a brick sits at [x-1][y])
    let occupied = resolveLevelMap(
        makeLevel(stamps: [
            (x: 5, y: 10, ch: "&"),
            (x: 4, y: 10, ch: "#"),
            (x: 4, y: 11, ch: "#"),
            (x: 5, y: 11, ch: "#"),
        ]))
    var sim2 = RunnerSimulation(level: occupied)
    sim2.tick(.digLeft)
    #expect(sim2.digState == nil)

    // (c) target column's base is gold
    let goldTarget = resolveLevelMap(
        makeLevel(stamps: [
            (x: 5, y: 10, ch: "&"),
            (x: 4, y: 10, ch: "$"),
            (x: 4, y: 11, ch: "#"),
            (x: 5, y: 11, ch: "#"),
        ]))
    var sim3 = RunnerSimulation(level: goldTarget)
    sim3.tick(.digLeft)
    #expect(sim3.digState == nil)
}

@Test("RunnerSimulation round-trips through JSON")
func codableRoundTrip() throws {
    let level = resolveLevelMap(
        makeLevel(stamps: [
            (x: 5, y: 10, ch: "&"),
            (x: 4, y: 11, ch: "#"),
            (x: 5, y: 11, ch: "#"),
        ]))
    var sim = RunnerSimulation(level: level)
    sim.tick(.digLeft)
    for _ in 0..<5 { sim.tick(.stop) }

    let data = try JSONEncoder().encode(sim)
    let decoded = try JSONDecoder().decode(RunnerSimulation.self, from: data)
    #expect(decoded == sim)
}
