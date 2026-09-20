import SwiftUI

/// Player-facing settings modal. Ports the trimmed subset of
/// `lodeRunner.settings.js` that carries over into the port:
///
/// - Sound on/off (JS `setSound`, `settings.js:74`)
/// - Speed step 0..4 (JS `setSpeed`, `settings.js:117`, table `main.js:73`)
/// - HUD mode (JS `settings.setMode()`, `settings.js:147`; renders as
///   "Training on/off" there, "MODE: Score / Stats" here — same
///   underlying `PLAY_CLASSIC` vs `PLAY_MODERN` split)
/// - Repeat actions on/off (JS `toggleRepeatAction`, `key.js:141-151`;
///   see `KeyboardInput.repeatActionsEnabled` for what the two modes mean)
/// - Red hat mode on/off (JS `toggleRedhatMode`, `key.js:170-186`; see
///   `GuardSpriteView.sheet(forHasGold:redhatModeEnabled:)` — the port
///   defaults this off, unlike the JS's on-by-default)
/// - Gamepad on/off (JS `toggleGamepadMode`, `key.js:153-167`; see
///   `GamepadInput.isEnabled` — the port matches the JS's on-by-default)
///
/// Deferred vs. the JS: editor / import / export, and the storage-clear tab.
///
/// **Permanently out of scope** (not just deferred — do not implement):
/// color-palette slots (`Ctrl+1`–`5`, `themeColorChange` at
/// `colorTheme.js:173-193`). JS re-tints the ground-tile bitmaps to one of
/// 5 preset hex colors per theme; it's a cosmetic recolor pipeline with no
/// gameplay effect, and the port has no equivalent tinting layer. Explicit
/// product decision — skip this if it resurfaces in a future gap analysis.
public struct SettingsOverlay: View {
    @Binding var soundEnabled: Bool
    @Binding var speedIndex: Int
    @Binding var hudMode: HUDMode
    @Binding var repeatActionsEnabled: Bool
    @Binding var redhatModeEnabled: Bool
    @Binding var gamepadEnabled: Bool
    let onClose: () -> Void

    public init(
        soundEnabled: Binding<Bool>,
        speedIndex: Binding<Int>,
        hudMode: Binding<HUDMode>,
        repeatActionsEnabled: Binding<Bool>,
        redhatModeEnabled: Binding<Bool>,
        gamepadEnabled: Binding<Bool>,
        onClose: @escaping () -> Void
    ) {
        _soundEnabled = soundEnabled
        _speedIndex = speedIndex
        _hudMode = hudMode
        _repeatActionsEnabled = repeatActionsEnabled
        _redhatModeEnabled = redhatModeEnabled
        _gamepadEnabled = gamepadEnabled
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 10) {
                Text("SETTINGS")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(.yellow)

                speedRow
                Divider().background(Color.white.opacity(0.3))
                toggleRow
                Divider().background(Color.white.opacity(0.3))

                closeButton
            }
            .padding(12)
            .background(Color.black)
            .overlay(Rectangle().stroke(Color.white, lineWidth: 1))
        }
    }

    /// All the plain on/off toggles, packed into a single row — at this
    /// panel width there's plenty of room, and one row is shorter than
    /// stacking them two-per-row. Order matches the original
    /// single-column layout read left-to-right.
    private var toggleRow: some View {
        HStack(alignment: .top, spacing: 16) {
            booleanRow("SOUND", isOn: soundEnabled) { soundEnabled = $0 }
            // TRAINING on = modern HUD (@ / # / TIME); off = classic HUD
            // (SCORE / MEN). Label + wording match the JS
            // `settings.js:147`'s "Training on/off" toggle verbatim;
            // internally still drives the same `HUDMode` enum.
            booleanRow("TRAINING", isOn: hudMode == .modern) {
                hudMode = $0 ? .modern : .classic
            }
            // ON = repeat/"Apple II" mode (held key persists past
            // release); OFF = sticky/"NES" mode (releasing stops), the JS
            // default. Label matches JS `toggleRepeatAction`'s tip text
            // (`key.js:143-147`) verbatim.
            booleanRow("REPEAT ACTIONS", isOn: repeatActionsEnabled) {
                repeatActionsEnabled = $0
            }
            // ON shows a red hat on any guard currently carrying gold
            // (worth trapping to recover it); OFF — the port's default,
            // unlike the JS's on-by-default — leaves gold-carrying guards
            // indistinguishable from empty-handed ones. Label matches JS
            // `toggleRedhatMode`'s tip text (`key.js:179,184`) verbatim.
            booleanRow("RED HAT", isOn: redhatModeEnabled) {
                redhatModeEnabled = $0
            }
            // ON (the JS default) reads connected `GCController` input;
            // OFF makes `GamepadInput` always report `.stop` regardless of
            // controller state. Label matches JS `toggleGamepadMode`'s tip
            // text (`key.js:161,164`) verbatim.
            booleanRow("GAMEPAD", isOn: gamepadEnabled) { gamepadEnabled = $0 }
        }
    }

    private func booleanRow(_ label: String, isOn: Bool, onChange: @escaping (Bool) -> Void)
        -> some View
    {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
            HStack(spacing: 6) {
                toggleButton("ON", isSelected: isOn) { onChange(true) }
                toggleButton("OFF", isSelected: !isOn) { onChange(false) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A single compact, centered control rather than a full-width row —
    /// spreading the "-"/dots/"+" across the panel's whole width (to
    /// match the two edge-anchored labels) looked disconnected once the
    /// panel widened to fit all five toggles on one row below.
    private var speedRow: some View {
        HStack(spacing: 8) {
            Text("SPEED")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
            stepperButton("-") {
                speedIndex = max(0, speedIndex - 1)
            }
            // Visual "dot" indicator for the 5 discrete positions.
            HStack(spacing: 6) {
                ForEach(0..<GameSpeed.stepCount, id: \.self) { i in
                    Circle()
                        .fill(i == speedIndex ? Color.yellow : Color.white.opacity(0.25))
                        .frame(width: 8, height: 8)
                }
            }
            stepperButton("+") {
                speedIndex = min(GameSpeed.stepCount - 1, speedIndex + 1)
            }
            Text(GameSpeed.label(for: speedIndex))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.yellow)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func toggleButton(_ title: String, isSelected: Bool, action: @escaping () -> Void)
        -> some View
    {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(isSelected ? .black : .yellow)
                .padding(.horizontal, 12)
                .padding(.vertical, 3)
                .background(isSelected ? Color.yellow : Color.clear)
                .overlay(Rectangle().stroke(Color.yellow, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func stepperButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.yellow)
                .frame(width: 20, height: 18)
                .overlay(Rectangle().stroke(Color.yellow, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var closeButton: some View {
        Button {
            onClose()
        } label: {
            Text("CLOSE")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 4)
                .background(Color.yellow)
        }
        .buttonStyle(.plain)
        .focusOnAppear()
        #if !os(tvOS)
        .keyboardShortcut(.return, modifiers: [])
        #endif
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
    @State private var repeatActionsEnabled = false
    @State private var redhatModeEnabled = false
    @State private var gamepadEnabled = true
    var body: some View {
        SettingsOverlay(
            soundEnabled: $sound,
            speedIndex: $speed,
            hudMode: $hudMode,
            repeatActionsEnabled: $repeatActionsEnabled,
            redhatModeEnabled: $redhatModeEnabled,
            gamepadEnabled: $gamepadEnabled,
            onClose: {}
        )
        .frame(width: 500, height: 450)
    }
}

#Preview("Settings overlay") { SettingsPreviewHost() }
