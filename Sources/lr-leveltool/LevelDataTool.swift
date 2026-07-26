import ArgumentParser
import Foundation
import LodeRunnerCore

@main
struct LevelDataTool: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lr-leveltool",
        abstract: "Extracts Lode Runner level packs from the project's .js sources into Codable JSON."
    )

    @Option(help: "Directory containing the lodeRunner.v.*.js source files.")
    var sourceDir: String = "."

    @Option(help: "Directory to write generated <pack>.json files into.")
    var outputDir: String

    func run() throws {
        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        for pack in LevelPack.all {
            let path = "\(sourceDir)/\(pack.fileName)"
            let js = try String(contentsOfFile: path, encoding: .utf8)
            let rawLevels = try JSLevelExtractor.extractLevels(from: js, variableName: pack.variableName)

            guard rawLevels.count == pack.expectedLevelCount else {
                throw ValidationError(
                    "\(pack.fileName): expected \(pack.expectedLevelCount) levels, got \(rawLevels.count)")
            }

            let parsed = rawLevels.map(resolveLevelMap)

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(parsed)

            let outputPath = "\(outputDir)/\(pack.outputName).json"
            try data.write(to: URL(fileURLWithPath: outputPath))
            print("wrote \(outputPath) (\(parsed.count) levels)")
        }
    }
}
