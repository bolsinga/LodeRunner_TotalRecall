// RUNNER_LIFE / RUNNER_MAX_LIFE, lodeRunner.def.js:140-141.
private let startingLives = 5
private let maxLives = 100

public enum GameSessionPhase: Equatable, Codable, Sendable {
    case playing
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

/// Which cause routed us into `.transitioning`. `currentLevelIndex` is
/// unchanged for `.death` and already-incremented for `.levelAdvance` by the
/// time this phase is entered.
public enum TransitionKind: Equatable, Codable, Sendable {
    case death
    case levelAdvance
}

public enum GameSessionError: Error, Equatable, Sendable, CustomStringConvertible {
    case noLevels

    public var description: String {
        switch self {
        case .noLevels: return "session requires at least one level"
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

    public init(levels: [LevelParseResult]) throws {
        guard !levels.isEmpty else {
            throw GameSessionError.noLevels
        }
        self.levels = levels
        currentLevelIndex = 0
        passedLevelCount = 0
        lives = startingLives
        score = 0
        simulation = try RunnerSimulation(level: levels[0])
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
        // `currentLevelIndex == 0` here is the 0-based analog of the JS's `wrap`
        // flag from `incLevel` — correct because, with level-select navigation
        // out of scope, completion is the only way this index ever changes.
        currentLevelIndex = (currentLevelIndex + 1) % levels.count
        if currentLevelIndex == 0 && passedLevelCount >= levels.count {
            phase = .won
        } else {
            phase = .transitioning(.levelAdvance)
        }
    }

    /// Swap `simulation` for a fresh instance of the current level and return
    /// to `.playing`. Ports the swap side of `newLevel()` / `initForPlay()`
    /// (`main.js:1185-1230,1298-1319`) — the piece that the JS runs at the
    /// moment the closing iris hits `r == 0`. No-op unless `phase` is
    /// `.transitioning`.
    public mutating func finalizeTransition() throws {
        guard case .transitioning = phase else { return }
        simulation = try RunnerSimulation(level: levels[currentLevelIndex])
        phase = .playing
    }
}
