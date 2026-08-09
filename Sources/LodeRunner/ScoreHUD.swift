import SwiftUI

/// Which HUD layout to render. Ports JS's `playMode` split at
/// `lodeRunner.main.js:711-742` (`drawInfo`):
///
/// - **`.classic`** — the `PLAY_CLASSIC`/`PLAY_AUTO`/`PLAY_DEMO` branch:
///   `SCORE 0000000  MEN 000  LEVEL 000`. Cumulative session score +
///   remaining lives + current level.
/// - **`.modern`** — the `PLAY_MODERN`/edit branch: `@ 000  # 000
///   TIME 000  LEVEL 000`. Per-level gold collected (`@`), guards
///   trapped (`#`), and elapsed play time; the session score/lives
///   still track internally but don't render here. Labels are the
///   literal JS chars at `main.js:771,776`.
///
/// The JS toggles between them via `settings.setMode()` at
/// `settings.js:147` (labeled "Training on/off"). Port exposes the same
/// via `SettingsOverlay`'s MODE row.
public enum HUDMode: String, CaseIterable, Sendable {
    case classic
    case modern
}

/// Info-line HUD. Column positions match `main.js:745-853`.
///
/// Classic (`SCORE`/`MEN`/`LEVEL`):
/// - `SCORE` label at col 0, digits at col 5 (7-char padded).
/// - `MEN` label at col 13, digits at col 16 (3-char padded).
///
/// Modern (`@`/`#`/`TIME`/`LEVEL`):
/// - `@` at col 0, gold count at col 1 (3-char padded).
/// - `#` at col 5, guards count at col 6 (3-char padded). JS uses
///   `(5+2/3)*tileW` / `(6+2/3)*tileW` at `main.js:776,836`; the port's
///   tile grid is integer-columned, so we round to col 5/col 6. The
///   fractional offset only matters for glyph-perfect alignment with
///   the JS canvas.
/// - `TIME` label at col 11, digits at col 15 (3-char padded). Same
///   rationale for the col 11 rounding (JS `(11+1/3)*tileW`).
///
/// LEVEL row is identical in both modes: label at col 20, digits at col 25.
public struct ScoreHUD: View {
    let mode: HUDMode
    let score: Int
    let lives: Int
    let level: Int
    let goldCollected: Int
    let guardsTrapped: Int
    let secondsElapsed: Int

    public init(
        mode: HUDMode = .classic,
        score: Int,
        lives: Int,
        level: Int,
        goldCollected: Int = 0,
        guardsTrapped: Int = 0,
        secondsElapsed: Int = 0
    ) {
        self.mode = mode
        self.score = score
        self.lives = lives
        self.level = level
        self.goldCollected = goldCollected
        self.guardsTrapped = guardsTrapped
        self.secondsElapsed = secondsElapsed
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            switch mode {
            case .classic:
                positioned(TextRow("SCORE"), column: 0)
                positioned(TextRow(padded(score, width: 7)), column: 5)
                positioned(TextRow("MEN"), column: 13)
                positioned(TextRow(padded(lives, width: 3)), column: 16)
            case .modern:
                positioned(TextRow("@"), column: 0)
                positioned(TextRow(padded(goldCollected, width: 3)), column: 1)
                positioned(TextRow("#"), column: 5)
                positioned(TextRow(padded(guardsTrapped, width: 3)), column: 6)
                positioned(TextRow("TIME"), column: 11)
                positioned(TextRow(padded(secondsElapsed, width: 3)), column: 15)
            }
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
    /// `("000000" + curScore).slice(-7)` pattern at `main.js:793`.
    private func padded(_ value: Int, width: Int) -> String {
        let raw = String(value)
        return raw.count >= width ? String(raw.suffix(width)) : String(repeating: "0", count: width - raw.count) + raw
    }
}

#Preview("HUD — Classic Apple2", traits: .landscapeLeft) {
    FittedBoardView(boardHeight: CGFloat(TileGeometry.tileHeight)) {
        ScoreHUD(mode: .classic, score: 12345, lives: 3, level: 1)
    }
    .environment(\.tileTheme, .apple2)
}

#Preview("HUD — Modern Apple2", traits: .landscapeLeft) {
    FittedBoardView(boardHeight: CGFloat(TileGeometry.tileHeight)) {
        ScoreHUD(
            mode: .modern, score: 0, lives: 5, level: 42,
            goldCollected: 12, guardsTrapped: 3, secondsElapsed: 421)
    }
    .environment(\.tileTheme, .apple2)
}

#Preview("HUD — Modern C64", traits: .landscapeLeft) {
    FittedBoardView(boardHeight: CGFloat(TileGeometry.tileHeight)) {
        ScoreHUD(
            mode: .modern, score: 0, lives: 5, level: 42,
            goldCollected: 12, guardsTrapped: 3, secondsElapsed: 421)
    }
    .environment(\.tileTheme, .c64)
}
