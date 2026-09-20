import SwiftUI

/// Styling constants shared by the modal "dialog" overlays
/// (`SettingsOverlay`, `PackChooserOverlay`) so their borders and text
/// sizes stay in sync when either one's chrome gets tuned.
enum OverlayChrome {
    /// Stroke width for every panel and button border across the overlays.
    static let borderWidth: CGFloat = 1
    /// Font size for a muted section header ("LEVEL PACK", "SPEED") or a
    /// toggle's caption label.
    static let secondaryLabelFontSize: CGFloat = 10
    /// Font size for a primary action button's label (CLOSE, PLAY, RESUME,
    /// etc).
    static let buttonFontSize: CGFloat = 12
}
