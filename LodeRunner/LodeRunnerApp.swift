import LodeRunner
import SwiftUI

/// SwiftUI `@main` entry for the shipped game. Everything gameplay-related
/// lives in the `LodeRunner` package; this target just opens a `WindowGroup`
/// on the pack chooser.
@main
struct LodeRunnerApp: App {
    /// Natural size of the game screen: the 28 × 16 playfield plus one HUD
    /// row, all at 40 × 44 base pixels. Opening the window at this exact size
    /// keeps macOS's rounded corners in the black frame around the board
    /// rather than clipping into the outer tiles when `FittedBoardView`
    /// aspect-fills the window.
    private static let naturalWindowWidth = CGFloat(
        LevelGrid.tilesX * TileGeometry.tileWidth)
    private static let naturalWindowHeight = CGFloat(
        (LevelGrid.tilesY + 1) * TileGeometry.tileHeight)

    var body: some Scene {
        WindowGroup {
            PackChooserView()
        }
        .defaultSize(width: Self.naturalWindowWidth, height: Self.naturalWindowHeight)
        #if os(macOS)
        .windowResizability(.contentSize)
        #endif
    }
}
