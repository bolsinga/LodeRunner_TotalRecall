import Observation
import SwiftUI

/// Ticks a `RunnerSimulation` at 30 Hz — the Swift equivalent of
/// `createjs.Ticker.setFPS(30)` + `Ticker.addEventListener("tick", mainTick)`
/// from `lodeRunner.preload.js:242-243` and `lodeRunner.main.js:373-379`. On
/// each tick, applies `currentAction` to the sim (matching the JS's
/// `keyRunnerAction` global read by `playGame`) and then updates the
/// `RunnerAppearance` / `GuardAppearance` snapshots the sprite views observe.
///
/// The sim tick and the sprite frame animation run on separate clocks by
/// design: the sim advances at 30 Hz here, while `AnimatedSprite` cycles
/// frames via its own `TimelineView(.periodic:)` at `RUNNER_SPEED × 30` and
/// `GUARD_SPEED × 30` fps (19.5 / 9 fps). The JS intermixes sim and draw
/// (`runnerMoveStep` sets `sprite.x`/`sprite.y` and calls `gotoAndPlay` inline);
/// the Swift port keeps them separate, so both clocks are needed.
@Observable @MainActor
public final class SimulationDriver {
    public private(set) var simulation: RunnerSimulation
    public private(set) var runnerAppearance: RunnerAppearance
    public private(set) var guardAppearances: [GuardAppearance]

    /// The action applied on each tick when no `input` source is attached.
    /// Callers can also write to this directly (previews with canned action
    /// sequences, deterministic tests); when `input` is non-nil, `tick()`
    /// overwrites this from `input.currentAction` before advancing the sim.
    public var currentAction: RunnerAction = .stop

    /// Optional live input source (`KeyboardInput`, later a gamepad/touch
    /// variant). Polled once per `tick()` — the Swift equivalent of the JS's
    /// `processInputKeyState` read in `lodeRunner.main.js:907`.
    public var input: (any RunnerInput)?

    /// 30 Hz to match the JS default (`lodeRunner.preload.js:242`).
    public let tickPeriod: Duration = .microseconds(1_000_000 / 30)

    private var isRunning = false

    public init(
        simulation: RunnerSimulation,
        runnerAppearance: RunnerAppearance = RunnerAppearance(),
        input: (any RunnerInput)? = nil
    ) {
        self.simulation = simulation
        self.runnerAppearance = runnerAppearance
        self.guardAppearances = Array(
            repeating: GuardAppearance(), count: simulation.guards.count)
        self.input = input
    }

    /// Runs the tick loop until the enclosing task is cancelled. Attach via
    /// `.task { await driver.run() }` in a SwiftUI view; the task's own
    /// cancellation on view teardown stops the loop.
    public func run() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        while !Task.isCancelled {
            tick()
            try? await Task.sleep(for: tickPeriod)
        }
    }

    /// One tick — advance sim, then refresh appearances. Exposed so callers
    /// can step the sim deterministically in tests without the async loop.
    public func tick() {
        if let input {
            currentAction = input.currentAction
        }
        simulation.tick(currentAction)
        let runner = simulation.runner
        let runnerBase = simulation.slots[runner.position.x][runner.position.y].base
        runnerAppearance.update(with: runner, baseTile: runnerBase)
        if guardAppearances.count != simulation.guards.count {
            guardAppearances = Array(
                repeating: GuardAppearance(), count: simulation.guards.count)
        }
        for i in simulation.guards.indices {
            let g = simulation.guards[i]
            let baseTile = simulation.slots[g.position.x][g.position.y].base
            guardAppearances[i].update(with: g, baseTile: baseTile)
        }
    }
}

// MARK: - Preview

/// Bottom floor + a mid-height platform holding two guards, with the runner
/// spawning on the floor below. The platform has no ladder down to the floor,
/// so guard AI (`lodeRunner.guard.js:moveGuard`) can't actually catch the
/// runner — it paces trying — which keeps the preview from freezing on death.
private func walkingPreviewSimulation() throws -> RunnerSimulation {
    var stamps: [(x: Int, y: Int, tile: TileType)] = [
        // Runner spawn on the floor
        (x: 3, y: 14, tile: .runner),
        // Guard spawns on the platform (one facing the runner, one away)
        (x: 12, y: 9, tile: .guard),
        (x: 18, y: 9, tile: .guard),
    ]
    // Mid-height platform, cols 8-22, row 10. (Bottom floor comes from
    // makeLevel's auto-fill of row 15.)
    for x in 8...22 {
        stamps.append((x: x, y: 10, tile: .brick))
    }
    return try RunnerSimulation(level: makeLevel(stamps: stamps))
}

private struct WalkingRunnerPreview: View {
    @State private var driver: SimulationDriver
    @State private var keyboard = KeyboardInput()

    init() {
        // The preview level always contains a runner spawn — safe to unwrap.
        let sim = try! walkingPreviewSimulation()
        _driver = State(initialValue: SimulationDriver(simulation: sim))
    }

    var body: some View {
        FittedBoardView {
            ZStack(alignment: .topLeading) {
                LevelGridView(tiles: entityLessTiles(driver.simulation.slots))
                RunnerSpriteView(
                    runner: driver.simulation.runner,
                    appearance: driver.runnerAppearance
                )
                ForEach(Array(driver.simulation.guards.enumerated()), id: \.offset) { i, guardState in
                    GuardSpriteView(
                        guardState: guardState,
                        appearance: driver.guardAppearances[i]
                    )
                }
            }
        }
        .background(Color.gray.opacity(0.2))
        .border(Color.gray)
        .keyboardInput(keyboard)
        .task {
            driver.input = keyboard
            await driver.run()
        }
    }

    /// Show `.base` where an entity currently occupies a cell so the static
    /// `runner1`/`guard1` tile in `TileCellView` doesn't ghost behind the
    /// overlaid `RunnerSpriteView`/`GuardSpriteView` during mid-tile motion.
    /// Everywhere else we defer to `LevelSlot.displayTile`, which resolves
    /// gold's `.base == .gold, .current == .empty` split back to `.gold`
    /// (rendering purely from `.current` would drop every gold piece). If an
    /// entity happens to be standing on a gold cell, `.base == .gold` still
    /// wins here so the gold stays visible under the overlaid sprite.
    private func entityLessTiles(_ slots: [[LevelSlot]]) -> [[TileType]] {
        slots.map { column in
            column.map { slot in
                if slot.current == .runner || slot.current == .guard {
                    return slot.base
                }
                return slot.displayTile
            }
        }
    }
}

#Preview("Walking runner + guards — Apple2", traits: .landscapeLeft) {
    WalkingRunnerPreview().environment(\.tileTheme, .apple2)
}

#Preview("Walking runner + guards — C64", traits: .landscapeLeft) {
    WalkingRunnerPreview().environment(\.tileTheme, .c64)
}
