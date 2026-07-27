import LodeRunner

struct StampParseError: Error, CustomStringConvertible {
    let raw: String
    var description: String { "invalid stamp \"\(raw)\" — expected \"x,y,ch\"" }
}

/// Parse one `--stamp` value ("x,y,ch"), e.g. "5,10,&".
func parseStamp(_ raw: String) throws -> (x: Int, y: Int, ch: Character) {
    let parts = raw.split(separator: ",", maxSplits: 2, omittingEmptySubsequences: false)
    guard parts.count == 3, let x = Int(parts[0]), let y = Int(parts[1]), parts[2].count == 1,
        let ch = parts[2].first
    else {
        throw StampParseError(raw: raw)
    }
    return (x: x, y: y, ch: ch)
}

/// Build a blank 28x16 level string from a set of stamps. Unlike the test helper this
/// package's tests use, there's no implicit floor fill here — what you stamp is what
/// you get, since this is a debugging tool, not a test fixture builder.
func buildLevelString(stamps: [(x: Int, y: Int, ch: Character)]) -> String {
    var cells = Array(repeating: Character(" "), count: LevelGrid.tileCount)
    for stamp in stamps {
        cells[stamp.y * LevelGrid.tilesX + stamp.x] = stamp.ch
    }
    return String(cells)
}

struct ActionParseError: Error, CustomStringConvertible {
    let raw: String
    var description: String { "invalid action \"\(raw)\"" }
}

/// Parse a comma-separated action list, each token optionally repeated with "*N"
/// (e.g. "right*3,up*2,stop"). Case-insensitive action names, matched against
/// `RunnerAction`'s lowercase raw values directly — no separate lookup table needed.
func parseActions(_ raw: String) throws -> [RunnerAction] {
    guard !raw.isEmpty else { return [] }

    var result: [RunnerAction] = []
    for token in raw.split(separator: ",") {
        let pieces = token.split(separator: "*", maxSplits: 1)
        guard let name = pieces.first, let action = RunnerAction(rawValue: name.lowercased())
        else {
            throw ActionParseError(raw: String(token))
        }
        let count = pieces.count == 2 ? Int(pieces[1]) : 1
        guard let count, count > 0 else { throw ActionParseError(raw: String(token)) }
        result.append(contentsOf: Array(repeating: action, count: count))
    }
    return result
}
