import SwiftUI

/// Player-facing settings modal. Ports the trimmed subset of
/// `lodeRunner.settings.js` that carries over into the port:
///
/// - Sound on/off (JS `setSound`, `settings.js:74`)
/// - Speed step 0..4 (JS `setSpeed`, `settings.js:117`, table `main.js:73`)
/// - HUD mode (JS `settings.setMode()`, `settings.js:147`; renders as
///   "Training on/off" there, "MODE: Score / Stats" here — same
///   underlying `PLAY_CLASSIC` vs `PLAY_MODERN` split)
///
/// Deferred vs. the JS: gamepad (no hardware wiring), color palettes (no
/// palette layer in the port), key repeat toggle (our `KeyboardInput`
/// matches the JS default with no toggle), editor / import / export, and
/// the storage-clear tab.
public struct SettingsOverlay: View {
    @Binding var soundEnabled: Bool
    @Binding var speedIndex: Int
    @Binding var hudMode: HUDMode
    let onClose: () -> Void

    public init(
        soundEnabled: Binding<Bool>,
        speedIndex: Binding<Int>,
        hudMode: Binding<HUDMode>,
        onClose: @escaping () -> Void
    ) {
        _soundEnabled = soundEnabled
        _speedIndex = speedIndex
        _hudMode = hudMode
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("SETTINGS")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(.yellow)

                soundRow
                Divider().background(Color.white.opacity(0.3))
                speedRow
                Divider().background(Color.white.opacity(0.3))
                hudRow

                closeButton
            }
            .padding(24)
            .background(Color.black)
            .overlay(Rectangle().stroke(Color.white, lineWidth: 1))
        }
    }

    private var soundRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SOUND")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
            HStack(spacing: 8) {
                toggleButton("ON", isSelected: soundEnabled) { soundEnabled = true }
                toggleButton("OFF", isSelected: !soundEnabled) { soundEnabled = false }
            }
        }
    }

    /// TRAINING on = modern HUD (@ / # / TIME); off = classic HUD (SCORE
    /// / MEN). Label + wording match the JS `settings.js:147`'s
    /// "Training on/off" toggle verbatim; internally still drives the
    /// same `HUDMode` enum.
    private var hudRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TRAINING")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
            HStack(spacing: 8) {
                toggleButton("ON", isSelected: hudMode == .modern) {
                    hudMode = .modern
                }
                toggleButton("OFF", isSelected: hudMode == .classic) {
                    hudMode = .classic
                }
            }
        }
    }

    private var speedRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SPEED")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(GameSpeed.label(for: speedIndex))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.yellow)
            }
            HStack(spacing: 8) {
                stepperButton("-") {
                    speedIndex = max(0, speedIndex - 1)
                }
                // Visual "dot" indicator for the 5 discrete positions.
                HStack(spacing: 6) {
                    ForEach(0..<GameSpeed.stepCount, id: \.self) { i in
                        Circle()
                            .fill(i == speedIndex ? Color.yellow : Color.white.opacity(0.25))
                            .frame(width: 10, height: 10)
                    }
                }
                .frame(maxWidth: .infinity)
                stepperButton("+") {
                    speedIndex = min(GameSpeed.stepCount - 1, speedIndex + 1)
                }
            }
        }
    }

    private func toggleButton(_ title: String, isSelected: Bool, action: @escaping () -> Void)
        -> some View
    {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(isSelected ? .black : .yellow)
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
                .background(isSelected ? Color.yellow : Color.clear)
                .overlay(Rectangle().stroke(Color.yellow, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func stepperButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(.yellow)
                .frame(width: 32, height: 32)
                .overlay(Rectangle().stroke(Color.yellow, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var closeButton: some View {
        Button {
            onClose()
        } label: {
            Text("CLOSE")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(Color.yellow)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.return, modifiers: [])
    }
}

/// Speed table ported verbatim from JS `main.js:73-75`:
///
/// ```
/// var speedMode = [14, 18, 23, 29, 35];
/// var speedText = ["VERY SLOW", "SLOW", "NORMAL", "FAST", "VERY FAST"];
/// ```
///
/// Index 2 ("NORMAL", 23 FPS) is the JS default. The port's historical
/// default was 30 FPS (`GameSessionDriver.tickPeriod`); switching the
/// default to the JS-canonical 23 FPS would change gameplay feel across
/// every save, so `GameSpeed.defaultIndex` keeps step 3 (29 FPS) — the
/// closest table entry to 30 — as the fallback for first-launch.
public enum GameSpeed {
    /// FPS values, one per step. `Int(1_000_000 / fps)` gives the tick
    /// period in microseconds.
    public static let framesPerSecond: [Int] = [14, 18, 23, 29, 35]
    public static let labels: [String] = [
        "VERY SLOW", "SLOW", "NORMAL", "FAST", "VERY FAST",
    ]
    public static let stepCount: Int = framesPerSecond.count
    /// First-launch default. Step 3 ≈ 30 FPS, matching the port's
    /// pre-settings tick period so existing installs feel unchanged.
    public static let defaultIndex: Int = 3

    public static func label(for index: Int) -> String {
        guard labels.indices.contains(index) else { return labels[defaultIndex] }
        return labels[index]
    }

    /// Tick period for step `index`. Clamps out-of-range values so a stale
    /// stored index (e.g. after a table change) still produces a sane rate.
    public static func tickPeriod(for index: Int) -> Duration {
        let clamped = max(0, min(stepCount - 1, index))
        let fps = framesPerSecond[clamped]
        return .microseconds(1_000_000 / fps)
    }
}

// MARK: - Preview

private struct SettingsPreviewHost: View {
    @State private var sound = true
    @State private var speed = GameSpeed.defaultIndex
    @State private var hudMode: HUDMode = .classic
    var body: some View {
        SettingsOverlay(
            soundEnabled: $sound,
            speedIndex: $speed,
            hudMode: $hudMode,
            onClose: {}
        )
        .frame(width: 500, height: 450)
    }
}

#Preview("Settings overlay") { SettingsPreviewHost() }
