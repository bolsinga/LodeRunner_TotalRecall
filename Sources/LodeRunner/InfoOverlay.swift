import SwiftUI

/// Per-pack facts (release year, platform, publisher, developer,
/// difficulty). Ports the `classicInfo` / `proInfo` / `revengeInfo` /
/// `fanBookInfo` / `championInfo` arrays at `lodeRunner.info.js:1-50`.
public struct PackFact: Identifiable, Sendable {
    public let id: Int
    public let label: String
    public let value: String

    public init(id: Int, label: String, value: String) {
        self.id = id
        self.label = label
        self.value = value
    }
}

extension LevelPack {
    /// Full display name for the info panel — matches the JS "TITLE" row.
    /// The pack-chooser overlay uses the shorter `displayName`.
    var infoTitle: String {
        switch self {
        case .classic: return "Classic Lode Runner"
        case .professional: return "Professional Lode Runner"
        case .revenge: return "Revenge of Lode Runner"
        case .fanBookMod: return "Lode Runner Fan Book"
        case .championship: return "Championship Lode Runner"
        }
    }

    /// Fact rows ported verbatim from JS `info.js:1-50`. Star strings kept
    /// as-is (`★ ★ ★` etc.) since the port renders in a monospace font
    /// that handles Unicode fine.
    var facts: [PackFact] {
        switch self {
        case .classic:
            return [
                PackFact(id: 0, label: "Release year", value: "1983, 1984"),
                PackFact(id: 1, label: "Platform",
                    value: "Apple II, Commodore 64, IBM PC, NES…"),
                PackFact(id: 2, label: "Publisher", value: "Brøderbund & Ariolasoft"),
                PackFact(id: 3, label: "Developer", value: "Douglas E. Smith"),
                PackFact(id: 4, label: "Difficulty", value: "★ ★ ★"),
            ]
        case .professional:
            return [
                PackFact(id: 0, label: "Release year", value: "1984, 1985"),
                PackFact(id: 1, label: "Platform", value: "Commodore 64"),
                PackFact(id: 2, label: "Publisher", value: "DodoSoft & AlphaSoft"),
                PackFact(id: 3, label: "Developer", value: "Unknown"),
                PackFact(id: 4, label: "Difficulty", value: "★ ★ ★ ★"),
            ]
        case .revenge:
            return [
                PackFact(id: 0, label: "Release year", value: "1985, 1986"),
                PackFact(id: 1, label: "Platform", value: "Apple II"),
                PackFact(id: 2, label: "Publisher", value: "Brøderbund"),
                PackFact(id: 3, label: "Developer", value: "Mad Man"),
                PackFact(id: 4, label: "Difficulty", value: "★ ★ ★ ★"),
            ]
        case .fanBookMod:
            return [
                PackFact(id: 0, label: "From",
                    value: "\"Apple Lode Runner - The Remake 2.0\""),
                PackFact(id: 1, label: "Platform", value: "Microsoft Windows"),
                PackFact(id: 2, label: "Publisher", value: "Spoonbill Software"),
                PackFact(id: 3, label: "Developer", value: "Custom levels"),
                PackFact(id: 4, label: "URL",
                    value: "omninet.net.au/~irhumph/loderunner.htm"),
                PackFact(id: 5, label: "Difficulty", value: "★ ★ ★ ★ ★"),
            ]
        case .championship:
            return [
                PackFact(id: 0, label: "Release year", value: "1984, 1985"),
                PackFact(id: 1, label: "Platform",
                    value: "Apple II, Commodore 64, NES…"),
                PackFact(id: 2, label: "Publisher", value: "Brøderbund & Hudson Soft"),
                PackFact(id: 3, label: "Developer", value: "Douglas E. Smith"),
                PackFact(id: 4, label: "Difficulty", value: "★ ★ ★ ★ ★"),
            ]
        }
    }
}

/// Modal that shows the fact table for one pack. Reachable from the
/// pack-chooser overlay's INFO button. Ports the JS "version facts"
/// popover at `settings.js:483-511` (rendered here as a standalone
/// modal in the same black/yellow monospaced style as the other
/// overlays).
public struct InfoOverlay: View {
    let pack: LevelPack
    let onClose: () -> Void

    public init(pack: LevelPack, onClose: @escaping () -> Void) {
        self.pack = pack
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 16) {
                Text(pack.infoTitle.uppercased())
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.yellow)
                    .multilineTextAlignment(.center)
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    ForEach(pack.facts) { fact in
                        GridRow {
                            Text(fact.label.uppercased())
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                            Text(fact.value)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                    }
                }
                closeButton
            }
            .padding(24)
            .frame(minWidth: 400, maxWidth: 560)
            .background(Color.black)
            .overlay(Rectangle().stroke(Color.white, lineWidth: 1))
        }
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

// MARK: - Preview

#Preview("Info — Classic") {
    InfoOverlay(pack: .classic, onClose: {}).frame(width: 700, height: 500)
}

#Preview("Info — Championship") {
    InfoOverlay(pack: .championship, onClose: {}).frame(width: 700, height: 500)
}

#Preview("Info — Fan Book") {
    InfoOverlay(pack: .fanBookMod, onClose: {}).frame(width: 700, height: 500)
}
