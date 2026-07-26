import Testing

@testable import lr_leveltool

@Test("extracts concatenated string from a comment-free snippet")
func extractsPlainSnippet() {
    let js = """
        var demoData = [
        "AAAA" +
        "BBBB",
        "CCCC"
        ];
        """
    let body = try! JSLevelExtractor.extractArrayBody(from: js, variableName: "demoData")
    #expect(JSLevelExtractor.concatenateStringLiterals(in: body) == "AAAABBBBCCCC")
}

@Test("a // line comment after a quoted string doesn't affect extraction")
func lineCommentIsStripped() {
    let js = """
        var demoData = [
        "AAAA" + // trailing note
        "BBBB"
        ];
        """
    let clean = JSLevelExtractor.stripComments(js)
    let body = try! JSLevelExtractor.extractArrayBody(from: clean, variableName: "demoData")
    #expect(JSLevelExtractor.concatenateStringLiterals(in: body) == "AAAABBBB")
}

@Test("a block comment containing decoy quoted strings is excluded")
func blockCommentWithDecoyQuotesIsExcluded() {
    // Models the real lodeRunner.v.revenge.js situation: a large /* ... */ block
    // containing leftover quoted level-like text that must not be picked up.
    let js = """
        var demoData = [
        "AAAA" +
        "BBBB",
        /*
        "ZZZZ" +
        "YYYY",
        */
        "CCCC"
        ];
        """
    let clean = JSLevelExtractor.stripComments(js)
    let body = try! JSLevelExtractor.extractArrayBody(from: clean, variableName: "demoData")
    #expect(JSLevelExtractor.concatenateStringLiterals(in: body) == "AAAABBBBCCCC")
}

@Test("bracket-matching only captures the named variable's array")
func bracketMatchingIsScopedToNamedVariable() {
    let js = """
        var other = [
        "ZZZZ"
        ];
        var demoData = [
        "AAAA" +
        "BBBB"
        ];
        """
    let clean = JSLevelExtractor.stripComments(js)
    let body = try! JSLevelExtractor.extractArrayBody(from: clean, variableName: "demoData")
    #expect(JSLevelExtractor.concatenateStringLiterals(in: body) == "AAAABBBB")
}

@Test("a concatenated length that isn't a multiple of 448 throws")
func invalidLengthThrows() {
    let js = """
        var demoData = [
        "AAAA"
        ];
        """
    #expect(throws: JSLevelExtractorError.self) {
        try JSLevelExtractor.extractLevels(from: js, variableName: "demoData")
    }
}
