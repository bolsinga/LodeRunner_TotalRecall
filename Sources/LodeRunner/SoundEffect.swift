/// Catalog of shipped sound effects, keyed by the raw file name (minus
/// extension) so `effect.rawValue` composes directly with the bundled
/// `Resources/Sounds/{Apple2,C64}/<name>.mp3` layout.
///
/// Ported from the `sndArray`/`play*Sound` set in `lodeRunner.main.js` (see
/// `main.js:56-72` for the effect list and `main.js:882-1043` for the call
/// sites): the eight common effects present in both themes ship first;
/// C64-only extras (`goldFinish1-6`, `fall.org`) are deferred.
public enum SoundEffect: String, CaseIterable, Sendable {
    /// Runner spawn / level start (`main.js:1305`).
    case born
    /// Runner death (`main.js:1587`).
    case dead
    /// Dig start (`runner.js:434`).
    case dig
    /// Guard sinking into a hole (`guard.js:227`).
    case down
    /// Runner falling (`runner.js:262`).
    case fall
    /// Gold pickup (`runner.js:315`).
    case getGold
    /// Level complete (`main.js:1610`).
    case pass
    /// Guard buried while still in the hole (`guard.js:257`).
    case trap
}
