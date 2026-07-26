import Foundation

extension Array where Element == [TileType] {
    public struct FormatStyle: Codable, Equatable, Hashable, Sendable {
        public init() {}
    }
}

extension Array.FormatStyle: Foundation.FormatStyle where Element == [TileType] {
    /// `value` is `[x][y]` indexed, matching `LevelParseResult.slots`. Rendered
    /// row-major (y outer, x inner), one line per row, joined with newlines.
    public func format(_ value: [[TileType]]) -> String {
        let tilesX = value.count
        let tilesY = tilesX == 0 ? 0 : value[0].count

        var lines: [String] = []
        for y in 0..<tilesY {
            var line = ""
            for x in 0..<tilesX {
                line += value[x][y].formatted(.tile)
            }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }
}

extension Array where Element == [TileType] {
    public func formatted() -> String {
        FormatStyle().format(self)
    }

    public func formatted<F: Foundation.FormatStyle>(_ style: F) -> F.FormatOutput
    where F.FormatInput == [[TileType]] {
        style.format(self)
    }
}

extension FormatStyle where Self == Array<[TileType]>.FormatStyle {
    public static var tileGrid: Self { .init() }
}
