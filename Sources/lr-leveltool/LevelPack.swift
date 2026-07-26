/// Registry of the level-pack `.js` files shipped in this repo, mirroring the `PACKS`
/// table in `test/level-integrity.test.js` so the tool and the JS tests agree on what
/// "correct" looks like.
struct LevelPack {
    let fileName: String
    let variableName: String
    let outputName: String
    let expectedLevelCount: Int

    static let all: [LevelPack] = [
        .init(
            fileName: "lodeRunner.v.classic.js", variableName: "classicData",
            outputName: "classic", expectedLevelCount: 150),
        .init(
            fileName: "lodeRunner.v.professional.js", variableName: "proData",
            outputName: "professional", expectedLevelCount: 150),
        .init(
            fileName: "lodeRunner.v.revenge.js", variableName: "revengeData",
            outputName: "revenge", expectedLevelCount: 17),
        .init(
            fileName: "lodeRunner.v.fanBookMod.js", variableName: "fanBookData",
            outputName: "fanBookMod", expectedLevelCount: 66),
        .init(
            fileName: "lodeRunner.v.championship.js", variableName: "championData",
            outputName: "championship", expectedLevelCount: 51),
    ]
}
