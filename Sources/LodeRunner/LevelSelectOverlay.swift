import SwiftUI

/// Grid of level thumbnails for picking a specific level within a pack — port
/// of `lodeRunner.levelSelect.js`'s modal grid plus `lodeRunner.levelThumb.js`'s
/// per-cell tile render.
///
/// Deferred vs. the JS:
/// - **Completion markers** — JS shades cleared levels and shows the score
///   (`levelSelect.js:98-117`). Our port has no persisted high-score store
///   yet, so every cell is always "clickable" and no score is drawn.
/// - **Version dropdown** — JS lets you jump between packs from inside the
///   dialog. Our flow picks pack first (in `PackChooserOverlay`) and then
///   opens level select for that pack, so no dropdown is needed.
/// - **Auto-scroll to current** — JS `showCurrent()` scrolls the active
///   level into view on open. Level select in this port opens *before* a
///   session, so there is no "current level" to scroll to.
public struct LevelSelectOverlay: View {
    let levels: [LevelParseResult]
    let onPick: (Int) -> Void
    let onClose: () -> Void

    public init(
        levels: [LevelParseResult],
        onPick: @escaping (Int) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.levels = levels
        self.onPick = onPick
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 12) {
                header
                ScrollView {
                    LazyVGrid(columns: Self.columns, spacing: 12) {
                        ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                            cell(index: index, level: level)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .frame(maxWidth: 700, maxHeight: 500)
            }
            .padding(20)
            .background(Color.black)
            .overlay(Rectangle().stroke(Color.white, lineWidth: 1))
        }
    }

    private var header: some View {
        HStack {
            Text("SELECT LEVEL")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(.yellow)
            Spacer()
            Button {
                onClose()
            } label: {
                Text("X")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .overlay(Rectangle().stroke(Color.white.opacity(0.7), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 4)
    }

    private func cell(index: Int, level: LevelParseResult) -> some View {
        Button {
            onPick(index)
        } label: {
            VStack(spacing: 4) {
                Text(String(format: "%03d", index + 1))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.yellow)
                LevelThumbnailView(level: level)
                    .overlay(Rectangle().stroke(Color.white.opacity(0.3), lineWidth: 1))
            }
        }
        .buttonStyle(.plain)
    }

    /// Three-column grid at the port's 0.16 thumbnail scale — 1120×704 px
    /// natural × 0.16 ≈ 179 px per thumbnail plus a small gutter fits ~3
    /// columns in the 700 pt panel width. `.adaptive` lets SwiftUI reflow
    /// to two columns on tighter widths without needing platform breakpoints.
    private static let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 190), spacing: 12)
    ]
}

// MARK: - Preview

private func previewLevels() -> [LevelParseResult] {
    // Use the shipped classic pack's first six levels for a realistic
    // preview — synthetic single-tile stamps produce mostly-empty
    // thumbnails that don't exercise the tile art.
    guard let all = try? LevelPack.classic.load() else { return [] }
    return Array(all.prefix(6))
}

#Preview("Level select — Apple2") {
    LevelSelectOverlay(
        levels: previewLevels(),
        onPick: { _ in },
        onClose: {}
    )
    .frame(width: 800, height: 600)
    .environment(\.tileTheme, .apple2)
}

#Preview("Level select — C64") {
    LevelSelectOverlay(
        levels: previewLevels(),
        onPick: { _ in },
        onClose: {}
    )
    .frame(width: 800, height: 600)
    .environment(\.tileTheme, .c64)
}
