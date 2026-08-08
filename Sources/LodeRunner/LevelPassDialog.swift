import SwiftUI

/// The level-pass scoring dialog — an animated tally of gold collected,
/// guards trapped, and elapsed time that fires between a level's finishing
/// tick and the iris-close transition to the next level. Ports the modern-
/// mode dialog opened at `lodeRunner.main.js:1578-1586` (`case PLAY_MODERN`
/// of `GAME_FINISH`) whose count-up state machine lives in `levelPass.js`.
///
/// Count-up cadence is preserved verbatim from `levelPass.js:25-27`:
/// `COUNT_MS = 85` ms per step, `ADD = 47` per step, `POINT = 100` per step.
/// Three rows animate in order — gold (0 → collected), guards (0 → trapped),
/// time (999 → elapsed, counting DOWN) — with a four-step rest between rows
/// (`levelPass.js:196`). `scoreBell` fires at the start of each row; a
/// `scoreCount` step tick fires per animated increment; `scoreEnding` fires
/// when the last row finishes (`levelPass.js:192,208,250`).
///
/// Deferred vs. the JS:
/// - Party poppers (`levelPass.js:172-186`) — needs a confetti particle
///   system that doesn't exist in the port yet.
/// - HI-SCORE row — the port has no persisted high-score store; the row
///   would always read 000000, so it's omitted.
/// - Replay / level-select buttons — level select isn't wired yet, so the
///   only action is "continue to next level", triggered by tap or any key.
///
/// Callers wire two closures: `onSound` gets each `scoreBell`/`scoreCount`/
/// `scoreEnding` trigger (typically `SoundPlayer.play`), and `onReady`
/// fires when the animation completes so the composition layer can arm
/// keyboard dismiss. Tap-to-dismiss short-circuits via `onDismiss`.
public struct LevelPassDialog: View {
    let summary: LevelPassSummary
    /// Optional previous best score for this level. When non-nil the
    /// HI-SCORE row is shown; when the animated `scoreDisplay` beats it,
    /// the row highlights (JS `levelPass.js:203-206`'s `.beat` class).
    /// `nil` hides the row entirely — the pre-persistence default.
    let hiScore: Int?
    let onSound: (SoundEffect) -> Void
    let onReady: () -> Void
    let onDismiss: () -> Void

    @State private var goldDisplay: Int = 0
    @State private var guardsDisplay: Int = 0
    @State private var timeDisplay: Int = maxTime
    @State private var scoreDisplay: Int = 0
    @State private var animationFinished: Bool = false

    public init(
        summary: LevelPassSummary,
        hiScore: Int? = nil,
        onSound: @escaping (SoundEffect) -> Void = { _ in },
        onReady: @escaping () -> Void = {},
        onDismiss: @escaping () -> Void = {}
    ) {
        self.summary = summary
        self.hiScore = hiScore
        self.onSound = onSound
        self.onReady = onReady
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("LEVEL COMPLETE")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(.yellow)
                Text("LEVEL \(pad3(summary.levelNumber))")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.white)
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    GridRow {
                        glyph(TextGlyph.gold)
                        Text(pad3(goldDisplay)).monospaced().foregroundStyle(.yellow)
                    }
                    GridRow {
                        glyph(TextGlyph.guard)
                        Text(pad3(guardsDisplay)).monospaced().foregroundStyle(.yellow)
                    }
                    GridRow {
                        Text("TIME").foregroundStyle(.white)
                        Text(pad3(timeDisplay)).monospaced().foregroundStyle(.yellow)
                    }
                    GridRow {
                        Text("SCORE").foregroundStyle(.white)
                        Text(pad6(scoreDisplay)).monospaced().foregroundStyle(.yellow)
                    }
                    if let hiScore {
                        GridRow {
                            Text("HI-SCORE").foregroundStyle(.white)
                            Text(pad6(max(hiScore, scoreDisplay)))
                                .monospaced()
                                .foregroundStyle(scoreDisplay > hiScore ? .green : .yellow)
                        }
                    }
                }
                .font(.system(size: 14, design: .monospaced))
                if animationFinished {
                    Text("TAP OR PRESS ANY KEY").font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(24)
            .background(Color.black)
            .overlay(
                Rectangle().stroke(Color.white, lineWidth: 1)
            )
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .task { await runAnimation() }
    }

    /// Drives the three-row count-up with the JS's cadence. Awaits between
    /// steps rather than scheduling `setTimeout` — the schedule collapses
    /// naturally because each `await sleep(85ms)` is the analog of
    /// `later(step, COUNT_MS)` at `levelPass.js:209`.
    private func runAnimation() async {
        // Initial 200 ms hold matches `levelPass.js:243` (`later(..., 200)`
        // that wraps the whole count-up sequence).
        try? await Task.sleep(for: .milliseconds(200))
        await countRow(from: 0, target: summary.goldCollected) { goldDisplay = $0 }
        await countRow(from: 0, target: summary.guardsTrapped) { guardsDisplay = $0 }
        await countRow(from: Self.maxTime, target: summary.secondsElapsed) { timeDisplay = $0 }
        onSound(.scoreEnding)
        animationFinished = true
        onReady()
    }

    /// One row's count-up. Ports `countUp` at `levelPass.js:188-211`. Advances
    /// `cur` toward `target` by at most `add` per step (signed), commits the
    /// step to `apply`, and accumulates the running dialog score at
    /// `point` per unit change. Fires one `scoreBell` before the first step
    /// and one `scoreCount` per step (matching the JS's post-step sound
    /// order at `levelPass.js:208`).
    private func countRow(
        from start: Int,
        target: Int,
        apply: @MainActor (Int) -> Void
    ) async {
        onSound(.scoreBell)
        var cur = start
        let direction = target < start ? -1 : 1
        while cur != target {
            let delta = min(Self.add, abs(target - cur)) * direction
            cur += delta
            scoreDisplay += abs(delta) * Self.point
            apply(cur)
            onSound(.scoreCount)
            try? await Task.sleep(for: .milliseconds(Self.countMs))
        }
        // Four-step rest between rows (`levelPass.js:196`).
        try? await Task.sleep(for: .milliseconds(Self.countMs * 4))
    }

    // JS constants, verbatim from `levelPass.js:25-27`.
    private static let countMs: Int = 85
    private static let add: Int = 47
    private static let point: Int = 100
    /// JS `MAX_TIME_COUNT` from `lodeRunner.def.js:155` — the row's start
    /// value for the DOWN-counting time animation.
    static let maxTime: Int = 999

    private func pad3(_ n: Int) -> String { String(format: "%03d", n) }
    private func pad6(_ n: Int) -> String { String(format: "%06d", n) }

    /// Row-label glyph from the text sprite sheet — GOLD row uses
    /// `TextGlyph.gold`, GUARDS row uses `TextGlyph.guard`. Mirrors the JS
    /// `.lp-glyph-gold` / `.lp-glyph-guard` label swap at
    /// `levelPass.js:89-91` (JS ships a text label for the TIME row too, so
    /// TIME stays as `Text("TIME")` above).
    ///
    /// Native frame is 40×44; the surrounding row text is 14 pt (~10pt
    /// glyph height at monospace). Scale to 24 pt tall — a bit bigger than
    /// the labels but proportional to the JS's 28×44 crop with 0.8x transform
    /// (`levelPass.css:88,95` → ~22 pt effective).
    private func glyph(_ index: Int) -> some View {
        SpriteFrame(sheet: .text, index: index)
            .frame(
                width: CGFloat(TileGeometry.tileWidth),
                height: CGFloat(TileGeometry.tileHeight))
            .scaleEffect(Self.glyphScale)
            .frame(
                width: CGFloat(TileGeometry.tileWidth) * Self.glyphScale,
                height: CGFloat(TileGeometry.tileHeight) * Self.glyphScale)
    }

    /// Same "pin natural size, scale, report scaled size" pattern as
    /// `LevelThumbnailView` — `.scaleEffect` alone doesn't shrink layout,
    /// so bracket it between two `.frame`s.
    private static let glyphScale: CGFloat = 24.0 / CGFloat(TileGeometry.tileHeight)
}

// MARK: - Preview

#Preview("Level pass dialog — short run", traits: .landscapeLeft) {
    LevelPassDialog(
        summary: LevelPassSummary(
            levelNumber: 3, goldCollected: 12, guardsTrapped: 4, secondsElapsed: 421
        )
    )
    .frame(width: 700, height: 400)
    .background(Color.gray.opacity(0.3))
}

#Preview("Level pass dialog — perfect run (999 elapsed)", traits: .landscapeLeft) {
    LevelPassDialog(
        summary: LevelPassSummary(
            levelNumber: 150, goldCollected: 25, guardsTrapped: 0, secondsElapsed: 999
        )
    )
    .frame(width: 700, height: 400)
    .background(Color.gray.opacity(0.3))
}
