import LodeRunnerCore
import Testing

@testable import lr_runnertool

@Test("parseStamp parses a well-formed \"x,y,ch\" value")
func parseStampParsesWellFormed() throws {
    let stamp = try parseStamp("5,10,&")
    #expect(stamp.x == 5)
    #expect(stamp.y == 10)
    #expect(stamp.ch == "&")
}

@Test("parseStamp rejects a malformed value")
func parseStampRejectsMalformed() {
    #expect(throws: StampParseError.self) { try parseStamp("bad") }
    #expect(throws: StampParseError.self) { try parseStamp("5,10") }
    #expect(throws: StampParseError.self) { try parseStamp("x,10,&") }
    #expect(throws: StampParseError.self) { try parseStamp("5,10,##") }
}

@Test("buildLevelString stamps characters at the right flat index")
func buildLevelStringStampsCorrectly() {
    let level = buildLevelString(stamps: [(x: 5, y: 10, ch: "&")])
    #expect(level.count == LevelGrid.tileCount)
    let index = level.index(level.startIndex, offsetBy: 10 * LevelGrid.tilesX + 5)
    #expect(level[index] == "&")
}

@Test("parseActions expands repeated tokens and is case-insensitive")
func parseActionsExpandsRepeats() throws {
    let actions = try parseActions("Right*3,up*2,STOP")
    #expect(actions == [.right, .right, .right, .up, .up, .stop])
}

@Test("parseActions returns an empty list for an empty string")
func parseActionsEmptyString() throws {
    #expect(try parseActions("") == [])
}

@Test("parseActions rejects an unknown action name")
func parseActionsRejectsUnknown() {
    #expect(throws: ActionParseError.self) { try parseActions("sprint") }
}

@Test("parseActions rejects a non-positive repeat count")
func parseActionsRejectsBadCount() {
    #expect(throws: ActionParseError.self) { try parseActions("right*0") }
    #expect(throws: ActionParseError.self) { try parseActions("right*-1") }
}
