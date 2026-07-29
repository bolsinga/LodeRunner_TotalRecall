import Foundation

/// The shipped level packs, loaded at runtime from the bundled `.txt` files
/// under `Resources/Levels/`. Each raw value matches the file stem generated
/// by the `lr level` CLI (`LevelCommand`) so the extractor and the loader
/// stay in lockstep.
public enum LevelPack: String, CaseIterable, Sendable {
    case classic
    case professional
    case revenge
    case fanBookMod
    case championship

    /// Read the bundled `.txt` for this pack and parse each 448-char line into
    /// a `LevelParseResult`. Trailing newlines / empty tail lines are tolerated
    /// so the on-disk file can end with `\n` without breaking the loader.
    public func load() throws -> [LevelParseResult] {
        guard let url = Bundle.module.url(forResource: rawValue, withExtension: "txt", subdirectory: "Levels") else {
            throw LevelPackError.bundledFileMissing(rawValue)
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        return try lines.enumerated().map { index, line in
            guard line.count == LevelGrid.tileCount else {
                throw LevelPackError.malformedLevelLine(pack: rawValue, index: index, length: line.count)
            }
            return resolveLevelMap(String(line))
        }
    }
}

public enum LevelPackError: Error, Equatable, CustomStringConvertible, Sendable {
    case bundledFileMissing(String)
    case malformedLevelLine(pack: String, index: Int, length: Int)

    public var description: String {
        switch self {
        case .bundledFileMissing(let name):
            return "bundled level pack '\(name).txt' is missing from Resources/Levels"
        case .malformedLevelLine(let pack, let index, let length):
            return "\(pack).txt line \(index) is \(length) chars, expected \(LevelGrid.tileCount)"
        }
    }
}

/// Registry of the level-pack `.js` files shipped in this repo, mirroring
/// the `PACKS` table in `test/level-integrity.test.js` so the extractor tool
/// and the JS tests agree on what "correct" looks like. Only used by
/// `LevelCommand` at build/tooling time — the runtime library reads the
/// bundled `.txt` files via `LevelPack.load()` instead.
struct LevelPackSource: Sendable {
    let fileName: String
    let variableName: String
    let outputName: String
    let expectedLevelCount: Int

    static let all: [LevelPackSource] = [
        .init(
            fileName: "lodeRunner.v.classic.js", variableName: "classicData",
            outputName: "classic", expectedLevelCount: 150),
        .init(
            fileName: "lodeRunner.v.professional.js", variableName: "proData",
            outputName: "professional", expectedLevelCount: 150),
        .init(
            fileName: "lodeRunner.v.revenge.js", variableName: "revengeData",
            outputName: "revenge", expectedLevelCount: 17),
        .init(
            fileName: "lodeRunner.v.fanBookMod.js", variableName: "fanBookData",
            outputName: "fanBookMod", expectedLevelCount: 66),
        .init(
            fileName: "lodeRunner.v.championship.js", variableName: "championData",
            outputName: "championship", expectedLevelCount: 51),
    ]
}
