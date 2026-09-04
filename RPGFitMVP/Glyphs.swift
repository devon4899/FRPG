// Custom vector iconography — every glyph is hand-drawn Path art sharing one
// line language (uniform stroke, round caps/joins, 100×100 design grid), so
// the set stays perfectly consistent, tints to any color, and scales crisply.

import SwiftUI
import UIKit

// MARK: - Glyph catalog

enum RPGGlyph: String, CaseIterable {
    // Attributes
    case sword          // strength
    case mountains      // size
    case bow            // dexterity
    case wing           // agility
    case shield         // endurance
    case potion         // vitality
    // Navigation & sections
    case crest          // character
    case dumbbell       // train
    case scroll         // quests
    case book           // records / history
    case chest          // satchel / inventory
    case compass        // journey
    case chart          // progress
    // Treasure items
    case rune
    case chalice
    case egg
    // Currency & flourish
    case coin
    case spark
    case crown

    /// Glyph geometry in a 100×100 design space.
    fileprivate func designPath() -> Path {
        var p = Path()
        switch self {
        case .sword:
            p.move(to: .init(x: 50, y: 6))
            p.addLine(to: .init(x: 58, y: 18))
            p.addLine(to: .init(x: 58, y: 56))
            p.addLine(to: .init(x: 42, y: 56))
            p.addLine(to: .init(x: 42, y: 18))
            p.closeSubpath()
            p.move(to: .init(x: 30, y: 63))
            p.addLine(to: .init(x: 70, y: 63))
            p.move(to: .init(x: 50, y: 63))
            p.addLine(to: .init(x: 50, y: 80))
            p.addEllipse(in: .init(x: 45, y: 82, width: 10, height: 10))

        case .mountains:
            p.move(to: .init(x: 8, y: 82))
            p.addLine(to: .init(x: 36, y: 34))
            p.addLine(to: .init(x: 50, y: 56))
            p.addLine(to: .init(x: 64, y: 26))
            p.addLine(to: .init(x: 92, y: 82))
            p.closeSubpath()

        case .bow:
            p.move(to: .init(x: 34, y: 12))
            p.addCurve(to: .init(x: 34, y: 88),
                       control1: .init(x: 74, y: 28),
                       control2: .init(x: 74, y: 72))
            p.move(to: .init(x: 34, y: 12))
            p.addLine(to: .init(x: 34, y: 88))
            p.move(to: .init(x: 26, y: 50))
            p.addLine(to: .init(x: 84, y: 50))
            p.move(to: .init(x: 84, y: 50))
            p.addLine(to: .init(x: 72, y: 42))
            p.move(to: .init(x: 84, y: 50))
            p.addLine(to: .init(x: 72, y: 58))

        case .wing:
            p.move(to: .init(x: 14, y: 80))
            p.addCurve(to: .init(x: 86, y: 18),
                       control1: .init(x: 18, y: 36),
                       control2: .init(x: 50, y: 16))
            p.addCurve(to: .init(x: 14, y: 80),
                       control1: .init(x: 76, y: 44),
                       control2: .init(x: 52, y: 62))
            p.closeSubpath()
            p.move(to: .init(x: 28, y: 68))
            p.addCurve(to: .init(x: 72, y: 30),
                       control1: .init(x: 36, y: 48),
                       control2: .init(x: 54, y: 36))

        case .shield:
            p.move(to: .init(x: 22, y: 20))
            p.addLine(to: .init(x: 50, y: 10))
            p.addLine(to: .init(x: 78, y: 20))
            p.addLine(to: .init(x: 78, y: 48))
            p.addCurve(to: .init(x: 50, y: 92),
                       control1: .init(x: 78, y: 68),
                       control2: .init(x: 66, y: 82))
            p.addCurve(to: .init(x: 22, y: 48),
                       control1: .init(x: 34, y: 82),
                       control2: .init(x: 22, y: 68))
            p.closeSubpath()

        case .potion:
            p.move(to: .init(x: 42, y: 10))
            p.addLine(to: .init(x: 58, y: 10))
            p.move(to: .init(x: 44, y: 10))
            p.addLine(to: .init(x: 44, y: 28))
            p.move(to: .init(x: 56, y: 10))
            p.addLine(to: .init(x: 56, y: 28))
            p.move(to: .init(x: 44, y: 28))
            p.addCurve(to: .init(x: 26, y: 64),
                       control1: .init(x: 30, y: 36),
                       control2: .init(x: 24, y: 50))
            p.addCurve(to: .init(x: 50, y: 90),
                       control1: .init(x: 28, y: 80),
                       control2: .init(x: 40, y: 90))
            p.addCurve(to: .init(x: 74, y: 64),
                       control1: .init(x: 60, y: 90),
                       control2: .init(x: 72, y: 80))
            p.addCurve(to: .init(x: 56, y: 28),
                       control1: .init(x: 76, y: 50),
                       control2: .init(x: 70, y: 36))
            p.move(to: .init(x: 28, y: 62))
            p.addLine(to: .init(x: 72, y: 62))

        case .crest:
            p.move(to: .init(x: 22, y: 20))
            p.addLine(to: .init(x: 50, y: 10))
            p.addLine(to: .init(x: 78, y: 20))
            p.addLine(to: .init(x: 78, y: 48))
            p.addCurve(to: .init(x: 50, y: 92),
                       control1: .init(x: 78, y: 68),
                       control2: .init(x: 66, y: 82))
            p.addCurve(to: .init(x: 22, y: 48),
                       control1: .init(x: 34, y: 82),
                       control2: .init(x: 22, y: 68))
            p.closeSubpath()
            p.move(to: .init(x: 36, y: 38))
            p.addLine(to: .init(x: 50, y: 52))
            p.addLine(to: .init(x: 64, y: 38))

        case .dumbbell:
            p.move(to: .init(x: 34, y: 50))
            p.addLine(to: .init(x: 66, y: 50))
            p.move(to: .init(x: 28, y: 30))
            p.addLine(to: .init(x: 28, y: 70))
            p.move(to: .init(x: 17, y: 38))
            p.addLine(to: .init(x: 17, y: 62))
            p.move(to: .init(x: 72, y: 30))
            p.addLine(to: .init(x: 72, y: 70))
            p.move(to: .init(x: 83, y: 38))
            p.addLine(to: .init(x: 83, y: 62))

        case .scroll:
            p.addRoundedRect(in: .init(x: 20, y: 30, width: 60, height: 40),
                             cornerSize: .init(width: 9, height: 9))
            p.move(to: .init(x: 30, y: 30))
            p.addLine(to: .init(x: 30, y: 70))
            p.move(to: .init(x: 70, y: 30))
            p.addLine(to: .init(x: 70, y: 70))
            p.move(to: .init(x: 40, y: 50))
            p.addLine(to: .init(x: 60, y: 50))

        case .book:
            p.move(to: .init(x: 50, y: 24))
            p.addLine(to: .init(x: 50, y: 76))
            p.move(to: .init(x: 50, y: 26))
            p.addCurve(to: .init(x: 16, y: 24),
                       control1: .init(x: 40, y: 18),
                       control2: .init(x: 28, y: 18))
            p.addLine(to: .init(x: 16, y: 72))
            p.addCurve(to: .init(x: 50, y: 76),
                       control1: .init(x: 28, y: 66),
                       control2: .init(x: 40, y: 68))
            p.move(to: .init(x: 50, y: 26))
            p.addCurve(to: .init(x: 84, y: 24),
                       control1: .init(x: 60, y: 18),
                       control2: .init(x: 72, y: 18))
            p.addLine(to: .init(x: 84, y: 72))
            p.addCurve(to: .init(x: 50, y: 76),
                       control1: .init(x: 72, y: 66),
                       control2: .init(x: 60, y: 68))

        case .chest:
            p.move(to: .init(x: 18, y: 46))
            p.addCurve(to: .init(x: 50, y: 18),
                       control1: .init(x: 18, y: 26),
                       control2: .init(x: 34, y: 18))
            p.addCurve(to: .init(x: 82, y: 46),
                       control1: .init(x: 66, y: 18),
                       control2: .init(x: 82, y: 26))
            p.move(to: .init(x: 18, y: 46))
            p.addLine(to: .init(x: 18, y: 74))
            p.addQuadCurve(to: .init(x: 26, y: 82), control: .init(x: 18, y: 82))
            p.addLine(to: .init(x: 74, y: 82))
            p.addQuadCurve(to: .init(x: 82, y: 74), control: .init(x: 82, y: 82))
            p.addLine(to: .init(x: 82, y: 46))
            p.move(to: .init(x: 18, y: 46))
            p.addLine(to: .init(x: 82, y: 46))
            p.move(to: .init(x: 50, y: 46))
            p.addLine(to: .init(x: 50, y: 56))
            p.addEllipse(in: .init(x: 45, y: 56, width: 10, height: 10))

        case .rune:
            p.move(to: .init(x: 50, y: 10))
            p.addLine(to: .init(x: 82, y: 50))
            p.addLine(to: .init(x: 50, y: 90))
            p.addLine(to: .init(x: 18, y: 50))
            p.closeSubpath()
            p.move(to: .init(x: 50, y: 30))
            p.addLine(to: .init(x: 50, y: 70))
            p.move(to: .init(x: 38, y: 50))
            p.addLine(to: .init(x: 62, y: 50))

        case .chalice:
            p.move(to: .init(x: 28, y: 16))
            p.addLine(to: .init(x: 72, y: 16))
            p.move(to: .init(x: 72, y: 16))
            p.addCurve(to: .init(x: 50, y: 52),
                       control1: .init(x: 72, y: 40),
                       control2: .init(x: 62, y: 52))
            p.addCurve(to: .init(x: 28, y: 16),
                       control1: .init(x: 38, y: 52),
                       control2: .init(x: 28, y: 40))
            p.move(to: .init(x: 50, y: 52))
            p.addLine(to: .init(x: 50, y: 74))
            p.move(to: .init(x: 32, y: 82))
            p.addLine(to: .init(x: 68, y: 82))

        case .egg:
            p.move(to: .init(x: 50, y: 10))
            p.addCurve(to: .init(x: 74, y: 62),
                       control1: .init(x: 70, y: 14),
                       control2: .init(x: 78, y: 42))
            p.addCurve(to: .init(x: 26, y: 62),
                       control1: .init(x: 70, y: 86),
                       control2: .init(x: 30, y: 86))
            p.addCurve(to: .init(x: 50, y: 10),
                       control1: .init(x: 22, y: 42),
                       control2: .init(x: 30, y: 14))
            p.closeSubpath()
            p.move(to: .init(x: 34, y: 56))
            p.addLine(to: .init(x: 42, y: 48))
            p.addLine(to: .init(x: 50, y: 56))
            p.addLine(to: .init(x: 58, y: 48))
            p.addLine(to: .init(x: 66, y: 56))

        case .coin:
            p.addEllipse(in: .init(x: 12, y: 12, width: 76, height: 76))
            p.addEllipse(in: .init(x: 28, y: 28, width: 44, height: 44))

        case .spark:
            p.move(to: .init(x: 50, y: 10))
            p.addQuadCurve(to: .init(x: 90, y: 50), control: .init(x: 56, y: 44))
            p.addQuadCurve(to: .init(x: 50, y: 90), control: .init(x: 56, y: 56))
            p.addQuadCurve(to: .init(x: 10, y: 50), control: .init(x: 44, y: 56))
            p.addQuadCurve(to: .init(x: 50, y: 10), control: .init(x: 44, y: 44))
            p.closeSubpath()

        case .crown:
            p.move(to: .init(x: 20, y: 70))
            p.addLine(to: .init(x: 20, y: 38))
            p.addLine(to: .init(x: 37, y: 53))
            p.addLine(to: .init(x: 50, y: 28))
            p.addLine(to: .init(x: 63, y: 53))
            p.addLine(to: .init(x: 80, y: 38))
            p.addLine(to: .init(x: 80, y: 70))
            p.closeSubpath()
            p.move(to: .init(x: 20, y: 80))
            p.addLine(to: .init(x: 80, y: 80))

        case .compass:
            // Ring, a four-point rose, and a hairline needle to the north.
            p.addEllipse(in: .init(x: 12, y: 12, width: 76, height: 76))
            p.move(to: .init(x: 50, y: 22))
            p.addLine(to: .init(x: 58, y: 42))
            p.addLine(to: .init(x: 78, y: 50))
            p.addLine(to: .init(x: 58, y: 58))
            p.addLine(to: .init(x: 50, y: 78))
            p.addLine(to: .init(x: 42, y: 58))
            p.addLine(to: .init(x: 22, y: 50))
            p.addLine(to: .init(x: 42, y: 42))
            p.closeSubpath()
            p.move(to: .init(x: 42, y: 42))
            p.addLine(to: .init(x: 58, y: 58))

        case .chart:
            // A ledger baseline with three rising marks and a climbing line.
            p.move(to: .init(x: 16, y: 82))
            p.addLine(to: .init(x: 84, y: 82))
            p.move(to: .init(x: 28, y: 82))
            p.addLine(to: .init(x: 28, y: 62))
            p.move(to: .init(x: 50, y: 82))
            p.addLine(to: .init(x: 50, y: 48))
            p.move(to: .init(x: 72, y: 82))
            p.addLine(to: .init(x: 72, y: 34))
            p.move(to: .init(x: 22, y: 44))
            p.addLine(to: .init(x: 44, y: 30))
            p.addLine(to: .init(x: 60, y: 38))
            p.addLine(to: .init(x: 80, y: 16))
        }
        return p
    }
}

// MARK: - Shape / view wrappers

struct GlyphShape: Shape {
    let glyph: RPGGlyph

    func path(in rect: CGRect) -> Path {
        let design = glyph.designPath()
        let scale = min(rect.width, rect.height) / 100
        let dx = rect.midX - 50 * scale
        let dy = rect.midY - 50 * scale
        return design.applying(
            CGAffineTransform(scaleX: scale, y: scale)
                .concatenating(CGAffineTransform(translationX: dx, y: dy))
        )
    }
}

/// A stroked glyph at a given point size — the app's equivalent of an SF
/// Symbol, sharing one line weight across the whole set.
struct GlyphIcon: View {
    let glyph: RPGGlyph
    var size: CGFloat = 20
    var tint: Color = .primary
    /// Stroke thickness relative to size; 0.085 visually matches SF medium.
    var weight: CGFloat = 0.085

    var body: some View {
        GlyphShape(glyph: glyph)
            .stroke(tint, style: StrokeStyle(
                lineWidth: max(1, size * weight),
                lineCap: .round,
                lineJoin: .round
            ))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// An attribute icon in that attribute's color by default.
struct StatIcon: View {
    let stat: Stat
    var size: CGFloat = 20
    var tint: Color? = nil

    var body: some View {
        RPGSymbolIcon(
            symbol: stat.rpgSymbol,
            size: size,
            presentation: size < 22 ? .compact : .standard,
            palette: tint.map(RPGSymbolPalette.monochrome) ?? .themed(stat.color)
        )
    }
}

/// A rank insignia whose silhouette advances with the tier. Compact badges
/// remain one-color; cards gain the shared ivory-and-gold engraving.
struct RankIcon: View {
    let tier: RankTier
    var size: CGFloat = 20

    var body: some View {
        RPGSymbolIcon(
            symbol: tier.rpgSymbol,
            size: size,
            presentation: size < 20 ? .compact : .standard,
            palette: .themed(tier.color)
        )
    }
}

/// Renders inventory using its semantic item identity. The standalone-name
/// initializer is retained for placeholders and truly unknown persisted icons,
/// which continue through the legacy glyph/SF Symbol compatibility paths.
struct ItemIcon: View {
    let name: String
    var size: CGFloat = 20
    var tint: Color = .primary
    private let symbol: RPGSymbol?

    init(item: InventoryItem, size: CGFloat = 20, tint: Color = .primary) {
        name = item.iconName
        self.size = size
        self.tint = tint
        symbol = item.rpgSymbol
    }

    init(name: String, size: CGFloat = 20, tint: Color = .primary) {
        self.name = name
        self.size = size
        self.tint = tint
        symbol = nil
    }

    var body: some View {
        if let symbol {
            RPGSymbolIcon(
                symbol: symbol,
                size: size,
                presentation: size < 24 ? .compact : .standard,
                palette: .themed(tint)
            )
        } else if name.hasPrefix("glyph:"), let glyph = RPGGlyph(rawValue: String(name.dropFirst(6))) {
            GlyphIcon(glyph: glyph, size: size, tint: tint)
        } else {
            Image(systemName: name)
                .font(.system(size: size * 0.85, weight: .medium))
                .foregroundColor(tint)
                .accessibilityHidden(true)
        }
    }
}

/// The one way coin amounts are shown: coin glyph + rounded numerals.
struct CoinBadge: View {
    let amount: Int
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: 5) {
            RPGSymbolIcon(
                symbol: .coin,
                size: size,
                presentation: .compact,
                palette: .monochrome(RPGTheme.gold)
            )
            Text("\(amount)")
                .font(RPGTheme.label(size - 1, weight: .bold))
                .monospacedDigit()
                .foregroundColor(.primary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(amount) coins")
    }
}

extension Stat {
    /// Classic RPG iconography per attribute.
    var glyph: RPGGlyph {
        switch self {
        case .size: return .mountains
        case .strength: return .sword
        case .dexterity: return .bow
        case .agility: return .wing
        case .endurance: return .shield
        case .vitality: return .potion
        }
    }
}

// MARK: - Class emblem

/// The dedicated heraldic crest for a class. Every silhouette fuses its two
/// trained attributes, so class identity survives without relying on color or
/// two miniature glyphs.
struct ClassEmblem: View {
    let rpgClass: RPGClass
    var size: CGFloat = 48
    /// Set when the emblem sits on a class-colored background.
    var onTint: Bool = false

    var body: some View {
        RPGSymbolIcon(
            symbol: rpgClass.rpgSymbol,
            size: size,
            presentation: size < 28 ? .compact : (size >= 72 ? .hero : .standard),
            palette: onTint ? .onPlate : .themed(rpgClass.color)
        )
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - UIKit rendering (tab bar)

extension RPGGlyph {
    private static var imageCache: [String: UIImage] = [:]

    /// Renders the glyph as a template UIImage for UIKit-owned surfaces
    /// (the tab bar), so it tints like an SF Symbol.
    func uiImage(pointSize: CGFloat, weight: CGFloat = 0.085) -> UIImage {
        let key = "\(rawValue)-\(pointSize)-\(weight)"
        if let cached = Self.imageCache[key] { return cached }

        let size = CGSize(width: pointSize, height: pointSize)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let path = GlyphShape(glyph: self).path(in: rect.insetBy(dx: pointSize * 0.05, dy: pointSize * 0.05))
            let bezier = UIBezierPath(cgPath: path.cgPath)
            bezier.lineWidth = max(1, pointSize * weight)
            bezier.lineCapStyle = .round
            bezier.lineJoinStyle = .round
            UIColor.black.setStroke()
            ctx.cgContext.setAllowsAntialiasing(true)
            bezier.stroke()
        }.withRenderingMode(.alwaysTemplate)

        Self.imageCache[key] = image
        return image
    }
}
