import Foundation

extension TileType {
    public struct FormatStyle: Codable, Equatable, Hashable, Sendable {
        public init() {}
    }
}

extension TileType.FormatStyle: Foundation.FormatStyle {
    public func format(_ value: TileType) -> String {
        switch value {
        case .empty: return " "
        case .brick: return "#"
        case .solid: return "@"
        case .ladder: return "H"
        case .bar: return "-"
        case .trap: return "X"
        case .hiddenLadder: return "S"
        case .gold: return "$"
        case .guard: return "0"
        case .runner: return "&"
        }
    }
}

extension TileType {
    public func formatted() -> String {
        Self.FormatStyle().format(self)
    }

    public func formatted<F: Foundation.FormatStyle>(_ style: F) -> F.FormatOutput
    where F.FormatInput == TileType {
        style.format(self)
    }
}

extension FormatStyle where Self == TileType.FormatStyle {
    public static var tile: Self { .init() }
}
