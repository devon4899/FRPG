import SwiftUI

// MARK: - Plate math
//
// Pure and unit-agnostic: everything is in the user's display units. The
// greedy solve is correct here because every standard plate divides the
// ones above it.

enum PlateMath {
    struct Solution: Equatable {
        /// (plate weight, count) per side, heaviest first. Empty = bar only.
        let perSide: [(weight: Double, count: Int)]
        /// What the bar + plates actually total.
        let achieved: Double
        /// How far below the target the achievable load falls (0 = exact).
        let shortfall: Double

        static func == (lhs: Solution, rhs: Solution) -> Bool {
            lhs.achieved == rhs.achieved && lhs.shortfall == rhs.shortfall &&
            lhs.perSide.map(\.weight) == rhs.perSide.map(\.weight) &&
            lhs.perSide.map(\.count) == rhs.perSide.map(\.count)
        }
    }

    static func standardPlates(kg: Bool) -> [Double] {
        kg ? [25, 20, 15, 10, 5, 2.5, 1.25] : [45, 35, 25, 10, 5, 2.5]
    }

    static func standardBars(kg: Bool) -> [Double] {
        kg ? [20, 15, 10] : [45, 35, 25]
    }

    static func solve(target: Double, bar: Double, plates: [Double]) -> Solution? {
        guard target.isFinite,
              bar.isFinite,
              target >= bar,
              plates.allSatisfy({ $0.isFinite && $0 > 0 }) else { return nil }
        var remaining = (target - bar) / 2
        var perSide: [(Double, Int)] = []
        for plate in plates.sorted(by: >) {
            let rawCount = floor((remaining / plate) + 0.0001)
            // A decimal field can still receive pasted scientific notation.
            // Converting a finite Double outside Int's range traps, so fail the
            // calculation instead of taking down the whole sheet.
            guard rawCount >= 0, rawCount < Double(Int.max) else { return nil }
            let count = Int(rawCount)
            if count > 0 {
                perSide.append((plate, count))
                remaining -= Double(count) * plate
            }
        }
        let shortfall = max(0, remaining * 2)
        let achieved = target - shortfall
        return Solution(perSide: perSide,
                        achieved: (achieved * 100).rounded() / 100,
                        shortfall: (shortfall * 100).rounded() / 100)
    }
}

// MARK: - Sheet

struct PlateCalculatorSheet: View {
    let units: Units
    @State private var targetText: String
    @State private var barWeight: Double
    @Environment(\.dismiss) private var dismiss

    init(units: Units, initialWeight: Double? = nil) {
        self.units = units
        _targetText = State(initialValue: initialWeight.map(AppState.fieldNumber) ?? "")
        _barWeight = State(initialValue: PlateMath.standardBars(kg: units == .kg)[0])
    }

    private var solution: PlateMath.Solution? {
        guard let target = flexibleDouble(targetText), target > 0 else { return nil }
        return PlateMath.solve(target: target,
                               bar: barWeight,
                               plates: PlateMath.standardPlates(kg: units == .kg))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel("Target (\(units.displayName))")
                            TextField("100", text: $targetText)
                                .keyboardType(.decimalPad)
                                .font(RPGTheme.display(34))
                                .monospacedDigit()
                                .foregroundColor(.primary)
                                .accessibilityLabel("Target barbell weight")
                                .accessibilityValue(targetText.isEmpty ? "Not set" : "\(targetText) \(units.displayName)")

                            SectionLabel("Bar")
                                .padding(.top, 4)
                            barChips
                        }
                        .rpgCard(padding: 14)

                        if let solution {
                            VStack(spacing: 14) {
                                SectionLabel("Per Side")
                                if solution.perSide.isEmpty {
                                    Text("Just the bar")
                                        .font(RPGTheme.heading(.headline, weight: .semibold))
                                        .foregroundColor(.secondary)
                                } else {
                                    PlateStackView(perSide: solution.perSide)

                                    Text(solution.perSide
                                            .map { "\($0.count) × \(AppState.fieldNumber($0.weight))" }
                                            .joined(separator: "  ·  "))
                                        .font(RPGTheme.display(16))
                                        .monospacedDigit()
                                        .foregroundColor(.primary)
                                    Text("per side")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                if solution.shortfall > 0 {
                                    Text("Closest below: \(AppState.fieldNumber(solution.achieved)) \(units.displayName) — short \(AppState.fieldNumber(solution.shortfall)) total")
                                        .font(.caption)
                                        .foregroundColor(RPGTheme.warningText)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .rpgCard(padding: 14)
                        } else if !targetText.isEmpty {
                            Text("Target must be at least the bar (\(AppState.fieldNumber(barWeight)) \(units.displayName)).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .rpgCard(padding: 14)
                        }
                    }
                    .frame(maxWidth: AppLayout.contentMaxWidth)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, AppLayout.horizontalPadding)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Plate Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// Bar weights as hairline capsule chips; the chosen bar is a brass seal.
    private var barChips: some View {
        HStack(spacing: 8) {
            ForEach(PlateMath.standardBars(kg: units == .kg), id: \.self) { bar in
                let isSelected = barWeight == bar
                Button {
                    guard !isSelected else { return }
                    Haptics.tick()
                    barWeight = bar
                } label: {
                    Text("\(AppState.fieldNumber(bar)) \(units.displayName)")
                        .font(RPGTheme.label(13, weight: .semibold))
                        .monospacedDigit()
                        .foregroundColor(isSelected ? .white : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            Capsule().fill(isSelected ? RPGTheme.accentFill : RPGTheme.surfaceInner)
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                RPGTheme.frame.opacity(isSelected ? 0 : RPGTheme.hairline),
                                lineWidth: 1
                            )
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Bar \(AppState.fieldNumber(bar)) \(units.displayName)")
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Bar")
    }
}

/// Half the barbell, loaded: sleeve line plus one rectangle per plate,
/// heaviest inboard, height scaled by plate weight.
private struct PlateStackView: View {
    let perSide: [(weight: Double, count: Int)]

    private var plates: [Double] {
        perSide.flatMap { Array(repeating: $0.weight, count: $0.count) }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            RoundedRectangle(cornerRadius: 2)
                .fill(RPGTheme.frame.opacity(0.7))
                .frame(width: 26, height: 8)
            ForEach(Array(plates.enumerated()), id: \.offset) { _, weight in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(plateColor(weight))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .strokeBorder(RPGTheme.frame.opacity(RPGTheme.hairline + 0.2), lineWidth: 1)
                    )
                    .frame(width: max(8, min(16, weight * 0.55)),
                           height: plateHeight(weight))
            }
            RoundedRectangle(cornerRadius: 2)
                .fill(RPGTheme.frame.opacity(0.7))
                .frame(width: 14, height: 8)
        }
        .frame(height: 84)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loaded bar diagram")
    }

    private func plateHeight(_ weight: Double) -> CGFloat {
        let heaviest = plates.max() ?? 1
        return CGFloat(30 + 54 * (weight / heaviest))
    }

    /// Three materials, heaviest to lightest: brass, ink, cream. The
    /// hairline outline keeps cream plates legible on parchment.
    private func plateColor(_ weight: Double) -> Color {
        switch weight {
        case 25, 45: return RPGTheme.accent
        case 20, 35: return RPGTheme.ink
        case 15:     return RPGTheme.goldDeep
        case 10:     return RPGTheme.frame
        default:     return RPGTheme.cream
        }
    }
}
