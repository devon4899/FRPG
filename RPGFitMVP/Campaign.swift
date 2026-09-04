import SwiftUI

// MARK: - Campaign map
//
// The boss ladder grouped into authored regions, so Trial progress reads
// as a journey across a world instead of a number going up. Purely a
// presentation layer over the existing ladder — same bosses, same might,
// same rewards.

struct CampaignRegion: Identifiable {
    let name: String
    let flavor: String
    let rungs: ClosedRange<Int>

    var id: Int { rungs.lowerBound }

    /// The region's authored map mark. Progress remains encoded separately by
    /// the lock and cleared seals, so this symbol never changes with state.
    var rpgSymbol: RPGSymbol {
        if rungs == 0...2 { return .regionKindlingVale }
        if rungs == 3...5 { return .regionAshenPasses }
        if rungs == 6...8 { return .regionStormreach }
        if rungs == 9...11 { return .regionCrownOfDawn }
        return .regionElderWilds
    }

    static let all: [CampaignRegion] = [
        CampaignRegion(name: "The Kindling Vale",
                       flavor: "Soft hills where every fire starts small.",
                       rungs: 0...2),
        CampaignRegion(name: "The Ashen Passes",
                       flavor: "Burnt ridges that test a plan's second week.",
                       rungs: 3...5),
        CampaignRegion(name: "The Stormreach",
                       flavor: "Thin air, loud sky, heavier iron.",
                       rungs: 6...8),
        CampaignRegion(name: "The Crown of Dawn",
                       flavor: "The last climb before legend.",
                       rungs: 9...11),
    ]
}

struct CampaignMapView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var currentRung: Int { state.user.trialRung }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        ForEach(CampaignRegion.all) { region in
                            regionCard(region)
                        }
                        elderWilds
                    }
                    .screenColumn()
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Campaign")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: Regions

    private func regionCard(_ region: CampaignRegion) -> some View {
        let cleared = currentRung > region.rungs.upperBound
        let reached = currentRung >= region.rungs.lowerBound
        let isCurrent = reached && !cleared

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                RPGSymbolIcon(
                    symbol: region.rpgSymbol,
                    size: 24,
                    presentation: .standard,
                    palette: .adaptive
                )

                SectionLabel(region.name, tint: isCurrent ? RPGTheme.gold : .secondary) {
                    if cleared {
                        ZStack {
                            RPGSymbolIcon(
                                symbol: .completionSeal,
                                size: 14,
                                presentation: .compact,
                                palette: .monochrome(RPGTheme.xp)
                            )
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Region cleared")
                    } else if !reached {
                        Image(systemName: "lock")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                            .accessibilityLabel("Region locked")
                    }
                }
            }

            Text(region.flavor)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
                .padding(.bottom, 6)

            ForEach(Array(region.rungs.enumerated()), id: \.element) { index, rung in
                if index > 0 { HairlineRule() }
                bossRow(TrialLadder.boss(atRung: rung))
            }
        }
        .rpgCard(padding: 14,
                 accent: isCurrent ? RPGTheme.gold : nil,
                 ornate: isCurrent)
        // Locked regions read as distant, not illegible: text keeps its full
        // contrast; only the panel's own weight softens.
        .saturation(reached ? 1 : 0.6)
        .opacity(reached ? 1 : 0.85)
    }

    // MARK: Boss rows

    @ViewBuilder
    private func bossRow(_ boss: TrialBoss) -> some View {
        let fallen = boss.rung < currentRung
        let isCurrent = boss.rung == currentRung
        let known = fallen || isCurrent
        let progress = min(1.0, state.user.trialMight / max(1, boss.hp))

        HStack(spacing: 12) {
            // A campaign can show a dozen bosses at once. Only the foe the
            // user is currently facing needs a 30-fps TimelineView.
            TrialBossView(boss: boss, size: 30, animated: isCurrent)
                .opacity(fallen ? 0.55 : (isCurrent ? 1 : 0.3))
                .saturation(known ? 1 : 0)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(known ? boss.name : "???")
                    .font(RPGTheme.heading(.subheadline, weight: .semibold))
                    .strikethrough(fallen)
                    .foregroundColor(fallen || !known ? .secondary : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(known ? boss.epithet : "Undiscovered")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 6)

            if fallen {
                RPGSymbolIcon(
                    symbol: .completionSeal,
                    size: 18,
                    presentation: .compact,
                    palette: .monochrome(RPGTheme.xp)
                )
            } else if isCurrent {
                HStack(spacing: 8) {
                    Text("\(Int(progress * 100))%")
                        .font(RPGTheme.label(12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundColor(RPGTheme.gold)
                    ZStack {
                        Circle()
                            .stroke(RPGTheme.surfaceInner, lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: CGFloat(progress))
                            .stroke(RPGTheme.gold, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8),
                                       value: progress)
                    }
                    .frame(width: 22, height: 22)
                }
            }
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(bossAccessibilityLabel(boss, fallen: fallen, isCurrent: isCurrent))
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private func bossAccessibilityLabel(_ boss: TrialBoss, fallen: Bool, isCurrent: Bool) -> String {
        if fallen {
            return "\(boss.name), \(boss.epithet), defeated"
        }
        if isCurrent {
            let progress = min(1.0, state.user.trialMight / max(1, boss.hp))
            return "\(boss.name), \(boss.epithet), current foe, \(Int(progress * 100)) percent of might banked"
        }
        return "Undiscovered boss, locked"
    }

    // MARK: Elder Wilds

    @ViewBuilder
    private var elderWilds: some View {
        let inWilds = currentRung > 11
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                RPGSymbolIcon(
                    symbol: .regionElderWilds,
                    size: 24,
                    presentation: .standard,
                    palette: .adaptive
                )

                SectionLabel("The Elder Wilds", tint: inWilds ? RPGTheme.gold : .secondary) {
                    if !inWilds {
                        Image(systemName: "lock")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                            .accessibilityHidden(true)
                    }
                }
            }

            Text(inWilds
                 ? "Beyond the crown, the beasts return — older, patient, tougher. The mountain has no summit, only higher camps."
                 : "What lies past the Crown of Dawn is spoken of only by those who cleared it.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
                .padding(.bottom, inWilds ? 6 : 0)

            if inWilds {
                bossRow(state.currentTrialBoss)
            }
        }
        .rpgCard(padding: 14, accent: inWilds ? RPGTheme.gold : nil, ornate: inWilds)
        .opacity(inWilds ? 1 : 0.6)
    }
}
