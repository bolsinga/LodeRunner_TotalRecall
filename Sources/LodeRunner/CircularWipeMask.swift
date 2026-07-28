import SwiftUI

/// Solid-black rect with a circular cutout at the center — the mask used by
/// both `LevelPassOverlay` (closing wipe, radius shrinks to 0) and
/// `LevelStartOverlay` (opening wipe, radius grows to `maxRadius`).
///
/// Ports the two-arc draw at `lodeRunner.main.js:1181-1182`/`1283-1284`,
/// where an outer disc of `cycMaxRadius` and an inner disc of `r` are added
/// to a single path and rendered with even-odd fill, punching a hole through
/// the outer disc.
struct CircularWipeMask: View {
    let radius: Double
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Canvas { ctx, size in
            var path = Path(CGRect(origin: .zero, size: size))
            if radius > 0 {
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                path.addEllipse(
                    in: CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                )
            }
            ctx.fill(path, with: .color(.black), style: FillStyle(eoFill: true))
        }
        .frame(width: width, height: height)
    }
}
