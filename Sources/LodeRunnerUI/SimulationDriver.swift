import LodeRunnerCore
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

    /// The action to apply on the next tick. In real gameplay this will be
    /// updated from keyboard/gamepad input, mirroring the JS's `keyRunnerAction`
    /// global (`lodeRunner.key.js`); for previews and tests, callers set it
    /// directly.
    public var currentAction: RunnerAction = .stop

    /// 30 Hz to match the JS default (`lodeRunner.preload.js:242`).
    public let tickPeriod: Duration = .microseconds(1_000_000 / 30)

    private var isRunning = false

    public init(
        simulation: RunnerSimulation,
        runnerAppearance: RunnerAppearance = RunnerAppearance()
    ) {
        self.simulation = simulation
        self.runnerAppearance = runnerAppearance
        self.guardAppearances = Array(
            repeating: GuardAppearance(), count: simulation.guards.count)
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
    var cells = Array(repeating: Character(" "), count: LevelGrid.tileCount)
    // Bottom floor
    for x in 0..<LevelGrid.tilesX {
        cells[(LevelGrid.tilesY - 1) * LevelGrid.tilesX + x] = "#"
    }
    // Mid-height platform, cols 8-22, row 10
    for x in 8...22 {
        cells[10 * LevelGrid.tilesX + x] = "#"
    }
    // Runner spawn on the floor
    cells[14 * LevelGrid.tilesX + 3] = "&"
    // Guard spawns on the platform (one facing the runner, one away)
    cells[9 * LevelGrid.tilesX + 12] = "0"
    cells[9 * LevelGrid.tilesX + 18] = "0"
    let level = resolveLevelMap(String(cells))
    return try RunnerSimulation(level: level)
}

private struct WalkingRunnerPreview: View {
    @State private var driver: SimulationDriver

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
        .task {
            driver.currentAction = .right
            await driver.run()
        }
    }

    /// Show `.base` where an entity currently occupies a cell so the static
    /// `runner1`/`guard1` tile in `TileCellView` doesn't ghost behind the
    /// overlaid `RunnerSpriteView`/`GuardSpriteView` during mid-tile motion.
    /// Everywhere else we show `.current` as usual (e.g. dug/filled brick
    /// states).
    private func entityLessTiles(_ slots: [[LevelSlot]]) -> [[TileType]] {
        slots.map { column in
            column.map { slot in
                (slot.current == .runner || slot.current == .guard) ? slot.base : slot.current
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
