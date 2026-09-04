// Companion system — eggs found in treasure cards hatch into one of three
// minimalist spirits. The spirits are deliberately abstract (blobs, not
// creatures) and are drawn as vector art from the app palette, so they match
// the rest of the design system exactly.

import SwiftUI

// MARK: - Species

enum CompanionSpecies: String, Codable, CaseIterable {
    case wisp      // flame spirit — gold
    case pebble    // stone spirit — indigo
    case sprout    // seed spirit — green

    var displayName: String {
        switch self {
        case .wisp: return "Wisp"
        case .pebble: return "Pebble"
        case .sprout: return "Sprout"
        }
    }

    var tint: Color {
        switch self {
        case .wisp: return RPGTheme.gold
        case .pebble: return RPGTheme.accent
        case .sprout: return RPGTheme.xp
        }
    }

    /// Idle line shown when the player hasn't trained today.
    var idleLine: String {
        idleLine(named: displayName)
    }

    func idleLine(named name: String) -> String {
        switch self {
        case .wisp: return "\(name) flickers softly. Log a workout to stoke it."
        case .pebble: return "\(name) sits patiently. Log a workout to wake it."
        case .sprout: return "\(name) droops a little. Log a workout to water it."
        }
    }
}

// MARK: - Sprite art (vector, palette-locked)

private enum SpritePalette {
    static let outline = RPGTheme.ink
    static let cream = RPGTheme.cream
    static let flame = Color(red: 0.89, green: 0.65, blue: 0.20)
    static let stone = Color(red: 0.27, green: 0.26, blue: 0.58)
    static let leafBody = Color(red: 0.20, green: 0.48, blue: 0.29)
    static let goldMark = RPGTheme.artGold
}

/// A companion spirit drawn in the app's flat, cream-outlined style.
/// Idles with species motion (flame lick, stone breath, leaf sway), live
/// eyes that glance around and blink, and an optional equipped accessory.
/// Reduce Motion renders a still frame.
struct CompanionSpriteView: View {
    let species: CompanionSpecies
    var size: CGFloat = 74
    var animated: Bool = true
    var accessory: PetAccessory? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if animated && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    sprite(time: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                sprite(time: 0)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func sprite(time t: Double) -> some View {
        Canvas { context, canvasSize in
            let s = min(canvasSize.width, canvasSize.height) / 100
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
            func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
                CGRect(x: x * s, y: y * s, width: w * s, height: h * s)
            }
            let outlineWidth = 4.5 * s

            // Shared gaze: pupils wander and occasionally recenter; a quick
            // blink lands every few seconds.
            let lookX = CGFloat(sin(t * 0.38) * sin(t * 0.16 + 0.8)) * 2.4
            let lookY = CGFloat(sin(t * 0.23 + 2.0)) * 1.1
            let blink = pow(max(0, sin(t * 1.55 + 0.4)), 24)
            let eyeOpen = CGFloat(1.0 - 0.9 * blink)

            // One eye: optional sclera with a wandering pupil, blink squash,
            // and a lid line when fully closed.
            func drawEye(_ ctx: GraphicsContext, cx: CGFloat, cy: CGFloat,
                         w: CGFloat, h: CGFloat, sclera: Color?, pupil: Color) {
                let openH = h * eyeOpen
                if openH < h * 0.16 {
                    var lid = Path()
                    lid.move(to: pt(cx - w / 2, cy))
                    lid.addLine(to: pt(cx + w / 2, cy))
                    ctx.stroke(lid, with: .color(sclera ?? pupil), lineWidth: 2.2 * s)
                    return
                }
                if let sclera {
                    ctx.fill(Path(ellipseIn: rect(cx - w / 2, cy - openH / 2, w, openH)), with: .color(sclera))
                    let pw = w * 0.52
                    let ph = openH * 0.55
                    ctx.fill(
                        Path(ellipseIn: rect(cx - pw / 2 + lookX, cy - ph / 2 + lookY * 0.6, pw, ph)),
                        with: .color(pupil)
                    )
                    // Sparkle riding the pupil, like the wisp's glint
                    ctx.fill(
                        Path(ellipseIn: rect(cx - pw / 2 + lookX + pw * 0.5, cy - ph / 2 + lookY * 0.6 + ph * 0.14, pw * 0.34, ph * 0.28)),
                        with: .color(.white.opacity(0.9))
                    )
                } else {
                    ctx.fill(
                        Path(ellipseIn: rect(cx - w / 2 + lookX, cy - openH / 2 + lookY * 0.6, w, openH)),
                        with: .color(pupil)
                    )
                    ctx.fill(
                        Path(ellipseIn: rect(cx - w / 2 + lookX + w * 0.55, cy - openH / 2 + lookY * 0.6 + openH * 0.16, w * 0.28, openH * 0.22)),
                        with: .color(.white.opacity(0.85))
                    )
                }
            }

            // Equipped accessory, drawn with per-species anchors so it rides
            // the same idle motion as the body.
            func drawAccessory(_ ctx: GraphicsContext,
                               hat: (x: CGFloat, y: CGFloat),
                               chin: (x: CGFloat, y: CGFloat),
                               eyes: (left: CGFloat, right: CGFloat, cy: CGFloat)) {
                guard let accessory else { return }
                let cream = SpritePalette.cream
                let gold = SpritePalette.goldMark
                let crimson = RPGTheme.crimson

                switch accessory {
                case .crown:
                    // Filled three-point crown seated on the head, ruby on top
                    let cx = hat.x
                    let base = hat.y + 3
                    var crown = Path()
                    crown.move(to: pt(cx - 11, base))
                    crown.addLine(to: pt(cx - 11, base - 9))
                    crown.addLine(to: pt(cx - 6, base - 4.5))
                    crown.addLine(to: pt(cx, base - 13))
                    crown.addLine(to: pt(cx + 6, base - 4.5))
                    crown.addLine(to: pt(cx + 11, base - 9))
                    crown.addLine(to: pt(cx + 11, base))
                    crown.closeSubpath()
                    ctx.fill(crown, with: .color(gold))
                    ctx.stroke(crown, with: .color(cream), lineWidth: 2.2 * s)
                    ctx.fill(Path(ellipseIn: rect(cx - 1.8, base - 16, 3.6, 3.6)), with: .color(crimson))

                case .cap:
                    // Ranger cap: tilted dome, upturned brim, gold quill
                    let cx = hat.x
                    let base = hat.y
                    var dome = Path()
                    dome.move(to: pt(cx - 15, base))
                    dome.addQuadCurve(to: pt(cx + 13, base - 2), control: pt(cx - 4, base - 20))
                    dome.addQuadCurve(to: pt(cx - 15, base), control: pt(cx, base + 2))
                    dome.closeSubpath()
                    ctx.fill(dome, with: .color(SpritePalette.leafBody))
                    ctx.stroke(dome, with: .color(cream), lineWidth: 2.4 * s)
                    var brim = Path()
                    brim.move(to: pt(cx - 17, base + 1))
                    brim.addQuadCurve(to: pt(cx + 15, base - 1), control: pt(cx, base + 4))
                    ctx.stroke(brim, with: .color(cream), lineWidth: 2.8 * s)
                    var quill = Path()
                    quill.move(to: pt(cx + 6, base - 10))
                    quill.addQuadCurve(to: pt(cx + 17, base - 19), control: pt(cx + 13, base - 11))
                    ctx.stroke(quill, with: .color(gold), lineWidth: 2.4 * s)
                    for i in 0..<2 {
                        var barb = Path()
                        barb.move(to: pt(cx + 9 + CGFloat(i) * 3.2, base - 12 - CGFloat(i) * 2.6))
                        barb.addLine(to: pt(cx + 7 + CGFloat(i) * 3.2, base - 15 - CGFloat(i) * 2.6))
                        ctx.stroke(barb, with: .color(gold), lineWidth: 1.8 * s)
                    }

                case .spectacles:
                    // Gold round frames, arched bridge, lens glints
                    let radius: CGFloat = 7
                    for cx in [eyes.left, eyes.right] {
                        ctx.stroke(
                            Path(ellipseIn: rect(cx - radius, eyes.cy - radius, radius * 2, radius * 2)),
                            with: .color(gold),
                            lineWidth: 2.6 * s
                        )
                        ctx.fill(
                            Path(ellipseIn: rect(cx + radius * 0.1, eyes.cy - radius * 0.7, 2.6, 2.6)),
                            with: .color(.white.opacity(0.8))
                        )
                    }
                    var bridge = Path()
                    bridge.move(to: pt(eyes.left + radius, eyes.cy - 1))
                    bridge.addQuadCurve(
                        to: pt(eyes.right - radius, eyes.cy - 1),
                        control: pt((eyes.left + eyes.right) / 2, eyes.cy - 4)
                    )
                    ctx.stroke(bridge, with: .color(gold), lineWidth: 2.4 * s)

                case .bowtie:
                    // Curved wings + gold square knot
                    let cx = chin.x
                    let cy = chin.y
                    var tie = Path()
                    tie.move(to: pt(cx - 3, cy))
                    tie.addQuadCurve(to: pt(cx - 13, cy - 7), control: pt(cx - 9, cy - 5))
                    tie.addQuadCurve(to: pt(cx - 13, cy + 7), control: pt(cx - 16, cy))
                    tie.addQuadCurve(to: pt(cx - 3, cy), control: pt(cx - 9, cy + 5))
                    tie.closeSubpath()
                    tie.move(to: pt(cx + 3, cy))
                    tie.addQuadCurve(to: pt(cx + 13, cy - 7), control: pt(cx + 9, cy - 5))
                    tie.addQuadCurve(to: pt(cx + 13, cy + 7), control: pt(cx + 16, cy))
                    tie.addQuadCurve(to: pt(cx + 3, cy), control: pt(cx + 9, cy + 5))
                    tie.closeSubpath()
                    ctx.fill(tie, with: .color(crimson))
                    ctx.stroke(tie, with: .color(cream), lineWidth: 2 * s)
                    let knot = Path(roundedRect: rect(cx - 3.2, cy - 3.5, 6.4, 7), cornerRadius: 2 * s)
                    ctx.fill(knot, with: .color(gold))
                    ctx.stroke(knot, with: .color(cream), lineWidth: 1.6 * s)

                case .scarf:
                    // Wrapped band with a gold stripe and fringed tail
                    let cx = chin.x
                    let cy = chin.y
                    let band = Path(roundedRect: rect(cx - 16, cy - 4.5, 32, 9), cornerRadius: 4.5 * s)
                    ctx.fill(band, with: .color(crimson))
                    ctx.stroke(band, with: .color(cream), lineWidth: 2 * s)
                    var stripe = Path()
                    stripe.move(to: pt(cx - 15, cy + 1.5))
                    stripe.addLine(to: pt(cx + 15, cy + 1.5))
                    ctx.stroke(stripe, with: .color(gold), lineWidth: 1.6 * s)
                    let tail = Path(roundedRect: rect(cx + 3, cy + 3, 8, 14), cornerRadius: 3 * s)
                    ctx.fill(tail, with: .color(crimson))
                    ctx.stroke(tail, with: .color(cream), lineWidth: 2 * s)
                    for i in 0..<3 {
                        var fringe = Path()
                        let fx = cx + 4.8 + CGFloat(i) * 2.4
                        fringe.move(to: pt(fx, cy + 16))
                        fringe.addLine(to: pt(fx, cy + 19.5))
                        ctx.stroke(fringe, with: .color(cream), lineWidth: 1.4 * s)
                    }
                }
            }

            switch species {
            case .wisp:
                let bob = CGFloat(sin(t * 1.7)) * 2.5
                let flick = CGFloat(sin(t * 3.4)) * 3.0
                let corePulse = 1.0 + 0.06 * sin(t * 2.6)

                var ctx = context
                ctx.translateBy(x: 0, y: bob * s)

                var body = Path()
                body.move(to: pt(50 + flick, 8))
                body.addCurve(to: pt(78, 62), control1: pt(64 + flick * 0.5, 22), control2: pt(80, 42))
                body.addCurve(to: pt(50, 92), control1: pt(76, 80), control2: pt(64, 92))
                body.addCurve(to: pt(22, 62), control1: pt(36, 92), control2: pt(24, 80))
                body.addCurve(to: pt(50 + flick, 8), control1: pt(20, 42), control2: pt(36 + flick * 0.5, 22))
                body.closeSubpath()
                ctx.fill(body, with: .color(SpritePalette.flame))
                ctx.stroke(body, with: .color(SpritePalette.cream), lineWidth: outlineWidth)

                let coreHeight: CGFloat = 44 * corePulse
                var core = Path()
                core.move(to: pt(50, 84 - coreHeight))
                core.addCurve(to: pt(64, 68), control1: pt(58, 88 - coreHeight), control2: pt(65, 58))
                core.addCurve(to: pt(50, 84), control1: pt(63, 78), control2: pt(57, 84))
                core.addCurve(to: pt(36, 68), control1: pt(43, 84), control2: pt(37, 78))
                core.addCurve(to: pt(50, 84 - coreHeight), control1: pt(35, 58), control2: pt(42, 88 - coreHeight))
                core.closeSubpath()
                ctx.fill(core, with: .color(SpritePalette.cream.opacity(0.85)))

                drawEye(ctx, cx: 42.5, cy: 61.5, w: 7, h: 11, sclera: nil, pupil: SpritePalette.outline)
                drawEye(ctx, cx: 57.5, cy: 61.5, w: 7, h: 11, sclera: nil, pupil: SpritePalette.outline)

                drawAccessory(ctx, hat: (50 + flick, 12), chin: (50, 86), eyes: (42.5, 57.5, 61.5))

            case .pebble:
                let breath = 1.0 + 0.022 * sin(t * 1.4)
                let runePulse = 0.7 + 0.3 * sin(t * 2.1)

                var ctx = context
                ctx.translateBy(x: 0, y: 86 * s)
                ctx.scaleBy(x: 1.0, y: CGFloat(breath))
                ctx.translateBy(x: 0, y: -86 * s)

                for x in [30.0, 54.0] {
                    let foot = Path(ellipseIn: rect(CGFloat(x), 78, 16, 10))
                    ctx.fill(foot, with: .color(SpritePalette.stone))
                    ctx.stroke(foot, with: .color(SpritePalette.cream), lineWidth: 3 * s)
                }

                for x in [6.0, 79.0] {
                    let arm = Path(roundedRect: rect(CGFloat(x), 48, 15, 24), cornerRadius: 7.5 * s)
                    ctx.fill(arm, with: .color(SpritePalette.stone))
                    ctx.stroke(arm, with: .color(SpritePalette.cream), lineWidth: 3 * s)
                }

                let body = Path(roundedRect: rect(18, 20, 64, 60), cornerRadius: 27 * s)
                ctx.fill(body, with: .color(SpritePalette.stone))
                ctx.stroke(body, with: .color(SpritePalette.cream), lineWidth: outlineWidth)

                var runeMark = Path()
                runeMark.move(to: pt(50, 28))
                runeMark.addLine(to: pt(57, 36))
                runeMark.addLine(to: pt(50, 44))
                runeMark.addLine(to: pt(43, 36))
                runeMark.closeSubpath()
                ctx.fill(runeMark, with: .color(SpritePalette.goldMark.opacity(runePulse)))

                drawEye(ctx, cx: 40, cy: 58, w: 8, h: 12, sclera: SpritePalette.cream, pupil: SpritePalette.outline)
                drawEye(ctx, cx: 60, cy: 58, w: 8, h: 12, sclera: SpritePalette.cream, pupil: SpritePalette.outline)

                var smile = Path()
                smile.move(to: pt(44, 71))
                smile.addQuadCurve(to: pt(56, 71), control: pt(50, 76))
                ctx.stroke(smile, with: .color(SpritePalette.cream), lineWidth: 3 * s)

                drawAccessory(ctx, hat: (50, 18), chin: (50, 80), eyes: (40, 60, 58))

            case .sprout:
                let bob = CGFloat(sin(t * 1.5)) * 2.0
                let leafAngle = sin(t * 1.9) * 0.16

                var ctx = context
                ctx.translateBy(x: 0, y: bob * s)

                for x in [34.0, 54.0] {
                    let foot = Path(ellipseIn: rect(CGFloat(x), 84, 12, 8))
                    ctx.fill(foot, with: .color(SpritePalette.leafBody))
                    ctx.stroke(foot, with: .color(SpritePalette.cream), lineWidth: 2.5 * s)
                }

                for (x, flip) in [(24.0, -1.0), (76.0, 1.0)] {
                    var arm = Path()
                    arm.move(to: pt(CGFloat(x), 56))
                    arm.addQuadCurve(
                        to: pt(CGFloat(x + flip * 12), 64),
                        control: pt(CGFloat(x + flip * 10), 54)
                    )
                    ctx.stroke(arm, with: .color(SpritePalette.cream), lineWidth: 3.5 * s)
                }

                let body = Path(ellipseIn: rect(24, 30, 52, 56))
                ctx.fill(body, with: .color(SpritePalette.leafBody))
                ctx.stroke(body, with: .color(SpritePalette.cream), lineWidth: outlineWidth)

                var stem = Path()
                stem.move(to: pt(50, 30))
                stem.addQuadCurve(to: pt(54, 17), control: pt(50, 22))
                ctx.stroke(stem, with: .color(SpritePalette.cream), lineWidth: 3.5 * s)

                var leafCtx = ctx
                leafCtx.translateBy(x: 54 * s, y: 17 * s)
                leafCtx.rotate(by: .radians(leafAngle))
                leafCtx.translateBy(x: -54 * s, y: -17 * s)

                var leaf = Path()
                leaf.move(to: pt(54, 17))
                leaf.addQuadCurve(to: pt(76, 11), control: pt(64, 5))
                leaf.addQuadCurve(to: pt(54, 17), control: pt(68, 21))
                leaf.closeSubpath()
                leafCtx.fill(leaf, with: .color(SpritePalette.leafBody))
                leafCtx.stroke(leaf, with: .color(SpritePalette.cream), lineWidth: 3 * s)

                drawEye(ctx, cx: 42, cy: 56, w: 8, h: 12, sclera: SpritePalette.cream, pupil: SpritePalette.outline)
                drawEye(ctx, cx: 58, cy: 56, w: 8, h: 12, sclera: SpritePalette.cream, pupil: SpritePalette.outline)

                var smile = Path()
                smile.move(to: pt(44, 70))
                smile.addQuadCurve(to: pt(56, 70), control: pt(50, 75))
                ctx.stroke(smile, with: .color(SpritePalette.cream), lineWidth: 3 * s)

                drawAccessory(ctx, hat: (44, 28), chin: (50, 84), eyes: (42, 58, 56))
            }
        }
    }
}
/// The unhatched companion egg, in the same style.
struct CompanionEggView: View {
    var size: CGFloat = 74

    var body: some View {
        Canvas { context, canvasSize in
            let s = min(canvasSize.width, canvasSize.height) / 100
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }

            var egg = Path()
            egg.move(to: pt(50, 10))
            egg.addCurve(to: pt(76, 62), control1: pt(71, 14), control2: pt(80, 42))
            egg.addCurve(to: pt(50, 92), control1: pt(72, 84), control2: pt(62, 92))
            egg.addCurve(to: pt(24, 62), control1: pt(38, 92), control2: pt(28, 84))
            egg.addCurve(to: pt(50, 10), control1: pt(20, 42), control2: pt(29, 14))
            egg.closeSubpath()
            context.fill(egg, with: .color(SpritePalette.cream))
            context.stroke(egg, with: .color(SpritePalette.outline.opacity(0.75)), lineWidth: 4 * s)

            // Gold zigzag band
            var band = Path()
            band.move(to: pt(27, 58))
            band.addLine(to: pt(38, 48))
            band.addLine(to: pt(50, 58))
            band.addLine(to: pt(62, 48))
            band.addLine(to: pt(73, 58))
            context.stroke(band, with: .color(SpritePalette.goldMark), lineWidth: 3.5 * s)

            // Indigo speckles
            for (x, y) in [(38.0, 32.0), (61.0, 42.0), (44.0, 70.0)] {
                context.fill(
                    Path(ellipseIn: CGRect(x: (x - 2.5) * s, y: (y - 2.5) * s, width: 5 * s, height: 5 * s)),
                    with: .color(SpritePalette.stone.opacity(0.8))
                )
            }
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(-6))
        .accessibilityHidden(true)
    }
}

// MARK: - State

extension AppState {
    var activeCompanionSpecies: CompanionSpecies? {
        user.activeCompanion.flatMap(CompanionSpecies.init(rawValue:))
    }

    /// The user's chosen name for a spirit, falling back to its species.
    func companionDisplayName(_ species: CompanionSpecies) -> String {
        user.companionNames[species.rawValue] ?? species.displayName
    }

    func renameCompanion(_ species: CompanionSpecies, to name: String) {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
        if trimmed.isEmpty {
            user.companionNames[species.rawValue] = nil   // back to species name
        } else {
            user.companionNames[species.rawValue] = trimmed
        }
        save()
    }

    /// Consumes one egg and hatches a random spirit. A duplicate species
    /// still becomes active but also brings a small coin consolation.
    func hatchEgg() -> (species: CompanionSpecies, isNew: Bool)? {
        guard user.companionEggs > 0 else { return nil }
        user.companionEggs -= 1

        let species = CompanionSpecies.allCases.randomElement() ?? .wisp
        let isNew = !user.hatchedCompanions.contains(species.rawValue)
        if isNew {
            user.hatchedCompanions.append(species.rawValue)
        } else {
            user.coins += 45
        }
        user.activeCompanion = species.rawValue
        save()
        return (species, isNew)
    }

    /// Makes a hatched species the active companion.
    func setActiveCompanion(_ species: CompanionSpecies) {
        guard user.hatchedCompanions.contains(species.rawValue) else { return }
        user.activeCompanion = species.rawValue
        save()
    }

    /// Switches the active companion to the next hatched species.
    func cycleCompanion() {
        let owned = user.hatchedCompanions.compactMap(CompanionSpecies.init(rawValue:))
        guard owned.count > 1, let current = activeCompanionSpecies,
              let index = owned.firstIndex(of: current) else { return }
        user.activeCompanion = owned[(index + 1) % owned.count].rawValue
        save()
    }
}

// MARK: - Card

/// Companion panel on the Skills page: shows the hatched spirit, an egg
/// waiting to hatch, or a hint that eggs come from treasure cards.
struct CompanionCard: View {
    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var bounce = false
    @State private var hatchAnnouncement: String? = nil
    @State private var hatchAnnouncementToken = UUID()
    @State private var hatchResult: HatchCeremonyView.Result? = nil
    @State private var showRename = false
    @State private var renameText = ""
    @State private var renameTargetSpecies: CompanionSpecies? = nil

    private var usesAccessibilityLayout: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        // At accessibility sizes the portrait, copy and Hatch plate stack
        // vertically so nothing is squeezed or clipped.
        let layout = usesAccessibilityLayout
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 16))

        layout {
            portrait

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(titleText)
                        .font(RPGTheme.heading(.headline, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    PillTag(text: "Companion", tint: RPGTheme.gold)
                }

                Text(hatchAnnouncement ?? subtitleText)
                    .font(.caption)
                    .foregroundColor(hatchAnnouncement == nil ? .secondary : RPGTheme.gold)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !usesAccessibilityLayout {
                Spacer(minLength: 8)
            }

            if state.user.companionEggs > 0 {
                Button {
                    hatch()
                } label: {
                    VStack(spacing: 1) {
                        Text("Hatch")
                            .font(.subheadline.weight(.semibold))
                        if state.user.companionEggs > 1 {
                            Text("×\(state.user.companionEggs)")
                                .font(RPGTheme.label(11, weight: .semibold))
                                .monospacedDigit()
                                .opacity(0.85)
                        }
                    }
                    .foregroundColor(RPGTheme.onPlate)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .frame(minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: RPGTheme.innerRadius, style: .continuous)
                            .fill(RPGTheme.plate)
                            .overlay(
                                RoundedRectangle(cornerRadius: RPGTheme.innerRadius, style: .continuous)
                                    .strokeBorder(RPGTheme.gold.opacity(0.55), lineWidth: 1)
                            )
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableCardStyle())
                .accessibilityLabel("Hatch egg, \(state.user.companionEggs) available")
            }

            // Rename and spirit switching, visible — the tap-to-cycle and
            // long-press shortcuts stay, but neither is the only door.
            if let species = state.activeCompanionSpecies {
                Menu {
                    Button {
                        renameTargetSpecies = species
                        renameText = state.companionDisplayName(species)
                        showRename = true
                    } label: {
                        Label("Rename \(state.companionDisplayName(species))", systemImage: "pencil")
                    }
                    if state.user.hatchedCompanions.count > 1 {
                        Button {
                            Haptics.tap()
                            state.cycleCompanion()
                        } label: {
                            RPGSymbolLabel("Switch Spirit", symbol: .companion)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                        .foregroundColor(RPGTheme.accent)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Companion options")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .rpgCard(padding: 14)
        .contentShape(Rectangle())
        .onTapGesture {
            guard state.activeCompanionSpecies != nil else { return }
            Haptics.tap()
            state.cycleCompanion()
            guard !reduceMotion else { return }
            bounce = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { bounce = false }
        }
        .contextMenu {
            if let species = state.activeCompanionSpecies {
                Button {
                    renameTargetSpecies = species
                    renameText = state.companionDisplayName(species)
                    showRename = true
                } label: {
                    Label("Rename \(state.companionDisplayName(species))", systemImage: "pencil")
                }
            }
        }
        .alert("Name your companion", isPresented: $showRename) {
            TextField("Name", text: $renameText)
            Button("Save") {
                if let species = renameTargetSpecies {
                    state.renameCompanion(species, to: renameText)
                }
                renameTargetSpecies = nil
            }
            Button("Cancel", role: .cancel) { renameTargetSpecies = nil }
        } message: {
            Text("Leave it blank to go back to the species name.")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(titleText). \(hatchAnnouncement ?? subtitleText)")
        .fullScreenCover(item: $hatchResult) { result in
            HatchCeremonyView(result: result) {
                hatchResult = nil
            }
        }
    }

    @ViewBuilder
    private var portrait: some View {
        Group {
            if let species = state.activeCompanionSpecies {
                BondedCompanionView(species: species, size: 66)
            } else if state.user.companionEggs > 0 {
                CompanionEggView(size: 60)
            } else {
                RPGSymbolIcon(
                    symbol: .companionEgg,
                    size: 30,
                    presentation: .standard,
                    palette: .adaptive
                )
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(RPGTheme.surfaceInner)
                            .overlay(Circle().strokeBorder(RPGTheme.frame.opacity(RPGTheme.hairline), lineWidth: 1))
                    )
            }
        }
        .scaleEffect(bounce ? 1.08 : 1.0)
        .offset(y: bounce ? -4 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.45), value: bounce)
    }

    private var titleText: String {
        if let species = state.activeCompanionSpecies { return state.companionDisplayName(species) }
        return state.user.companionEggs > 0 ? "Mysterious Egg" : "No Companion"
    }

    private var subtitleText: String {
        guard let species = state.activeCompanionSpecies else {
            if state.user.companionEggs > 0 {
                return "Something stirs inside. Hatch it to meet your companion."
            }
            return "Treasure chests sometimes hold companion eggs."
        }

        let calendar = Calendar.current

        // A fresh Trial victory outranks everything else worth saying.
        if let lastVictory = state.user.trialVictories.last,
           Date().timeIntervalSince(lastVictory.date) < 3600 {
            return "\(state.companionDisplayName(species)) is still buzzing from the fall of \(lastVictory.bossName)."
        }

        let sessionsToday = state.history.filter { calendar.isDateInToday($0.date) }.count
        if sessionsToday == 0 {
            return species.idleLine(named: state.companionDisplayName(species))
        }
        let ownedCount = state.user.hatchedCompanions.count
        let switchHint = ownedCount > 1 ? " Tap to switch spirits." : ""
        if sessionsToday == 1 {
            return "One session today. \(state.companionDisplayName(species)) approves.\(switchHint)"
        }
        return "\(sessionsToday) sessions today. \(state.companionDisplayName(species)) is thriving.\(switchHint)"
    }

    private func hatch() {
        guard let result = state.hatchEgg() else { return }
        // The ceremony is the celebration; the card line lingers afterward.
        hatchResult = HatchCeremonyView.Result(species: result.species, isNew: result.isNew)
        let displayName = state.companionDisplayName(result.species)
        hatchAnnouncement = result.isNew
            ? "\(displayName) hatched!"
            : "\(displayName) again — it brought 45 coins."
        let token = UUID()
        hatchAnnouncementToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            // Only clear our own announcement — a newer hatch owns the label
            if hatchAnnouncementToken == token {
                hatchAnnouncement = nil
            }
        }
    }
}

/// Full-screen hatch ceremony — the most magical moment in the app finally
/// gets its beat: the egg stirs, cracks, and the spirit springs out.
struct HatchCeremonyView: View {
    struct Result: Identifiable {
        let id = UUID()
        let species: CompanionSpecies
        let isNew: Bool
    }

    let result: Result
    let onDone: () -> Void
    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stage = 0 // 0 = still egg, 1 = stirring, 2 = revealed
    @State private var wobble = false
    @State private var burst = false

    private var companionName: String {
        state.companionDisplayName(result.species)
    }

    var body: some View {
        ZStack {
            RPGTheme.canvas.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    // Gold burst behind the reveal
                    if stage == 2 {
                        ForEach(0..<8, id: \.self) { index in
                            GlyphIcon(glyph: .spark, size: 16, tint: RPGTheme.gold.opacity(0.8))
                                .offset(y: burst ? -86 : -20)
                                .rotationEffect(.degrees(Double(index) * 45))
                                .opacity(burst ? 0 : 1)
                                .animation(reduceMotion ? nil : .easeOut(duration: 0.9).delay(Double(index) * 0.03), value: burst)
                                .accessibilityHidden(true)
                        }
                    }

                    if stage < 2 {
                        CompanionEggView(size: 120)
                            .rotationEffect(.degrees(stage == 1 && wobble ? 7 : (stage == 1 ? -7 : 0)))
                            .animation(
                                stage == 1 && !reduceMotion
                                    ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true)
                                    : .default,
                                value: wobble
                            )
                    } else {
                        CompanionSpriteView(species: result.species, size: 150, accessory: state.accessory(for: result.species))
                            .transition(.scale(scale: 0.3).combined(with: .opacity))
                    }
                }
                .frame(height: 190)

                VStack(spacing: 8) {
                    if stage == 2 {
                        Text(companionName)
                            .font(RPGTheme.heading(34))
                            .foregroundColor(.primary)
                        Text(result.isNew
                             ? "A new spirit joins your journey!"
                             : "You've met before — it brought 45 coins.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Something stirs…")
                            .font(RPGTheme.heading(.title3, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

                Spacer()

                Text(stage == 2 ? "Tap anywhere to continue" : " ")
                    .font(RPGTheme.label(11, weight: .medium))
                    .tracking(0.6)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 28)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if stage == 2 {
                onDone()
            } else {
                reveal() // impatient taps skip straight to the good part
            }
        }
        .onAppear {
            if reduceMotion {
                stage = 2
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard stage == 0 else { return }
                stage = 1
                wobble = true
                Haptics.tap()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                reveal()
            }
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { onDone() }
        .accessibilityLabel(stage == 2
            ? "\(companionName) hatched. \(result.isNew ? "A new spirit joins your journey." : "A duplicate — it brought 45 coins.") Double tap to continue."
            : "An egg is hatching")
    }

    private func reveal() {
        guard stage != 2 else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            stage = 2
        }
        burst = true
        Haptics.success()
    }
}

// MARK: - Accessories

/// Cosmetic accessories for companions, purchased with coins. Drawn as
/// vector overlays by CompanionSpriteView so they inherit each spirit's
/// idle motion.
enum PetAccessory: String, Codable, CaseIterable, Identifiable {
    case bowtie, spectacles, scarf, cap, crown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bowtie: return "Bow Tie"
        case .spectacles: return "Spectacles"
        case .scarf: return "Adventurer's Scarf"
        case .cap: return "Ranger Cap"
        case .crown: return "Tiny Crown"
        }
    }

    var price: Int {
        switch self {
        case .bowtie: return 100
        case .spectacles: return 150
        case .scarf: return 250
        case .cap: return 400
        case .crown: return 800
        }
    }
}

extension AppState {
    func ownsAccessory(_ accessory: PetAccessory) -> Bool {
        user.ownedAccessories.contains(accessory.rawValue)
    }

    func accessory(for species: CompanionSpecies) -> PetAccessory? {
        user.petAccessories[species.rawValue].flatMap(PetAccessory.init(rawValue:))
    }

    /// Buys an accessory with coins and equips it on the active companion.
    @discardableResult
    func buyAccessory(_ accessory: PetAccessory) -> Bool {
        guard !ownsAccessory(accessory), user.coins >= accessory.price else { return false }
        user.coins -= accessory.price
        user.ownedAccessories.append(accessory.rawValue)
        if let species = activeCompanionSpecies {
            user.petAccessories[species.rawValue] = accessory.rawValue
        }
        save()
        return true
    }

    /// Equips the accessory on the species, or takes it off if already worn.
    func toggleAccessory(_ accessory: PetAccessory, for species: CompanionSpecies) {
        guard ownsAccessory(accessory) else { return }
        if user.petAccessories[species.rawValue] == accessory.rawValue {
            user.petAccessories[species.rawValue] = nil
        } else {
            user.petAccessories[species.rawValue] = accessory.rawValue
        }
        save()
    }
}

// MARK: - Shop

/// Spend coins on companion accessories. Reached from the Inventory tab.
struct PetShopView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        fittingRoomPanel
                        suppliesPanel
                        accessoriesPanel
                    }
                    .screenColumn()
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Companion Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    CoinBadge(amount: state.user.coins)
                }
            }
        }
    }

    // MARK: Fitting room

    /// The marquee panel: the active companion models its gear. The one
    /// ornate plate on this screen.
    private var fittingRoomPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Fitting Room")

            if let species = state.activeCompanionSpecies {
                VStack(spacing: 10) {
                    BondedCompanionView(species: species, size: 110)
                    Text(state.companionDisplayName(species))
                        .font(RPGTheme.heading(.title3, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    Text(state.accessory(for: species).map { "Wearing: \($0.displayName)" } ?? "Nothing equipped")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Bond: deterministic, earned, never sold.
                    let stage = state.bondStage(for: species)
                    let days = state.bondDays(for: species)
                    HStack(spacing: 5) {
                        RPGSymbolIcon(
                            symbol: .companionBond,
                            size: 12,
                            presentation: .compact,
                            palette: .monochrome(stage == .ascendant ? RPGTheme.gold : RPGTheme.accent)
                        )
                        if let next = BondStage(rawValue: stage.rawValue + 1) {
                            Text("\(stage.displayName) · \(days) training days · \(next.threshold - days) to \(next.displayName)")
                        } else {
                            Text("\(stage.displayName) · \(days) training days")
                        }
                    }
                    .font(.caption2.weight(.medium))
                    .monospacedDigit()
                    .foregroundColor(stage == .ascendant ? RPGTheme.gold : RPGTheme.accent)
                    .multilineTextAlignment(.center)

                    // Swap which spirit is being dressed
                    let owned = state.user.hatchedCompanions.compactMap(CompanionSpecies.init(rawValue:))
                    if owned.count > 1 {
                        HStack(spacing: 8) {
                            ForEach(owned, id: \.self) { candidate in
                                spiritChip(candidate, selected: candidate == species)
                            }
                        }
                        .padding(.top, 6)
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                EmptyStateView(
                    title: "No Companion Yet",
                    message: "Open chests to find companion eggs, then hatch them from your Character sheet and come back to dress up your spirit.",
                    tint: RPGTheme.gold,
                    symbol: .companion
                )
            }
        }
        .rpgCard(padding: 14, ornate: true)
    }

    /// Selectable spirit chip: sprite plus name, brass-filled when chosen.
    private func spiritChip(_ candidate: CompanionSpecies, selected: Bool) -> some View {
        Button {
            Haptics.tap()
            state.setActiveCompanion(candidate)
        } label: {
            HStack(spacing: 6) {
                CompanionSpriteView(
                    species: candidate,
                    size: 26,
                    animated: false,
                    accessory: state.accessory(for: candidate)
                )
                Text(state.companionDisplayName(candidate))
                    .font(RPGTheme.label(12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(selected ? .white : .primary)
            .padding(.leading, 6)
            .padding(.trailing, 12)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(selected ? RPGTheme.accentFill : RPGTheme.surfaceInner)
            )
            .overlay(
                Capsule().strokeBorder(
                    selected ? Color.clear : RPGTheme.frame.opacity(RPGTheme.hairline),
                    lineWidth: 1
                )
            )
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel("Dress \(state.companionDisplayName(candidate))")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Supplies

    /// Permanent coin sinks that stay useful: freezes protect the streak,
    /// eggs fill the collection.
    private var suppliesPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel("Supplies")
                .padding(.bottom, 6)

            supplyRow(
                title: "Streak Freeze",
                subtitle: state.user.streakFreezes >= 3
                    ? "Fully stocked (3 of 3)"
                    : "Covers one missed day · holding \(state.user.streakFreezes) of 3",
                price: 250,
                enabled: state.user.streakFreezes < 3 && state.user.coins >= 250,
                leading: {
                    RPGSymbolIcon(
                        symbol: .streakFreeze,
                        size: 20,
                        presentation: .compact,
                        palette: .monochrome(RPGTheme.accent)
                    )
                }
            ) {
                state.buyStreakFreeze()
            }

            if state.user.hatchedCompanions.count < CompanionSpecies.allCases.count {
                HairlineRule()
                supplyRow(
                    title: "Mysterious Egg",
                    subtitle: "A new spirit might be inside",
                    price: 400,
                    enabled: state.user.coins >= 400,
                    leading: {
                        RPGSymbolIcon(
                            symbol: .companionEgg,
                            size: 20,
                            presentation: .compact,
                            palette: .monochrome(RPGTheme.gold)
                        )
                    }
                ) {
                    state.buyCompanionEgg()
                }
            }
        }
        .rpgCard(padding: 14)
    }

    private func supplyRow<Leading: View>(title: String,
                                          subtitle: String,
                                          price: Int,
                                          enabled: Bool,
                                          @ViewBuilder leading: @escaping () -> Leading,
                                          onBuy: @escaping () -> Void) -> some View {
        RPGRow(title: title, subtitle: subtitle, chevron: false, leading: leading) {
            HStack(spacing: 10) {
                CoinBadge(amount: price, size: 13)
                Button("Buy") {
                    onBuy()
                }
                .buttonStyle(CompactSecondaryButtonStyle())
                .disabled(!enabled)
                .accessibilityLabel("Buy \(title)")
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Accessories

    private var accessoriesPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel("Accessories")
                .padding(.bottom, 6)

            ForEach(Array(PetAccessory.allCases.enumerated()), id: \.element.id) { index, accessory in
                if index > 0 { HairlineRule() }
                accessoryRow(accessory)
            }
        }
        .rpgCard(padding: 14)
    }

    @ViewBuilder
    private func accessoryRow(_ accessory: PetAccessory) -> some View {
        let species = state.activeCompanionSpecies
        let owned = state.ownsAccessory(accessory)
        let equipped = species.map { state.accessory(for: $0) == accessory } ?? false
        let affordable = state.user.coins >= accessory.price

        RPGRow(title: accessory.displayName,
               subtitle: owned ? "Owned" : nil,
               chevron: false) {
            // Preview on the active spirit (or a generic relic mark before hatching)
            if let species {
                CompanionSpriteView(species: species, size: 32, animated: false, accessory: accessory)
            } else {
                RPGSymbolIcon(
                    symbol: .equipmentRelic,
                    size: 20,
                    presentation: .compact,
                    palette: .monochrome(RPGTheme.frame)
                )
            }
        } trailing: {
            HStack(spacing: 10) {
                if owned {
                    if equipped {
                        Button("Unequip") {
                            guard let species else { return }
                            Haptics.tap()
                            state.toggleAccessory(accessory, for: species)
                        }
                        .buttonStyle(RPGQuietButtonStyle())
                        .accessibilityLabel("Unequip \(accessory.displayName)")
                        .disabled(species == nil)
                    } else {
                        Button("Equip") {
                            guard let species else { return }
                            Haptics.tap()
                            state.toggleAccessory(accessory, for: species)
                        }
                        .buttonStyle(CompactSecondaryButtonStyle())
                        .accessibilityLabel("Equip \(accessory.displayName)")
                        .disabled(species == nil)
                    }
                } else {
                    CoinBadge(amount: accessory.price, size: 13)
                    Button("Buy") {
                        Haptics.success()
                        state.buyAccessory(accessory)
                    }
                    .buttonStyle(CompactSecondaryButtonStyle())
                    .accessibilityLabel("Buy \(accessory.displayName)")
                    .disabled(!affordable)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// RPGSecondaryButtonStyle at row scale: the same surface fill and brass
/// hairline, compact padding, and a 44pt hit target inside a list row.
private struct CompactSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundColor(isEnabled ? .primary : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: RPGTheme.innerRadius - 2, style: .continuous)
                    .fill(RPGTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: RPGTheme.innerRadius - 2, style: .continuous)
                            .strokeBorder(RPGTheme.accent.opacity(isEnabled ? 0.6 : 0.25), lineWidth: 1.2)
                    )
            )
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.98 : 1.0))
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7),
                value: configuration.isPressed
            )
    }
}

// MARK: - Companion Bond
//
// Deterministic evolution — the Finch lesson applied with the Walking RPG
// lesson subtracted: attachment grows from showing up (distinct training
// days), never from dice rolls, and no stage is ever sold. The companion
// celebrates your consistency; it cannot suffer.

enum BondStage: Int, CaseIterable {
    case hatchling = 1
    case kindred = 2
    case ascendant = 3

    var displayName: String {
        switch self {
        case .hatchling: return "Hatchling"
        case .kindred: return "Kindred"
        case .ascendant: return "Ascendant"
        }
    }

    /// Training days needed to reach this stage.
    var threshold: Int {
        switch self {
        case .hatchling: return 0
        case .kindred: return 10
        case .ascendant: return 30
        }
    }

    static func stage(forBondDays days: Int) -> BondStage {
        if days >= BondStage.ascendant.threshold { return .ascendant }
        if days >= BondStage.kindred.threshold { return .kindred }
        return .hatchling
    }
}

extension AppState {
    func bondDays(for species: CompanionSpecies) -> Int {
        user.companionBondDays[species.rawValue] ?? 0
    }

    func bondStage(for species: CompanionSpecies) -> BondStage {
        BondStage.stage(forBondDays: bondDays(for: species))
    }

    /// Called from logWorkout: the first log of each calendar day deepens
    /// the active companion's bond by one. Crossing a stage celebrates.
    func deepenCompanionBond() {
        guard !isReplayingHistory,
              let species = activeCompanionSpecies else { return }
        let cal = Calendar.current
        if let last = user.lastBondDay, cal.isDateInToday(last) { return }
        user.lastBondDay = Date()

        let before = bondStage(for: species)
        user.companionBondDays[species.rawValue, default: 0] += 1
        let after = bondStage(for: species)

        if after != before {
            Haptics.success()
            let name = companionDisplayName(species)
            pushToast(title: "\(name) evolved!",
                      subtitle: "Your bond has grown — \(name) is now \(after.displayName).",
                      kind: .gold,
                      symbol: .companionBond)
        }
    }
}

/// The companion with its bond made visible: Kindred spirits sit inside a
/// brass ring, Ascendant ones a gold ring with sparks and a touch more
/// presence. Flat and additive over the sprite — no glow, no blur — so the
/// Canvas art stays untouched.
struct BondedCompanionView: View {
    @EnvironmentObject var state: AppState
    let species: CompanionSpecies
    var size: CGFloat = 66

    var body: some View {
        let stage = state.bondStage(for: species)
        let auraTint = stage == .ascendant ? RPGTheme.gold : RPGTheme.accent
        ZStack {
            if stage != .hatchling {
                Circle()
                    .fill(auraTint.opacity(0.08))
                    .overlay(
                        Circle().strokeBorder(auraTint.opacity(0.35), lineWidth: 1)
                    )
                    .frame(width: size * 1.24, height: size * 1.24)
                    .accessibilityHidden(true)
            }

            if stage == .ascendant {
                ForEach(0..<3, id: \.self) { index in
                    GlyphIcon(glyph: .spark, size: size * 0.13, tint: RPGTheme.gold.opacity(0.85))
                        .offset(x: cos(Double(index) * 2.1 + 0.6) * size * 0.58,
                                y: sin(Double(index) * 2.1 + 0.6) * size * 0.52 - size * 0.1)
                        .accessibilityHidden(true)
                }
            }

            CompanionSpriteView(species: species,
                                size: stage == .ascendant ? size * 1.06 : size,
                                accessory: state.accessory(for: species))
        }
        .accessibilityLabel("\(state.companionDisplayName(species)), \(stage.displayName) bond")
    }
}
