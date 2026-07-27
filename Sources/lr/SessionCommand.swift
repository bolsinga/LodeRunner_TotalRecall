import ArgumentParser
import LodeRunner

struct SessionCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "session",
        abstract: """
            Drives a GameSession from an ad-hoc level (repeated to form the session's \
            level list) and action sequence, for debugging/verifying lives, level \
            progression, and win/game-over logic.
            """,
        discussion: """
            Example: an adjacent guard kills the runner, retrying the same level.

              lr session \\
                --stamp 5,14,& --stamp 6,14,0 \\
                --actions "right*5"
            """
    )

    @Option(name: .customLong("stamp"), help: "A tile stamp \"x,y,ch\" (repeatable). Exactly one '&' stamp is required.")
    var stamps: [String] = []

    @Option(help: "Repeat this level N times to form the session's level list.")
    var levelCount: Int = 1

    @Option(help: "Comma-separated actions, each optionally repeated with *N (e.g. \"right*3,up*5,stop\").")
    var actions: String = ""

    @Flag(help: "Print the grid as ASCII art after the final tick.")
    var ascii = false

    @Flag(help: "Suppress the per-tick state line.")
    var quiet = false

    func run() throws {
        let parsedStamps = try stamps.map(parseStamp)
        let level = resolveLevelMap(buildLevelString(stamps: parsedStamps))
        var session = try GameSession(levels: Array(repeating: level, count: levelCount))
        if !quiet {
            print(describe(session, tick: 0))
        }

        for (index, action) in try parseActions(actions).enumerated() {
            try session.tick(action)
            if !quiet {
                print(describe(session, tick: index + 1))
            }
        }

        if ascii {
            let currentTiles = session.simulation.slots.map { column in column.map(\.current) }
            print(currentTiles.formatted(.tileGrid))
        }
    }
}

private func describe(_ session: GameSession, tick: Int) -> String {
    let runner = session.simulation.runner
    return """
        tick \(tick): level=\(session.currentLevelIndex) lives=\(session.lives) \
        score=\(session.score) passed=\(session.passedLevelCount) phase=\(session.phase) \
        sim.phase=\(session.simulation.phase) pos=(\(runner.position.x),\(runner.position.y)) \
        action=\(runner.action)
        """
}
