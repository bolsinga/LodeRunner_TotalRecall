enum JSLevelExtractorError: Error, CustomStringConvertible {
    case variableNotFound(String)
    case unmatchedBrackets(String)
    case invalidLevelDataLength(String, Int)

    var description: String {
        switch self {
        case .variableNotFound(let name):
            return "could not find 'var \(name)' declaration"
        case .unmatchedBrackets(let name):
            return "unmatched '[' / ']' while scanning '\(name)' array literal"
        case .invalidLevelDataLength(let name, let length):
            return "'\(name)' concatenated level data length \(length) is not a multiple of \(LevelGrid.tileCount)"
        }
    }
}

/// Extracts Lode Runner level strings out of this repo's `lodeRunner.v.*.js` source
/// files, without needing a JS runtime.
///
/// Scoped narrowly to what these specific files actually contain: double-quoted string
/// literals (no escapes, no single-quote strings), `//` and `/* */` comments, and one
/// `var <name> = [ ... ];` array-literal declaration per file. Several packs contain
/// large `/* ... */` block comments with leftover/duplicate level text inside them
/// (confirmed in lodeRunner.v.revenge.js) — comments must be stripped before scanning for
/// quoted strings, or that decoy content gets pulled in.
enum JSLevelExtractor {
    /// Extract every level string declared in `var <variableName> = [ ... ];` within
    /// `source`. Each returned string is exactly `LevelGrid.tileCount` characters.
    static func extractLevels(from source: String, variableName: String) throws -> [String] {
        let clean = stripComments(source)
        let arrayBody = try extractArrayBody(from: clean, variableName: variableName)
        let concatenated = concatenateStringLiterals(in: arrayBody)

        guard concatenated.count % LevelGrid.tileCount == 0 else {
            throw JSLevelExtractorError.invalidLevelDataLength(variableName, concatenated.count)
        }

        var levels: [String] = []
        var remainder = Substring(concatenated)
        while !remainder.isEmpty {
            levels.append(String(remainder.prefix(LevelGrid.tileCount)))
            remainder = remainder.dropFirst(LevelGrid.tileCount)
        }
        return levels
    }

    /// Remove `//` line comments and `/* */` block comments, leaving double-quoted string
    /// literal contents (including their quotes) untouched.
    static func stripComments(_ source: String) -> String {
        enum State {
            case normal
            case inString
            case inLineComment
            case inBlockComment
        }

        var result = ""
        result.reserveCapacity(source.count)

        var state = State.normal
        var iterator = source.makeIterator()
        var pending: Character?

        func next() -> Character? {
            if let value = pending {
                pending = nil
                return value
            }
            return iterator.next()
        }

        while let char = next() {
            switch state {
            case .normal:
                if char == "\"" {
                    state = .inString
                    result.append(char)
                } else if char == "/" {
                    guard let following = next() else {
                        result.append(char)
                        break
                    }
                    if following == "/" {
                        state = .inLineComment
                    } else if following == "*" {
                        state = .inBlockComment
                    } else {
                        result.append(char)
                        pending = following
                    }
                } else {
                    result.append(char)
                }
            case .inString:
                result.append(char)
                if char == "\\" {
                    if let escaped = next() {
                        result.append(escaped)
                    }
                } else if char == "\"" {
                    state = .normal
                }
            case .inLineComment:
                if char == "\n" {
                    state = .normal
                    result.append(char)
                }
            case .inBlockComment:
                if char == "*" {
                    if let following = next() {
                        if following == "/" {
                            state = .normal
                        } else {
                            pending = following
                        }
                    }
                }
            }
        }

        return result
    }

    /// Locate `var <variableName>` then bracket-match from the following `[` to its
    /// matching `]`, returning the span between them (exclusive of the brackets). Scopes
    /// everything downstream to only this pack's array literal, ignoring any other
    /// content elsewhere in the file.
    static func extractArrayBody(from source: String, variableName: String) throws -> Substring {
        guard let declarationRange = source.range(of: "var \(variableName)") else {
            throw JSLevelExtractorError.variableNotFound(variableName)
        }
        guard let openBracketIndex = source[declarationRange.upperBound...].firstIndex(of: "[") else {
            throw JSLevelExtractorError.variableNotFound(variableName)
        }

        var depth = 0
        var index = openBracketIndex
        var closeBracketIndex: String.Index?
        while index < source.endIndex {
            let char = source[index]
            if char == "[" {
                depth += 1
            } else if char == "]" {
                depth -= 1
                if depth == 0 {
                    closeBracketIndex = index
                    break
                }
            }
            index = source.index(after: index)
        }

        guard let closeBracketIndex else {
            throw JSLevelExtractorError.unmatchedBrackets(variableName)
        }

        let bodyStart = source.index(after: openBracketIndex)
        return source[bodyStart..<closeBracketIndex]
    }

    /// Concatenate the contents of every double-quoted string literal in `source`, in
    /// reading order. Safe here because `legalLevelChars` never contains `"`, `,`, `+`,
    /// `[` or `]` — so once comments are gone, every quoted string inside an already
    /// bracket-scoped array body is level content, and the comma/`+`/array structure
    /// connecting them is redundant to parse.
    static func concatenateStringLiterals(in source: Substring) -> String {
        var result = ""
        var index = source.startIndex
        while index < source.endIndex {
            guard source[index] == "\"" else {
                index = source.index(after: index)
                continue
            }
            var scan = source.index(after: index)
            while scan < source.endIndex, source[scan] != "\"" {
                result.append(source[scan])
                scan = source.index(after: scan)
            }
            guard scan < source.endIndex else { break }
            index = source.index(after: scan)
        }
        return result
    }
}
