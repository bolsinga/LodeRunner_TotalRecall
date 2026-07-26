/// The named entries in `Resources/Tiles.xcassets` — the single source of truth for
/// which sprite assets this module actually bundles, so call sites reference a case
/// (checked at compile time) instead of a bare string that could silently typo or
/// drift from what the catalog really contains.
enum TileAsset: String, CaseIterable {
    case empty
    case brick
    case block
    case ladder
    case rope
    case trap
    case hladder
    case gold
    case guard1
    case runner1
}
