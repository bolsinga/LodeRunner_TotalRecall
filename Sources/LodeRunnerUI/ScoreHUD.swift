import LodeRunnerCore
import SwiftUI

/// Info-line HUD showing `SCORE 0000000  MEN 000  LEVEL 000`. Column positions
/// match `lodeRunner.main.js`'s `drawScoreTxt`/`drawLifeTxt`/`drawLevelTxt` and
/// `drawScore` layout (lines 695-765):
///
/// - `SCORE` label at col 0, score digits at col 5, zero-padded to 7 chars.
/// - `MEN` label at col 13, lives digits at col 16, zero-padded to 3 chars.
/// - `LEVEL` label at col 20, level digits at col 25, zero-padded to 3 chars.
///
/// One tile-height tall, `LevelGrid.tilesX` tiles wide — matching the board's
/// column pitch so the HUD lines up cleanly under a `LevelGridView`.
public struct ScoreHUD: View {
    let score: Int
    let lives: Int
    let level: Int

    public init(score: Int, lives: Int, level: Int) {
        self.score = score
        self.lives = lives
        self.level = level
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            positioned(TextRow("SCORE"), column: 0)
            positioned(TextRow(padded(score, width: 7)), column: 5)
            positioned(TextRow("MEN"), column: 13)
            positioned(TextRow(padded(lives, width: 3)), column: 16)
            positioned(TextRow("LEVEL"), column: 20)
            positioned(TextRow(padded(level, width: 3)), column: 25)
        }
        .frame(
            width: CGFloat(LevelGrid.tilesX * TileGeometry.tileWidth),
            height: CGFloat(TileGeometry.tileHeight),
            alignment: .topLeading
        )
    }

    private func positioned<Content: View>(_ content: Content, column: Int) -> some View {
        content.offset(x: CGFloat(column * TileGeometry.tileWidth), y: 0)
    }

    /// Left-pad `value` with `0`s to `width` characters, matching the JS's
    /// `("000000" + curScore).slice(-7)` pattern at `main.js:743`.
    private func padded(_ value: Int, width: Int) -> String {
        let raw = String(value)
        return raw.count >= width ? String(raw.suffix(width)) : String(repeating: "0", count: width - raw.count) + raw
    }
}

#Preview("HUD — Apple2", traits: .landscapeLeft) {
    FittedBoardView(boardHeight: CGFloat(TileGeometry.tileHeight)) {
        ScoreHUD(score: 12345, lives: 3, level: 1)
    }
    .environment(\.tileTheme, .apple2)
}

#Preview("HUD — C64", traits: .landscapeLeft) {
    FittedBoardView(boardHeight: CGFloat(TileGeometry.tileHeight)) {
        ScoreHUD(score: 12345, lives: 3, level: 1)
    }
    .environment(\.tileTheme, .c64)
}

#Preview("HUD — zero state", traits: .landscapeLeft) {
    FittedBoardView(boardHeight: CGFloat(TileGeometry.tileHeight)) {
        ScoreHUD(score: 0, lives: 5, level: 1)
    }
    .environment(\.tileTheme, .apple2)
}
