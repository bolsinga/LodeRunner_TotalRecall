import SwiftUI

/// Which sprite set to render with. Raw values match the "provides namespace" group
/// names in `Resources/Tiles.xcassets`, so `Theme + TileAsset` composes directly into
/// a catalog lookup path (e.g. `"Apple2/brick"`).
///
/// Ported from `lodeRunner.def.js`'s `THEME_APPLE2`/`THEME_C64`; `.apple2` matches
/// `lodeRunner.main.js`'s default `curTheme`.
public enum Theme: String, CaseIterable, Sendable {
    case apple2 = "Apple2"
    case c64 = "C64"
}

extension EnvironmentValues {
    @Entry public var tileTheme: Theme = .apple2
}
