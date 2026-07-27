import LodeRunnerCore
import SwiftUI

/// Renders a string as a horizontal row of glyph tiles from the text sheet.
/// Same character-to-frame mapping the JS's `drawText` uses
/// (`lodeRunner.main.js:837-885`). Each glyph is one tile-width wide, so an
/// N-character string occupies `N × tileWidth` pt.
public struct TextRow: View {
    let text: String
    let digitVariant: DigitVariant

    public init(_ text: String, digitVariant: DigitVariant = .normal) {
        self.text = text
        self.digitVariant = digitVariant
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(textFrames(text, digitVariant: digitVariant).enumerated()), id: \.offset) {
                _, frame in
                SpriteFrame(sheet: .text, index: frame)
            }
        }
    }
}

#Preview("Alphabet — Apple2") {
    VStack(alignment: .leading, spacing: 4) {
        TextRow("ABCDEFGHIJKLM")
        TextRow("NOPQRSTUVWXYZ")
        TextRow("0123456789")
        TextRow("0123456789", digitVariant: .blue)
        TextRow(".<>-@#:_")
    }
    .padding()
    .environment(\.tileTheme, .apple2)
}

#Preview("Alphabet — C64") {
    VStack(alignment: .leading, spacing: 4) {
        TextRow("ABCDEFGHIJKLM")
        TextRow("NOPQRSTUVWXYZ")
        TextRow("0123456789")
        TextRow("0123456789", digitVariant: .blue)
        TextRow(".<>-@#:_")
    }
    .padding()
    .environment(\.tileTheme, .c64)
}
