import Foundation
import Testing

@testable import LodeRunnerCore

/// Build a blank 28x16 level, then stamp entities/terrain at [x,y] positions, matching
/// phase 2's `makeLevel` test helper. Always fills the bottom row with bricks so the
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

@Test("guard spawns match the level's guard positions; scheduler starts at 0")
func guardSpawnsMatchLevel() throws {
    let level = resolveLevelMap(
        makeLevel(stamps: [
            (x: 5, y: 14, ch: "&"),
            (x: 10, y: 5, ch: "0"),
            (x: 12, y: 5, ch: "0"),
        ]))
    let sim = try RunnerSimulation(level: level)

    #expect(sim.guards.count == 2)
    #expect(sim.guards[0].position == GridPoint(x: 10, y: 5))
    #expect(sim.guards[1].position == GridPoint(x: 12, y: 5))
    for spawnedGuard in sim.guards {
        #expect(spawnedGuard.xOffset == 0)
        #expect(spawnedGuard.yOffset == 0)
        #expect(spawnedGuard.action == .stop)
        #expect(spawnedGuard.hasGold == 0)
        #expect(spawnedGuard.holePos == nil)
    }
    #expect(sim.moveOffset == 0)
    #expect(sim.moveId == 0)
    #expect(sim.shakingGuards.isEmpty)
    #expect(sim.rebornGuards.isEmpty)
}

@Test("move-throttling: with one guard, it only actually steps on odd ticks")
func moveThrottlingWithOneGuard() throws {
    let level = resolveLevelMap(
        makeLevel(stamps: [
            (x: 20, y: 14, ch: "&"),
            (x: 5, y: 5, ch: "0"),
        ]))
    var sim = try RunnerSimulation(level: level)
    // Column 5 is open air below the guard for many rows, so it just keeps
    // falling every time it's actually given a turn — a simple, observable signal.

    sim.tick(.stop)  // tick 1 (odd): moves
    #expect(sim.guards[0].yOffset == 9)
    sim.tick(.stop)  // tick 2 (even): doesn't move
    #expect(sim.guards[0].yOffset == 9)
    sim.tick(.stop)  // tick 3 (odd): moves
    #expect(sim.guards[0].yOffset == 18)
    sim.tick(.stop)  // tick 4 (even): doesn't move
    #expect(sim.guards[0].yOffset == 18)
    sim.tick(.stop)  // tick 5 (odd): moves, crosses into row 6
    #expect(sim.guards[0].position == GridPoint(x: 5, y: 6))
    #expect(sim.guards[0].yOffset == -17)
    sim.tick(.stop)  // tick 6 (even): doesn't move
    #expect(sim.guards[0].position == GridPoint(x: 5, y: 6))
    #expect(sim.guards[0].yOffset == -17)
}

@Test("a guard falls through the runner's tile from directly above")
func guardFallsThroughRunnerFromAbove() throws {
    let level = resolveLevelMap(
        makeLevel(stamps: [
            (x: 5, y: 10, ch: "&"),
            (x: 5, y: 11, ch: "#"),
            (x: 5, y: 9, ch: "0"),
        ]))
    var sim = try RunnerSimulation(level: level)

    // Guard moves on ticks 1,3,5 (odds, only 1 guard). Crossing into the
    // runner's row happens on the 3rd active move: 9, 18, 27(>22, cross).
    for _ in 0..<5 { sim.tick(.stop) }
    #expect(sim.phase == .dead)
}

@Test("a guard resting on another guard's head does not fall")
func guardOnGuardHeadDoesNotFall() throws {
    let level = resolveLevelMap(
        makeLevel(stamps: [
            (x: 20, y: 14, ch: "&"),
            (x: 5, y: 9, ch: "0"),
            (x: 5, y: 10, ch: "0"),
            (x: 5, y: 11, ch: "#"),
            // Box both guards in laterally so neither wanders off via scanFloor
            // pathfinding while looking for an unreachable runner — the forced-fall
            // check under test (resting on another guard's head) is otherwise
            // unaffected by these walls.
            (x: 4, y: 9, ch: "#"),
            (x: 6, y: 9, ch: "#"),
            (x: 4, y: 10, ch: "#"),
            (x: 6, y: 10, ch: "#"),
        ]))
    var sim = try RunnerSimulation(level: level)

    for _ in 0..<10 { sim.tick(.stop) }

    #expect(sim.guards[0].position == GridPoint(x: 5, y: 9))
    #expect(sim.guards[0].xOffset == 0)
    #expect(sim.guards[0].yOffset == 0)
    #expect(sim.guards[1].position == GridPoint(x: 5, y: 10))
    #expect(sim.guards[1].xOffset == 0)
    #expect(sim.guards[1].yOffset == 0)
}

@Test("same-floor chase: an adjacent guard catches the runner")
func chaseAdjacentGuardCatchesRunner() throws {
    let level = resolveLevelMap(
        makeLevel(stamps: [
            (x: 15, y: 14, ch: "&"),
            (x: 14, y: 14, ch: "0"),
        ]))
    var sim = try RunnerSimulation(level: level)

    // Guard moves on odd ticks. xOffset: 8, 16, 24(>20, cross into runner's cell).
    for _ in 0..<5 { sim.tick(.stop) }
    #expect(sim.phase == .dead)
}

@Test("same-floor chase fails across a floor gap, but scanFloor still finds the gap")
func chaseFailsAcrossFloorGap() throws {
    // Same setup as before pathfinding existed, where the guard stayed frozen at
    // .stop forever. Now that scanFloor is wired in, the trap column is a real
    // scanDown candidate (falling through it eventually lands the guard on the
    // runner's row), so the guard heads toward the gap instead — an intentional
    // behavior change from the phase-3a stub, not a regression. Only the
    // immediate decision is checked here rather than the multi-tile fall-through.
    let level = resolveLevelMap(
        makeLevel(stamps: [
            (x: 15, y: 14, ch: "&"),
            (x: 10, y: 14, ch: "0"),
            (x: 12, y: 15, ch: "X"),  // trap: neither solid/ladder/brick footing
        ]))
    var sim = try RunnerSimulation(level: level)

    sim.tick(.stop)  // tick 1 (odd, only 1 guard): the guard's first active move.

    #expect(sim.guards[0].action == .right)
}

@Test("a guard boxed in on all four sides with no ladder returns .stop")
func scanFloorFindsNothingWhenBoxedIn() throws {
    let level = resolveLevelMap(
        makeLevel(stamps: [
            (x: 20, y: 14, ch: "&"),
            (x: 10, y: 10, ch: "0"),
            (x: 9, y: 10, ch: "#"),
            (x: 11, y: 10, ch: "#"),
            (x: 10, y: 9, ch: "#"),
            (x: 10, y: 11, ch: "#"),
        ]))
    var sim = try RunnerSimulation(level: level)

    for _ in 0..<10 { sim.tick(.stop) }

    #expect(sim.guards[0].position == GridPoint(x: 10, y: 10))
    #expect(sim.guards[0].xOffset == 0)
    #expect(sim.guards[0].yOffset == 0)
    #expect(sim.guards[0].action == .stop)
}

@Test("pathfinding: a guard descends a ladder to the runner's floor, then catches it")
func scanFloorDescendsLadderThenCatchesRunner() throws {
    // Guard starts two rows above the runner, with a ladder between them (column
    // 12) reachable by walking along the guard's own floor. scanFloor should
    // guide the guard to the ladder, then down it, then phase 3a's already-tested
    // same-floor chase finishes the catch.
    let level = resolveLevelMap(
        makeLevel(stamps: [
            (x: 15, y: 12, ch: "&"),
            (x: 10, y: 10, ch: "0"),
            (x: 12, y: 10, ch: "H"),
            (x: 12, y: 11, ch: "H"),
            (x: 12, y: 12, ch: "H"),
            (x: 10, y: 11, ch: "#"),  // footing under the guard's start
            (x: 11, y: 11, ch: "#"),  // footing along the walk to the ladder
            (x: 12, y: 13, ch: "#"),  // anchors the ladder's bottom at row 12
            (x: 13, y: 13, ch: "#"),  // footing for the row-12 chase, once there
            (x: 14, y: 13, ch: "#"),
            (x: 15, y: 13, ch: "#"),  // footing under the runner
        ]))
    var sim = try RunnerSimulation(level: level)

    var reachedLadder = false
    for _ in 0..<200 {
        sim.tick(.stop)
        if sim.guards[0].position == GridPoint(x: 12, y: 10) {
            reachedLadder = true
            break
        }
    }
    #expect(reachedLadder)

    var reachedRunnerFloor = false
    for _ in 0..<200 {
        sim.tick(.stop)
        if sim.guards[0].position.y == 12 {
            reachedRunnerFloor = true
            break
        }
    }
    #expect(reachedRunnerFloor)

    var caught = false
    for _ in 0..<200 {
        sim.tick(.stop)
        if sim.phase == .dead {
            caught = true
            break
        }
    }
    #expect(caught)
}

@Test("a guard chasing across a freshly-dug hole falls in, shakes, and climbs back out")
func guardFallsIntoHoleAndClimbsOut() throws {
    // The guard starts far enough away (x=1, vs. the dig target at column 4) that
    // it doesn't reach the runner's own cell (digState.pos, which the guard-
    // interrupt check in isDigging() watches) until well after the dig has
    // already completed naturally — arriving mid-dig would abort the dig instead
    // of ever creating a hole to fall into.
    let level = resolveLevelMap(
        makeLevel(stamps: [
            (x: 5, y: 10, ch: "&"),
            (x: 1, y: 10, ch: "0"),
            (x: 1, y: 11, ch: "#"),
            (x: 2, y: 11, ch: "#"),
            (x: 3, y: 11, ch: "#"),
            (x: 4, y: 11, ch: "#"),
            (x: 5, y: 11, ch: "#"),
            (x: 4, y: 12, ch: "#"),  // support so the guard settles in the hole
        ]))
    var sim = try RunnerSimulation(level: level)

    sim.tick(.digLeft)
    for _ in 0..<11 { sim.tick(.stop) }  // dig completes, hole opens at (4,11)

    var enteredHole = false
    for _ in 0..<80 {
        sim.tick(.stop)
        if sim.guards[0].action == .inHole {
            enteredHole = true
            break
        }
        #expect(sim.score == 0)  // SCORE_IN_HOLE only fires once landed.
    }
    #expect(enteredHole)
    #expect(sim.guards[0].position == GridPoint(x: 4, y: 11))
    #expect(sim.score == 75)

    // Once the guard climbs back out, it lands on the runner's own row (y=10)
    // right next to it, and — since the runner just sits still (.stop) — the
    // guard correctly resumes chasing and eventually catches it. That's the
    // real game behavior, not a bug, so this only asserts the climb-out itself
    // (leaving the hole's row) actually happens; it doesn't assert anything
    // about what happens to the runner afterward.
    var climbedOut = false
    for _ in 0..<150 {
        sim.tick(.stop)
        if sim.guards[0].position.y < 11 {
            climbedOut = true
            break
        }
    }
    #expect(climbedOut)
    #expect(sim.shakingGuards.isEmpty)
    #expect(sim.score == 75)  // unchanged by shaking/climbing out, only by landing.
}

@Test("a guard buried while still in the hole scores SCORE_GUARD_DEAD too")
func guardBuriedWhileInHoleScoresTwice() throws {
    // The guard starts far enough away that it lands in the hole late — late
    // enough that the fill timer (fixed at ~198 ticks after the dig starts: 11
    // dig + 186 fill) completes before the guard finishes shaking and climbing
    // out (~85 ticks after landing: 66 shake + climb travel), so burial preempts
    // the climb-out and scores SCORE_GUARD_DEAD on top of the SCORE_IN_HOLE it
    // already earned on landing.
    var stamps: [(x: Int, y: Int, ch: Character)] = [
        (x: 25, y: 10, ch: "&"),
        (x: 6, y: 10, ch: "0"),
    ]
    for x in 0..<LevelGrid.tilesX {
        stamps.append((x: x, y: 11, ch: "#"))
    }
    stamps.append((x: 24, y: 12, ch: "#"))
    let level = resolveLevelMap(makeLevel(stamps: stamps))
    var sim = try RunnerSimulation(level: level)

    sim.tick(.digLeft)
    for _ in 0..<11 { sim.tick(.stop) }  // dig completes, hole opens at (24,11)

    var enteredHole = false
    var landedTick = 0
    for tick in 1...250 {
        sim.tick(.stop)
        landedTick = tick
        if sim.guards[0].action == .inHole {
            enteredHole = true
            break
        }
    }
    #expect(enteredHole)
    #expect(sim.score == 75)

    var buried = false
    for _ in 0..<250 {
        sim.tick(.stop)
        if sim.guards[0].action != .inHole {
            // Either buried (fillComplete fired first) or it climbed out — tell
            // them apart by whether it's still occupying the hole's cell.
            buried = sim.slots[24][11].current == .brick
            break
        }
    }
    #expect(buried, "expected burial to preempt climb-out (landed at tick \(landedTick))")
    #expect(sim.score == 150)
    #expect(sim.shakingGuards.isEmpty)
}

@Test("guard reborn: schedules a respawn, completes after 9 ticks, lands on a valid cell")
func guardRebornSchedulesAndCompletes() throws {
    let level = resolveLevelMap(
        makeLevel(stamps: [
            (x: 5, y: 14, ch: "&"),
            (x: 10, y: 5, ch: "0"),
        ]))
    var sim = try RunnerSimulation(level: level)
    let buriedCell = sim.guards[0].position

    sim.guardReborn(at: buriedCell)
    #expect(sim.guards[0].action == .reborn)
    #expect(sim.rebornGuards.count == 1)

    // frameTime starts at -1, so frame 0 (duration 6) needs 7 ticks to advance,
    // not 6 — the same "-1 sentinel costs one extra tick" lesson as the fill-hole
    // queue. Total: 7 + 2 = 9.
    for _ in 0..<9 { sim.tick(.stop) }

    #expect(sim.rebornGuards.isEmpty)
    #expect(sim.guards[0].action == .fall)
    #expect(sim.guards[0].xOffset == 0)
    #expect(sim.guards[0].yOffset == 0)

    let newPosition = sim.guards[0].position
    #expect(sim.slots[newPosition.x][newPosition.y].current == .guard)
    #expect(sim.slots[newPosition.x][newPosition.y].base != .gold)
    #expect(sim.slots[newPosition.x][newPosition.y].base != .brick)
    #expect(newPosition.y >= 1)
}

@Test("a guard chasing across gold picks it up, then eventually drops it")
func guardPicksUpAndDropsGold() throws {
    let level = resolveLevelMap(
        makeLevel(stamps: [
            (x: 20, y: 14, ch: "&"),
            (x: 10, y: 14, ch: "0"),
            (x: 11, y: 14, ch: "$"),
        ]))
    var sim = try RunnerSimulation(level: level)

    // Guard moves on odd ticks. xOffset: 8, 16, 24(cross to x=11, offset -16),
    // -8, 0 (5th active move, tick 9) — centered exactly on the gold tile.
    for _ in 0..<9 { sim.tick(.stop) }
    #expect((12...37).contains(sim.guards[0].hasGold))
    #expect(sim.slots[11][14].base == .empty)

    let pickedUp = sim.guards[0].hasGold
    for _ in 0..<200 { sim.tick(.stop) }
    #expect(sim.guards[0].hasGold != pickedUp)
    // A guard's own gold pickup/carry/drop never scores — only the runner's own
    // pickup (SCORE_GET_GOLD) and the two guard-death triggers do.
    #expect(sim.score == 0)
}

@Test("runner colliding with a guard is fatal")
func runnerCollidingWithGuardIsFatal() throws {
    let level = resolveLevelMap(
        makeLevel(stamps: [
            (x: 5, y: 14, ch: "&"),
            (x: 6, y: 14, ch: "0"),
        ]))
    var sim = try RunnerSimulation(level: level)

    for _ in 0..<10 {
        sim.tick(.right)
        if sim.phase == .dead { break }
    }
    #expect(sim.phase == .dead)
}

@Test("RunnerSimulation with guards round-trips through JSON")
func codableRoundTripWithGuards() throws {
    let level = resolveLevelMap(
        makeLevel(stamps: [
            (x: 5, y: 10, ch: "&"),
            (x: 1, y: 10, ch: "0"),
            (x: 1, y: 11, ch: "#"),
            (x: 2, y: 11, ch: "#"),
            (x: 3, y: 11, ch: "#"),
            (x: 4, y: 11, ch: "#"),
            (x: 5, y: 11, ch: "#"),
            (x: 4, y: 12, ch: "#"),
        ]))
    var sim = try RunnerSimulation(level: level)

    sim.tick(.digLeft)
    for _ in 0..<11 { sim.tick(.stop) }
    for _ in 0..<80 {
        sim.tick(.stop)
        if sim.guards[0].action == .inHole { break }
    }
    #expect(!sim.shakingGuards.isEmpty)
    #expect(sim.score == 75)  // SCORE_IN_HOLE, landed this tick.

    let data = try JSONEncoder().encode(sim)
    let decoded = try JSONDecoder().decode(RunnerSimulation.self, from: data)
    #expect(decoded == sim)
}
