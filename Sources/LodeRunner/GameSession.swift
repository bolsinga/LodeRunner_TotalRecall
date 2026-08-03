// RUNNER_LIFE / RUNNER_MAX_LIFE, lodeRunner.def.js:140-141.
private let startingLives = 5
private let maxLives = 100

public enum GameSessionPhase: Equatable, Codable, Sendable {
    case playing
    /// Held after a level-pass while the level-pass dialog animates its
    /// count-up. Ports the JS's `GAME_WAITING` slice at `main.js:1578-1586`
    /// (`case PLAY_MODERN` of `GAME_FINISH`), which parks the state machine
    /// while `levelPass.open()` runs. Cleared by `finalizeScoring()` — which
    /// then transitions to `.transitioning(.levelAdvance)` so the iris wipe
    /// can bookend the sim swap.
    case scoring(LevelPassSummary)
    /// Held between the tick that produced a `.dead`/`.finished` sim and the
    /// caller's `finalizeTransition()` — the JS's `GAME_WAITING` between
    /// `GAME_RUNNER_DEAD`/`GAME_FINISH` and `GAME_NEW_LEVEL` (`main.js:1479-
    /// 1480,1499-1500`). Score/lives/level bookkeeping has already been
    /// applied; only the `simulation` swap is deferred, so the composition
    /// layer can play the iris close/open around the swap.
    case transitioning(TransitionKind)
    case gameOver  // ran out of lives
    case won  // passed every level at least once
}

/// Snapshot of the just-finished level's stats, threaded to the level-pass
/// dialog. Populated at `handleLevelComplete()` from `simulation` + `levels`
/// before the sim is replaced. Ports the `opts` payload of `levelPass.open()`
/// at `lodeRunner.main.js:1581-1585`.
public struct LevelPassSummary: Equatable, Codable, Sendable {
    /// 1-based level number for display (matches JS `curLevel`). The 0-based
    /// index is `levelNumber - 1`; kept as 1-based here because the value is
    /// only ever rendered.
    public let levelNumber: Int
    /// Gold pieces the runner picked up on this attempt of this level.
    public let goldCollected: Int
    /// Guards buried this attempt, capped at 100 in the sim
    /// (`RunnerSimulation.fillComplete`, matching `main.js:832`).
    public let guardsTrapped: Int
    /// Elapsed time in play "seconds" (16 ticks each), capped at 999
    /// (`MAX_TIME_COUNT`, `def.js:155`).
    public let secondsElapsed: Int

    public init(levelNumber: Int, goldCollected: Int, guardsTrapped: Int, secondsElapsed: Int) {
        self.levelNumber = levelNumber
        self.goldCollected = goldCollected
        self.guardsTrapped = guardsTrapped
        self.secondsElapsed = secondsElapsed
    }
}

/// Which cause routed us into `.transitioning`. `currentLevelIndex` is
/// unchanged for `.death` and already-incremented for `.levelAdvance` by the
/// time this phase is entered.
public enum TransitionKind: Equatable, Codable, Sendable {
    case death
    case levelAdvance
}

public enum GameSessionError: Error, Equatable, Sendable, CustomStringConvertible {
    case noLevels
    case startingLevelOutOfRange(index: Int, count: Int)

    public var description: String {
        switch self {
        case .noLevels: return "session requires at least one level"
        case .startingLevelOutOfRange(let index, let count):
            return "startingLevelIndex \(index) is out of range for \(count) levels"
        }
    }
}

/// Owns the multi-attempt/multi-level bookkeeping around a single
/// `RunnerSimulation` attempt: lives, level progression, and win/game-over.
/// Ported from the `PLAY_CLASSIC` branches of `lodeRunner.main.js`'s `gameState`
/// switch (`GAME_RUNNER_DEAD`/`GAME_FINISH`/`GAME_NEW_LEVEL`/`GAME_OVER`/
/// `GAME_WIN`) and `lodeRunner.storage.js`'s `passedLevel` bookkeeping.
public struct GameSession: Equatable, Codable, Sendable {
    public let levels: [LevelParseResult]
    /// 0-based; the JS's `curLevel` is 1-based, shifted here to match Swift array
    /// indexing.
    public private(set) var currentLevelIndex: Int
    public private(set) var passedLevelCount: Int
    public private(set) var lives: Int
    /// Score from *completed* attempts only — add `simulation.score` for the
    /// live running total.
    public private(set) var score: Int
    public private(set) var simulation: RunnerSimulation
    public private(set) var phase: GameSessionPhase

    public init(levels: [LevelParseResult], startingLevelIndex: Int = 0) throws {
        guard !levels.isEmpty else {
            throw GameSessionError.noLevels
        }
        guard levels.indices.contains(startingLevelIndex) else {
            throw GameSessionError.startingLevelOutOfRange(
                index: startingLevelIndex, count: levels.count)
        }
        self.levels = levels
        currentLevelIndex = startingLevelIndex
        passedLevelCount = 0
        lives = startingLives
        score = 0
        simulation = try RunnerSimulation(level: levels[startingLevelIndex])
        phase = .playing
    }

    /// Move the current simulation into `.starting`, gating `tick(_:)` on
    /// the first input. Opt-in for the composition layer that wants the
    /// pre-play born blink (`GameSessionDriver` / `GameView`); direct callers
    /// (CLI, existing tests) skip this and stay in `.playing`.
    public mutating func armBornBlink() {
        simulation.phase = .starting
    }

    /// Passthrough to `RunnerSimulation.beginPlay()` (port of `beginPlay` at
    /// `lodeRunner.main.js:1298-1306`). Safe to call in any phase; no-op
    /// unless the current sim is `.starting`.
    public mutating func beginPlay() {
        simulation.beginPlay()
    }

    public mutating func tick(_ action: RunnerAction) throws {
        guard phase == .playing else { return }
        simulation.tick(action)
        switch simulation.phase {
        case .starting, .playing:
            break
        case .dead:
            try handleDeath()
        case .finished:
            try handleLevelComplete()
        }
    }

    private mutating func handleDeath() throws {
        score += simulation.score
        lives -= 1
        if lives <= 0 {
            phase = .gameOver
        } else {
            phase = .transitioning(.death)
        }
    }

    private mutating func handleLevelComplete() throws {
        score += simulation.score + Score.completeLevel.value
        lives = min(lives + 1, maxLives)
        passedLevelCount += 1
        // Snapshot dialog inputs before the sim is replaced. `goldCollected`
        // comes from the level's initial gold count minus what's still on the
        // board — the sim doesn't retain the parse result so we go through
        // `levels[currentLevelIndex]` here (still the *old* level; the swap
        // happens below).
        let summary = LevelPassSummary(
            levelNumber: currentLevelIndex + 1,
            goldCollected: levels[currentLevelIndex].goldCount - simulation.goldRemaining,
            guardsTrapped: simulation.guardsTrappedCount,
            secondsElapsed: simulation.secondsElapsed
        )
        // `currentLevelIndex == 0` here is the 0-based analog of the JS's `wrap`
        // flag from `incLevel` — correct because, with level-select navigation
        // out of scope, completion is the only way this index ever changes.
        currentLevelIndex = (currentLevelIndex + 1) % levels.count
        phase = .scoring(summary)
    }

    /// Dismiss the level-pass dialog: advance from `.scoring` to
    /// `.transitioning(.levelAdvance)` (or `.won` if this was the last level).
    /// Ports the JS `gameFinishCallback` at `main.js:1584`, which fires after
    /// the modern-mode dialog closes and routes the game into `GAME_NEW_LEVEL`.
    /// No-op unless the current phase is `.scoring`.
    public mutating func finalizeScoring() {
        guard case .scoring = phase else { return }
        // `passedLevelCount >= levels.count` covers both zero- and non-zero
        // starting indexes: it means the player has cleared every level in
        // the pack at least once regardless of where they started. The
        // pre-level-select check gated on `currentLevelIndex == 0` too,
        // which only aligns when the player started at level 0.
        if passedLevelCount >= levels.count {
            phase = .won
        } else {
            phase = .transitioning(.levelAdvance)
        }
    }

    /// Swap `simulation` for a fresh instance of the current level and return
    /// to `.playing`. Ports the swap side of `newLevel()` / `initForPlay()`
    /// (`main.js:1185-1230,1298-1319`) — the piece that the JS runs at the
    /// moment the closing iris hits `r == 0`. The fresh sim is armed into
    /// `.starting` so the runner blinks and waits for the player's first move,
    /// matching the JS's `GAME_START` gate at `main.js:1354,1470-1485`
    /// (`beginPlay` is called at the tail of `openingScreen`). No-op unless
    /// `phase` is `.transitioning`.
    public mutating func finalizeTransition() throws {
        guard case .transitioning = phase else { return }
        simulation = try RunnerSimulation(level: levels[currentLevelIndex])
        simulation.phase = .starting
        phase = .playing
    }
}
