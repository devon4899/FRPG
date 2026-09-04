import SwiftUI

/// The compact, widget-safe form of RPGFit's identity seal.
///
/// It deliberately avoids blur and fine engraving so it remains legible in
/// the smallest widget and Dynamic Island-adjacent layouts. The app target
/// owns the richer display treatment; this mark shares its ivory, brass, and
/// growth-green visual grammar without depending on UIKit or app-only code.
struct WidgetBrandMark: View {
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            WidgetCrestLayer(layer: .outline)
                .stroke(
                    WidgetPalette.cream,
                    style: StrokeStyle(
                        lineWidth: max(1.4, size * 0.065),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

            if size >= 28 {
                WidgetCrestLayer(layer: .engraving)
                    .stroke(
                        WidgetPalette.gold,
                        style: StrokeStyle(
                            lineWidth: max(1.1, size * 0.045),
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )

                WidgetCrestLayer(layer: .jewel)
                    .fill(WidgetPalette.xp)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A widget-safe rest mark: an angular ivory time canopy over an open recovery
/// cradle, with a broad brass ember banked between them. Its two simple layers
/// survive the Lock Screen and Dynamic Island without blur or hairline detail.
struct WidgetRestMark: View {
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            WidgetRestLayer(layer: .frame)
                .stroke(
                    WidgetPalette.cream,
                    style: StrokeStyle(
                        lineWidth: max(1.3, size * 0.075),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

            WidgetRestLayer(layer: .ember)
                .fill(WidgetPalette.gold)
        }
        .frame(width: size, height: size)
    }
}

private struct WidgetCrestLayer: Shape {
    enum Layer {
        case outline
        case engraving
        case jewel
    }

    let layer: Layer

    func path(in rect: CGRect) -> Path {
        var design = Path()

        switch layer {
        case .outline:
            design.move(to: CGPoint(x: 18, y: 22))
            design.addLine(to: CGPoint(x: 50, y: 10))
            design.addLine(to: CGPoint(x: 82, y: 22))
            design.addLine(to: CGPoint(x: 82, y: 49))
            design.addCurve(
                to: CGPoint(x: 50, y: 90),
                control1: CGPoint(x: 82, y: 68),
                control2: CGPoint(x: 66, y: 82)
            )
            design.addCurve(
                to: CGPoint(x: 18, y: 49),
                control1: CGPoint(x: 34, y: 82),
                control2: CGPoint(x: 18, y: 68)
            )
            design.closeSubpath()

        case .engraving:
            design.move(to: CGPoint(x: 31, y: 37))
            design.addLine(to: CGPoint(x: 50, y: 55))
            design.addLine(to: CGPoint(x: 69, y: 37))
            design.move(to: CGPoint(x: 38, y: 58))
            design.addLine(to: CGPoint(x: 50, y: 70))
            design.addLine(to: CGPoint(x: 62, y: 58))

        case .jewel:
            design.move(to: CGPoint(x: 50, y: 22))
            design.addLine(to: CGPoint(x: 56, y: 29))
            design.addLine(to: CGPoint(x: 50, y: 36))
            design.addLine(to: CGPoint(x: 44, y: 29))
            design.closeSubpath()
        }

        let scale = min(rect.width, rect.height) / 100
        let dx = rect.midX - 50 * scale
        let dy = rect.midY - 50 * scale
        return design.applying(
            CGAffineTransform(scaleX: scale, y: scale)
                .concatenating(CGAffineTransform(translationX: dx, y: dy))
        )
    }
}

private struct WidgetRestLayer: Shape {
    enum Layer {
        case frame
        case ember
    }

    let layer: Layer

    func path(in rect: CGRect) -> Path {
        var design = Path()

        switch layer {
        case .frame:
            // The tapered upper chamber retains the time metaphor, while the
            // broken lower silhouette reads as recovery rather than duration.
            design.move(to: CGPoint(x: 20, y: 14))
            design.addLine(to: CGPoint(x: 80, y: 14))
            design.move(to: CGPoint(x: 27, y: 17))
            design.addLine(to: CGPoint(x: 33, y: 31))
            design.addLine(to: CGPoint(x: 50, y: 49))
            design.addLine(to: CGPoint(x: 67, y: 31))
            design.addLine(to: CGPoint(x: 73, y: 17))
            design.move(to: CGPoint(x: 20, y: 64))
            design.addLine(to: CGPoint(x: 30, y: 77))
            design.addLine(to: CGPoint(x: 50, y: 86))
            design.addLine(to: CGPoint(x: 70, y: 77))
            design.addLine(to: CGPoint(x: 80, y: 64))

        case .ember:
            // One broad banked ember keeps the brass accent recognizable at
            // sixteen points without relying on grains or internal engraving.
            design.move(to: CGPoint(x: 50, y: 44))
            design.addLine(to: CGPoint(x: 57, y: 52))
            design.addLine(to: CGPoint(x: 63, y: 63))
            design.addLine(to: CGPoint(x: 59, y: 71))
            design.addLine(to: CGPoint(x: 50, y: 76))
            design.addLine(to: CGPoint(x: 41, y: 71))
            design.addLine(to: CGPoint(x: 37, y: 63))
            design.addLine(to: CGPoint(x: 43, y: 52))
            design.closeSubpath()
        }

        let scale = min(rect.width, rect.height) / 100
        let dx = rect.midX - 50 * scale
        let dy = rect.midY - 50 * scale
        return design.applying(
            CGAffineTransform(scaleX: scale, y: scale)
                .concatenating(CGAffineTransform(translationX: dx, y: dy))
        )
    }
}
