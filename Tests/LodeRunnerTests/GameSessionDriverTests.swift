import Foundation
import Testing

@testable import LodeRunner

@Suite
@MainActor
struct GameSessionDriverTests {
    private func level() -> LevelParseResult {
        makeLevel(stamps: [(x: 5, y: 14, tile: .runner)])
    }

    @Test("init arms .starting by default; tick no-ops until an input arrives")
    func initArmsStartingAndTicksNoOp() throws {
        let session = try GameSession(levels: [level()])
        let input = StubInput(currentAction: .stop)
        let driver = GameSessionDriver(session: session, input: input)

        #expect(driver.session.simulation.phase == .starting)

        // .stop keeps us in .starting.
        for _ in 0..<3 { driver.tick() }
        #expect(driver.session.simulation.phase == .starting)
        #expect(driver.session.simulation.runner.position == GridPoint(x: 5, y: 14))
        #expect(driver.session.simulation.runner.xOffset == 0)

        // First non-.stop input performs the born-blink handoff and moves the runner
        // in the same tick.
        input.currentAction = .right
        driver.tick()
        #expect(driver.session.simulation.phase == .playing)
        #expect(driver.session.simulation.runner.xOffset == 8)
    }

    @Test("startInBornBlink: false leaves the sim in .playing (opt-out path)")
    func startInBornBlinkFalse() throws {
        let session = try GameSession(levels: [level()])
        let input = StubInput(currentAction: .right)
        let driver = GameSessionDriver(
            session: session, input: input, startInBornBlink: false)

        #expect(driver.session.simulation.phase == .playing)
        driver.tick()
        #expect(driver.session.simulation.runner.xOffset == 8)
    }

    @Test("guardAppearances length tracks the level's guard count")
    func guardAppearancesMatchGuardCount() throws {
        let multiGuard = makeLevel(stamps: [
            (x: 5, y: 14, tile: .runner),
            (x: 8, y: 14, tile: .guard),
            (x: 12, y: 14, tile: .guard),
        ])
        let session = try GameSession(levels: [multiGuard])
        let driver = GameSessionDriver(session: session)
        #expect(driver.guardAppearances.count == driver.session.simulation.guards.count)
        #expect(driver.guardAppearances.count == 2)
    }
}

/// Test-only `RunnerInput` — flip `currentAction` between `driver.tick()`
/// calls to drive scripted scenarios deterministically.
@MainActor
private final class StubInput: RunnerInput {
    var currentAction: RunnerAction
    init(currentAction: RunnerAction) {
        self.currentAction = currentAction
    }
}
