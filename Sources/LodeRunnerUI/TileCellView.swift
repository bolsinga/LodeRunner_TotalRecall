import LodeRunnerCore
import SwiftUI

/// Renders a single `TileType` as a fixed-size, `TileGeometry`-sized cell, using the
/// active `Theme`'s sprites (defaults to `.apple2`, matching `lodeRunner.main.js`'s
/// default `curTheme`). One of these per grid position is the base building block
/// for the level view.
///
/// `guard`/`runner` use the single-frame "stop" sprite (`guard1`/`runner1`) rather
/// than the multi-frame animation sheets (`guard.png`/`runner.png`) — frame-slicing
/// for animation is deferred to whenever movement actually drives this view.
public struct TileCellView: View {
    @Environment(\.tileTheme) private var theme

    let tile: TileType

    public init(_ tile: TileType) {
        self.tile = tile
    }

    public var body: some View {
        Image("\(theme.rawValue)/\(tile.asset.rawValue)", bundle: .module)
            .resizable()
            .frame(width: CGFloat(TileGeometry.tileWidth), height: CGFloat(TileGeometry.tileHeight))
    }
}

extension TileType {
    fileprivate var asset: TileAsset {
        switch self {
        case .empty: .empty
        case .brick: .brick
        case .solid: .block
        case .ladder: .ladder
        case .bar: .rope
        case .trap: .trap
        case .hiddenLadder: .hladder
        case .gold: .gold
        case .guard: .guard1
        case .runner: .runner1
        }
    }
}

private struct AllTilesRow: View {
    var body: some View {
        HStack(spacing: 1) {
            ForEach(
                [
                    TileType.empty, .brick, .solid, .ladder, .bar, .trap, .hiddenLadder, .gold,
                    .guard, .runner,
                ], id: \.self
            ) { tile in
                TileCellView(tile)
            }
        }
        .padding()
    }
}

#Preview("Apple2") {
    AllTilesRow().environment(\.tileTheme, .apple2)
}

#Preview("C64") {
    AllTilesRow().environment(\.tileTheme, .c64)
}
