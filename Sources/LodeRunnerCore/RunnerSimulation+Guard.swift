private let numberOfMoveSlots = 6

// shakeTime, guard.js:448-449 — AI4's value is 51, not the AI<=3 value of 36.
private let guardShakeFrameDurations = [51, 3, 3, 3, 3, 3]

// rebornTime, guard.js:927 — not version-branched.
private let guardRebornFrameDurations = [6, 2]

// digLimit, AI4 (preload.js:638) — used by RunnerSimulation.isDigging()'s
// guard-interrupt check.
let guardDigInterruptFrameLimit = 8

// movePolicy[guardCount][moveOffset], guard.js:6-18, with row 1 overridden to the
// AI4 value directly (preload.js:469-475: [0,1,0,1,0,1], not the AI<3 [0,1,1,0,1,1]).
// Rows 0 and 6-11 are unreachable (guardCount is always 0...5) but kept for literal
// fidelity against the source table.
private let movePolicy: [[Int]] = [
    [0, 0, 0, 0, 0, 0],
    [0, 1, 0, 1, 0, 1],
    [1, 1, 1, 1, 1, 1],
    [1, 2, 1, 1, 2, 1],
    [1, 2, 2, 1, 2, 2],
    [2, 2, 2, 2, 2, 2],
    [2, 2, 3, 2, 2, 3],
    [2, 3, 3, 2, 3, 3],
    [3, 3, 3, 3, 3, 3],
    [3, 3, 4, 3, 3, 4],
    [3, 4, 4, 3, 4, 4],
    [4, 4, 4, 4, 4, 4],
]

/// A guard mid-shake, after falling into a dug hole (`guard.js:421-512`).
public struct ShakeState: Equatable, Codable, Sendable {
    public let guardIndex: Int
    public var frameIndex: Int
    public var frameTime: Int
}

/// A guard mid-respawn, after being buried (`guard.js:923-970`).
public struct RebornState: Equatable, Codable, Sendable {
    public let guardIndex: Int
    public var frameIndex: Int
    public var frameTime: Int
}

/// Fair-shuffle-without-repeat column picker for guard respawn. Deliberately uses
/// Swift's standard `.shuffle()` rather than the JS's specific (and non-standard)
/// shuffle algorithm — see the phase-3a plan for why that simplification doesn't
/// affect any deterministic, testable behavior.
public struct ShuffledColumnPicker: Equatable, Codable, Sendable {
    private var order: [Int]
    private var index: Int

    public init(columns: Int) {
        order = Array(0..<columns)
        order.shuffle()
        index = 0
    }

    public mutating func next() -> Int {
        if index >= order.count {
            order.shuffle()
            index = 0
        }
        let value = order[index]
        index += 1
        return value
    }
}

extension RunnerSimulation {
    // MARK: - Scheduler (guard.js:33-54)

    mutating func moveGuard() {
        guard !guards.isEmpty else { return }
        moveOffset = (moveOffset + 1) % numberOfMoveSlots
        let moves = movePolicy[guards.count][moveOffset]
        for _ in 0..<moves {
            moveId = (moveId + 1) % guards.count
            if guards[moveId].action == .inHole || guards[moveId].action == .reborn { continue }
            let action = bestMove(for: moveId)
            guardMoveStep(moveId, action: action)
        }
    }

    // MARK: - bestMove (guard.js:531-625, minus scanFloor/scanDown/scanUp)

    private mutating func bestMove(for id: Int) -> GuardAction {
        let guardState = guards[id]
        let x = guardState.position.x
        let y = guardState.position.y
        let yOffset = guardState.yOffset

        var checkSameLevelOnly = false
        let curToken = slots[x][y].base

        if guardState.action == .climbOut, let holePos = guardState.holePos {
            if y == holePos.y {
                return .up
            } else {
                checkSameLevelOnly = true
                if x != holePos.x {
                    guards[id] = Guard(
                        position: guardState.position, xOffset: guardState.xOffset,
                        yOffset: guardState.yOffset, action: .left, hasGold: guardState.hasGold,
                        holePos: guardState.holePos)
                }
            }
        }

        if !checkSameLevelOnly {
            if curToken == .ladder || (curToken == .bar && yOffset == 0) {
                // no forced fall
            } else if yOffset < 0 {
                return .fall
            } else if y < TileGeometry.maxTileY {
                switch slots[x][y + 1].current {
                case .empty, .runner:
                    return .fall
                case .brick, .solid, .guard, .ladder:
                    break  // no forced fall
                default:
                    return .fall
                }
            }
        }

        let runnerX = runner.position.x
        let runnerY = runner.position.y

        if y == runnerY && runner.action != .fall {
            var cursorX = x
            while cursorX != runnerX {
                let belowBase: TileType = y < TileGeometry.maxTileY ? slots[cursorX][y + 1].base : .solid
                // Bounds-guarded (see the phase-3a plan's "Scope" note): the source
                // re-checks map[x][y+1].act == GUARD_T unguarded here, unlike the
                // parallel belowBase lookup above.
                let belowIsGuard = y < TileGeometry.maxTileY && slots[cursorX][y + 1].current == .guard
                let curTok = slots[cursorX][y].base

                if curTok == .ladder || curTok == .bar
                    || belowBase == .solid || belowBase == .ladder || belowBase == .brick
                    || belowIsGuard || belowBase == .bar || belowBase == .gold
                {
                    if cursorX < runnerX { cursorX += 1 } else if cursorX > runnerX { cursorX -= 1 }
                } else {
                    break
                }
            }

            if cursorX == runnerX {
                if guardState.position.x < runnerX {
                    return .right
                } else if guardState.position.x > runnerX {
                    return .left
                } else {
                    return guardState.xOffset < runner.xOffset ? .right : .left
                }
            }
        }

        return scanFloor(for: id)
    }

    // MARK: - scanFloor / scanDown / scanUp (guard.js:631-823)

    /// When a guard can't chase the runner directly on its own floor, scan every
    /// column on that floor with real footing and, from each, try a single
    /// ladder-climb or a single fall to see if it lands on the runner's row. The
    /// closest such landing (by a simple distance/rating heuristic) wins, falling
    /// back to `.stop` if nothing beats the worst-rating sentinel. This considers
    /// only one vertical hop from the current floor — not real pathfinding — which
    /// is a faithful limitation of the original, not a shortcut taken here.
    private func scanFloor(for id: Int) -> GuardAction {
        let startX = guards[id].position.x
        let startY = guards[id].position.y
        let runnerY = runner.position.y

        var bestRating = 255
        var bestPath: GuardAction = .stop

        func firmFooting(_ base: TileType) -> Bool {
            base == .brick || base == .solid || base == .ladder
        }

        // Left/right floor extent (guard.js:646-677): walk until a wall (brick/solid
        // current tile), or — past the last column with real footing below — extend
        // exactly one tile further ("go on anyway") before stopping.
        var x = startX
        while x > 0 {
            let curToken = slots[x - 1][startY].current
            if curToken == .brick || curToken == .solid { break }
            let hasFooting =
                curToken == .ladder || curToken == .bar || startY >= TileGeometry.maxTileY
                || firmFooting(slots[x - 1][startY + 1].base)
            x -= 1
            if !hasFooting { break }
        }
        let leftEnd = x

        x = startX
        while x < TileGeometry.maxTileX {
            let curToken = slots[x + 1][startY].current
            if curToken == .brick || curToken == .solid { break }
            let hasFooting =
                curToken == .ladder || curToken == .bar || startY >= TileGeometry.maxTileY
                || firmFooting(slots[x + 1][startY + 1].base)
            x += 1
            if !hasFooting { break }
        }
        let rightEnd = x

        // guard.js:719-774 — "BUG from original book? (changed by Simon)": the
        // source keeps a commented-out `runnerX - x` alternate rating next to the
        // Math.abs version that actually runs. Nothing to resolve; the active line
        // is what's ported.
        func scanDown(_ x: Int, _ curPath: GuardAction) {
            var y = startY
            while y < TileGeometry.maxTileY {
                let nextBelow = slots[x][y + 1].base
                if nextBelow == .brick || nextBelow == .solid { break }
                if slots[x][y].base != .empty && slots[x][y].base != .hiddenLadder {
                    if x > 0 {
                        let leftBelow = slots[x - 1][y + 1].base
                        if (leftBelow == .brick || leftBelow == .ladder || leftBelow == .solid
                            || slots[x - 1][y].base == .bar) && y >= runnerY
                        {
                            break
                        }
                    }
                    if x < TileGeometry.maxTileX {
                        let rightBelow = slots[x + 1][y + 1].base
                        if (rightBelow == .brick || rightBelow == .ladder || rightBelow == .solid
                            || slots[x + 1][y].base == .bar) && y >= runnerY
                        {
                            break
                        }
                    }
                }
                y += 1
            }
            let curRating =
                y == runnerY
                    ? abs(startX - x) : y > runnerY ? y - runnerY + 200 : runnerY - y + 100
            if curRating < bestRating {
                bestRating = curRating
                bestPath = curPath
            }
        }

        func scanUp(_ x: Int, _ curPath: GuardAction) {
            var y = startY
            while y > 0 && slots[x][y].base == .ladder {
                y -= 1
                if x > 0 {
                    let leftBelow = slots[x - 1][y + 1].base
                    if (leftBelow == .brick || leftBelow == .solid || leftBelow == .ladder
                        || slots[x - 1][y].base == .bar) && y <= runnerY
                    {
                        break
                    }
                }
                if x < TileGeometry.maxTileX {
                    let rightBelow = slots[x + 1][y + 1].base
                    if (rightBelow == .brick || rightBelow == .solid || rightBelow == .ladder
                        || slots[x + 1][y].base == .bar) && y <= runnerY
                    {
                        break
                    }
                }
            }
            let curRating =
                y == runnerY
                    ? abs(startX - x) : y > runnerY ? y - runnerY + 200 : runnerY - y + 100
            if curRating < bestRating {
                bestRating = curRating
                bestPath = curPath
            }
        }

        x = startX
        if startY < TileGeometry.maxTileY, !firmFooting(slots[x][startY + 1].base) {
            scanDown(x, .down)
        }
        if slots[x][startY].base == .ladder {
            scanUp(x, .up)
        }

        var curPath: GuardAction = .left
        x = leftEnd
        while true {
            if x == startX {
                if curPath == .left && rightEnd != startX {
                    curPath = .right
                    x = rightEnd
                } else {
                    break
                }
            }
            if startY < TileGeometry.maxTileY, !firmFooting(slots[x][startY + 1].base) {
                scanDown(x, curPath)
            }
            if slots[x][startY].base == .ladder {
                scanUp(x, curPath)
            }
            x += curPath == .left ? 1 : -1
        }

        return bestPath
    }

    // MARK: - guardMoveStep (guard.js:56-373)

    private mutating func guardMoveStep(_ id: Int, action: GuardAction) {
        let guardState = guards[id]
        var x = guardState.position.x
        var y = guardState.position.y
        var xOffset = guardState.xOffset
        var yOffset = guardState.yOffset
        var resolvedAction = action
        var stayCurrPos = false

        if guards[id].action == .climbOut && resolvedAction == .stop {
            let s = guards[id]
            guards[id] = Guard(
                position: s.position, xOffset: s.xOffset, yOffset: s.yOffset, action: .stop,
                hasGold: s.hasGold, holePos: s.holePos)
        }

        enum CenterAxis { case none, up, down, left, right }
        var centerX = CenterAxis.none
        var centerY = CenterAxis.none

        switch resolvedAction {
        case .up:
            stayCurrPos =
                y <= 0 || slots[x][y - 1].current == .brick || slots[x][y - 1].current == .solid
                || slots[x][y - 1].current == .trap || slots[x][y - 1].current == .guard
            if yOffset <= 0 && stayCurrPos { resolvedAction = .stop }
            if resolvedAction != .stop {
                if xOffset > 0 { centerX = .left } else if xOffset < 0 { centerX = .right }
            }
        case .down, .fall:
            stayCurrPos =
                y >= TileGeometry.maxTileY || slots[x][y + 1].current == .brick
                || slots[x][y + 1].current == .solid || slots[x][y + 1].current == .guard
            if resolvedAction == .fall && yOffset < 0 && slots[x][y].base == .brick {
                resolvedAction = .inHole
                stayCurrPos = true
            } else if yOffset >= 0 && stayCurrPos {
                resolvedAction = .stop
            }
            if resolvedAction != .stop {
                if xOffset > 0 { centerX = .left } else if xOffset < 0 { centerX = .right }
            }
        case .left:
            stayCurrPos =
                x <= 0 || slots[x - 1][y].current == .brick || slots[x - 1][y].current == .solid
                || slots[x - 1][y].current == .guard || slots[x - 1][y].base == .trap
            if xOffset <= 0 && stayCurrPos { resolvedAction = .stop }
            if resolvedAction != .stop {
                if yOffset > 0 { centerY = .up } else if yOffset < 0 { centerY = .down }
            }
        case .right:
            stayCurrPos =
                x >= TileGeometry.maxTileX || slots[x + 1][y].current == .brick
                || slots[x + 1][y].current == .solid || slots[x + 1][y].current == .guard
                || slots[x + 1][y].base == .trap
            if xOffset >= 0 && stayCurrPos { resolvedAction = .stop }
            if resolvedAction != .stop {
                if yOffset > 0 { centerY = .up } else if yOffset < 0 { centerY = .down }
            }
        default:
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
                if slots[x][y].current == .runner { phase = .dead }
            }
            if yOffset <= 0 && yOffset > -runnerYMove {
                dropGold(id)
            }
        }

        if centerY == .up {
            yOffset -= runnerYMove
            if yOffset < 0 { yOffset = 0 }
        }

        if resolvedAction == .down || resolvedAction == .fall || resolvedAction == .inHole {
            var holdOnBar = false
            if curToken == .bar {
                if yOffset < 0 {
                    holdOnBar = true
                } else if resolvedAction == .down && y < TileGeometry.maxTileY
                    && slots[x][y + 1].current != .ladder
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
                if slots[x][y].current == .runner { phase = .dead }
            }

            if (resolvedAction == .fall || resolvedAction == .down) && yOffset >= 0
                && yOffset < runnerYMove
            {
                dropGold(id)
            }

            if resolvedAction == .inHole {
                if yOffset < 0 {
                    resolvedAction = .fall
                    if guards[id].hasGold > 0 {
                        if slots[x][y - 1].base == .empty {
                            slots[x][y - 1].base = .gold
                        } else {
                            decGold()
                        }
                        let s = guards[id]
                        guards[id] = Guard(
                            position: s.position, xOffset: s.xOffset, yOffset: s.yOffset,
                            action: s.action, hasGold: 0, holePos: s.holePos)
                    }
                } else {
                    if guards[id].hasGold > 0 {
                        if slots[x][y - 1].base == .empty {
                            slots[x][y - 1].base = .gold
                        } else {
                            decGold()
                        }
                        let s = guards[id]
                        guards[id] = Guard(
                            position: s.position, xOffset: s.xOffset, yOffset: s.yOffset,
                            action: s.action, hasGold: 0, holePos: s.holePos)
                    }
                    enqueueShake(id)
                    addScore(75)  // SCORE_IN_HOLE, guard.js:253-254 — only once landed.
                }
            }
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
                if slots[x][y].current == .runner { phase = .dead }
            }
            if xOffset <= 0 && xOffset > -runnerXMove {
                dropGold(id)
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
                if slots[x][y].current == .runner { phase = .dead }
            }
            if xOffset >= 0 && xOffset < runnerXMove {
                dropGold(id)
            }
        }

        if centerX == .right {
            xOffset += runnerXMove
            if xOffset > 0 { xOffset = 0 }
        }

        let currentGuardAction = guards[id].action
        if resolvedAction == .stop {
            if currentGuardAction != .stop && currentGuardAction != .climbOut {
                let s = guards[id]
                guards[id] = Guard(
                    position: s.position, xOffset: s.xOffset, yOffset: s.yOffset, action: .stop,
                    hasGold: s.hasGold, holePos: s.holePos)
            }
        } else {
            if currentGuardAction == .climbOut {
                resolvedAction = .climbOut
            }
            let s = guards[id]
            guards[id] = Guard(
                position: GridPoint(x: x, y: y), xOffset: xOffset, yOffset: yOffset,
                action: resolvedAction, hasGold: s.hasGold, holePos: s.holePos)
        }

        slots[x][y].current = .guard

        // Gold pickup (guard.js:355-369) — same proximity check as the runner's,
        // plus the hasGold==0 gate (a guard already carrying can't pick up more).
        if slots[x][y].base == .gold && guards[id].hasGold == 0
            && ((xOffset == 0 && yOffset >= 0 && yOffset < TileGeometry.quarterTileHeight)
                || (yOffset == 0 && xOffset >= 0 && xOffset < TileGeometry.quarterTileWidth)
                || (y < TileGeometry.maxTileY && slots[x][y + 1].base == .ladder
                    && yOffset < TileGeometry.quarterTileHeight))
        {
            let s = guards[id]
            guards[id] = Guard(
                position: s.position, xOffset: s.xOffset, yOffset: s.yOffset, action: s.action,
                hasGold: Int.random(in: 12...37), holePos: s.holePos)
            slots[x][y].base = .empty
        }
    }

    // MARK: - dropGold (guard.js:387-418)

    private mutating func dropGold(_ id: Int) {
        let guardState = guards[id]
        switch guardState.hasGold {
        case let n where n > 1:
            guards[id] = Guard(
                position: guardState.position, xOffset: guardState.xOffset,
                yOffset: guardState.yOffset, action: guardState.action, hasGold: n - 1,
                holePos: guardState.holePos)
        case 1:
            let x = guardState.position.x
            let y = guardState.position.y
            // NB: checks .base (structural ground), not .current — matching
            // guard.js:401-403 exactly. A dug-but-not-yet-refilled hole's base is
            // still .brick, so it still counts as solid support here.
            let supported =
                y >= TileGeometry.maxTileY || slots[x][y + 1].base == .brick
                || slots[x][y + 1].base == .solid || slots[x][y + 1].base == .ladder
            if slots[x][y].base == .empty && supported {
                slots[x][y].base = .gold
                guards[id] = Guard(
                    position: guardState.position, xOffset: guardState.xOffset,
                    yOffset: guardState.yOffset, action: guardState.action, hasGold: -1,
                    holePos: guardState.holePos)
            }
            // else: stays 1, retried next centered tick
        case let n where n < 0:
            guards[id] = Guard(
                position: guardState.position, xOffset: guardState.xOffset,
                yOffset: guardState.yOffset, action: guardState.action, hasGold: n + 1,
                holePos: guardState.holePos)
        default:
            break  // hasGold == 0
        }
    }

    // MARK: - Shake queue (guard.js:421-512)

    private mutating func enqueueShake(_ guardIndex: Int) {
        shakingGuards.append(ShakeState(guardIndex: guardIndex, frameIndex: 0, frameTime: -1))
    }

    mutating func processGuardShake() {
        var i = 0
        while i < shakingGuards.count {
            let curIdx = shakingGuards[i].frameIndex
            if shakingGuards[i].frameTime < 0 {
                shakingGuards[i].frameTime = 0
                i += 1
            } else {
                shakingGuards[i].frameTime += 1
                if shakingGuards[i].frameTime >= guardShakeFrameDurations[curIdx] {
                    shakingGuards[i].frameIndex += 1
                    if shakingGuards[i].frameIndex < guardShakeFrameDurations.count {
                        shakingGuards[i].frameTime = 0
                        i += 1
                    } else {
                        let gid = shakingGuards[i].guardIndex
                        shakingGuards.remove(at: i)
                        climbOut(gid)
                        // no i += 1 — the next element has shifted into index i
                    }
                } else {
                    i += 1
                }
            }
        }
    }

    mutating func removeFromShake(_ guardIndex: Int) {
        guard let index = shakingGuards.firstIndex(where: { $0.guardIndex == guardIndex }) else { return }
        shakingGuards.remove(at: index)
    }

    // MARK: - climbOut (guard.js:518-529)

    private mutating func climbOut(_ guardIndex: Int) {
        let guardState = guards[guardIndex]
        guards[guardIndex] = Guard(
            position: guardState.position, xOffset: guardState.xOffset,
            yOffset: guardState.yOffset, action: .climbOut, hasGold: guardState.hasGold,
            holePos: guardState.position)
    }

    // MARK: - Reborn/respawn (guard.js:845-970)

    mutating func guardReborn(at cell: GridPoint) {
        guard let id = guardIndex(at: cell) else { return }

        var bornY = 1
        var bornX = columnPicker.next()
        let rndStart = bornX

        // Bounds-check bornY before every slots access (short-circuiting `&&`) rather
        // than trusting there's always a valid row, the way the JS source's `assert` does.
        while bornY <= TileGeometry.maxTileY
            && (slots[bornX][bornY].current != .empty || slots[bornX][bornY].base == .gold
                || slots[bornX][bornY].base == .brick)
        {
            bornX = columnPicker.next()
            if bornX == rndStart {
                bornY += 1
            }
        }
        guard bornY <= TileGeometry.maxTileY else { return }

        slots[bornX][bornY].current = .guard
        let guardState = guards[id]
        guards[id] = Guard(
            position: GridPoint(x: bornX, y: bornY), xOffset: 0, yOffset: 0, action: .reborn,
            hasGold: guardState.hasGold, holePos: guardState.holePos)
        rebornGuards.append(RebornState(guardIndex: id, frameIndex: 0, frameTime: -1))
    }

    mutating func processReborn() {
        var i = 0
        while i < rebornGuards.count {
            let curIdx = rebornGuards[i].frameIndex
            rebornGuards[i].frameTime += 1
            if rebornGuards[i].frameTime >= guardRebornFrameDurations[curIdx] {
                rebornGuards[i].frameIndex += 1
                if rebornGuards[i].frameIndex < guardRebornFrameDurations.count {
                    rebornGuards[i].frameTime = 0
                    i += 1
                } else {
                    let gid = rebornGuards[i].guardIndex
                    rebornGuards.remove(at: i)
                    rebornComplete(gid)
                    // no i += 1 — the next element has shifted into index i
                }
            } else {
                i += 1
            }
        }
    }

    private mutating func rebornComplete(_ id: Int) {
        let cell = guards[id].position
        if slots[cell.x][cell.y].current == .runner {
            phase = .dead
        }
        slots[cell.x][cell.y].current = .guard
        let guardState = guards[id]
        guards[id] = Guard(
            position: guardState.position, xOffset: guardState.xOffset,
            yOffset: guardState.yOffset, action: .fall, hasGold: guardState.hasGold,
            holePos: guardState.holePos)
    }

    // MARK: - Lookups (guard.js:833-843, runner.js:737-747)

    func guardIndex(at point: GridPoint) -> Int? {
        guards.firstIndex { $0.position == point }
    }

    /// A guard mid-shake/in-hole still counts as "alive" here — only a guard
    /// actively respawning (`.reborn`) doesn't.
    func guardAlive(at point: GridPoint) -> Bool {
        guard let id = guardIndex(at: point) else { return false }
        return guards[id].action != .reborn
    }
}
