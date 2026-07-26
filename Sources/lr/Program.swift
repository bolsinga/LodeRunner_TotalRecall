import ArgumentParser

@main
struct Program: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lr",
        abstract: "Tools for working with Lode Runner level packs and simulations.",
        subcommands: [
            LevelCommand.self,
            RunnerCommand.self,
            SessionCommand.self,
        ]
    )
}
