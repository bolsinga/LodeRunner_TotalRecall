// AI version 4 (the only version this port targets) speed constants, from
// lodeRunner.preload.js's spriteSpeed table (ver 3 & 4 row: xMoveBase=8, yMoveBase=9).
private let runnerXMove = 8
private let runnerYMove = 9

// digHoleLeft/digHoleRight table length, lodeRunner.runner.js:456-457.
private let digAnimationFrameCount = 11

// fillHoleTime, lodeRunner.runner.js:699 — genuinely simulation-relevant (not
// display), since it determines exactly when fillComplete fires and therefore when
// burial-death can trigger. Total fill duration: 166+8+8+4 = 186 ticks.
private let fillFrameDurations = [166, 8, 8, 4]

/// A brick mid-dig. `pos` matches the JS's `holeObj.pos`: the RUNNER's row, not the
/// brick's — the brick actually being dug is at `(pos.x, pos.y + 1)`. Kept literally
/// as-is (not renamed/normalized) to avoid introducing an off-by-one bug porting the
/// several call sites that rely on this convention.
public struct DigState: Equatable, Codable, Sendable {
    public let pos: GridPoint
    public let direction: RunnerAction  // .digLeft or .digRight
    public var frameIndex: Int
}

/// A brick mid-refill. `position` is the absolute brick cell (already correct in the
/// JS's `fillHoleObj` entries, no off-by-one convention here).
public struct FillState: Equatable, Codable, Sendable {
    public let position: GridPoint
    public var frameIndex: Int
    public var frameTime: Int
}

public enum RunnerSimulationError: Error, Equatable, Sendable, CustomStringConvertible {
    case noRunnerSpawn

    public var description: String {
        switch self {
        case .noRunnerSpawn: return "level has no runner spawn"
        }
    }
}

/// Ported from `lodeRunner.runner.js`, targeting AI version 4 only. Guard-existence
/// gated logic (`checkCollision`, the guard-interrupt path in digging, the
/// guard-head landing clamp) is deferred to a later phase — see the phase-2 plan for
/// why each is a provable no-op with zero guards on the map.
public struct RunnerSimulation: Equatable, Codable, Sendable {
    public private(set) var slots: [[LevelSlot]]  // [x][y]
    public private(set) var runner: Runner
    public private(set) var digState: DigState?
    public private(set) var fillStates: [FillState]
    public private(set) var goldRemaining: Int
    public private(set) var goldComplete: Bool
    public private(set) var phase: RunnerPhase

    public init(level: LevelParseResult) throws {
        guard let spawn = level.runner else {
            throw RunnerSimulationError.noRunnerSpawn
        }
        slots = level.slots
        runner = Runner(position: spawn, xOffset: 0, yOffset: 0, action: .stop)
        digState = nil
        fillStates = []
        goldRemaining = level.goldCount
        goldComplete = false
        phase = .playing
    }

    /// Advance the simulation by exactly one tick. Ported from `playGame`'s ordering
    /// in `lodeRunner.main.js:878-908` (minus every guard-related step).
    public mutating func tick(_ requestedAction: RunnerAction) {
        guard phase == .playing else { return }

        if goldComplete && runner.position.y == 0 && runner.yOffset == 0 {
            phase = .finished
            return
        }

        if digState == nil {
            moveRunner(requestedAction)
        } else {
            processDigHole()
        }

        processFillHole()  // always runs, matching main.js's unconditional per-tick call
    }

    // MARK: - moveRunner (lodeRunner.runner.js:8-115)

    private mutating func moveRunner(_ requestedAction: RunnerAction) {
        let x = runner.position.x
        let y = runner.position.y
        let xOffset = runner.xOffset
        let yOffset = runner.yOffset

        enum MoveState { case okToMove, falling }

        let state: MoveState
        let curBase = slots[x][y].base

        if curBase == .ladder || (curBase == .bar && yOffset == 0) {
            state = .okToMove
        } else if yOffset < 0 {
            state = .falling
        } else if y < TileGeometry.maxTileY {
            switch slots[x][y + 1].current {
            case .empty:
                state = .falling
            case .brick, .ladder, .solid, .guard:
                state = .okToMove
            default:  // .bar, .trap, .gold, .hiddenLadder, .runner
                state = .falling
            }
        } else {
            state = .okToMove
        }

        if state == .falling {
            let stayCurrPos =
                y >= TileGeometry.maxTileY || slots[x][y + 1].current == .brick
                || slots[x][y + 1].current == .solid || slots[x][y + 1].current == .guard
            runnerMoveStep(.fall, stayCurrPos: stayCurrPos)
            return
        }

        var moveStep: RunnerAction = .stop
        var stayCurrPos = true

        switch requestedAction {
        case .up:
            stayCurrPos =
                y <= 0 || slots[x][y - 1].current == .brick || slots[x][y - 1].current == .solid
                || slots[x][y - 1].current == .trap

            if y > 0 && slots[x][y].base != .ladder && yOffset < TileGeometry.quarterTileHeight
                && yOffset > 0 && slots[x][y + 1].base == .ladder
            {
                stayCurrPos = true
                moveStep = .up
            } else if !((slots[x][y].base != .ladder
                && (yOffset <= 0 || slots[x][y + 1].base != .ladder))
                || (yOffset <= 0 && stayCurrPos))
            {
                moveStep = .up
            }

        case .down:
            // Deliberately omits .trap, unlike .up/.left/.right: stepping down onto a
            // false brick falls through (that's the trap's whole purpose), while
            // walking/climbing into one from another direction is blocked.
            stayCurrPos =
                y >= TileGeometry.maxTileY || slots[x][y + 1].current == .brick
                || slots[x][y + 1].current == .solid

            if !(yOffset >= 0 && stayCurrPos) {
                moveStep = .down
            }

        case .left:
            stayCurrPos =
                x <= 0 || slots[x - 1][y].current == .brick || slots[x - 1][y].current == .solid
                || slots[x - 1][y].current == .trap

            if !(xOffset <= 0 && stayCurrPos) {
                moveStep = .left
            }

        case .right:
            stayCurrPos =
                x >= TileGeometry.maxTileX || slots[x + 1][y].current == .brick
                || slots[x + 1][y].current == .solid || slots[x + 1][y].current == .trap

            if !(xOffset >= 0 && stayCurrPos) {
                moveStep = .right
            }

        case .digLeft, .digRight:
            if ok2Dig(requestedAction) {
                runnerMoveStep(requestedAction, stayCurrPos: stayCurrPos)
                digHole(requestedAction)
            } else {
                runnerMoveStep(.stop, stayCurrPos: stayCurrPos)
            }
            return

        case .stop, .fall, .fallBar:
            break
        }

        runnerMoveStep(moveStep, stayCurrPos: stayCurrPos)
    }

    // MARK: - runnerMoveStep (lodeRunner.runner.js:117-324)

    private mutating func runnerMoveStep(_ action: RunnerAction, stayCurrPos: Bool) {
        var x = runner.position.x
        var y = runner.position.y
        var xOffset = runner.xOffset
        var yOffset = runner.yOffset
        var resolvedAction = action

        enum CenterAxis { case none, up, down, left, right }
        var centerX = CenterAxis.none
        var centerY = CenterAxis.none

        switch action {
        case .digLeft, .digRight:
            xOffset = 0
            yOffset = 0
        case .up, .down, .fall:
            if xOffset > 0 { centerX = .left } else if xOffset < 0 { centerX = .right }
        case .left, .right:
            if yOffset > 0 { centerY = .up } else if yOffset < 0 { centerY = .down }
        case .stop, .fallBar:
            break
        }

        var curToken = slots[x][y].base

        if resolvedAction == .up {
            yOffset -= runnerYMove
            if stayCurrPos && yOffset < 0 {
                yOffset = 0
            } else if yOffset < -TileGeometry.halfTileHeight {
                if curToken == .brick || curToken == .hiddenLadder { curToken = .empty }
                slots[x][y].current = curToken
                y -= 1
                yOffset = TileGeometry.tileHeight + yOffset
                // guard-collision check deferred (runner.js:161)
            }
        }

        if centerY == .up {
            yOffset -= runnerYMove
            if yOffset < 0 { yOffset = 0 }
        }

        if resolvedAction == .down || resolvedAction == .fall {
            var holdOnBar = false
            if curToken == .bar {
                if yOffset < 0 {
                    holdOnBar = true
                } else if resolvedAction == .down && y < TileGeometry.maxTileY
                    && slots[x][y + 1].current != .ladder && slots[x][y + 1].current != .guard
                {
                    resolvedAction = .fall
                }
            }

            yOffset += runnerYMove

            if holdOnBar && yOffset >= 0 {
                yOffset = 0
                resolvedAction = .fallBar
            }
            if stayCurrPos && yOffset > 0 {
                yOffset = 0
            } else if yOffset > TileGeometry.halfTileHeight {
                if curToken == .brick || curToken == .hiddenLadder { curToken = .empty }
                slots[x][y].current = curToken
                y += 1
                yOffset -= TileGeometry.tileHeight
                // guard-collision check deferred (runner.js:198)
            }
            // guard-head landing clamp deferred (runner.js:205-209)
        }

        if centerY == .down {
            yOffset += runnerYMove
            if yOffset > 0 { yOffset = 0 }
        }

        if resolvedAction == .left {
            xOffset -= runnerXMove
            if stayCurrPos && xOffset < 0 {
                xOffset = 0
            } else if xOffset < -TileGeometry.halfTileWidth {
                if curToken == .brick || curToken == .hiddenLadder { curToken = .empty }
                slots[x][y].current = curToken
                x -= 1
                xOffset = TileGeometry.tileWidth + xOffset
                // guard-collision check deferred (runner.js:236)
            }
        }

        if centerX == .left {
            xOffset -= runnerXMove
            if xOffset < 0 { xOffset = 0 }
        }

        if resolvedAction == .right {
            xOffset += runnerXMove
            if stayCurrPos && xOffset > 0 {
                xOffset = 0
            } else if xOffset > TileGeometry.halfTileWidth {
                if curToken == .brick || curToken == .hiddenLadder { curToken = .empty }
                slots[x][y].current = curToken
                x += 1
                xOffset -= TileGeometry.tileWidth
                // guard-collision check deferred (runner.js:256)
            }
        }

        if centerX == .right {
            xOffset += runnerXMove
            if xOffset > 0 { xOffset = 0 }
        }

        runner = Runner(position: GridPoint(x: x, y: y), xOffset: xOffset, yOffset: yOffset, action: resolvedAction)

        slots[x][y].current = .runner

        // Gold pickup (runner.js:301-307) — the left/right check is deliberately
        // asymmetric (only 0 <= xOffset < quarterTileWidth, no negative-offset
        // counterpart for approaching from the right); preserve as written.
        if slots[x][y].base == .gold
            && ((xOffset == 0 && yOffset >= 0 && yOffset < TileGeometry.quarterTileHeight)
                || (yOffset == 0 && xOffset >= 0 && xOffset < TileGeometry.quarterTileWidth)
                || (y < TileGeometry.maxTileY && slots[x][y + 1].base == .ladder
                    && yOffset < TileGeometry.quarterTileHeight))
        {
            slots[x][y].base = .empty
            goldRemaining -= 1
            if goldRemaining <= 0 {
                showHideLaddr()
            }
        }

        // checkCollision deferred entirely (runner.js:374-422) — guard-existence
        // gated, provably a no-op with zero guards on the map.
    }

    // MARK: - Gold / hidden ladders (lodeRunner.runner.js:326-372)

    private mutating func showHideLaddr() {
        for y in 0..<LevelGrid.tilesY {
            for x in 0..<LevelGrid.tilesX {
                if slots[x][y].base == .hiddenLadder {
                    slots[x][y].base = .ladder
                    slots[x][y].current = .ladder
                }
            }
        }
        goldComplete = true
    }

    // MARK: - Digging (lodeRunner.runner.js:425-731, minus the guard-interrupt path)

    private func ok2Dig(_ action: RunnerAction) -> Bool {
        let x = runner.position.x
        let y = runner.position.y

        switch action {
        case .digLeft:
            guard y < TileGeometry.maxTileY, x > 0 else { return false }
            return slots[x - 1][y + 1].current == .brick && slots[x - 1][y].current == .empty
                && slots[x - 1][y].base != .gold
        case .digRight:
            guard y < TileGeometry.maxTileY, x < TileGeometry.maxTileX else { return false }
            return slots[x + 1][y + 1].current == .brick && slots[x + 1][y].current == .empty
                && slots[x + 1][y].base != .gold
        default:
            return false
        }
    }

    private mutating func digHole(_ action: RunnerAction) {
        let targetX = action == .digLeft ? runner.position.x - 1 : runner.position.x + 1
        digState = DigState(
            pos: GridPoint(x: targetX, y: runner.position.y), direction: action, frameIndex: 0)
    }

    private mutating func processDigHole() {
        guard var state = digState else { return }
        state.frameIndex += 1
        digState = state
        if state.frameIndex >= digAnimationFrameCount {
            digComplete()
        }
    }

    private mutating func digComplete() {
        guard let state = digState else { return }
        let cell = GridPoint(x: state.pos.x, y: state.pos.y + 1)
        slots[cell.x][cell.y].current = .empty
        fillStates.append(FillState(position: cell, frameIndex: 0, frameTime: -1))
        digState = nil
    }

    private mutating func processFillHole() {
        var i = 0
        while i < fillStates.count {
            let curIdx = fillStates[i].frameIndex
            fillStates[i].frameTime += 1
            if fillStates[i].frameTime >= fillFrameDurations[curIdx] {
                fillStates[i].frameIndex += 1
                if fillStates[i].frameIndex < fillFrameDurations.count {
                    fillStates[i].frameTime = 0
                    i += 1
                } else {
                    let completed = fillStates.remove(at: i)
                    fillComplete(completed)
                    // no i += 1 — the next element has shifted into index i
                }
            } else {
                i += 1
            }
        }
    }

    private mutating func fillComplete(_ state: FillState) {
        let cell = state.position
        if slots[cell.x][cell.y].current == .runner {
            phase = .dead
        }
        slots[cell.x][cell.y].current = .brick
    }
}
