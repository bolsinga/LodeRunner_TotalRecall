import AVFoundation
import Observation
import SwiftUI

/// Plays short game sound effects on demand. Ported from the `sndArray`/
/// `play*Sound` layer in `lodeRunner.main.js` (`main.js:56-72` catalog +
/// `main.js:882-1043` call sites) — one `AVAudioPlayer` per (theme, effect)
/// pair, lazily loaded on first `play(_:)` and cached so subsequent calls
/// re-trigger without re-decoding the file.
///
/// Not wired into the sim yet — this PR ships only the audio path, with a
/// preview that plays each effect on button tap. Follow-ups will hook this
/// to sim events (gold pickup, death, dig start, level pass, etc.).
@Observable @MainActor
public final class SoundPlayer {
    /// Master mute toggle; a caller-controlled kill switch (e.g. for a future
    /// settings UI or an `AVAudioSession` interruption fallback).
    public var isEnabled: Bool = true

    /// Which theme's asset variant to play. Callers can flip this
    /// independently of the visual theme, but typically it tracks
    /// `\.tileTheme` from the environment.
    public var theme: Theme

    private var players: [CacheKey: AVAudioPlayer] = [:]

    public init(theme: Theme = .apple2) {
        self.theme = theme
    }

    /// Play `effect` for the current `theme`. No-op if `isEnabled == false`
    /// or if the bundled file / decode fails (i.e. audio is best-effort,
    /// never a hard error surface for the game).
    public func play(_ effect: SoundEffect) {
        guard isEnabled else { return }
        let key = CacheKey(theme: theme, effect: effect)
        let player: AVAudioPlayer?
        if let existing = players[key] {
            player = existing
        } else {
            player = Self.makePlayer(theme: theme, effect: effect)
            players[key] = player
        }
        guard let player else { return }
        // Rewind so a rapidly-repeated effect (getGold on consecutive pickups)
        // restarts from frame 0 rather than continuing a still-playing clip.
        player.currentTime = 0
        player.play()
    }

    /// Stop a currently-playing effect. Mirrors `soundStop(soundFall)` in the
    /// JS — used to cut the fall clip on landing so it doesn't ring past the
    /// end of the actual fall (fall.mp3 is ~4s; most falls are a fraction of
    /// that). No-op if the effect was never played or is already stopped.
    public func stop(_ effect: SoundEffect) {
        let key = CacheKey(theme: theme, effect: effect)
        guard let player = players[key] else { return }
        player.stop()
        player.currentTime = 0
    }

    /// Bundle URL for `effect`'s `theme` variant, or `nil` if the file isn't
    /// shipped. Exposed for tests to verify the resource layout without
    /// touching AVFoundation. `nonisolated` because it reads only from the
    /// module bundle (no player state), so tests can hit it off the main
    /// actor.
    public nonisolated static func resourceURL(theme: Theme, effect: SoundEffect) -> URL? {
        Bundle.module.url(
            forResource: effect.rawValue,
            withExtension: "mp3",
            subdirectory: "Sounds/\(theme.rawValue)"
        )
    }

    private static func makePlayer(theme: Theme, effect: SoundEffect) -> AVAudioPlayer? {
        guard let url = resourceURL(theme: theme, effect: effect) else { return nil }
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.prepareToPlay()
        return player
    }

    private struct CacheKey: Hashable {
        let theme: Theme
        let effect: SoundEffect
    }
}

// MARK: - Preview

private struct SoundPlayerPreview: View {
    @Environment(\.tileTheme) private var theme
    @State private var player = SoundPlayer()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Theme: \(theme.rawValue)").font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                ForEach(SoundEffect.allCases, id: \.self) { effect in
                    GridRow {
                        Text(effect.rawValue).monospaced()
                        Button("Play") { player.play(effect) }
                    }
                }
            }
        }
        .padding()
        .onAppear { player.theme = theme }
        .onChange(of: theme) { _, newValue in player.theme = newValue }
    }
}

#Preview("Sound player — Apple2") {
    SoundPlayerPreview().environment(\.tileTheme, .apple2)
}

#Preview("Sound player — C64") {
    SoundPlayerPreview().environment(\.tileTheme, .c64)
}
