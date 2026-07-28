import ArgumentParser

public struct RunnerCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "runner",
        abstract: """
            Drives a RunnerSimulation from an ad-hoc level and action sequence, for \
            debugging/verifying the runner movement + digging port.
            """,
        discussion: """
            Example: a runner walking onto a ladder and climbing one tile up.

              lr runner \\
                --stamp 4,10,& --stamp 4,11,# \\
                --stamp 5,9,H --stamp 5,10,H --stamp 5,11,H \\
                --actions "right*3,up*3" --ascii
            """
    )

    @Option(name: .customLong("stamp"), help: "A tile stamp \"x,y,ch\" (repeatable). Exactly one '&' stamp is required.")
    var stamps: [String] = []

    @Option(help: "Comma-separated actions, each optionally repeated with *N (e.g. \"right*3,up*5,stop\").")
    var actions: String = ""

    @Flag(help: "Print the grid as ASCII art after the final tick.")
    var ascii = false

    @Flag(help: "Suppress the per-tick state line.")
    var quiet = false

    public init() {}

    public func run() throws {
        let parsedStamps = try stamps.map(parseStamp)
        let level = resolveLevelMap(buildLevelString(stamps: parsedStamps))
        var simulation = try RunnerSimulation(level: level)
        if !quiet {
            print(describe(simulation, tick: 0))
        }

        for (index, action) in try parseActions(actions).enumerated() {
            simulation.tick(action)
            if !quiet {
                print(describe(simulation, tick: index + 1))
            }
        }

        if ascii {
            let currentTiles = simulation.slots.map { column in column.map(\.displayTile) }
            print(currentTiles.formatted(.tileGrid))
        }
    }
}

private func describe(_ simulation: RunnerSimulation, tick: Int) -> String {
    let runner = simulation.runner
    return """
        tick \(tick): pos=(\(runner.position.x),\(runner.position.y)) \
        offset=(\(runner.xOffset),\(runner.yOffset)) action=\(runner.action) \
        phase=\(simulation.phase) gold=\(simulation.goldRemaining) \
        goldComplete=\(simulation.goldComplete) digging=\(simulation.digState != nil) \
        filling=\(simulation.fillStates.count)
        """
}
