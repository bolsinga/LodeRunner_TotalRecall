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
        Image("\(theme.rawValue)/\(tile.assetName)", bundle: .module)
            .resizable()
            .frame(width: CGFloat(TileGeometry.tileWidth), height: CGFloat(TileGeometry.tileHeight))
    }
}

extension TileType {
    /// The bundled asset base name used to render this tile. Kept `internal`
    /// (not `fileprivate`) so tests can pin the invariants:
    ///
    /// - `.hiddenLadder` renders as `empty` (JS `buildLevelMap:571-572` draws
    ///   the ladder bitmap with `alpha: 0`). The port's `hladder` PNG is a
    ///   visible white ladder authored for `lodeRunner.edit.js:31` (editor
    ///   palette) — not the gameplay look.
    /// - `.trap` renders as `brick` (JS `themeScreen.js:59-61` picks the brick
    ///   bitmap for `TRAP_T`; the trap-specific look only appears while the
    ///   runner is falling through, via a temporary `alpha:0.5` at
    ///   `runner.js:299`). Same story as `hladder`: the port's `trap` PNG is
    ///   authored for the editor palette, not gameplay.
    var assetName: String {
        switch self {
        case .empty: "empty"
        case .brick: "brick"
        case .solid: "block"
        case .ladder: "ladder"
        case .bar: "rope"
        case .trap: "brick"
        case .hiddenLadder: "empty"
        case .gold: "gold"
        case .guard: "guard1"
        case .runner: "runner1"
        }
    }
}

private struct AllTilesGrid: View {
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(
                [
                    TileType.empty, .brick, .solid, .ladder, .bar, .trap, .hiddenLadder, .gold,
                    .guard, .runner,
                ], id: \.self
            ) { tile in
                TileCellView(tile)
                    .background(Color.gray.opacity(0.2))
                    .border(Color.gray)
            }
        }
        .padding()
    }
}

#Preview("Apple2") {
    AllTilesGrid().environment(\.tileTheme, .apple2)
}

#Preview("C64") {
    AllTilesGrid().environment(\.tileTheme, .c64)
}
