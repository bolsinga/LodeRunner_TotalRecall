import SwiftUI

/// Arcade-style name-entry display: renders `text` with the same
/// glyph-sheet font as the rest of the board (blue digit variant, matching
/// JS `makeGlyphText(..., "D")` at `hiscore.js:213,326`), with a blinking
/// block cursor after the last character — a port of `CanvasGlyph`'s
/// `GLYPH_FLASH` animation (`preload.js:515-519`) rather than a native
/// caret.
///
/// Display-only: the actual keystroke capture is a real `TextField`
/// elsewhere (`LeaderboardOverlay.nameCapture`), kept out of any scaled or
/// offset coordinate space so focus/click hit-testing keeps working. This
/// view just mirrors that field's live value.
public struct ArcadeNameField: View {
    let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        HStack(spacing: 0) {
            TextRow(text, digitVariant: .blue)
            ArcadeBlinkCursor()
        }
    }

    /// Uppercases and drops any character outside the JS input's allowed
    /// set (`handleStringInput`'s switch at `hiscore.js:632-654`: letters,
    /// digits, '.', '-', space), then caps length at `maxLength`.
    static func sanitize(_ raw: String, maxLength: Int) -> String {
        let allowed = raw.uppercased().filter {
            $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == " "
        }
        return String(allowed.prefix(maxLength))
    }
}

/// Blinking block cursor — port of the `GLYPH_FLASH` glyph animation
/// (frames 42, 42, 43, 43 at `speed: 0.25` on the JS's clock-driven ticker).
/// At the default 23 FPS that's the same ~348 ms half-period as
/// `RunnerBornBlink`, reused here rather than duplicating the constant.
/// Frame 43 is the blank "SPACE" glyph, so toggling opacity on frame 42
/// reproduces the same on/off blink the JS gets from alternating frames.
private struct ArcadeBlinkCursor: View {
    @State private var startDate = Date()

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(startDate)
            SpriteFrame(sheet: .text, index: 42)
                .opacity(
                    RunnerBornBlink.isVisible(
                        atElapsedSeconds: elapsed,
                        togglePeriodSeconds: RunnerBornBlink.jsBlinkTogglePeriodSeconds
                    ) ? 1 : 0
                )
        }
    }
}

// MARK: - Preview

#Preview("Arcade name field — Apple2") {
    ArcadeNameField(text: "ALICE")
        .padding()
        .background(Color.black)
        .environment(\.tileTheme, .apple2)
}

#Preview("Arcade name field — C64") {
    ArcadeNameField(text: "ALICE")
        .padding()
        .background(Color.black)
        .environment(\.tileTheme, .c64)
}
