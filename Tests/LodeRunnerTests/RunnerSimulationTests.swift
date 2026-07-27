import Foundation
import Testing

@testable import LodeRunner

@Suite
struct RunnerSimulationTests {
    @Test("a level with no runner spawn throws noRunnerSpawn")
    func noRunnerSpawnThrows() {
        let level = makeLevel(stamps: [] as [(x: Int, y: Int, tile: TileType)])
        #expect(throws: RunnerSimulationError.noRunnerSpawn) {
            try RunnerSimulation(level: level)
        }
    }

    @Test("initial state matches the level's runner spawn")
    func initialStateMatchesSpawn() throws {
        let level = makeLevel(stamps: [
            (x: 5, y: 10, tile: .runner),
            (x: 8, y: 10, tile: .gold),
            (x: 9, y: 10, tile: .gold),
        ])
        let sim = try RunnerSimulation(level: level)

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
        #expect(sim.score == 0)
    }

    @Test("walking right on open floor: 3 ticks crosses one tile boundary")
    func walkingRightCrossesTileBoundary() throws {
        let level = makeLevel(stamps: [(x: 5, y: 14, tile: .runner)])
        var sim = try RunnerSimulation(level: level)

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
    func blockedByWallStaysClamped() throws {
        let level = makeLevel(stamps: [
            (x: 5, y: 14, tile: .runner),
            (x: 6, y: 14, tile: .brick),
        ])
        var sim = try RunnerSimulation(level: level)

        for _ in 0..<3 {
            sim.tick(.right)
            #expect(sim.runner.xOffset == 0)
            #expect(sim.runner.position.x == 5)
            #expect(sim.runner.action == .stop)
        }
    }

    @Test("falling: lands on solid ground one tile below")
    func fallingLandsOnFloor() throws {
        let level = makeLevel(stamps: [
            (x: 5, y: 10, tile: .runner),
            (x: 5, y: 12, tile: .brick),
        ])
        var sim = try RunnerSimulation(level: level)

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
    func walkOntoLadderThenClimb() throws {
        let level = makeLevel(stamps: [
            (x: 4, y: 10, tile: .runner),
            (x: 4, y: 11, tile: .brick),
            (x: 5, y: 5, tile: .ladder),
            (x: 5, y: 6, tile: .ladder),
            (x: 5, y: 7, tile: .ladder),
            (x: 5, y: 8, tile: .ladder),
            (x: 5, y: 9, tile: .ladder),
            (x: 5, y: 10, tile: .ladder),
            (x: 5, y: 11, tile: .ladder),
        ])
        var sim = try RunnerSimulation(level: level)

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
    func barHangAndDrop() throws {
        let level = makeLevel(stamps: [
            (x: 5, y: 8, tile: .runner),
            (x: 5, y: 9, tile: .bar),
        ])
        var sim = try RunnerSimulation(level: level)

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
    func goldPickupRevealsHiddenLadders() throws {
        let level = makeLevel(stamps: [
            (x: 5, y: 14, tile: .runner),
            (x: 6, y: 14, tile: .gold),
            (x: 10, y: 5, tile: .hiddenLadder),
        ])
        var sim = try RunnerSimulation(level: level)
        #expect(sim.goldRemaining == 1)

        for _ in 0..<5 { sim.tick(.right) }

        #expect(sim.goldRemaining == 0)
        #expect(sim.goldComplete == true)
        #expect(sim.slots[6][14].base == .empty)
        #expect(sim.slots[10][5].base == .ladder)
        #expect(sim.slots[10][5].current == .ladder)
        #expect(sim.score == 250)
    }

    @Test("reaching row 0 centered with all gold collected wins")
    func reachingTopWithAllGoldWins() throws {
        let level = makeLevel(stamps: [
            (x: 3, y: 1, tile: .runner),
            (x: 4, y: 1, tile: .gold),
            (x: 5, y: 0, tile: .ladder),
            (x: 5, y: 1, tile: .ladder),
            (x: 3, y: 2, tile: .brick),
            (x: 4, y: 2, tile: .brick),
        ])
        var sim = try RunnerSimulation(level: level)

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
    func diggingHappyPath() throws {
        let level = makeLevel(stamps: [
            (x: 5, y: 10, tile: .runner),
            (x: 4, y: 11, tile: .brick),
            (x: 5, y: 11, tile: .brick),
        ])
        var sim = try RunnerSimulation(level: level)

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
    func diggingBurialDeath() throws {
        let level = makeLevel(stamps: [
            (x: 5, y: 10, tile: .runner),
            (x: 4, y: 11, tile: .brick),
            (x: 5, y: 11, tile: .brick),
            (x: 4, y: 12, tile: .brick),
        ])
        var sim = try RunnerSimulation(level: level)

        sim.tick(.digLeft)
        for _ in 0..<11 { sim.tick(.stop) }  // dig completes
        for _ in 0..<3 { sim.tick(.left) }  // cross into column 4, over the open hole
        #expect(sim.runner.position == GridPoint(x: 4, y: 10))

        for _ in 0..<183 { sim.tick(.stop) }  // fall into the hole, rest, then fillComplete buries it
        #expect(sim.phase == .dead)
        #expect(sim.slots[4][11].current == .brick)
    }

    @Test("ok2Dig rejects a non-brick target, an occupied column, and a gold-based target")
    func ok2DigRejections() throws {
        // (a) diagonal target isn't a brick (it's empty)
        let notBrick = makeLevel(stamps: [
            (x: 5, y: 10, tile: .runner),
            (x: 5, y: 11, tile: .brick),
        ])
        var sim1 = try RunnerSimulation(level: notBrick)
        sim1.tick(.digLeft)
        #expect(sim1.digState == nil)
        #expect(sim1.runner.action == .stop)

        // (b) target column is occupied (a brick sits at [x-1][y])
        let occupied = makeLevel(stamps: [
            (x: 5, y: 10, tile: .runner),
            (x: 4, y: 10, tile: .brick),
            (x: 4, y: 11, tile: .brick),
            (x: 5, y: 11, tile: .brick),
        ])
        var sim2 = try RunnerSimulation(level: occupied)
        sim2.tick(.digLeft)
        #expect(sim2.digState == nil)

        // (c) target column's base is gold
        let goldTarget = makeLevel(stamps: [
            (x: 5, y: 10, tile: .runner),
            (x: 4, y: 10, tile: .gold),
            (x: 4, y: 11, tile: .brick),
            (x: 5, y: 11, tile: .brick),
        ])
        var sim3 = try RunnerSimulation(level: goldTarget)
        sim3.tick(.digLeft)
        #expect(sim3.digState == nil)
    }

    @Test("RunnerSimulation round-trips through JSON")
    func codableRoundTrip() throws {
        let level = makeLevel(stamps: [
            (x: 5, y: 10, tile: .runner),
            (x: 4, y: 11, tile: .brick),
            (x: 5, y: 11, tile: .brick),
        ])
        var sim = try RunnerSimulation(level: level)
        sim.tick(.digLeft)
        for _ in 0..<5 { sim.tick(.stop) }

        let data = try JSONEncoder().encode(sim)
        let decoded = try JSONDecoder().decode(RunnerSimulation.self, from: data)
        #expect(decoded == sim)
    }
}
