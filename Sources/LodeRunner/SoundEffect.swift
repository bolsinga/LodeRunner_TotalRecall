/// Catalog of shipped sound effects, keyed by the raw file name (minus
/// extension) so `effect.rawValue` composes directly with the bundled
/// `Resources/Sounds/{Apple2,C64}/<name>.mp3` layout.
///
/// Ported from the `sndArray`/`play*Sound` set in `lodeRunner.main.js` (see
/// `main.js:56-72` for the effect list and `main.js:882-1043` for the call
/// sites). The eight base effects ship for both themes. `goldFinish` is the
/// Apple2 "you got the last gold" clip (JS `runner.js:333`, which reads from
/// a shared `sound/goldFinish.mp3` at the JS root); `goldFinish1..6` are the
/// C64 per-level variants (JS `runner.js:332`, `themeAssets.js:62`).
public enum SoundEffect: String, CaseIterable, Sendable {
    /// Guard reborn (`guard.js:913`, `themeSoundPlay("reborn")`). The JS id is
    /// `"reborn"` but its file stem is `"born"` (`themeAssets.js:28`), so this
    /// case keeps the filename to match the shipped assets.
    case born
    /// Runner death (`main.js:1467`, `themeSoundPlay("dead")`).
    case dead
    /// Dig start (`runner.js:496`, `soundPlay(soundDig)`).
    case dig
    /// Runner landing after a fall (`runner.js:270`, `runner.js:287`,
    /// `themeSoundPlay("down")` — the thump on transition out of `.fall`).
    case down
    /// Runner starts falling (`runner.js:289`, `soundPlay(soundFall)`). The
    /// clip is stopped via `SoundPlayer.stop(.fall)` on the landing/death/
    /// level-pass edges to match the JS `soundStop(soundFall)` calls at
    /// `runner.js:269,286`, `main.js:1465,1615,1621`.
    case fall
    /// Gold pickup (`runner.js:310`, `themeSoundPlay("getGold")`).
    case getGold
    /// Level complete (`main.js:1534`, `soundPlay(soundPass)`).
    case pass
    /// Guard buried while still in the hole (`guard.js:245`,
    /// `themeSoundPlay("trap")`).
    case trap
    /// Apple2 "last gold picked up" flourish (`runner.js:333`). The JS ships
    /// this as a shared `sound/goldFinish.mp3` — the Apple2 asset in this port
    /// is a copy of that shared file.
    case goldFinish
    /// One of six C64 per-level "last gold picked up" clips (`runner.js:332`,
    /// `themeAssets.js:62`). Only shipped for the C64 theme.
    case goldFinish1, goldFinish2, goldFinish3, goldFinish4, goldFinish5, goldFinish6

    /// Sound effects that ship for both themes. Everything else is theme-
    /// specific: `goldFinish` is Apple2-only and `goldFinish1..6` are C64-only.
    public static var commonToBothThemes: [SoundEffect] {
        [.born, .dead, .dig, .down, .fall, .getGold, .pass, .trap]
    }

    /// The variant to play when the last gold is picked up. Ports the
    /// theme-branched selector at `runner.js:331-333`:
    ///
    /// - C64 → `goldFinish{1..6}` picked by `((levelIndex) % 6) + 1`.
    /// - Apple2 → the single shared `goldFinish` clip.
    public static func goldFinish(for theme: Theme, levelIndex: Int) -> SoundEffect {
        switch theme {
        case .c64:
            let variants: [SoundEffect] = [
                .goldFinish1, .goldFinish2, .goldFinish3,
                .goldFinish4, .goldFinish5, .goldFinish6,
            ]
            let n = variants.count
            return variants[((levelIndex % n) + n) % n]
        case .apple2:
            return .goldFinish
        }
    }
}
