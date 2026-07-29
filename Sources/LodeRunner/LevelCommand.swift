import ArgumentParser
import Foundation

public struct LevelCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "level",
        abstract: "Extracts Lode Runner level packs from the project's .js sources into newline-separated text files."
    )

    @Option(help: "Directory containing the lodeRunner.v.*.js source files.")
    var sourceDir: String = "."

    @Option(help: "Directory to write generated <pack>.txt files into.")
    var outputDir: String

    public init() {}

    public func run() async throws {
        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        let sourceDir = self.sourceDir
        let outputDir = self.outputDir

        try await withThrowingTaskGroup(of: Void.self) { group in
            for pack in LevelPackSource.all {
                group.addTask {
                    try Self.process(pack, sourceDir: sourceDir, outputDir: outputDir)
                }
            }
            try await group.waitForAll()
        }
    }

    private static func process(_ pack: LevelPackSource, sourceDir: String, outputDir: String) throws {
        let path = "\(sourceDir)/\(pack.fileName)"
        let js = try String(contentsOfFile: path, encoding: .utf8)
        let rawLevels = try JSLevelExtractor.extractLevels(from: js, variableName: pack.variableName)

        guard rawLevels.count == pack.expectedLevelCount else {
            throw ValidationError(
                "\(pack.fileName): expected \(pack.expectedLevelCount) levels, got \(rawLevels.count)")
        }

        // Parse-validate — catches any corruption in the extracted strings
        // before we ship them as bundled resources — but the shipped file is
        // the raw 448-char text (one level per line), not the parsed struct.
        _ = rawLevels.map(resolveLevelMap)

        let contents = rawLevels.joined(separator: "\n") + "\n"
        let outputPath = "\(outputDir)/\(pack.outputName).txt"
        try contents.write(toFile: outputPath, atomically: true, encoding: .utf8)
        print("wrote \(outputPath) (\(rawLevels.count) levels)")
    }
}
