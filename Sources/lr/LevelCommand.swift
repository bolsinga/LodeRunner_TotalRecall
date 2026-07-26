import ArgumentParser
import Foundation
import LodeRunnerCore

struct LevelCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "level",
        abstract: "Extracts Lode Runner level packs from the project's .js sources into Codable JSON."
    )

    @Option(help: "Directory containing the lodeRunner.v.*.js source files.")
    var sourceDir: String = "."

    @Option(help: "Directory to write generated <pack>.json files into.")
    var outputDir: String

    func run() async throws {
        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        let sourceDir = self.sourceDir
        let outputDir = self.outputDir

        try await withThrowingTaskGroup(of: Void.self) { group in
            for pack in LevelPack.all {
                group.addTask {
                    try Self.process(pack, sourceDir: sourceDir, outputDir: outputDir)
                }
            }
            try await group.waitForAll()
        }
    }

    private static func process(_ pack: LevelPack, sourceDir: String, outputDir: String) throws {
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
