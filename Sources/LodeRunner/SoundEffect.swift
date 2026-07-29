/// Catalog of shipped sound effects, keyed by the raw file name (minus
/// extension) so `effect.rawValue` composes directly with the bundled
/// `Resources/Sounds/{Apple2,C64}/<name>.mp3` layout.
///
/// Ported from the `sndArray`/`play*Sound` set in `lodeRunner.main.js` (see
/// `main.js:56-72` for the effect list and `main.js:882-1043` for the call
/// sites): the eight common effects present in both themes ship first;
/// C64-only extras (`goldFinish1-6`, `fall.org`) are deferred.
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
}
