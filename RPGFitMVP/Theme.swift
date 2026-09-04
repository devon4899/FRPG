// RPGFit visual system — single source of truth for colors, typography,
// panel surfaces, buttons, and shared UI primitives.
//
// Direction (2026-09-01 overhaul): premium, mature, minimalist fantasy.
// Materials, not ornament: parchment and charcoal canvases, brass hairlines,
// forest-green action plates, ink text. Serif is ceremonial (screen titles,
// names, ranks); training data is sans with tabular numerals. One flourish
// per screen. No drop shadows on panels — surfaces read as engraved plates.

import SwiftUI
import UIKit

// MARK: - Adaptive color helper

extension Color {
    /// A color that resolves differently in light and dark mode.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

// MARK: - Theme

enum RPGTheme {
    /// Brass — the app's interactive tint (links, selection, tab bar).
    /// AA on both parchment canvases; warm, never neon, in the dark keep.
    static let accent = Color(
        light: Color(red: 0.45, green: 0.33, blue: 0.08),
        dark: Color(red: 0.85, green: 0.70, blue: 0.40)
    )

    // MARK: Canvas & surfaces
    // Light mode reads as an aged-parchment character sheet; dark mode as a
    // charcoal keep lit by brass. All panels sit on these, never on system
    // grouped backgrounds.

    /// Screen background.
    static let canvas = Color(
        light: Color(red: 0.945, green: 0.922, blue: 0.867),
        dark: Color(red: 0.078, green: 0.080, blue: 0.105)
    )

    /// Panel surface.
    static let surface = Color(
        light: Color(red: 0.980, green: 0.966, blue: 0.930),
        dark: Color(red: 0.118, green: 0.120, blue: 0.150)
    )

    /// Inset surface — input fields, tracks, chips inside panels.
    static let surfaceInner = Color(
        light: Color(red: 0.918, green: 0.890, blue: 0.826),
        dark: Color(red: 0.160, green: 0.162, blue: 0.198)
    )

    /// Brass hairline for panel borders, rules, and ornaments.
    static let frame = Color(
        light: Color(red: 0.66, green: 0.53, blue: 0.28),
        dark: Color(red: 0.64, green: 0.52, blue: 0.30)
    )

    /// Opacity every hairline is drawn at — one weight of line across the app.
    static let hairline: Double = 0.26

    /// Fixed parchment cream — inlays, labels on plates and seals.
    static let cream = Color(red: 0.97, green: 0.94, blue: 0.87)

    // MARK: Symbol palette

    /// The bright rail of a custom RPG symbol. On parchment it becomes dark
    /// engraved ink; in the keep it resolves to warm ivory.
    static let symbolPrimary = Color(
        light: Color(red: 0.29, green: 0.23, blue: 0.14),
        dark: Color(red: 0.97, green: 0.94, blue: 0.87)
    )

    /// The inner metal line and small ornamental details of a symbol.
    static let symbolSecondary = Color(
        light: Color(red: 0.49, green: 0.34, blue: 0.07),
        dark: Color(red: 0.88, green: 0.71, blue: 0.37)
    )

    /// The rare living accent inside a symbol: growth, completion, or focus.
    /// It is deliberately subordinate to the ivory-and-gold line work.
    static let symbolAccent = Color(
        light: Color(red: 0.04, green: 0.39, blue: 0.23),
        dark: Color(red: 0.48, green: 0.84, blue: 0.59)
    )

    /// Halo color for feature-scale symbols. Renderers decide whether a role
    /// earns a halo; ordinary list and card symbols remain crisp and flat.
    static let symbolGlow = Color(
        light: Color(red: 0.56, green: 0.39, blue: 0.03),
        dark: Color(red: 0.92, green: 0.76, blue: 0.40)
    )

    /// A restrained engraved well used only when a standalone symbol needs a
    /// boundary, such as an empty-state medallion.
    static let symbolSurface = Color(
        light: Color(red: 0.91, green: 0.87, blue: 0.78),
        dark: Color(red: 0.095, green: 0.096, blue: 0.118)
    )

    // Illustration palette — shared by companion sprites, chest art, and
    // accessories so all drawn artwork stays in one voice.
    /// Deep navy ink used for outlines, pupils, and keyholes.
    static let ink = Color(red: 0.14, green: 0.13, blue: 0.30)
    /// Warm artwork gold for fittings, runes, and trims.
    static let artGold = Color(red: 0.83, green: 0.62, blue: 0.18)
    /// Accessory crimson (bow ties, scarves, jewels).
    static let crimson = Color(red: 0.72, green: 0.18, blue: 0.22)

    /// Forest plate — the fill under every primary action. Growth-colored on
    /// purpose: the one thing the app asks you to press is the thing that
    /// makes the character grow.
    static let plate = Color(
        light: Color(red: 0.10, green: 0.35, blue: 0.25),
        dark: Color(red: 0.15, green: 0.44, blue: 0.31)
    )

    /// Label color on `plate`.
    static let onPlate = cream

    /// Deep brass as a fill behind white text (selected chips, small seals).
    static let accentFill = Color(
        light: Color(red: 0.45, green: 0.33, blue: 0.08),
        dark: Color(red: 0.55, green: 0.42, blue: 0.16)
    )

    /// Arcane violet — rarity color for epic loot and the radiant seal tier.
    /// No longer an app-wide accent.
    static let arcane = Color(
        light: Color(red: 0.46, green: 0.28, blue: 0.72),
        dark: Color(red: 0.70, green: 0.54, blue: 0.94)
    )

    /// Gold — rewards, coins, prestige, personal records.
    // Light-mode gold/green are tuned to ≥4.5:1 on BOTH canvas and surface.
    static let gold = Color(
        light: Color(red: 0.56, green: 0.39, blue: 0.03),
        dark: Color(red: 0.92, green: 0.76, blue: 0.40)
    )

    /// Deep gold — quest frames and gold gradients.
    static let goldDeep = Color(
        light: Color(red: 0.44, green: 0.31, blue: 0.05),
        dark: Color(red: 0.78, green: 0.60, blue: 0.26)
    )

    /// Gold as a fill behind white text — dark enough for contrast in both modes.
    static let goldFill = Color(
        light: Color(red: 0.58, green: 0.41, blue: 0.04),
        dark: Color(red: 0.60, green: 0.43, blue: 0.10)
    )

    /// XP green — experience gains and success states.
    static let xp = Color(
        light: Color(red: 0.03, green: 0.48, blue: 0.27),
        dark: Color(red: 0.44, green: 0.80, blue: 0.56)
    )

    /// Bright end of the XP-bar gradient.
    static let xpBright = Color(
        light: Color(red: 0.16, green: 0.62, blue: 0.40),
        dark: Color(red: 0.56, green: 0.90, blue: 0.66)
    )

    /// AA-safe semantic colors for small warning/error copy on every light
    /// parchment surface.
    static let warningText = Color(
        light: Color(red: 0.48, green: 0.28, blue: 0.00),
        dark: Color(red: 1.00, green: 0.68, blue: 0.28)
    )

    static let errorText = Color(
        light: Color(red: 0.65, green: 0.08, blue: 0.12),
        dark: Color(red: 1.00, green: 0.48, blue: 0.52)
    )

    static let cornerRadius: CGFloat = 14
    static let innerRadius: CGFloat = 10

    /// Marquee gradient — brass into deep gold. Used sparingly (level seals,
    /// rank insignia), never as a screen background.
    static var heroGradient: LinearGradient {
        LinearGradient(colors: [gold, goldDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var xpGradient: LinearGradient {
        LinearGradient(colors: [xp, xpBright], startPoint: .leading, endPoint: .trailing)
    }

    static var goldGradient: LinearGradient {
        LinearGradient(colors: [gold, goldDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: Typography

    /// Numerals for training data and hero figures: sans, tabular, heavy.
    /// Scaled through UIFontMetrics so Dynamic Type is respected.
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: UIFontMetrics.default.scaledValue(for: size), weight: weight, design: .default)
    }

    /// Serif storybook face for headings and fantasy names (New York).
    static func heading(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: UIFontMetrics.default.scaledValue(for: size), weight: weight, design: .serif)
    }

    /// Text-style-based serif for inline headings that should track Dynamic Type.
    static func heading(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .serif, weight: weight)
    }

    /// Micro-label face for badges, chips, and section labels. Scales with
    /// Dynamic Type but caps growth so ornamental labels can't outgrow the
    /// capsules they sit in.
    static func label(_ size: CGFloat,
                      weight: Font.Weight = .medium,
                      design: Font.Design = .default) -> Font {
        let scaled = min(UIFontMetrics.default.scaledValue(for: size), size * 2.2)
        return .system(size: scaled, weight: weight, design: design)
    }

    /// Ornamental pill face — the only label allowed to stop growing early,
    /// because a tag must never outgrow the capsule it sits in.
    static func pill(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        let scaled = min(UIFontMetrics.default.scaledValue(for: size), size * 1.5)
        return .system(size: scaled, weight: weight, design: .default)
    }

    /// Applies the serif identity to UIKit-owned chrome (navigation titles)
    /// and the brass tint to the tab bar. Call once at app start.
    static func configureChrome() {
        func serifFont(for style: UIFont.TextStyle, bold: Bool) -> UIFont {
            let base = UIFont.preferredFont(forTextStyle: style)
            var descriptor = base.fontDescriptor
            if let serif = descriptor.withDesign(.serif) { descriptor = serif }
            if bold, let bolded = descriptor.withSymbolicTraits(.traitBold) { descriptor = bolded }
            return UIFont(descriptor: descriptor, size: 0)
        }

        let atRest = UINavigationBarAppearance()
        atRest.configureWithTransparentBackground()
        atRest.largeTitleTextAttributes = [.font: serifFont(for: .largeTitle, bold: true)]
        atRest.titleTextAttributes = [.font: serifFont(for: .headline, bold: true)]

        // When content scrolls under the bar, back the title with the canvas
        // so text never collides with panel content.
        let scrolled = UINavigationBarAppearance()
        scrolled.configureWithOpaqueBackground()
        scrolled.backgroundColor = UIColor(RPGTheme.canvas)
        scrolled.shadowColor = UIColor(RPGTheme.frame.opacity(0.30))
        scrolled.largeTitleTextAttributes = [.font: serifFont(for: .largeTitle, bold: true)]
        scrolled.titleTextAttributes = [.font: serifFont(for: .headline, bold: true)]

        UINavigationBar.appearance().standardAppearance = scrolled
        UINavigationBar.appearance().scrollEdgeAppearance = atRest
        UINavigationBar.appearance().compactAppearance = scrolled

        // Custom tab symbols still live in UIKit-owned chrome. Give that
        // chrome the same quiet surface and brass selection as the screens,
        // while using the system's adaptive secondary label for a legible but
        // deliberately subdued unselected state.
        let tabBar = UITabBarAppearance()
        tabBar.configureWithOpaqueBackground()
        tabBar.backgroundColor = UIColor(RPGTheme.surface)
        tabBar.shadowColor = UIColor(RPGTheme.frame.opacity(0.34))

        let selected = UIColor(RPGTheme.accent)
        let unselected = UIColor.secondaryLabel

        func style(_ appearance: UITabBarItemAppearance) {
            appearance.normal.iconColor = unselected
            appearance.normal.titleTextAttributes = [.foregroundColor: unselected]
            appearance.selected.iconColor = selected
            appearance.selected.titleTextAttributes = [.foregroundColor: selected]
        }

        style(tabBar.stackedLayoutAppearance)
        style(tabBar.inlineLayoutAppearance)
        style(tabBar.compactInlineLayoutAppearance)

        let tabBarProxy = UITabBar.appearance()
        tabBarProxy.standardAppearance = tabBar
        tabBarProxy.scrollEdgeAppearance = tabBar
        tabBarProxy.tintColor = selected
        tabBarProxy.unselectedItemTintColor = unselected
    }
}

// MARK: - Stat metadata

/// Unified metadata for the six character attributes.
enum Stat: String, CaseIterable, Identifiable {
    case size, strength, dexterity, agility, endurance, vitality

    var id: String { rawValue }

    var name: String {
        switch self {
        case .size: return "Size"
        case .strength: return "Strength"
        case .dexterity: return "Dexterity"
        case .agility: return "Agility"
        case .endurance: return "Endurance"
        case .vitality: return "Vitality"
        }
    }

    var abbreviation: String {
        switch self {
        case .size: return "SIZ"
        case .strength: return "STR"
        case .dexterity: return "DEX"
        case .agility: return "AGI"
        case .endurance: return "END"
        case .vitality: return "VIT"
        }
    }

    /// Attribute hue — used for glyph tints and thin bars only, never large
    /// fills. Dark-mode values are held back from neon so the six colors
    /// sit inside the brass-and-charcoal world instead of shouting over it.
    var color: Color {
        switch self {
        case .size:
            return Color(light: Color(red: 0.470, green: 0.270, blue: 0.720),
                         dark: Color(red: 0.72, green: 0.58, blue: 0.95))
        case .strength:
            return Color(light: Color(red: 0.700, green: 0.190, blue: 0.190),
                         dark: Color(red: 0.94, green: 0.50, blue: 0.46))
        case .dexterity:
            return Color(light: Color(red: 0.620, green: 0.320, blue: 0.030),
                         dark: Color(red: 0.95, green: 0.64, blue: 0.34))
        case .agility:
            return Color(light: Color(red: 0.500, green: 0.380, blue: 0.000),
                         dark: Color(red: 0.93, green: 0.78, blue: 0.36))
        case .endurance:
            return Color(light: Color(red: 0.120, green: 0.370, blue: 0.760),
                         dark: Color(red: 0.48, green: 0.66, blue: 0.94))
        case .vitality:
            return Color(light: Color(red: 0.100, green: 0.450, blue: 0.260),
                         dark: Color(red: 0.44, green: 0.80, blue: 0.56))
        }
    }

    /// Darker "container" variant used as a fill behind white text.
    var fill: Color {
        switch self {
        case .size:
            return Color(light: Color(red: 0.46, green: 0.25, blue: 0.72),
                         dark: Color(red: 0.44, green: 0.29, blue: 0.66))
        case .strength:
            return Color(light: Color(red: 0.70, green: 0.19, blue: 0.19),
                         dark: Color(red: 0.66, green: 0.22, blue: 0.22))
        case .dexterity:
            return Color(light: Color(red: 0.68, green: 0.33, blue: 0.03),
                         dark: Color(red: 0.62, green: 0.32, blue: 0.06))
        case .agility:
            return Color(light: Color(red: 0.56, green: 0.42, blue: 0.00),
                         dark: Color(red: 0.52, green: 0.39, blue: 0.03))
        case .endurance:
            return Color(light: Color(red: 0.12, green: 0.35, blue: 0.74),
                         dark: Color(red: 0.16, green: 0.34, blue: 0.66))
        case .vitality:
            return Color(light: Color(red: 0.10, green: 0.46, blue: 0.27),
                         dark: Color(red: 0.12, green: 0.42, blue: 0.26))
        }
    }
}

extension StatBlock {
    func value(for stat: Stat) -> Double {
        switch stat {
        case .size: return size
        case .strength: return strength
        case .dexterity: return dexterity
        case .agility: return agility
        case .endurance: return endurance
        case .vitality: return vitality
        }
    }

    /// All (stat, value) pairs in canonical order.
    var statPairs: [(stat: Stat, value: Double)] {
        Stat.allCases.map { ($0, value(for: $0)) }
    }
}

extension FocusGroup {
    /// The attribute this training focus primarily builds.
    var primaryStat: Stat {
        switch self {
        case .strength: return .strength
        case .hypertrophy: return .size
        case .bodyweight: return .dexterity
        case .explosive: return .agility
        case .endurance: return .endurance
        case .mobility: return .vitality
        }
    }
}

// MARK: - Ornaments

/// Thin L-brackets tucked inside each corner of a plate — the one flourish
/// a screen is allowed, reserved for its marquee element.
struct CornerBrackets: Shape {
    var inset: CGFloat = 7
    var length: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let i = inset, l = length
        p.move(to: CGPoint(x: rect.minX + i, y: rect.minY + i + l))
        p.addLine(to: CGPoint(x: rect.minX + i, y: rect.minY + i))
        p.addLine(to: CGPoint(x: rect.minX + i + l, y: rect.minY + i))
        p.move(to: CGPoint(x: rect.maxX - i - l, y: rect.minY + i))
        p.addLine(to: CGPoint(x: rect.maxX - i, y: rect.minY + i))
        p.addLine(to: CGPoint(x: rect.maxX - i, y: rect.minY + i + l))
        p.move(to: CGPoint(x: rect.maxX - i, y: rect.maxY - i - l))
        p.addLine(to: CGPoint(x: rect.maxX - i, y: rect.maxY - i))
        p.addLine(to: CGPoint(x: rect.maxX - i - l, y: rect.maxY - i))
        p.move(to: CGPoint(x: rect.minX + i + l, y: rect.maxY - i))
        p.addLine(to: CGPoint(x: rect.minX + i, y: rect.maxY - i))
        p.addLine(to: CGPoint(x: rect.minX + i, y: rect.maxY - i - l))
        return p
    }
}

/// Horizontal rule with a centered diamond — a classic fantasy divider.
struct OrnateDivider: View {
    var tint: Color = RPGTheme.frame

    var body: some View {
        HStack(spacing: 8) {
            LinearGradient(colors: [.clear, tint.opacity(0.55)], startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
            Rectangle()
                .fill(tint.opacity(0.75))
                .frame(width: 6, height: 6)
                .rotationEffect(.degrees(45))
            LinearGradient(colors: [tint.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
        }
        .accessibilityHidden(true)
    }
}

/// A brass hairline rule.
struct HairlineRule: View {
    var tint: Color = RPGTheme.frame
    var body: some View {
        Rectangle()
            .fill(tint.opacity(RPGTheme.hairline))
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

/// The character's level rendered as a gilded diamond seal. The seal keeps
/// one silhouette forever but gains ornament and richer material with each
/// prestige tier (0–9, capping total level at 100):
///   P1+ inner ring · P2+ tip studs · P3+ second ring · P5+ crown ·
///   materials deepen in bands · P9 glows.
struct LevelSeal: View {
    let level: Int
    var prestige: Int = 0
    var size: CGFloat = 56

    private var tier: Int { max(0, min(prestige, StatEngine.maxPrestige)) }
    private var isMax: Bool { tier >= StatEngine.maxPrestige }

    private var materialColors: [Color] {
        switch tier {
        case 0: // Bronze
            return [Color(red: 0.62, green: 0.42, blue: 0.22), Color(red: 0.48, green: 0.31, blue: 0.15)]
        case 1: // Silver
            return [Color(red: 0.62, green: 0.65, blue: 0.70), Color(red: 0.44, green: 0.47, blue: 0.53)]
        case 2: // Gold
            return [RPGTheme.gold, RPGTheme.goldDeep]
        case 3: // Emerald
            return [Color(red: 0.13, green: 0.55, blue: 0.34), Color(red: 0.07, green: 0.40, blue: 0.24)]
        case 4: // Sapphire
            return [Color(red: 0.16, green: 0.42, blue: 0.82), Color(red: 0.10, green: 0.28, blue: 0.62)]
        case 5: // Amethyst
            return [Color(red: 0.50, green: 0.28, blue: 0.80), Color(red: 0.36, green: 0.17, blue: 0.62)]
        case 6: // Crimson
            return [Color(red: 0.76, green: 0.20, blue: 0.26), Color(red: 0.55, green: 0.11, blue: 0.17)]
        case 7: // Obsidian
            return [Color(red: 0.23, green: 0.23, blue: 0.33), Color(red: 0.11, green: 0.11, blue: 0.19)]
        case 8: // Radiant — gold veined with arcane
            return [RPGTheme.gold, RPGTheme.arcane]
        default: // Mythic — gold and crimson, glowing
            return [RPGTheme.gold, TreasureChestType.mythic.rarityColor]
        }
    }

    private var material: LinearGradient {
        LinearGradient(colors: materialColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var haloColor: Color { materialColors[0] }

    private var numeralColor: Color {
        [1, 2, 8, 9].contains(tier) ? RPGTheme.ink : .white
    }

    private var tipDistance: CGFloat { size * 0.707 }

    var body: some View {
        ZStack {
            if isMax {
                Circle()
                    .fill(RPGTheme.gold.opacity(0.35))
                    .frame(width: size * 1.5, height: size * 1.5)
                    .blur(radius: size * 0.18)
            }

            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .fill(material)
                .frame(width: size, height: size)
                .rotationEffect(.degrees(45))
                .shadow(color: haloColor.opacity(0.35), radius: 6, x: 0, y: 3)

            if tier >= 1 {
                RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                    .strokeBorder(.white.opacity(0.55), lineWidth: 1.2)
                    .frame(width: size * 0.82, height: size * 0.82)
                    .rotationEffect(.degrees(45))
            }

            if tier >= 3 {
                RoundedRectangle(cornerRadius: size * 0.10, style: .continuous)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 0.8)
                    .frame(width: size * 0.66, height: size * 0.66)
                    .rotationEffect(.degrees(45))
            }

            if tier >= 2 {
                ForEach(0..<4, id: \.self) { i in
                    let angle = Double(i) * 90.0
                    Rectangle()
                        .fill(RPGTheme.cream.opacity(0.9))
                        .frame(width: size * 0.09, height: size * 0.09)
                        .rotationEffect(.degrees(45))
                        .offset(
                            x: tipDistance * CGFloat(cos(angle * .pi / 180 - .pi / 2)),
                            y: tipDistance * CGFloat(sin(angle * .pi / 180 - .pi / 2))
                        )
                }
            }

            Text("\(level)")
                .font(.system(size: size * 0.42, weight: .bold, design: .serif))
                .foregroundColor(numeralColor)
                .shadow(color: numeralColor == .white ? .black.opacity(0.35) : .clear, radius: 1, x: 0, y: 1)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .frame(width: size * 0.8)
                .multilineTextAlignment(.center)

            if tier >= 5 {
                RPGSymbolIcon(
                    symbol: .rank,
                    size: size * 0.28,
                    presentation: .compact,
                    palette: .onPlate
                )
                    .offset(y: -tipDistance * 0.96)
            }
        }
        .frame(width: size * 1.42, height: size * 1.42)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            isMax && level >= 10
                ? "Level \(level), maximum prestige"
                : (tier > 0 ? "Level \(level), prestige \(tier)" : "Level \(level)")
        )
    }
}

/// Progress gauge: inset track with a brass hairline, flat tinted fill.
struct OrnateProgressBar: View {
    let progress: Double
    var tint: Color = RPGTheme.xp
    var height: CGFloat = 8
    /// Spoken name of what the bar measures.
    var label: String = "Progress"

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(RPGTheme.surfaceInner)
                    .overlay(
                        Capsule().strokeBorder(RPGTheme.frame.opacity(RPGTheme.hairline + 0.08), lineWidth: 1)
                    )

                Capsule()
                    .fill(
                        LinearGradient(colors: [tint.opacity(0.85), tint], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: max(height, min(1, max(0, progress)) * geo.size.width))
                    .opacity(progress > 0 ? 1 : 0)
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(min(1, max(0, progress)) * 100)) percent")
    }
}

// MARK: - Panel surface

private struct RPGCardModifier: ViewModifier {
    var padding: CGFloat
    var accent: Color?
    var ornate: Bool

    func body(content: Content) -> some View {
        let borderTint = accent ?? RPGTheme.frame
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: RPGTheme.cornerRadius, style: .continuous)
                    .fill(RPGTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: RPGTheme.cornerRadius, style: .continuous)
                            .strokeBorder(
                                borderTint.opacity(accent == nil ? RPGTheme.hairline : RPGTheme.hairline + 0.14),
                                lineWidth: 1
                            )
                    )
                    .overlay(
                        CornerBrackets()
                            .stroke(borderTint.opacity(ornate ? 0.45 : 0), lineWidth: 1)
                    )
            )
    }
}

extension View {
    /// The app's standard panel: quiet parchment/charcoal surface with a
    /// single brass hairline. `ornate: true` adds corner brackets —
    /// reserved for one marquee panel per screen.
    func rpgCard(padding: CGFloat = 18, accent: Color? = nil, ornate: Bool = false) -> some View {
        modifier(RPGCardModifier(padding: padding, accent: accent, ornate: ornate))
    }

    /// Inset sub-surface inside a panel (rows, tracks, chips).
    func rpgInset(padding: CGFloat = 12, radius: CGFloat = RPGTheme.innerRadius) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(RPGTheme.surfaceInner.opacity(0.7))
            )
    }
}

// MARK: - Screen background

/// Shared screen background: parchment (light) or charcoal keep (dark) with a
/// barely-there grain and a warm brass glow at the top edge.
struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            RPGTheme.canvas

            // Paper grain — a faint diagonal hatch
            Canvas { context, size in
                var path = Path()
                let spacing: CGFloat = 7
                var x: CGFloat = -size.height
                while x < size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                    x += spacing
                }
                context.stroke(path, with: .color(.primary), lineWidth: 0.35)
            }
            .opacity(colorScheme == .dark ? 0.014 : 0.020)
            .allowsHitTesting(false)

            // Vignette pulls focus to the content
            RadialGradient(
                colors: [.clear, Color.black.opacity(colorScheme == .dark ? 0.32 : 0.05)],
                center: .center,
                startRadius: 200,
                endRadius: 760
            )

            // Brass light from above — the keep's lamp, the sheet's candle
            LinearGradient(
                colors: [RPGTheme.gold.opacity(colorScheme == .dark ? 0.10 : 0.06), .clear],
                startPoint: .top,
                endPoint: .center
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Section header

/// Panel header: serif title with an optional small glyph, and no tinted
/// icon tile — the title carries the weight, the glyph is a marginal note.
struct SectionHeader: View {
    var icon: String = ""
    let title: String
    var tint: Color = RPGTheme.accent
    var glyph: RPGGlyph? = nil
    var symbol: RPGSymbol? = nil
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let symbol {
                    RPGSymbolIcon(
                        symbol: symbol,
                        size: 16,
                        presentation: .compact,
                        palette: .monochrome(tint)
                    )
                } else if let glyph {
                    GlyphIcon(glyph: glyph, size: 15, tint: tint)
                } else if !icon.isEmpty {
                    Image(systemName: icon)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(tint)
                }
            }
            .accessibilityHidden(true)

            Text(title)
                .font(RPGTheme.heading(.headline, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}

/// Engraved section label: small caps, tracked, with a hairline rule running
/// to the trailing edge (or to an optional trailing control).
struct SectionLabel<Trailing: View>: View {
    let title: String
    var tint: Color = .secondary
    @ViewBuilder var trailing: () -> Trailing

    init(_ title: String, tint: Color = .secondary, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.tint = tint
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(title.uppercased())
                .font(RPGTheme.label(11, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(tint)
                .lineLimit(1)
                .fixedSize()
                .accessibilityLabel(title)
                .accessibilityAddTraits(.isHeader)
            HairlineRule()
            trailing()
        }
    }
}

extension SectionLabel where Trailing == EmptyView {
    init(_ title: String, tint: Color = .secondary) {
        self.init(title, tint: tint) { EmptyView() }
    }
}

/// A small tracked capsule label — "DAILY", "COMPANION", "SUPERSET".
struct PillTag: View {
    let text: String
    var tint: Color = RPGTheme.gold
    var filled: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(text.uppercased())
            .font(RPGTheme.pill(9))
            .tracking(1.0)
            .foregroundColor(filled ? .white : tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(filled ? tint : tint.opacity(0.08))
            )
            .background(
                // Bright dark-mode tints cannot carry white; deepen the fill.
                Capsule().fill(Color.black.opacity(filled && colorScheme == .dark ? 0.35 : 0))
            )
            .overlay(
                Capsule().strokeBorder(tint.opacity(filled ? 0 : 0.45), lineWidth: 0.8)
            )
            .fixedSize()
    }
}

// MARK: - Rows

/// A tappable list row inside a panel: leading glyph, serif title,
/// caption, trailing accessory. The workhorse of the redesign — routines,
/// quests, items, and settings all share it, so every list reads the same.
struct RPGRow<Leading: View, Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    var chevron: Bool = true
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(title: String,
         subtitle: String? = nil,
         chevron: Bool = true,
         @ViewBuilder leading: @escaping () -> Leading,
         @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.chevron = chevron
        self.leading = leading
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 12) {
            leading()
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)

            // At accessibility sizes the title may wrap freely — a truncated
            // row label is worse than a taller row.
            let accessible = dynamicTypeSize.isAccessibilitySize
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(RPGTheme.heading(.subheadline, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(accessible ? nil : 1)
                    .minimumScaleFactor(accessible ? 1 : 0.85)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(accessible ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 6)

            trailing()

            if chevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(RPGTheme.frame)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

extension RPGRow where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, chevron: Bool = true,
         @ViewBuilder leading: @escaping () -> Leading) {
        self.init(title: title, subtitle: subtitle, chevron: chevron, leading: leading) { EmptyView() }
    }
}

// MARK: - Buttons

/// Primary call-to-action: a forest plate with a brass hairline and cream
/// label. Flat, no glow — the weight comes from the color, not effects.
/// `tint` keeps its old meaning (an alternative plate color) for the few
/// places that need gold or crimson plates.
struct RPGPrimaryButtonStyle: ButtonStyle {
    var tint: Color = RPGTheme.plate
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .default, weight: .semibold))
            .foregroundColor(isEnabled ? RPGTheme.onPlate : .secondary)
            .padding(.vertical, 15)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: RPGTheme.innerRadius + 2, style: .continuous)
                    .fill(isEnabled ? tint : RPGTheme.surfaceInner)
                    .overlay(
                        // Bright tints (xp, gold) are tuned for text ON dark
                        // surfaces; darken them under the cream label.
                        RoundedRectangle(cornerRadius: RPGTheme.innerRadius + 2, style: .continuous)
                            .fill(Color.black.opacity(colorScheme == .dark && isEnabled && tint != RPGTheme.plate ? 0.32 : 0))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: RPGTheme.innerRadius + 2, style: .continuous)
                            .strokeBorder(RPGTheme.gold.opacity(isEnabled ? 0.55 : 0.2), lineWidth: 1)
                    )
            )
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.98 : 1.0))
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7),
                value: configuration.isPressed
            )
    }
}

/// Bordered companion to RPGPrimaryButtonStyle for a co-equal secondary
/// action: brass hairline, ink label.
struct RPGSecondaryButtonStyle: ButtonStyle {
    var tint: Color = RPGTheme.accent
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .default, weight: .semibold))
            .foregroundColor(tint == RPGTheme.accent ? .primary : tint)
            .opacity(isEnabled ? 1 : 0.45)
            .padding(.vertical, 15)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: RPGTheme.innerRadius + 2, style: .continuous)
                    .fill(RPGTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: RPGTheme.innerRadius + 2, style: .continuous)
                            .strokeBorder(tint.opacity(0.6), lineWidth: 1.2)
                    )
            )
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.98 : 1.0))
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7),
                value: configuration.isPressed
            )
    }
}

/// Quiet text action for tertiary controls ("Campaign Map", "Ranks").
struct RPGQuietButtonStyle: ButtonStyle {
    var tint: Color = RPGTheme.accent
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundColor(tint)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .opacity(!isEnabled ? 0.45 : (configuration.isPressed ? 0.6 : 1.0))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Light press feedback for tappable panels and rows.
struct PressableCardStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.985 : 1.0))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7),
                value: configuration.isPressed
            )
    }
}

/// The marquee plate: a full-width forest block with corner brackets, a
/// serif title, and a one-line promise. Used once per screen at most.
struct HeroPlate: View {
    let title: String
    var subtitle: String? = nil
    var glyph: RPGGlyph? = nil
    var systemImage: String? = nil
    var tint: Color = RPGTheme.plate
    var symbol: RPGSymbol? = nil

    var body: some View {
        HStack(spacing: 16) {
            Group {
                if let symbol {
                    RPGSymbolIcon(
                        symbol: symbol,
                        size: 34,
                        presentation: .hero,
                        palette: .onPlate
                    )
                } else if let glyph {
                    GlyphIcon(glyph: glyph, size: 28, tint: RPGTheme.cream)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(RPGTheme.cream)
                }
            }
            .frame(width: 40, height: 40)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(RPGTheme.heading(.title2, weight: .bold))
                    .foregroundColor(RPGTheme.cream)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundColor(RPGTheme.cream.opacity(0.94))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "arrow.right")
                .font(.headline.weight(.semibold))
                .foregroundColor(RPGTheme.cream.opacity(0.85))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: RPGTheme.cornerRadius, style: .continuous)
                .fill(tint)
                .overlay(
                    RoundedRectangle(cornerRadius: RPGTheme.cornerRadius, style: .continuous)
                        .strokeBorder(RPGTheme.gold.opacity(0.55), lineWidth: 1)
                )
                .overlay(
                    CornerBrackets(inset: 8, length: 14)
                        .stroke(RPGTheme.cream.opacity(0.45), lineWidth: 1)
                )
        )
    }
}

// MARK: - Dock

/// Bottom action dock: pinned above the safe area, fading the canvas in
/// behind it so scrolled content never collides with the primary action.
/// One-handed by construction — everything inside is in thumb reach.
struct DockBar<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HairlineRule()
            content()
                .padding(.horizontal, AppLayout.horizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .frame(maxWidth: AppLayout.contentMaxWidth)
                .frame(maxWidth: .infinity)
        }
        .background(
            RPGTheme.canvas
                .opacity(0.96)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Empty state

/// Shared empty-state layout used across tabs.
struct EmptyStateView: View {
    var icon: String? = nil
    let title: String
    let message: String
    var tint: Color = RPGTheme.accent
    /// An empty state should hand the user their next move, not a shrug.
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var symbol: RPGSymbol? = nil
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(symbol == nil ? Color.clear : RPGTheme.symbolSurface.opacity(0.72))
                    .overlay(
                        Circle().strokeBorder(
                            (symbol == nil ? tint : RPGTheme.symbolSecondary)
                                .opacity(
                                    colorSchemeContrast == .increased
                                        ? 0.78
                                        : (symbol == nil ? 0.35 : 0.42)
                                ),
                            lineWidth: colorSchemeContrast == .increased ? 1.5 : 1
                        )
                    )
                    .frame(width: 84, height: 84)

                if let symbol {
                    RPGSymbolIcon(
                        symbol: symbol,
                        size: 44,
                        presentation: .standard,
                        palette: .adaptive
                    )
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 32, weight: .regular))
                        .foregroundColor(tint.opacity(0.85))
                }
            }
            .accessibilityHidden(true)

            Text(title)
                .font(RPGTheme.heading(.title3, weight: .semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(RPGPrimaryButtonStyle())
                    .frame(maxWidth: 260)
                    .padding(.top, 6)
            }
        }
        .padding(.vertical, 36)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Layout helpers

/// Two columns on regular width (iPad, landscape phones), one column
/// otherwise. Children are laid out as panels of equal width.
struct AdaptiveColumns<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    var spacing: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        if sizeClass == .regular {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: spacing, alignment: .top),
                                GridItem(.flexible(), spacing: spacing, alignment: .top)],
                      alignment: .leading, spacing: spacing) {
                content()
            }
        } else {
            VStack(spacing: spacing) { content() }
        }
    }
}

extension View {
    /// Standard screen column: readable width, centered, with the app's
    /// horizontal padding. Wider on regular size classes so iPad breathes.
    func screenColumn(maxWidth: CGFloat = AppLayout.contentMaxWidth) -> some View {
        self
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppLayout.horizontalPadding)
    }
}

// MARK: - Haptics

/// One haptic beat per event — never stacked, never decorative.
enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// A completed set: a firmer, single impact.
    static func setComplete() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Selection change in a stepper or segmented control.
    static func tick() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
