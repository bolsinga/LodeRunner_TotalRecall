import SwiftUI

/// Keyboard cheat-sheet modal. Ports the "Keyboard" tab of the JS
/// `helpDialog` at `lodeRunner.help.js:70-119`.
///
/// Deferred vs. the JS: the "Gamepad" tab (`help.js:122-153`) is out of
/// scope — no gamepad support in the port. Editor / trap-reveal / color
/// palette / red-hat toggle rows are also dropped: none map onto the
/// port's actual keybindings (`KeyboardInput.swift`).
public struct HelpOverlay: View {
    let onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("HELP — KEYBOARD")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.yellow)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        moveSection
                        digSection
                    }
                    .padding(.horizontal, 8)
                }
                .frame(maxHeight: 380)

                closeButton
            }
            .padding(24)
            .frame(minWidth: 460, maxWidth: 620)
            .background(Color.black)
            .overlay(Rectangle().stroke(Color.white, lineWidth: 1))
        }
    }

    /// Three clustered layouts — arrows / WASD / IJKL — that share the
    /// classic "inverted T" of directional keys. Ports the JS
    /// `controlSet` clusters at `help.js:38-52,80-83`.
    private var moveSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("MOVE")
            HStack(alignment: .top, spacing: 32) {
                cluster(up: "↑", left: "←", down: "↓", right: "→", label: "arrow keys")
                cluster(up: "W", left: "A", down: "S", right: "D", label: "left hand")
                cluster(up: "I", left: "J", down: "K", right: "L", label: "right hand")
            }
        }
    }

    /// Dig-left/right key pairs. Ports the JS `hk-pair` clusters directly
    /// under the movement clusters at `help.js:47-49`.
    private var digSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("DIG")
            HStack(alignment: .top, spacing: 32) {
                digPair(left: "Z", right: "X")
                digPair(left: "Q", right: "E")
                digPair(left: "U", right: "O")
            }
            #if os(macOS)
            HStack(spacing: 8) {
                Text("ALSO:")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                Text("Y / , = dig left")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white)
                Text("· . = dig right")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white)
            }
            #endif
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(.yellow.opacity(0.85))
    }

    /// Inverted-T movement cluster with a caption below.
    private func cluster(up: String, left: String, down: String, right: String, label: String)
        -> some View
    {
        VStack(spacing: 4) {
            keyCap(up)
            HStack(spacing: 4) {
                keyCap(left)
                keyCap(down)
                keyCap(right)
            }
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    /// Dig-left / dig-right pair with left/right captions below.
    private func digPair(left: String, right: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                keyCap(left)
                keyCap(right)
            }
            HStack(spacing: 4) {
                Text("left")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 34, alignment: .center)
                Text("right")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 34, alignment: .center)
            }
        }
    }

    /// A single keycap glyph — 34×30 outlined box with a monospaced letter.
    /// Same visual weight as the CSS `.hk-k` / `.cap` classes in the JS.
    private func keyCap(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .frame(width: 34, height: 30)
            .overlay(Rectangle().stroke(Color.white.opacity(0.7), lineWidth: 1))
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

#Preview("Help overlay") {
    HelpOverlay(onClose: {}).frame(width: 700, height: 550)
}
