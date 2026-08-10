import SwiftUI
import Observation

/// Transient "tip" message flashed over the playfield when the user hits
/// a mid-game hotkey (sound toggle, speed change, training toggle…).
/// Ports the JS `showTipsText(text, time, text1)` at
/// `lodeRunner.main.js:993-1050` — a bold red string on a dark backdrop
/// centered on the playfield, fading linearly to zero opacity over the
/// requested duration. A new tip replaces the previous one (JS
/// `tween… {override:true}` at `main.js:1022-1023`).
@Observable @MainActor
public final class TipsController {
    /// The tip currently on screen (or fading out); `nil` when nothing to
    /// show. `TipsOverlay` observes this and animates its opacity.
    public private(set) var currentTip: Tip?

    /// In-flight fade task. Cancelled when a new tip arrives so the old
    /// one's "clear after duration" doesn't stomp on the replacement.
    private var currentTask: Task<Void, Never>?

    public init() {}

    /// A single flashed message. `id` distinguishes back-to-back tips
    /// with identical text so SwiftUI's `.id(_:)` restarts the fade.
    public struct Tip: Equatable, Identifiable, Sendable {
        public let id: UUID
        public let text: String
        public let duration: TimeInterval
    }

    /// Show `text` for `duration` seconds, then fade to nothing.
    /// Duration defaults to 1.5 s — JS's most common `showTipsText` time
    /// (`key.js:66,208`). Longer messages (e.g. 2.5 s) pass an explicit
    /// value.
    public func show(_ text: String, duration: TimeInterval = 1.5) {
        currentTask?.cancel()
        let tip = Tip(id: UUID(), text: text, duration: duration)
        currentTip = tip
        currentTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard let self, self.currentTip?.id == tip.id else { return }
            self.currentTip = nil
        }
    }
}

/// Renders the current tip. Placement is one big centered label over the
/// board — the JS positions the text at `(canvasBaseW - width) / 2` /
/// `(NO_OF_TILES_Y * tileH - height) / 2` at `main.js:1010-1011`, i.e.
/// horizontally centered and vertically centered within the playfield.
public struct TipsOverlay: View {
    let controller: TipsController

    public init(controller: TipsController) {
        self.controller = controller
    }

    public var body: some View {
        if let tip = controller.currentTip {
            TipView(tip: tip)
                .id(tip.id)
                .allowsHitTesting(false)
        }
    }
}

/// Extracted so the fade `@State` can reset per-tip via `.id(...)` on
/// the parent, which recreates this view (and its `@State`) whenever a
/// new tip arrives.
private struct TipView: View {
    let tip: TipsController.Tip
    @State private var opacity: Double = 1.0

    var body: some View {
        Text(tip.text)
            .font(.system(size: 32, weight: .bold, design: .default))
            .foregroundStyle(Self.foreground)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Self.background)
            .shadow(color: .white.opacity(0.8), radius: 1, x: 2, y: 2)
            .opacity(opacity)
            .onAppear {
                // Fade linearly from 1 → 0 over the full duration. JS
                // does the same at `main.js:1022-1023` with
                // `tweenGet().set({alpha:1}).to({alpha:0}, time)`.
                withAnimation(.linear(duration: tip.duration)) {
                    opacity = 0
                }
            }
    }

    /// JS `#ee1122` at `main.js:1002`.
    static let foreground = Color(
        red: 0xEE / 255.0, green: 0x11 / 255.0, blue: 0x22 / 255.0)
    /// JS `#020722` at `main.js:1015`, alpha 0.8.
    static let background = Color(
        red: 0x02 / 255.0, green: 0x07 / 255.0, blue: 0x22 / 255.0).opacity(0.8)
}

// MARK: - Preview

private struct TipsPreviewHost: View {
    @State private var controller = TipsController()
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                Button("SOUND ON") { controller.show("SOUND ON") }
                Button("NORMAL (1.5 s)") { controller.show("NORMAL") }
                Button("TRAINING ON (2.5 s)") {
                    controller.show("TRAINING ON", duration: 2.5)
                }
                Button("PAUSE (persistent 5 s)") {
                    controller.show("PAUSE", duration: 5.0)
                }
            }
            .buttonStyle(.bordered)
            .tint(.yellow)
            TipsOverlay(controller: controller)
        }
        .frame(width: 700, height: 500)
    }
}

#Preview("Tips overlay") { TipsPreviewHost() }
