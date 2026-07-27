import Foundation

/// Which digit slot in the text sheet a `0`-`9` character maps into. The JS
/// `drawText` takes a `numberType` prefix — `"N"` (default) picks frames 0-9,
/// `"D"` picks 50-59 for the blue player-name digits (`lodeRunner.main.js:842,
/// 849`, `preload.js:557`).
public enum DigitVariant: Sendable {
    case normal  // "N0"-"N9" — orange, frames 0-9
    case blue  // "D0"-"D9" — blue, frames 50-59
}

/// Convert a string into the sequence of `SpriteSheetSpec.text` frame indices
/// needed to render it — a direct port of `drawText`'s switch at
/// `lodeRunner.main.js:837-885`. Unmapped characters fall back to frame 43
/// (the JS's `SPACE` default).
public func textFrames(_ text: String, digitVariant: DigitVariant = .normal) -> [Int] {
    let upper = text.uppercased()
    var frames: [Int] = []
    frames.reserveCapacity(upper.count)
    for scalar in upper.unicodeScalars {
        frames.append(frameIndex(for: scalar, digitVariant: digitVariant))
    }
    return frames
}

private func frameIndex(for scalar: Unicode.Scalar, digitVariant: DigitVariant) -> Int {
    let code = Int(scalar.value)
    switch code {
    case 0x30...0x39:  // '0'..'9'
        let digit = code - 0x30
        return digitVariant == .blue ? (50 + digit) : digit
    case 0x41...0x5A:  // 'A'..'Z'
        return 10 + (code - 0x41)
    case 0x2E: return 36  // '.'
    case 0x3C: return 37  // '<'
    case 0x3E: return 38  // '>'
    case 0x2D: return 39  // '-'
    case 0x40: return 40  // '@' — gold glyph
    case 0x23: return 41  // '#' — trap/hole glyph
    case 0x3A: return 44  // ':'
    case 0x5F: return 45  // '_'
    default: return 43  // JS default: "SPACE"
    }
}
