// FRPG MVP — Single-file SwiftUI prototype
// Focus: workout logging → stat gains → EXP → leveling
// Persistence: JSON in Documents
// iOS 16+ (SwiftUI)


import SwiftUI
import Foundation
import UIKit

// iOS 16/17 compatible onChange wrapper (uses two-parameter closure on iOS 17+)
extension View {
    @ViewBuilder
    func onChangeCompat<T: Equatable>(of value: T, perform action: @escaping (_ oldValue: T, _ newValue: T) -> Void) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: value) { oldValue, newValue in
                action(oldValue, newValue)
            }
        } else {
            self.onChange(of: value) { newValue in
                action(value, newValue) // best-effort old value on iOS 16
            }
        }
    }
    
    // Helper function to dismiss keyboard
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // Keyboard dismiss toolbar helper
    func keyboardDismissToolbar() -> some View {
        self.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(action: dismissKeyboard) {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                }
                Spacer()
            }
        }
    }
    
    // Tap to dismiss keyboard
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture(perform: dismissKeyboard)
    }
    
    // Swipe down to dismiss keyboard
    func dismissKeyboardOnSwipe() -> some View {
        self.simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 50 && value.translation.width < 50 {
                        dismissKeyboard()
                    }
                }
        )
    }
}

// MARK: - StatBlock Scaler Extension
extension StatBlock {
    /// Returns a copy scaled by the given factor (used for display-scale adjustments)
    func scaled(_ k: Double) -> StatBlock {
        StatBlock(size: size * k,
                  strength: strength * k,
                  dexterity: dexterity * k,
                  agility: agility * k,
                  endurance: endurance * k,
                  vitality: vitality * k)
    }
}

// MARK: - Design Constants
struct ChestCardDesign {
    static let cardWidth: CGFloat = 160
    static let cardHeight: CGFloat = 200
    static let chestWidth: CGFloat = 120
    static let chestHeight: CGFloat = 160
    static let cornerRadius: CGFloat = 16
    static let innerBorderWidth: CGFloat = 6
    static let iconSize: CGFloat = 42
    static let cardSpacing: CGFloat = 12
    static let bounceScale: CGFloat = 0.95
    static let iconBounceScale: CGFloat = 1.1
}

// MARK: - Models
struct StatBlock: Codable, Equatable {
    var size: Double = 0
    var strength: Double = 0
    var dexterity: Double = 0
    var agility: Double = 0
    var endurance: Double = 0
    var vitality: Double = 0

    static let zero = StatBlock()

    var total: Double { size + strength + dexterity + agility + endurance + vitality }

    static func +(lhs: StatBlock, rhs: StatBlock) -> StatBlock {
        StatBlock(size: lhs.size + rhs.size,
                  strength: lhs.strength + rhs.strength,
                  dexterity: lhs.dexterity + rhs.dexterity,
                  agility: lhs.agility + rhs.agility,
                  endurance: lhs.endurance + rhs.endurance,
                  vitality: lhs.vitality + rhs.vitality)
    }

    mutating func add(_ rhs: StatBlock) { self = self + rhs }

}

// MARK: - Units Enum
enum Units: String, CaseIterable, Codable, Identifiable {
    case kg, lb
    var id: String { rawValue }
    var displayName: String { rawValue }
    var weightPlaceholder: String { self == .kg ? "e.g. 60 (kg)" : "e.g. 135 (lb)" }
    func toKg(_ value: Double) -> Double { self == .kg ? value : value * 0.45359237 }
    func fromKg(_ kg: Double) -> Double { self == .kg ? kg : kg / 0.45359237 }

    // MARK: - Distance helpers (paired to weight unit)
    /// UI label for distance unit: .kg → "km", .lb → "mi"
    var distanceDisplayName: String {
        switch self {
        case .kg: return "km"
        case .lb: return "mi"
        }
    }

    /// Convert a user-entered distance into kilometers for internal storage.
    /// When units == .lb we interpret input as miles and convert to km.
    func toKm(_ value: Double) -> Double {
        switch self {
        case .kg: return value
        case .lb: return value * 1.6
        }
    }

    /// Convert a stored kilometer value into the user's display units.
    /// When units == .lb we show miles.
    func fromKm(_ km: Double) -> Double {
        switch self {
        case .kg: return km
        case .lb: return km / 1.6
        }
    }
}

enum FocusGroup: String, CaseIterable, Codable, Identifiable {
    case strength, hypertrophy, endurance, explosive, mobility, bodyweight
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .strength: return "Strength"
        case .hypertrophy: return "Hypertrophy"
        case .endurance: return "Endurance"
        case .explosive: return "Explosive"
        case .mobility: return "Mobility"
        case .bodyweight: return "Bodyweight/Rings"
        }
    }
    var shortDisplayName: String {
        switch self {
        case .strength: return "Strength"
        case .hypertrophy: return "Hypertrophy"
        case .endurance: return "Endurance"
        case .explosive: return "Explosive"
        case .mobility: return "Mobility"
        case .bodyweight: return "Bodyweight"
        }
    }
}

struct ModernFocusChips: View {
    @Binding var selection: FocusGroup
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(FocusGroup.allCases) { focus in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selection = focus
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: iconForFocus(focus))
                                    .font(.title2)
                                    .foregroundColor(selection == focus ? .white : .primary)
                                    .frame(height: 30) // Add this line

                                Text(focus.shortDisplayName)
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(selection == focus ? .white : .primary)
                                    .lineLimit(1) // Add this line
                                    .minimumScaleFactor(0.8) // Add this line
                            }
                            .frame(width: 70, height: 70) // Add this modifier to the VStack
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(selection == focus ? .blue : Color(.secondarySystemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(
                                                selection == focus ? Color.clear : Color(.separator),
                                                lineWidth: 0.5
                                            )
                                    )
                            )
                            .scaleEffect(selection == focus ? 1.05 : 1.0)
                            .shadow(
                                color: selection == focus ? .blue.opacity(0.3) : .clear,
                                radius: selection == focus ? 8 : 0,
                                x: 0,
                                y: selection == focus ? 4 : 0
                            )
                        }
                        .id(focus)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .onAppear {
                DispatchQueue.main.async {
                    withAnimation { proxy.scrollTo(selection, anchor: .center) }
                }
            }
            .onChangeCompat(of: selection) { _, newSel in
                withAnimation { proxy.scrollTo(newSel, anchor: .center) }
            }
        }
    }
    
    private func iconForFocus(_ focus: FocusGroup) -> String {
        switch focus {
        case .strength: return "figure.strengthtraining.traditional"
        case .hypertrophy: return "figure.hand.cycling"
        case .endurance: return "figure.run.treadmill"
        case .explosive: return "figure.step.training"
        case .mobility: return "figure.yoga"
        case .bodyweight: return "figure.core.training"
        }
    }
}

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )
            )
    }
}

struct ModernInputRow: View {
    let title: String
    let subtitle: String?
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    
    init(title: String, subtitle: String? = nil, placeholder: String, text: Binding<String>, keyboardType: UIKeyboardType = .default) {
        self.title = title
        self.subtitle = subtitle
        self.placeholder = placeholder
        self._text = text
        self.keyboardType = keyboardType
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                if let subtitle = subtitle {
                    Text("(\(subtitle))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textFieldStyle(ModernTextFieldStyle())
        }
    }
}

enum ExerciseCategory: String, CaseIterable, Codable, Identifiable {
    // Strength / Compounds & Accessories
    case squat, frontSquat, deadlift, romanianDeadlift
    case benchPress, overheadPress, row, hipThrust
    case bulgarianSplitSquat, legPress
    case latPulldown, cableRow, chestFly
    case lateralRaise, curl, tricepsExtension
    case legExtension, legCurl, calfRaiseStanding

    // Bodyweight & Rings
    case pushUp, dip, pullUp, plank, hangingLegRaise, abWheel
    case handstand, pistolSquat

    // Explosive / Athleticism
    case kettlebellSwing, boxJump, medBallSlam, sprint
    case powerClean, sledPush, jumpRope

    // Endurance / Conditioning
    case run, cycle, rower, swimming, hikingStairs, battleRopes

    // Mobility / Prehab
    case hip90_90, couchStretch, cars, thoracicRotation, externalRotation
    case monsterWalks, nordicHamstring, copenhagenPlank, tibialisRaise
    case mcgillBig3, hipAirplanes, yoga

    var id: String { rawValue }

    var displayName: String {
        switch self {
        // Strength
        case .squat: return "Back Squat"
        case .frontSquat: return "Front Squat"
        case .deadlift: return "Deadlift"
        case .romanianDeadlift: return "Romanian Deadlift"
        case .benchPress: return "Bench Press"
        case .overheadPress: return "Overhead Press"
        case .row: return "Bent-Over Row"
        case .hipThrust: return "Hip Thrust / Glute Bridge"
        case .bulgarianSplitSquat: return "Bulgarian Split Squat"
        case .legPress: return "Leg Press"
        case .latPulldown: return "Lat Pulldown"
        case .cableRow: return "Seated Cable Row"
        case .chestFly: return "Chest Fly (Cable/DB)"
        case .lateralRaise: return "Lateral Raise"
        case .curl: return "Biceps Curl"
        case .tricepsExtension: return "Triceps Extension"
        case .legExtension: return "Leg Extension"
        case .legCurl: return "Leg Curl"
        case .calfRaiseStanding: return "Calf Raise (Standing)"

        // Bodyweight
        case .pushUp: return "Push-Ups"
        case .dip: return "Dips"
        case .pullUp: return "Pull-Ups / Chin-Ups"
        case .plank: return "Plank / Side Plank"
        case .hangingLegRaise: return "Hanging Leg Raise"
        case .abWheel: return "Ab Wheel Rollout"
        case .handstand: return "Handstand (wall→free)"
        case .pistolSquat: return "Pistol Squat"

        // Explosive
        case .kettlebellSwing: return "Kettlebell Swing"
        case .boxJump: return "Box/Broad Jump"
        case .medBallSlam: return "Med-Ball Slams/Throws"
        case .sprint: return "Sprints"
        case .powerClean: return "Power Clean"
        case .sledPush: return "Sled Push/Pull"
        case .jumpRope: return "Jump Rope"

        // Endurance
        case .run: return "Running (Zone2/Tempo)"
        case .cycle: return "Cycling/Spin"
        case .rower: return "Rowing Erg"
        case .swimming: return "Swimming"
        case .hikingStairs: return "Hiking/Stair Climber"
        case .battleRopes: return "Battle Ropes"

        // Mobility / Prehab
        case .hip90_90: return "90/90 Hip Switches"
        case .couchStretch: return "Couch Stretch / Pigeon"
        case .cars: return "CARS"
        case .thoracicRotation: return "Thoracic Rotations"
        case .externalRotation: return "External Rotation (band/cable)"
        case .monsterWalks: return "Monster Walks / Clamshells"
        case .nordicHamstring: return "Nordic Hamstring (eccentric)"
        case .copenhagenPlank: return "Copenhagen Plank"
        case .tibialisRaise: return "Tibialis Raises"
        case .mcgillBig3: return "McGill Big 3"
        case .hipAirplanes: return "Hip Airplanes"
        case .yoga: return "Yoga/Mobility"
        }
    }

    var focus: FocusGroup {
        switch self {
        case .squat, .frontSquat, .deadlift, .romanianDeadlift, .benchPress, .overheadPress, .row, .hipThrust, .bulgarianSplitSquat, .legPress:
            return .strength
        case .latPulldown, .cableRow, .chestFly, .lateralRaise, .curl, .tricepsExtension, .legExtension, .legCurl, .calfRaiseStanding:
            return .hypertrophy
        case .pushUp, .dip, .pullUp, .plank, .hangingLegRaise, .abWheel, .handstand, .pistolSquat:
            return .bodyweight
        case .kettlebellSwing, .boxJump, .medBallSlam, .sprint, .powerClean, .sledPush, .jumpRope:
            return .explosive
        case .run, .cycle, .rower, .swimming, .hikingStairs, .battleRopes:
            return .endurance
        case .hip90_90, .couchStretch, .cars, .thoracicRotation, .externalRotation, .monsterWalks, .nordicHamstring, .copenhagenPlank, .tibialisRaise, .mcgillBig3, .hipAirplanes, .yoga:
            return .mobility
        }
    }
}

struct WorkoutEntry: Codable, Identifiable {
    let id: UUID
    var date: Date
    var name: String
    var category: ExerciseCategory
    var reps: Int? // for resistance/bodyweight
    var weight: Double? // kg (or lbs if you prefer — treat consistently in app settings)
    var durationMinutes: Double? // for cardio/core/yoga
    var distanceKm: Double? // optional for cardio

    // Calculated at log time
    var statGains: StatBlock
    var expGained: Double
    var catchUpLevel: Int? = nil

    // Level and PR debug info
    var prevLevel: Int? = nil
    var newLevel: Int? = nil
    var prevBest1RM: Double? = nil
    var est1RM: Double? = nil

    // Total XP progress for popup (may include catch-up)
    var totalProgressXP: Double? = nil
}

struct StatRanks: Codable {
    var size: Int = 1
    var strength: Int = 1
    var dexterity: Int = 1
    var agility: Int = 1
    var endurance: Int = 1
    var vitality: Int = 1
}

enum TreasureChestType: String, CaseIterable, Codable {
    case common = "common"
    case uncommon = "uncommon"
    case rare = "rare"
    case epic = "epic"
    case mythic = "mythic"
    
    var displayName: String {
        switch self {
        case .common: return "Common"
        case .uncommon: return "Uncommon"
        case .rare: return "Rare"
        case .epic: return "Epic"
        case .mythic: return "Mythic"
        }
    }
    
    var color: String {
        switch self {
        case .common: return "brown"
        case .uncommon: return "green"
        case .rare: return "blue"
        case .epic: return "purple"
        case .mythic: return "red"
        }
    }
    
    var rarityColor: Color {
        switch self {
        case .common: return .brown
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .mythic: return .red
        }
    }
}

enum RewardType: String, Codable {
    case bonus_xp
    case coins
    case item
    
    var displayName: String {
        switch self {
        case .bonus_xp: return "Bonus Exp"
        case .coins: return "Coins"
        case .item: return "Item"
        }
    }
    
    // Check if a coin amount is a jackpot value
    func isJackpotAmount(_ amount: Double) -> Bool {
        let jackpotAmounts: Set<Int> = [135, 225, 315, 405, 495]
        return jackpotAmounts.contains(Int(amount))
    }
}

enum EpicTierItem: String, CaseIterable, Codable {
    case birthdaycake
    case gamecontroller
    
    var displayName: String {
        switch self {
        case .birthdaycake: return "Birthday Cake"
        case .gamecontroller: return "Game Controller"
        }
    }
    
    var iconName: String {
        switch self {
        case .birthdaycake: return "birthday.cake.fill"
        case .gamecontroller: return "gamecontroller.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .birthdaycake: return Color(red: 1.0, green: 0.8, blue: 0.9) // Pink
        case .gamecontroller: return .black
        }
    }
    
    var rarity: String {
        return "Epic"
    }
    
    var rarityColor: Color {
        return .purple
    }
}

enum LegendaryTierItem: String, CaseIterable, Codable {
    case trophy
    case wand
    
    var displayName: String {
        switch self {
        case .trophy: return "Trophy"
        case .wand: return "Magic Wand"
        }
    }
    
    var iconName: String {
        switch self {
        case .trophy: return "trophy.fill"
        case .wand: return "wand.and.stars"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .trophy: return Color(red: 1.0, green: 0.8, blue: 0.2) // Gold
        case .wand: return Color(red: 0.9, green: 0.7, blue: 1.0) // Light purple/magical
        }
    }
    
    var rarity: String {
        return "Legendary"
    }
    
    var rarityColor: Color {
        return Color(red: 1.0, green: 0.8, blue: 0.2) // Gold background
    }
}

enum MythicTierItem: String, CaseIterable, Codable {
    case teddybear
    
    var displayName: String {
        switch self {
        case .teddybear: return "Teddy Bear"
        }
    }
    
    var iconName: String {
        switch self {
        case .teddybear: return "teddybear.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .teddybear: return Color(red: 0.6, green: 0.4, blue: 0.2) // Brown
        }
    }
    
    var rarity: String {
        return "Mythic"
    }
    
    var rarityColor: Color {
        return .red
    }
}

// MARK: - Fitness Goals for Class Placement
enum FitnessGoal: String, CaseIterable, Codable, Identifiable {
    case strength = "Get Stronger"
    case hypertrophy = "Get Bigger"
    case endurance = "Increase Endurance"
    case explosive = "Get More Explosive"
    case mobility = "Improve Flexibility"
    case bodyweight = "Master Bodyweight"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .strength: return "Get Stronger"
        case .hypertrophy: return "Get Bigger"
        case .endurance: return "Increase Endurance"
        case .explosive: return "Get More Explosive"
        case .mobility: return "Improve Recovery"
        case .bodyweight: return "Master Bodyweight"
        }
    }
    
    var description: String {
        switch self {
        case .strength: return "Heavy lifts, raw power"
        case .hypertrophy: return "Muscle size and volume"
        case .endurance: return "Cardio and stamina"
        case .explosive: return "Speed and athleticism"
        case .mobility: return "Mobility and recovery"
        case .bodyweight: return "Calisthenics mastery"
        }
    }
    
    var icon: String {
        switch self {
        case .strength: return "figure.strengthtraining.traditional"
        case .hypertrophy: return "arrow.up.left.and.arrow.down.right"
        case .endurance: return "lungs.fill"
        case .explosive: return "bolt.fill"
        case .mobility: return "cross.fill"
        case .bodyweight: return "figure.highintensity.intervaltraining"
        }
    }
    
    var color: Color {
        switch self {
        case .strength: return .red
        case .hypertrophy: return .purple
        case .endurance: return .blue
        case .explosive: return .yellow
        case .mobility: return .green
        case .bodyweight: return .orange
        }
    }
}

// MARK: - RPG Class System
enum RPGClass: String, CaseIterable, Codable {
    case warrior = "Warrior"
    case quality = "Quality"
    case berserker = "Berserker"
    case paladin = "Paladin"
    case assassin = "Assassin"
    case monk = "Monk"
    case ranger = "Ranger"
    case scout = "Scout"
    case tank = "Tank"
    case brawler = "Brawler"
    case titan = "Titan"
    case juggernaut = "Juggernaut"
    case spartan = "Spartan"
    case druid = "Druid"
    case healer = "Healer"
    
    var displayName: String { rawValue }
    
    var description: String {
        switch self {
        case .warrior: return "Masters of raw power and size. Focus on building strength and muscle mass."
        case .quality: return "Balanced strength fighters. Combine power with precise bodyweight control."
        case .berserker: return "Explosive strength athletes. Channel raw power into explosive movements."
        case .paladin: return "Strong and flexible warriors. Merge strength training with mobility work."
        case .assassin: return "Swift and precise. Excel at bodyweight movements and explosive training."
        case .monk: return "Balanced warriors. Focus on bodyweight mastery and mobility."
        case .ranger: return "Endurance athletes with agility. Mix cardio with functional movement."
        case .scout: return "Speed and endurance specialists. Excel in explosive cardio training."
        case .tank: return "Built like fortresses. Combine massive size with flexibility and resilience."
        case .brawler: return "Size and control masters. Build mass while maintaining bodyweight skills."
        case .titan: return "Explosive giants. Combine massive size with explosive power."
        case .juggernaut: return "Endurance powerhouses. Build size while maintaining stamina."
        case .spartan: return "Ultimate warriors. Pure strength combined with endless endurance."
        case .druid: return "Nature's athletes. Master explosive movements and mobility flow."
        case .healer: return "Resilient endurance masters. Focus on stamina and mobility recovery."
        }
    }
    
    var icon: String {
        switch self {
        case .warrior: return "flame.fill"
        case .quality: return "star.fill"
        case .berserker: return "bolt.fill"
        case .paladin: return "shield.lefthalf.filled"
        case .assassin: return "wind"
        case .monk: return "figure.mind.and.body"
        case .ranger: return "location.north.line.fill"
        case .scout: return "eyes"
        case .tank: return "shield.fill"
        case .brawler: return "hands.clap.fill"
        case .titan: return "mountain.2.fill"
        case .juggernaut: return "infinity"
        case .spartan: return "pentagon.fill"
        case .druid: return "tree.fill"
        case .healer: return "heart.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .warrior: return Color(red: 1.0, green: 0.2, blue: 0.2) // Bright red
        case .quality: return Color(red: 1.0, green: 0.5, blue: 0.0) // Vibrant orange
        case .berserker: return Color(red: 1.0, green: 0.3, blue: 0.0) // Red-orange
        case .paladin: return Color(red: 1.0, green: 0.84, blue: 0.0) // Gold
        case .assassin: return Color(red: 0.58, green: 0.0, blue: 0.83) // Deep purple
        case .monk: return Color(red: 0.0, green: 0.5, blue: 1.0) // Vibrant blue
        case .ranger: return Color(red: 0.2, green: 0.8, blue: 0.2) // Vibrant green
        case .scout: return Color(red: 0.0, green: 0.9, blue: 0.5) // Bright mint
        case .tank: return Color(red: 1.0, green: 0.6, blue: 0.0) // Vibrant orange
        case .brawler: return Color(red: 0.85, green: 0.35, blue: 0.0) // Burnt orange
        case .titan: return Color(red: 0.5, green: 0.0, blue: 1.0) // Royal purple
        case .juggernaut: return Color(red: 0.4, green: 0.4, blue: 0.5) // Steel blue
        case .spartan: return Color(red: 0.9, green: 0.1, blue: 0.1) // Crimson
        case .druid: return Color(red: 0.0, green: 0.7, blue: 0.3) // Vibrant forest
        case .healer: return Color(red: 0.0, green: 0.7, blue: 0.9) // Sky blue
        }
    }
    
    var focusCategories: [FocusGroup] {
        switch self {
        case .warrior: // Strength + Hypertrophy
            return [.strength, .hypertrophy]
        case .quality: // Strength + Bodyweight
            return [.strength, .bodyweight]
        case .berserker: // Strength + Explosive
            return [.strength, .explosive]
        case .paladin: // Strength + Mobility
            return [.strength, .mobility]
        case .assassin: // Bodyweight + Explosive
            return [.bodyweight, .explosive]
        case .monk: // Bodyweight + Mobility
            return [.bodyweight, .mobility]
        case .ranger: // Endurance + Bodyweight
            return [.endurance, .bodyweight]
        case .scout: // Explosive + Endurance
            return [.explosive, .endurance]
        case .tank: // Hypertrophy + Mobility
            return [.hypertrophy, .mobility]
        case .brawler: // Hypertrophy + Bodyweight
            return [.hypertrophy, .bodyweight]
        case .titan: // Hypertrophy + Explosive
            return [.hypertrophy, .explosive]
        case .juggernaut: // Hypertrophy + Endurance
            return [.hypertrophy, .endurance]
        case .spartan: // Strength + Endurance
            return [.strength, .endurance]
        case .druid: // Explosive + Mobility
            return [.explosive, .mobility]
        case .healer: // Endurance + Mobility
            return [.endurance, .mobility]
        }
    }
    
    var preferredExercises: [ExerciseCategory] {
        switch self {
        case .warrior: // Size + Strength
            return [.deadlift, .squat, .benchPress, .overheadPress, .row, .legPress]
        case .quality: // Strength + Bodyweight
            return [.deadlift, .pullUp, .benchPress, .dip, .squat, .pushUp]
        case .berserker: // Strength + Explosiveness
            return [.deadlift, .boxJump, .squat, .sprint, .overheadPress, .jumpRope]
        case .paladin: // Strength + Mobility
            return [.deadlift, .yoga, .squat, .couchStretch, .overheadPress, .hip90_90]
        case .assassin: // Bodyweight + Explosiveness
            return [.pullUp, .boxJump, .dip, .sprint, .pushUp, .jumpRope]
        case .monk: // Bodyweight + Mobility
            return [.pullUp, .yoga, .dip, .couchStretch, .pushUp, .thoracicRotation]
        case .ranger: // Endurance + Bodyweight
            return [.run, .pullUp, .cycle, .dip, .rower, .pushUp]
        case .scout: // Explosiveness + Endurance
            return [.boxJump, .run, .sprint, .cycle, .jumpRope, .battleRopes]
        case .tank: // Size + Mobility
            return [.squat, .yoga, .legPress, .hip90_90, .benchPress, .couchStretch]
        case .brawler: // Size + Bodyweight
            return [.squat, .pullUp, .legPress, .dip, .benchPress, .pushUp]
        case .titan: // Size + Explosiveness
            return [.squat, .boxJump, .legPress, .sprint, .benchPress, .jumpRope]
        case .juggernaut: // Size + Endurance
            return [.squat, .run, .legPress, .cycle, .benchPress, .rower]
        case .spartan: // Strength + Endurance
            return [.deadlift, .run, .squat, .cycle, .overheadPress, .battleRopes]
        case .druid: // Explosiveness + Mobility
            return [.boxJump, .yoga, .sprint, .hip90_90, .jumpRope, .thoracicRotation]
        case .healer: // Endurance + Mobility
            return [.run, .yoga, .cycle, .couchStretch, .rower, .mcgillBig3]
        }
    }
    
    var primarySkills: [String] {
        switch self {
        case .warrior: // Strength + Hypertrophy
            return ["Strength", "Size"]
        case .quality: // Strength + Bodyweight
            return ["Strength", "Dexterity"]
        case .berserker: // Strength + Explosive
            return ["Strength", "Agility"]
        case .paladin: // Strength + Mobility
            return ["Strength", "Vitality"]
        case .assassin: // Bodyweight + Explosive
            return ["Dexterity", "Agility"]
        case .monk: // Bodyweight + Mobility
            return ["Dexterity", "Vitality"]
        case .ranger: // Endurance + Bodyweight
            return ["Endurance", "Dexterity"]
        case .scout: // Explosive + Endurance
            return ["Agility", "Endurance"]
        case .tank: // Hypertrophy + Mobility
            return ["Size", "Vitality"]
        case .brawler: // Hypertrophy + Bodyweight
            return ["Size", "Dexterity"]
        case .titan: // Hypertrophy + Explosive
            return ["Size", "Agility"]
        case .juggernaut: // Hypertrophy + Endurance
            return ["Size", "Endurance"]
        case .spartan: // Strength + Endurance
            return ["Strength", "Endurance"]
        case .druid: // Explosive + Mobility
            return ["Agility", "Vitality"]
        case .healer: // Endurance + Mobility
            return ["Endurance", "Vitality"]
        }
    }
    
    // Class placement based on selected goals
    static func classPlacement(from goals: Set<FitnessGoal>) -> RPGClass? {
        guard goals.count == 2 else { return nil }
        
        let goalSet = goals
        
        // All 15 possible combinations
        if goalSet.contains(.strength) && goalSet.contains(.hypertrophy) {
            return .warrior
        } else if goalSet.contains(.strength) && goalSet.contains(.bodyweight) {
            return .quality
        } else if goalSet.contains(.strength) && goalSet.contains(.explosive) {
            return .berserker
        } else if goalSet.contains(.strength) && goalSet.contains(.mobility) {
            return .paladin
        } else if goalSet.contains(.bodyweight) && goalSet.contains(.explosive) {
            return .assassin
        } else if goalSet.contains(.bodyweight) && goalSet.contains(.mobility) {
            return .monk
        } else if goalSet.contains(.endurance) && goalSet.contains(.bodyweight) {
            return .ranger
        } else if goalSet.contains(.explosive) && goalSet.contains(.endurance) {
            return .scout
        } else if goalSet.contains(.hypertrophy) && goalSet.contains(.mobility) {
            return .tank
        } else if goalSet.contains(.hypertrophy) && goalSet.contains(.bodyweight) {
            return .brawler
        } else if goalSet.contains(.hypertrophy) && goalSet.contains(.explosive) {
            return .titan
        } else if goalSet.contains(.hypertrophy) && goalSet.contains(.endurance) {
            return .juggernaut
        } else if goalSet.contains(.strength) && goalSet.contains(.endurance) {
            return .spartan
        } else if goalSet.contains(.explosive) && goalSet.contains(.mobility) {
            return .druid
        } else if goalSet.contains(.endurance) && goalSet.contains(.mobility) {
            return .healer
        }
        
        return nil // Invalid combination (shouldn't happen with the 6 goals and 15 combinations)
    }
}

// MARK: - Challenge/Quest System
struct Challenge: Codable, Identifiable {
    let id: UUID
    let type: ChallengeType
    let title: String
    let description: String
    let targetCategory: FocusGroup
    let targetAmount: Int // Could be reps, sets, minutes, or distance
    let unit: ChallengeUnit
    let expReward: Int
    let classType: RPGClass
    let createdAt: Date
    let expiresAt: Date
    var completedAt: Date?
    var progress: Int = 0
    var uniqueExercises: Set<String> = Set() // Track unique exercises for variety challenges
    
    var isCompleted: Bool { completedAt != nil }
    var isExpired: Bool { Date() > expiresAt }
    var isActive: Bool { !isCompleted && !isExpired }
    
    var progressPercentage: Double {
        guard targetAmount > 0 else { return 0 }
        // For exercise variety challenges, use uniqueExercises count
        if unit == .exercises {
            return min(Double(uniqueExercises.count) / Double(targetAmount), 1.0)
        }
        return min(Double(progress) / Double(targetAmount), 1.0)
    }
}

enum ChallengeType: String, Codable {
    case daily = "Daily Quest"
    case weekly = "Weekly Quest"
}

enum ChallengeUnit: String, Codable {
    case reps = "reps"
    case sets = "sets"
    case minutes = "minutes"
    case kilometers = "km"
    case times = "times"
    case exercises = "exercises"
    
    var displayName: String {
        switch self {
        case .reps: return "reps"
        case .sets: return "sets"
        case .minutes: return "minutes"
        case .kilometers: return "km"
        case .times: return "times"
        case .exercises: return "exercises"
        }
    }
}

enum ItemInfo: Codable {
    case uncommon(UncommonTierItem)
    case rare(RareTierItem)
    case epic(EpicTierItem)
    case legendary(LegendaryTierItem)
    case mythic(MythicTierItem)
    
    var displayName: String {
        switch self {
        case .uncommon(let item): return item.displayName
        case .rare(let item): return item.displayName
        case .epic(let item): return item.displayName
        case .legendary(let item): return item.displayName
        case .mythic(let item): return item.displayName
        }
    }
    
    var iconName: String {
        switch self {
        case .uncommon(let item): return item.iconName
        case .rare(let item): return item.iconName
        case .epic(let item): return item.iconName
        case .legendary(let item): return item.iconName
        case .mythic(let item): return item.iconName
        }
    }
    
    var iconColor: Color {
        switch self {
        case .uncommon(let item): return item.iconColor
        case .rare(let item): return item.iconColor
        case .epic(let item): return item.iconColor
        case .legendary(let item): return item.iconColor
        case .mythic(let item): return item.iconColor
        }
    }
    
    var rarity: String {
        switch self {
        case .uncommon(let item): return item.rarity
        case .rare(let item): return item.rarity
        case .epic(let item): return item.rarity
        case .legendary(let item): return item.rarity
        case .mythic(let item): return item.rarity
        }
    }
    
    var rarityColor: Color {
        switch self {
        case .uncommon(let item): return item.rarityColor
        case .rare(let item): return item.rarityColor
        case .epic(let item): return item.rarityColor
        case .legendary(let item): return item.rarityColor
        case .mythic(let item): return item.rarityColor
        }
    }
}

struct TreasureReward: Codable, Identifiable {
    let id = UUID()
    let type: RewardType
    let amount: Double
    let description: String
    let itemInfo: ItemInfo?
    
    private enum CodingKeys: String, CodingKey {
        case type, amount, description, itemInfo
    }
}

struct TreasureChest: Codable, Identifiable {
    let id = UUID()
    let type: TreasureChestType
    let earnedAtLevel: Int
    let dateEarned: Date
    var isOpened: Bool = false
    var rewards: [TreasureReward] = []
    
    private enum CodingKeys: String, CodingKey {
        case type, earnedAtLevel, dateEarned, isOpened, rewards
    }
    
    // Icon based on chest rarity (like playing card suits)
    var rarityIcon: String {
        switch type {
        case .common: return "suit.heart.fill"
        case .uncommon: return "suit.club.fill"
        case .rare: return "suit.diamond.fill"
        case .epic: return "suit.spade.fill"
        case .mythic: return "crown.fill"
        }
    }
}

enum InventoryItemType: String, CaseIterable, Codable {
    case consumable = "consumable"
    case equipment = "equipment"
    case material = "material"
    case collectible = "collectible"
    
    var displayName: String {
        switch self {
        case .consumable: return "Consumable"
        case .equipment: return "Equipment"
        case .material: return "Material"
        case .collectible: return "Collectible"
        }
    }
    
    var icon: String {
        switch self {
        case .consumable: return "pills.fill"
        case .equipment: return "wrench.and.screwdriver.fill"
        case .material: return "cube.fill"
        case .collectible: return "star.fill"
        }
    }
}

enum InventoryItemRarity: String, CaseIterable, Codable {
    case common = "common"
    case uncommon = "uncommon"
    case rare = "rare"
    case epic = "epic"
    case legendary = "legendary"
    case mythic = "mythic"
    
    var color: String {
        switch self {
        case .common: return "gray"
        case .uncommon: return "green"
        case .rare: return "blue"
        case .epic: return "purple"
        case .legendary: return "gold"
        case .mythic: return "red"
        }
    }
}

struct InventoryItem: Codable, Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let type: InventoryItemType
    let rarity: InventoryItemRarity
    let iconName: String // Specific SF Symbol icon name
    var quantity: Int
    let dateObtained: Date
    let value: Int // For future trading/selling
    
    private enum CodingKeys: String, CodingKey {
        case name, description, type, rarity, iconName, quantity, dateObtained, value
    }
}

enum UncommonTierItem: String, CaseIterable, Codable {
    case soccerball
    case basketball
    case volleyball
    
    var displayName: String {
        switch self {
        case .soccerball: return "Soccer Ball"
        case .basketball: return "Basketball"
        case .volleyball: return "Volleyball"
        }
    }
    
    var iconName: String {
        switch self {
        case .soccerball: return "soccerball"
        case .basketball: return "basketball.fill"
        case .volleyball: return "volleyball.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .soccerball: return .white
        case .basketball: return Color(red: 0.8, green: 0.4, blue: 0.1) // Basketball orange-brown
        case .volleyball: return .white
        }
    }
    
    var rarity: String {
        return "Uncommon"  // All current items are uncommon tier
    }
    
    var rarityColor: Color {
        return .green // Green for uncommon items
    }
}

enum RareTierItem: String, CaseIterable, Codable {
    case dice
    case puzzlepiece
    case balloon
    
    var displayName: String {
        switch self {
        case .dice: return "Dice"
        case .puzzlepiece: return "Puzzle Piece"
        case .balloon: return "Balloon"
        }
    }
    
    var iconName: String {
        switch self {
        case .dice: return "dice.fill"
        case .puzzlepiece: return "puzzlepiece.fill"
        case .balloon: return "balloon.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .dice: return .white
        case .puzzlepiece: return Color(red: 1.0, green: 1.0, blue: 0.8) // Pale yellow
        case .balloon: return .red
        }
    }
    
    var rarity: String {
        return "Rare"
    }
    
    var rarityColor: Color {
        return .blue
    }
}

// MARK: - Challenge Preferences
enum ChallengePreference: String, Codable, CaseIterable {
    // Endurance options
    case time = "time"
    case distance = "distance"
    
    // Recovery/Mobility options
    case frequency = "frequency"
    
    // General options
    case sets = "sets"
    case reps = "reps"
    case times = "times"
    
    var displayName: String {
        switch self {
        case .time: return "Time"
        case .distance: return "Distance"
        case .frequency: return "Sessions"
        case .sets: return "Sets"
        case .reps: return "Reps"
        case .times: return "Rounds"
        }
    }
    
    var unit: ChallengeUnit {
        switch self {
        case .time: return .minutes
        case .distance: return .kilometers
        case .frequency: return .times
        case .sets: return .sets
        case .reps: return .reps
        case .times: return .times
        }
    }
}

struct UserProfile: Codable {
    /// Best per-exercise "performance" metric for placementMetric (non-1RM categories)
    var bestPerf: [ExerciseCategory: Double] = [:]
    var level: Int = 1
    var xp: Double = 0
    var nextLevelXP: Double = StatEngine.xpNeeded(forNextLevel: 1) // XP required to reach next level
    var stats: StatBlock = .zero
    var coins: Int = 0
    // Settings
    var units: Units = .kg
    var bodyweightKg: Double? = nil
    // Personal best 1RM estimates per lift category
    var best1RM: [ExerciseCategory: Double] = [:]
    // Per‑exercise performance baselines used for relative XP calculation
    var xpBaselines: [ExerciseCategory: Double] = [:]
    var ranks: StatRanks = StatRanks()
    // Streaks (light instrumentation for MVP)
    var mobilityStreakCount: Int = 0
    var lastMobilityDay: Date? = nil
    // Track which exercises have received their first-time stat grant
    var firstStatGrantApplied: Set<ExerciseCategory> = []
    // Treasure chests
    var treasureChests: [TreasureChest] = []
    // Inventory
    var inventory: [InventoryItem] = []
    // RPG Class and Challenges
    var rpgClass: RPGClass? = nil
    var dailyChallenges: [Challenge] = []
    var weeklyChallenges: [Challenge] = []
    var lastDailyChallengeGeneration: Date? = nil
    var lastWeeklyChallengeGeneration: Date? = nil
    // Challenge measurement preferences
    var challengePreferences: [FocusGroup: ChallengePreference] = [:]
}

struct PersistedData: Codable {
    var user: UserProfile
    var history: [WorkoutEntry]
}

// MARK: - Stat/EXP Engine
enum StatEngine {
    // Specify how many primary stats to display per exercise in History
    static func primaryDisplayCount(for category: ExerciseCategory) -> Int {
        switch category {
        // Mostly two-attribute moves
        case .benchPress, .overheadPress, .row, .latPulldown, .cableRow, .chestFly,
             .lateralRaise, .curl, .tricepsExtension, .legExtension, .legCurl, .calfRaiseStanding,
             .plank, .hangingLegRaise, .abWheel, .handstand, .pistolSquat:
            return 2
        default:
            return 3
        }
    }
    // MARK: - Stat/EXP Engine
    static let maxLevel = 100

    // Linear interpolate an x value across anchor points (x ascending). Returns clamped 0...maxLevel.
    private static func interpLevel(x: Double, anchors: [(Double, Int)]) -> Int {
        guard let first = anchors.first, let last = anchors.last else { return 0 }
        if x <= first.0 { return max(0, min(maxLevel, first.1)) }
        if x >= last.0  { return max(0, min(maxLevel, last.1)) }
        for i in 0..<(anchors.count-1) {
            let (x0, y0) = anchors[i]
            let (x1, y1) = anchors[i+1]
            if x >= x0 && x <= x1 {
                let t = (x - x0) / max(1e-9, (x1 - x0))
                let y = Double(y0) + t * Double(y1 - y0)
                return max(0, min(maxLevel, Int(round(y))))
            }
        }
        return 0
    }

    // Bench placement: est1RM/bodyweight anchors (male-ish generic)
    private static func levelFromBenchRatio(_ ratio: Double) -> Int {
        let pts: [(Double, Int)] = [
            (0.60, 10), (0.80, 25), (1.00, 40), (1.25, 55), (1.50, 70), (2.00, 90), (2.50, 98)
        ]
        return interpLevel(x: ratio, anchors: pts)
    }

    // Squat placement: est1RM/bodyweight anchors
    private static func levelFromSquatRatio(_ ratio: Double) -> Int {
        let pts: [(Double, Int)] = [
            (0.80, 15), (1.00, 25), (1.50, 45), (2.00, 65), (2.50, 85), (3.00, 97)
        ]
        return interpLevel(x: ratio, anchors: pts)
    }

    // Deadlift placement: est1RM/bodyweight anchors
    private static func levelFromDeadliftRatio(_ ratio: Double) -> Int {
        let pts: [(Double, Int)] = [
            (1.00, 20), (1.25, 35), (1.75, 55), (2.25, 75), (2.75, 90), (3.00, 96)
        ]
        return interpLevel(x: ratio, anchors: pts)
    }

    // Overhead Press placement: est1RM/bodyweight anchors
    private static func levelFromOHPRatio(_ ratio: Double) -> Int {
        let pts: [(Double, Int)] = [
            (0.40, 10), (0.60, 25), (0.80, 45), (1.00, 65), (1.20, 85), (1.40, 96)
        ]
        return interpLevel(x: ratio, anchors: pts)
    }

    // Front Squat placement: est1RM/bodyweight anchors (slightly lower than back squat)
    private static func levelFromFrontSquatRatio(_ ratio: Double) -> Int {
        let pts: [(Double, Int)] = [
            (0.70, 15), (0.90, 25), (1.20, 45), (1.60, 65), (2.00, 85), (2.30, 96)
        ]
        return interpLevel(x: ratio, anchors: pts)
    }

    // Romanian Deadlift placement: est1RM/bodyweight anchors (hinge, below DL)
    private static func levelFromRDLRatio(_ ratio: Double) -> Int {
        let pts: [(Double, Int)] = [
            (0.80, 20), (1.00, 35), (1.40, 50), (1.80, 70), (2.20, 85), (2.60, 95)
        ]
        return interpLevel(x: ratio, anchors: pts)
    }

    // Power Clean placement: est1RM/bodyweight anchors (technique & power)
    private static func levelFromPowerCleanRatio(_ ratio: Double) -> Int {
        let pts: [(Double, Int)] = [
            (0.60, 30), (0.80, 45), (1.00, 60), (1.20, 80), (1.40, 92), (1.60, 98)
        ]
        return interpLevel(x: ratio, anchors: pts)
    }

    // Cycling placement: speed-first (km/h), small distance boost
    private static func levelFromCycling(speedKPH: Double, distanceKm: Double) -> Int {
        let pts: [(Double, Int)] = [
            (20, 20), (25, 35), (30, 50), (35, 70), (40, 85), (45, 95)
        ]
        var lvl = interpLevel(x: speedKPH, anchors: pts)
        // Gentle distance boost so long hard rides nudge higher but pace dominates
        if distanceKm > 0 {
            let boost = min(10, Int(round(pow(min(distanceKm, 200), 0.25))) - 1) // 0..~
            lvl = min(maxLevel, max(0, lvl + boost))
        }
        return lvl
    }

    // Running placement: speed-first (km/h), small distance boost
    private static func levelFromRunning(speedKPH: Double, distanceKm: Double) -> Int {
        let pts: [(Double, Int)] = [
            (8, 25), (10, 40), (12, 50), (15, 70), (18, 85), (20, 95)
        ]
        var lvl = interpLevel(x: speedKPH, anchors: pts)
        if distanceKm > 0 {
            let boost = min(8, Int(round(pow(min(distanceKm, 100), 0.25))) - 1)
            lvl = min(maxLevel, max(0, lvl + max(0, boost)))
        }
        return lvl
    }

    // Rowing placement: speed-first (km/h), small distance boost
    private static func levelFromRowing(speedKPH: Double, distanceKm: Double) -> Int {
        let pts: [(Double, Int)] = [
            (9.0, 35), (10.5, 50), (12.0, 70), (13.5, 85), (15.0, 95)
        ]
        var lvl = interpLevel(x: speedKPH, anchors: pts)
        if distanceKm > 0 {
            let boost = min(8, Int(round(pow(min(distanceKm, 20), 0.25))) - 1)
            lvl = min(maxLevel, max(0, lvl + max(0, boost)))
        }
        return lvl
    }

    // Swimming placement: speed-first (km/h), small distance boost
    private static func levelFromSwimming(speedKPH: Double, distanceKm: Double) -> Int {
        let pts: [(Double, Int)] = [
            (2.5, 35), (3.5, 55), (4.5, 75), (5.5, 90)
        ]
        var lvl = interpLevel(x: speedKPH, anchors: pts)
        if distanceKm > 0 {
            let boost = min(8, Int(round(pow(min(distanceKm, 10), 0.25))) - 1)
            lvl = min(maxLevel, max(0, lvl + max(0, boost)))
        }
        return lvl
    }

    // Global contract: total stats = k * cumulative XP
    static let kStatsPerXP: Double = 0.007
    static func statPerXP(forLevel level: Int) -> Double { kStatsPerXP }
    static func targetTotalStats(level: Int, xpWithin: Double) -> Double {
        return kStatsPerXP * cumulativeXP(level: level, xpWithin: xpWithin)
    }

    static func statBudget(forXPDelta xp: Double, level: Int) -> Double {
        return max(0, xp) * statPerXP(forLevel: level)
    }


    static func placementLevel(for category: ExerciseCategory, metric: Double) -> Int {
        guard metric > 0 else { return 0 }
        let alpha: Double = 1.1
        let S: Double
        switch category {
        // barbell/bodyweight use strength curve
        case .squat, .frontSquat, .deadlift, .romanianDeadlift, .benchPress, .overheadPress, .row, .hipThrust, .powerClean,
             .pushUp, .dip, .pullUp, .handstand, .pistolSquat, .plank, .copenhagenPlank, .mcgillBig3:
            return levelFromBest1RM(metric)
        // endurance categories have separate scales (tuned for placement extremes)
        case .run:
            S = 500 // speed*distance; ~80–90 for elite marathon
        case .cycle:
            S = 80000 // TDF‑scale ends ~90+
        case .rower:
            S = 15000
        case .swimming:
            S = 7000
        case .hikingStairs, .battleRopes, .jumpRope, .sledPush:
            S = 8000
        default:
            S = 10000
        }
        let x = pow(metric / S, alpha)
        let frac = 1.0 - Foundation.exp(-max(0, x))
        let lvl = Int(round(Double(maxLevel) * frac))
        return max(0, min(maxLevel, lvl))
    }

    static func placementLevelCandidate(category: ExerciseCategory,
                                        reps: Int?, weight: Double?,
                                        durationMin: Double?, distanceKm: Double?,
                                        bodyweightKg: Double?) -> Int {
        switch category {
        case .squat:
            let est = estimate1RM(category: category, reps: reps, weight: weight)
            guard let bw = bodyweightKg, bw > 0, est > 0 else {
                return placementLevel(for: category, metric: est)
            }
            return levelFromSquatRatio(est / bw)
        case .frontSquat:
            let est = estimate1RM(category: category, reps: reps, weight: weight)
            guard let bw = bodyweightKg, bw > 0, est > 0 else {
                return placementLevel(for: category, metric: est)
            }
            return levelFromFrontSquatRatio(est / bw)
        case .deadlift:
            let est = estimate1RM(category: category, reps: reps, weight: weight)
            guard let bw = bodyweightKg, bw > 0, est > 0 else {
                return placementLevel(for: category, metric: est)
            }
            return levelFromDeadliftRatio(est / bw)
        case .romanianDeadlift:
            let est = estimate1RM(category: category, reps: reps, weight: weight)
            guard let bw = bodyweightKg, bw > 0, est > 0 else {
                return placementLevel(for: category, metric: est)
            }
            return levelFromRDLRatio(est / bw)
        case .overheadPress:
            let est = estimate1RM(category: category, reps: reps, weight: weight)
            guard let bw = bodyweightKg, bw > 0, est > 0 else {
                return placementLevel(for: category, metric: est)
            }
            return levelFromOHPRatio(est / bw)
        case .powerClean:
            let est = estimate1RM(category: category, reps: reps, weight: weight)
            guard let bw = bodyweightKg, bw > 0, est > 0 else {
                return placementLevel(for: category, metric: est)
            }
            return levelFromPowerCleanRatio(est / bw)
        case .benchPress:
            let est = estimate1RM(category: category, reps: reps, weight: weight)
            guard let bw = bodyweightKg, bw > 0, est > 0 else {
                return placementLevel(for: category, metric: est)
            }
            let ratio = est / bw
            return levelFromBenchRatio(ratio)
        case .cycle:
            let d = max(0, distanceKm ?? 0)
            let tHr = max(0.0, (durationMin ?? 0) / 60.0)
            guard d > 0, tHr > 0 else { return 0 }
            let speed = d / tHr
            return levelFromCycling(speedKPH: speed, distanceKm: d)
        case .run:
            let d = max(0, distanceKm ?? 0)
            let tHr = max(0.0, (durationMin ?? 0) / 60.0)
            guard d > 0, tHr > 0 else { return 0 }
            let speed = d / tHr
            return levelFromRunning(speedKPH: speed, distanceKm: d)
        case .rower:
            let d = max(0, distanceKm ?? 0)
            let tHr = max(0.0, (durationMin ?? 0) / 60.0)
            guard d > 0, tHr > 0 else { return 0 }
            let speed = d / tHr
            return levelFromRowing(speedKPH: speed, distanceKm: d)
        case .swimming:
            let d = max(0, distanceKm ?? 0)
            let tHr = max(0.0, (durationMin ?? 0) / 60.0)
            guard d > 0, tHr > 0 else { return 0 }
            let speed = d / tHr
            return levelFromSwimming(speedKPH: speed, distanceKm: d)
        default:
            let m = placementMetric(category: category, reps: reps, weight: weight, durationMin: durationMin, distanceKm: distanceKm, bodyweightKg: bodyweightKg)
            return placementLevel(for: category, metric: m)
        }
    }

    static func minimumSessionBudget(for category: ExerciseCategory, score: Double) -> Double {
        // Ensure non-barbell sessions (runs, cycling, pull-ups) register meaningful gains
        let n = log10(max(10, score + 10)) // 1..~
        var base = 0.18 * n                 // baseline visibility
        switch category.focus {
        case .endurance:  base *= 1.25
        case .bodyweight: base *= 1.15
        case .explosive:  base *= 1.10
        default: break
        }
        return base
    }

    static func distribute(budget: Double, weights: StatBlock, prBoost: Double) -> StatBlock {
        // Emphasize primaries more when PRs are larger
        let p = min(3.0, 1.0 + 0.5 * prBoost) // 1…3 exponent
        func emph(_ v: Double) -> Double { pow(max(0.0001, v), p) }
        let wSiz = emph(weights.size), wStr = emph(weights.strength), wDex = emph(weights.dexterity)
        let wAgi = emph(weights.agility), wEnd = emph(weights.endurance), wVit = emph(weights.vitality)
        let sum = wSiz + wStr + wDex + wAgi + wEnd + wVit
        guard sum > 0 else { return .zero }
        let k = budget / sum
        return StatBlock(
            size: wSiz * k,
            strength: wStr * k,
            dexterity: wDex * k,
            agility: wAgi * k,
            endurance: wEnd * k,
            vitality: wVit * k
        )
    }
    // Base multipliers for each category → which attributes it mainly hits
    // These are relative weights; final gains scale with volume/intensity.
    static func statWeights(for category: ExerciseCategory) -> StatBlock {
        switch category {
        // Strength (compounds & key accessories)
        case .squat:                 return StatBlock(size: 0.40, strength: 0.50, dexterity: 0.00, agility: 0.10, endurance: 0.00, vitality: 0.00)
        case .frontSquat:            return StatBlock(size: 0.40, strength: 0.45, dexterity: 0.15, agility: 0.00, endurance: 0.00, vitality: 0.00)
        case .deadlift:              return StatBlock(size: 0.30, strength: 0.60, dexterity: 0.00, agility: 0.00, endurance: 0.00, vitality: 0.10)
        case .romanianDeadlift:      return StatBlock(size: 0.40, strength: 0.45, dexterity: 0.00, agility: 0.00, endurance: 0.00, vitality: 0.15)
        case .benchPress:            return StatBlock(size: 0.40, strength: 0.55, dexterity: 0.00, agility: 0.00, endurance: 0.00, vitality: 0.05)
        case .overheadPress:         return StatBlock(size: 0.35, strength: 0.55, dexterity: 0.10, agility: 0.00, endurance: 0.00, vitality: 0.00)
        case .row:                   return StatBlock(size: 0.35, strength: 0.45, dexterity: 0.20, agility: 0.00, endurance: 0.00, vitality: 0.00)
        case .hipThrust:             return StatBlock(size: 0.40, strength: 0.45, dexterity: 0.00, agility: 0.15, endurance: 0.00, vitality: 0.00)
        case .bulgarianSplitSquat:   return StatBlock(size: 0.35, strength: 0.40, dexterity: 0.25, agility: 0.00, endurance: 0.00, vitality: 0.00)
        case .legPress:              return StatBlock(size: 0.45, strength: 0.45, dexterity: 0.00, agility: 0.00, endurance: 0.00, vitality: 0.10)

        // Hypertrophy (isolation/accessories)
        case .latPulldown:           return StatBlock(size: 0.45, strength: 0.45, dexterity: 0.10, agility: 0.00, endurance: 0.00, vitality: 0.00)
        case .cableRow:              return StatBlock(size: 0.45, strength: 0.45, dexterity: 0.10, agility: 0.00, endurance: 0.00, vitality: 0.00)
        case .chestFly:              return StatBlock(size: 0.60, strength: 0.30, dexterity: 0.00, agility: 0.00, endurance: 0.00, vitality: 0.10)
        case .lateralRaise:          return StatBlock(size: 0.65, strength: 0.00, dexterity: 0.25, agility: 0.00, endurance: 0.00, vitality: 0.10)
        case .curl:                  return StatBlock(size: 0.70, strength: 0.25, dexterity: 0.00, agility: 0.00, endurance: 0.00, vitality: 0.05)
        case .tricepsExtension:      return StatBlock(size: 0.65, strength: 0.30, dexterity: 0.00, agility: 0.00, endurance: 0.00, vitality: 0.05)
        case .legExtension:          return StatBlock(size: 0.60, strength: 0.25, dexterity: 0.00, agility: 0.00, endurance: 0.00, vitality: 0.15)
        case .legCurl:               return StatBlock(size: 0.55, strength: 0.25, dexterity: 0.00, agility: 0.00, endurance: 0.00, vitality: 0.20)
        case .calfRaiseStanding:     return StatBlock(size: 0.35, strength: 0.55, dexterity: 0.10, agility: 0.00, endurance: 0.00, vitality: 0.00)

        // Bodyweight & rings
        case .pushUp:                return StatBlock(size: 0.30, strength: 0.45, dexterity: 0.25, agility: 0.00, endurance: 0.00, vitality: 0.00)
        case .dip:                   return StatBlock(size: 0.35, strength: 0.50, dexterity: 0.00, agility: 0.15, endurance: 0.00, vitality: 0.00)
        case .pullUp:                return StatBlock(size: 0.20, strength: 0.45, dexterity: 0.35, agility: 0.00, endurance: 0.00, vitality: 0.00)
        case .plank:                 return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.50, agility: 0.00, endurance: 0.20, vitality: 0.30)
        case .hangingLegRaise:       return StatBlock(size: 0.00, strength: 0.25, dexterity: 0.55, agility: 0.00, endurance: 0.00, vitality: 0.20)
        case .abWheel:               return StatBlock(size: 0.00, strength: 0.20, dexterity: 0.50, agility: 0.00, endurance: 0.00, vitality: 0.30)
        case .handstand:             return StatBlock(size: 0.00, strength: 0.25, dexterity: 0.60, agility: 0.00, endurance: 0.15, vitality: 0.00)
        case .pistolSquat:           return StatBlock(size: 0.00, strength: 0.35, dexterity: 0.45, agility: 0.00, endurance: 0.00, vitality: 0.20)

        // Explosive / athleticism
        case .kettlebellSwing:       return StatBlock(size: 0.00, strength: 0.25, dexterity: 0.00, agility: 0.45, endurance: 0.30, vitality: 0.00)
        case .boxJump:               return StatBlock(size: 0.00, strength: 0.15, dexterity: 0.25, agility: 0.60, endurance: 0.00, vitality: 0.00)
        case .medBallSlam:           return StatBlock(size: 0.00, strength: 0.35, dexterity: 0.15, agility: 0.50, endurance: 0.00, vitality: 0.00)
        case .sprint:                return StatBlock(size: 0.00, strength: 0.15, dexterity: 0.00, agility: 0.60, endurance: 0.25, vitality: 0.00)
        case .powerClean:            return StatBlock(size: 0.00, strength: 0.25, dexterity: 0.30, agility: 0.45, endurance: 0.00, vitality: 0.00)
        case .sledPush:              return StatBlock(size: 0.00, strength: 0.30, dexterity: 0.00, agility: 0.35, endurance: 0.35, vitality: 0.00)
        case .jumpRope:              return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.20, agility: 0.35, endurance: 0.45, vitality: 0.00)

        // Endurance / conditioning
        case .run:                   return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.00, agility: 0.20, endurance: 0.65, vitality: 0.15)
        case .cycle:                 return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.00, agility: 0.25, endurance: 0.60, vitality: 0.15)
        case .rower:                 return StatBlock(size: 0.00, strength: 0.25, dexterity: 0.00, agility: 0.20, endurance: 0.55, vitality: 0.00)
        case .swimming:              return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.25, agility: 0.20, endurance: 0.55, vitality: 0.00)
        case .hikingStairs:          return StatBlock(size: 0.00, strength: 0.20, dexterity: 0.00, agility: 0.00, endurance: 0.60, vitality: 0.20)
        case .battleRopes:           return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.25, agility: 0.30, endurance: 0.45, vitality: 0.00)

        // Mobility / prehab
        case .hip90_90:              return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.40, agility: 0.00, endurance: 0.00, vitality: 0.60)
        case .couchStretch:          return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.40, agility: 0.00, endurance: 0.00, vitality: 0.60)
        case .cars:                  return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.65, agility: 0.00, endurance: 0.00, vitality: 0.35)
        case .thoracicRotation:      return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.40, agility: 0.00, endurance: 0.00, vitality: 0.60)
        case .externalRotation:      return StatBlock(size: 0.00, strength: 0.20, dexterity: 0.15, agility: 0.00, endurance: 0.00, vitality: 0.65)
        case .monsterWalks:          return StatBlock(size: 0.00, strength: 0.25, dexterity: 0.20, agility: 0.00, endurance: 0.00, vitality: 0.55)
        case .nordicHamstring:       return StatBlock(size: 0.20, strength: 0.35, dexterity: 0.00, agility: 0.00, endurance: 0.00, vitality: 0.45)
        case .copenhagenPlank:       return StatBlock(size: 0.00, strength: 0.15, dexterity: 0.35, agility: 0.00, endurance: 0.00, vitality: 0.50)
        case .tibialisRaise:         return StatBlock(size: 0.00, strength: 0.30, dexterity: 0.20, agility: 0.00, endurance: 0.00, vitality: 0.50)
        case .mcgillBig3:            return StatBlock(size: 0.00, strength: 0.10, dexterity: 0.30, agility: 0.00, endurance: 0.00, vitality: 0.60)
        case .hipAirplanes:          return StatBlock(size: 0.00, strength: 0.15, dexterity: 0.50, agility: 0.00, endurance: 0.00, vitality: 0.35)
        case .yoga:                  return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.50, agility: 0.15, endurance: 0.00, vitality: 0.35)
        }
    }

    // One-time fixed stat grant per exercise (×10 display scale).
    // Applied only the first time a given exercise is logged by the user.
    static func firstTimeGrant(for category: ExerciseCategory) -> StatBlock {
        switch category {
        // =============================
        // Strength / Hypertrophy (loaded)
        // =============================
        case .squat:
            return StatBlock(size: 1.2, strength: 1.8, dexterity: 0.0, agility: 0.2, endurance: 0.0, vitality: 0.0)
        case .frontSquat:
            return StatBlock(size: 1.0, strength: 1.6, dexterity: 0.4, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .deadlift:
            return StatBlock(size: 1.0, strength: 2.0, dexterity: 0.0, agility: 0.0, endurance: 0.0, vitality: 0.2)
        case .romanianDeadlift:
            return StatBlock(size: 1.2, strength: 1.6, dexterity: 0.0, agility: 0.0, endurance: 0.0, vitality: 0.2)
        case .benchPress:
            return StatBlock(size: 1.3, strength: 1.8, dexterity: 0.0, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .overheadPress:
            return StatBlock(size: 0.9, strength: 1.7, dexterity: 0.3, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .row:
            return StatBlock(size: 1.0, strength: 1.4, dexterity: 0.4, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .hipThrust:
            return StatBlock(size: 1.2, strength: 1.4, dexterity: 0.0, agility: 0.3, endurance: 0.0, vitality: 0.0)
        case .bulgarianSplitSquat:
            return StatBlock(size: 0.4, strength: 1.2, dexterity: 0.8, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .legPress:
            return StatBlock(size: 1.3, strength: 1.3, dexterity: 0.0, agility: 0.0, endurance: 0.0, vitality: 0.1)
        case .latPulldown:
            return StatBlock(size: 1.1, strength: 1.1, dexterity: 0.2, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .cableRow:
            return StatBlock(size: 1.1, strength: 1.1, dexterity: 0.2, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .chestFly:
            return StatBlock(size: 1.6, strength: 0.5, dexterity: 0.0, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .lateralRaise:
            return StatBlock(size: 1.4, strength: 0.0, dexterity: 0.3, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .curl:
            return StatBlock(size: 1.4, strength: 0.5, dexterity: 0.0, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .tricepsExtension:
            return StatBlock(size: 1.4, strength: 0.5, dexterity: 0.0, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .legExtension:
            return StatBlock(size: 1.4, strength: 0.2, dexterity: 0.0, agility: 0.0, endurance: 0.0, vitality: 0.3)
        case .legCurl:
            return StatBlock(size: 1.2, strength: 0.2, dexterity: 0.0, agility: 0.0, endurance: 0.0, vitality: 0.4)
        case .calfRaiseStanding:
            return StatBlock(size: 0.6, strength: 1.0, dexterity: 0.2, agility: 0.0, endurance: 0.0, vitality: 0.0)

        // =============================
        // Bodyweight & skill
        // =============================
        case .pushUp:
            return StatBlock(size: 0.3, strength: 0.8, dexterity: 0.8, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .dip:
            return StatBlock(size: 0.6, strength: 1.0, dexterity: 0.0, agility: 0.2, endurance: 0.0, vitality: 0.0)
        case .pullUp:
            return StatBlock(size: 0.3, strength: 1.0, dexterity: 0.8, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .pistolSquat:
            return StatBlock(size: 0.0, strength: 0.6, dexterity: 1.0, agility: 0.0, endurance: 0.0, vitality: 0.2)
        case .hangingLegRaise:
            return StatBlock(size: 0.0, strength: 0.4, dexterity: 0.9, agility: 0.0, endurance: 0.0, vitality: 0.3)
        case .abWheel:
            return StatBlock(size: 0.0, strength: 0.3, dexterity: 0.8, agility: 0.0, endurance: 0.0, vitality: 0.6)
        case .handstand:
            return StatBlock(size: 0.0, strength: 0.5, dexterity: 0.9, agility: 0.0, endurance: 0.2, vitality: 0.0)
        case .plank:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.7, agility: 0.0, endurance: 0.3, vitality: 0.8)
        case .copenhagenPlank:
            return StatBlock(size: 0.0, strength: 0.2, dexterity: 0.6, agility: 0.0, endurance: 0.0, vitality: 0.8)
        case .mcgillBig3:
            return StatBlock(size: 0.0, strength: 0.2, dexterity: 0.6, agility: 0.0, endurance: 0.0, vitality: 0.8)

        // =============================
        // Explosive / athleticism
        // =============================
        case .kettlebellSwing:
            return StatBlock(size: 0.0, strength: 0.4, dexterity: 0.0, agility: 1.0, endurance: 0.5, vitality: 0.0)
        case .boxJump:
            return StatBlock(size: 0.0, strength: 0.2, dexterity: 0.6, agility: 1.2, endurance: 0.0, vitality: 0.0)
        case .medBallSlam:
            return StatBlock(size: 0.0, strength: 0.6, dexterity: 0.2, agility: 1.0, endurance: 0.0, vitality: 0.0)
        case .sprint:
            return StatBlock(size: 0.0, strength: 0.2, dexterity: 0.0, agility: 1.1, endurance: 0.6, vitality: 0.0)
        case .powerClean:
            return StatBlock(size: 0.0, strength: 0.6, dexterity: 0.5, agility: 1.0, endurance: 0.0, vitality: 0.0)
        case .sledPush:
            return StatBlock(size: 0.0, strength: 0.5, dexterity: 0.0, agility: 0.7, endurance: 0.7, vitality: 0.0)
        case .jumpRope:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.3, agility: 0.7, endurance: 0.8, vitality: 0.0)

        // =============================
        // Endurance / conditioning
        // =============================
        case .run:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.0, agility: 0.4, endurance: 1.6, vitality: 0.2)
        case .cycle:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.0, agility: 0.4, endurance: 1.6, vitality: 0.2)
        case .rower:
            return StatBlock(size: 0.0, strength: 0.4, dexterity: 0.0, agility: 0.3, endurance: 1.4, vitality: 0.0)
        case .swimming:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.4, agility: 0.3, endurance: 1.5, vitality: 0.0)
        case .hikingStairs:
            return StatBlock(size: 0.0, strength: 0.2, dexterity: 0.0, agility: 0.0, endurance: 1.2, vitality: 0.5)
        case .battleRopes:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.3, agility: 0.6, endurance: 1.0, vitality: 0.0)

        // =============================
        // Mobility / prehab
        // =============================
        case .hip90_90:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.6, agility: 0.0, endurance: 0.0, vitality: 0.8)
        case .couchStretch:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.6, agility: 0.0, endurance: 0.0, vitality: 0.8)
        case .cars:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.8, agility: 0.0, endurance: 0.0, vitality: 0.6)
        case .thoracicRotation:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.6, agility: 0.0, endurance: 0.0, vitality: 0.8)
        case .externalRotation:
            return StatBlock(size: 0.0, strength: 0.3, dexterity: 0.3, agility: 0.0, endurance: 0.0, vitality: 0.8)
        case .monsterWalks:
            return StatBlock(size: 0.0, strength: 0.4, dexterity: 0.3, agility: 0.0, endurance: 0.0, vitality: 0.7)
        case .tibialisRaise:
            return StatBlock(size: 0.0, strength: 0.4, dexterity: 0.3, agility: 0.0, endurance: 0.0, vitality: 0.7)
        case .hipAirplanes:
            return StatBlock(size: 0.0, strength: 0.2, dexterity: 0.8, agility: 0.0, endurance: 0.0, vitality: 0.6)
        case .yoga:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.6, agility: 0.2, endurance: 0.0, vitality: 0.8)
        case .nordicHamstring:
            return StatBlock(size: 0.0, strength: 0.5, dexterity: 0.2, agility: 0.0, endurance: 0.0, vitality: 0.7)
        }
    }

    // Primary volume estimators
    static func intensityScore(category: ExerciseCategory, reps: Int?, weight: Double?, durationMin: Double?, distanceKm: Double?) -> Double {
        switch category {
        // Weight × reps tonnage style
        case .squat, .frontSquat, .deadlift, .romanianDeadlift, .benchPress, .overheadPress, .row, .hipThrust, .bulgarianSplitSquat, .legPress,
             .latPulldown, .cableRow, .chestFly, .lateralRaise, .curl, .tricepsExtension, .legExtension, .legCurl, .calfRaiseStanding,
             .kettlebellSwing, .powerClean:
            let r = max(0, Double(reps ?? 0))
            let w = max(0, weight ?? 0)
            return r * w

        // Bodyweight reps with added load support
        case .pushUp, .dip, .pullUp, .handstand, .pistolSquat:
            let r1 = max(0, Double(reps ?? 0))
            let add = max(0, weight ?? 0) // treat as weighted if provided
            return r1 * (60 + add * 2)

        case .hangingLegRaise, .abWheel:
            let r2 = max(0, Double(reps ?? 0))
            return r2 * 60

        // Time-based core holds / mobility
        case .plank, .copenhagenPlank, .mcgillBig3, .hip90_90, .couchStretch, .cars, .thoracicRotation, .externalRotation, .monsterWalks, .tibialisRaise, .hipAirplanes, .yoga:
            let t = max(0, durationMin ?? 0)
            return t * 35

        // Explosive reps without meaningful load
        case .boxJump:
            let r = max(0, Double(reps ?? 0))
            return r * 70

        // Med-ball with load (if weight provided)
        case .medBallSlam:
            let r = max(0, Double(reps ?? 0))
            let w = max(0, weight ?? 10)
            return r * w * 0.5

        // Conditioning / cardio
        case .sprint:
            let t = max(0, durationMin ?? 0)
            return t * 90
        case .run, .cycle, .rower:
            let t = max(0, durationMin ?? 0)
            let d = max(0, distanceKm ?? 0)
            return t * 20 + d * 220
        case .swimming:
            let t = max(0, durationMin ?? 0)
            let d = max(0, distanceKm ?? 0)
            return t * 24 + d * 260
        case .hikingStairs:
            let t = max(0, durationMin ?? 0)
            return t * 25
        case .battleRopes:
            let t = max(0, durationMin ?? 0)
            return t * 70

        case .sledPush:
            let t = max(0, durationMin ?? 0)
            return t * 60

        case .jumpRope:
            let t = max(0, durationMin ?? 0)
            return t * 70
        case .nordicHamstring:
            // Allow either time-under-tension or reps to drive score
            if let t = durationMin, t > 0 { return t * 25 }
            let r = max(0, Double(reps ?? 0))
            return r * 40
        }
    }

    static func exp(for category: ExerciseCategory, score: Double) -> Double {
        // Converts intensity score to EXP; tuned to keep early levels brisk
        let base: Double = 0.1
        let root = sqrt(max(0, score))
        let scale: Double
        switch category {
        case .sprint:
            scale = 0.30
        case .run, .cycle, .rower:
            scale = 0.35
        case .swimming:
            scale = 0.40
        default:
            // Fallback by focus group so all categories are covered
            switch category.focus {
            case .strength:   scale = 0.15
            case .hypertrophy:scale = 0.12
            case .bodyweight: scale = 0.22
            case .explosive:  scale = 0.22
            case .endurance:  scale = 0.14
            case .mobility:   scale = 0.08
            }
        }
        return base + root * scale
    }

    // Effort score (0–100) used for session XP banding
    static func effortScore(category: ExerciseCategory,
                            score: Double,
                            prRatio: Double,
                            durationMin: Double?,
                            distanceKm: Double?) -> Double {
        // Base from volume/intensity with diminishing returns
        let vol = log1p(max(0, score))             // 0…
        var E = 40.0 + min(40.0, 12.0 * vol)       // 40…80 for typical sessions

        // PR boost: +0 for no PR, up to +~20 for big PRs (log2 scale)
        let pr = max(0.0, log2(max(1.0, prRatio)))
        E += min(20.0, pr * 20.0)

        // Endurance duration soft cap so very long easy sessions don't dominate
        if let d = durationMin, d > 90, category.focus == .endurance {
            E -= min(10.0, (d - 90.0) * 0.08)
        }

        // Clamp 10…100 to avoid degenerate bands
        return max(10.0, min(100.0, E))
    }

    // Map Effort score to clean XP bands for readability
    static func xpForEffort(_ E: Double) -> Double {
        switch E {
        case ..<41:  return 40
        case ..<61:  return 80
        case ..<81:  return 120
        default:     return 160
        }
    }

    // Smoothstep helper for soft, eased scaling (0..1 input mapped to 0..1)
    static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        if edge0 == edge1 { return x >= edge1 ? 1.0 : 0.0 }
        let t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
        return t * t * (3.0 - 2.0 * t)
    }

    // Map improvement ratio r (perf / baseline) to a gentle magnitude multiplier for stat budget.
    // Asymmetric: improvements can boost up to +40%, regressions dampen up to −30%.
    static func magnitudeScale(fromRatio rIn: Double) -> Double {
        // Clamp the incoming ratio to a reasonable band
        let r = max(0.5, min(2.0, rIn))
        if r >= 1.0 {
            // Map 1.0→2.0 to 0→1, ease it, and scale to +40%
            let x = (r - 1.0) / 1.0
            return 1.0 + 0.40 * smoothstep(0.0, 1.0, x)
        } else {
            // Map 1.0→0.5 to 0→1, ease it, and scale to −30%
            let x = (1.0 - r) / 0.5
            return 1.0 - 0.30 * smoothstep(0.0, 1.0, x)
        }
    }

    // Per-focus gain multiplier
    static func focusGainMultiplier(_ focus: FocusGroup) -> Double {
        switch focus {
        case .strength, .hypertrophy: return 1.0
        case .explosive:  return 1.15
        case .bodyweight: return 1.25
        case .endurance:  return 1.30
        case .mobility:   return 1.15
        }
    }

    // One‑decimal random helper for first‑time XP banding
    private static func randomOneDecimal(in range: ClosedRange<Double>) -> Double {
        let v = Double.random(in: range)
        return (v * 10.0).rounded() / 10.0
    }

    // Relative XP vs personal baseline with asymmetric rewards
    static func relativeXP(category: ExerciseCategory,
                           perf: Double,
                           baseline: Double?,
                           isFirstEver: Bool) -> Double {
        // First *ever* workout or first time for this exercise → engaging 10.x–12.x XP
        if isFirstEver || baseline == nil || baseline == 0 || perf == 0 {
            let seed = randomOneDecimal(in: 10.1...12.9)
            return (seed * focusGainMultiplier(category.focus) * 10).rounded() / 10
        }
        let base = max(0.0001, baseline ?? 0.0001)
        let ratio = max(0.01, perf / base)
        // Reward increases more than penalize decreases
        let incExp = 1.25   // faster-than-linear for improvements
        let decExp = 0.50   // softer penalty for regressions
        let neutral = 12.0  // around “feels good” mid value
        let raw = ratio >= 1.0 ? neutral * pow(ratio, incExp)
                               : neutral * pow(ratio, decExp)
        // Clamp readable bands; floor is 8.x–9.x if worse than baseline
        let floorMin = 8.0, floorMax = 9.0, hardMax = 50.0
        var xp = raw
        if ratio < 1.0 { xp = max(randomOneDecimal(in: floorMin...floorMax), raw) }
        xp = min(hardMax, xp)
        // Keep category feel with a small multiplier
        xp *= focusGainMultiplier(category.focus)
        // ±0.4 jitter for feel; clamp again to readable bounds
        xp += Double.random(in: -0.4...0.4)
        xp = min(hardMax, max(floorMin, xp))
        return (xp * 10).rounded() / 10
    }

    static func statGains(for category: ExerciseCategory, score: Double) -> StatBlock {
        // Normalize score to a gentle curve so small sessions still feel rewarding
        let normalized = log10(max(1, score + 10)) // 1…~
        let weights = statWeights(for: category)
        // Scale the weight vector by normalized effort and a small global factor
        let k = 0.25 * normalized * focusGainMultiplier(category.focus)
        return StatBlock(
            size: weights.size * k,
            strength: weights.strength * k,
            dexterity: weights.dexterity * k,
            agility: weights.agility * k,
            endurance: weights.endurance * k,
            vitality: weights.vitality * k
        )
    }

    // Estimate 1RM using improved Epley formula for main compound lifts only
    static func estimate1RM(category: ExerciseCategory, reps: Int?, weight: Double?) -> Double {
        // Only calculate 1RM for major compound lifts where it's meaningful
        let oneRMRelevantLifts: Set<ExerciseCategory> = [
            .squat, .frontSquat, .deadlift, .romanianDeadlift, .benchPress, .overheadPress, .powerClean
        ]
        guard oneRMRelevantLifts.contains(category) else { return 0 }
        guard let w = weight, w > 0 else { return 0 }
        guard let r = reps, r > 0, r <= 15 else { return 0 } // Only valid for 1-15 reps
        
        // Use Brzycki formula for better accuracy: 1RM = weight / (1.0278 - 0.0278 × reps)
        // More accurate than Epley for lower rep ranges
        let repsDouble = Double(r)
        if r == 1 {
            return w // 1 rep = 1RM
        } else {
            return w / (1.0278 - 0.0278 * repsDouble)
        }
    }

    // Unified "performance" metric used for personal-ratio XP and placement.
    // Implements the agreed per-category rules so r = perf / EMA(perf) captures intensity relative to self.
    static func placementMetric(category: ExerciseCategory,
                                reps: Int?,
                                weight: Double?,
                                durationMin: Double?,
                                distanceKm: Double?,
                                bodyweightKg: Double?) -> Double {
        let bw = max(1.0, bodyweightKg ?? 70.0)
        let r = max(0.0, Double(reps ?? 0))
        let w = max(0.0, weight ?? 0.0)
        let tMin = max(0.0, durationMin ?? 0.0)
        let dKm = max(0.0, distanceKm ?? 0.0)
        let tHr = tMin / 60.0

        switch category {

        // ——— Main compound lifts (1RM relevant) ———
        case .squat, .frontSquat, .deadlift, .romanianDeadlift, .benchPress, .overheadPress, .powerClean:
            // perf = accurate 1RM estimate using Brzycki formula
            return max(0.0, estimate1RM(category: category, reps: Int(r), weight: w))
            
        // ——— Other loaded lifts (use simpler weight × reps metric) ———
        case .row, .hipThrust, .bulgarianSplitSquat, .legPress, .latPulldown, .cableRow, .chestFly,
             .lateralRaise, .curl, .tricepsExtension, .legExtension, .legCurl, .calfRaiseStanding:
            // perf = total volume (weight × reps) for accessory movements
            return w * r

        // ——— Bodyweight & skill (reps; optional weight) ———
        case .pushUp, .dip, .pullUp, .pistolSquat, .hangingLegRaise, .abWheel:
            // perf = reps × (effectiveLoad / BW)^0.65
            let eff = (w > 0 ? bw + w : bw)
            return r * pow(eff / bw, 0.65)

        // Handstand can be reps or hold; choose rule based on inputs
        case .handstand:
            if tMin > 0 {
                // Hold rule (see below)
                let eff = bw + w
                return tMin * pow(eff / bw, 0.30)
            } else {
                let eff = (w > 0 ? bw + w : bw)
                return r * pow(eff / bw, 0.65)
            }

        // ——— Holds (time ± optional weight) ———
        case .plank, .copenhagenPlank, .mcgillBig3:
            // perf = time × ((BW+added)/BW)^0.3
            let eff = bw + w
            return tMin * pow(eff / bw, 0.30)

        // ——— Explosive / athleticism ———
        case .kettlebellSwing, .medBallSlam:
            // Loaded reps: reps × (weight/BW)^0.65 (if no weight given, treat as BW)
            let load = max(w, 0.0)
            let ratio = (load > 0 ? load / bw : 1.0)
            return r * pow(ratio, 0.65)

        case .boxJump:
            // Until we capture jump height, treat as skill reps
            return r

        case .sprint:
            if dKm > 0 && tHr > 0 {
                let v = dKm / tHr
                return v * pow(dKm, 0.25)
            } else if tMin > 0 {
                // Timed fixed distance: perf ≈ 1 / time (normalized to minutes)
                return 60.0 / tMin
            } else {
                return 0
            }

        // ——— Endurance / conditioning (pace + time) ———
        case .run, .cycle, .rower, .swimming:
            guard dKm > 0 && tHr > 0 else { return 0 }
            let v = dKm / tHr    // km/h
            return v * pow(dKm, 0.50)

        // ——— Conditioning (duration-dominant with optional load) ———
        case .hikingStairs, .battleRopes, .jumpRope, .sledPush:
            guard tMin > 0 else { return 0 }
            // perf = minutes × ((BW+added)/BW)^0.5
            let eff = bw + w
            return tMin * pow(eff / bw, 0.50)

        // ——— Mobility / prehab (consistency over intensity) ———
        case .hip90_90, .couchStretch, .cars, .thoracicRotation, .externalRotation, .monsterWalks, .tibialisRaise, .hipAirplanes, .yoga:
            // Track minutes for EMA; XP bonuses are handled elsewhere via streak logic.
            return tMin

        case .nordicHamstring:
            // If time provided → hold rule; if reps → bodyweight-reps rule
            if tMin > 0 {
                let eff = bw + w
                return tMin * pow(eff / bw, 0.30)
            } else {
                let eff = (w > 0 ? bw + w : bw)
                return r * pow(eff / bw, 0.65)
            }
        }
    }

    // Map best 1RM to a target level. Stronger lifters get placed higher even without prior logs.
    static func levelFromBest1RM(_ best: Double) -> Int {
        // Saturating placement: maps best 1RM (kg) to 0…100 with diminishing returns
        // Tunables: S (scale), alpha (curvature)
        let S = 220.0
        let alpha = 1.4
        let x = pow(max(best, 0.0) / S, alpha)
        let frac = 1.0 - Foundation.exp(-x) // 0→1
        let lvl = Int(round(Double(maxLevel) * frac))
        return max(0, min(maxLevel, lvl))
    }
    
    // MARK: - Treasure Chest System
    static func generateTreasureChest(forLevel level: Int) -> TreasureChest {
        let chestType = determineTreasureChestType(forLevel: level)
        var chest = TreasureChest(
            type: chestType,
            earnedAtLevel: level,
            dateEarned: Date(),
            isOpened: false,
            rewards: []
        )
        
        chest.rewards = generateRewards(for: chestType, level: level)
        return chest
    }
    
    // Debug version that allows forcing a specific chest type
    static func generateTreasureChest(forLevel level: Int, forcedType: TreasureChestType) -> TreasureChest {
        var chest = TreasureChest(
            type: forcedType,
            earnedAtLevel: level,
            dateEarned: Date(),
            isOpened: false,
            rewards: []
        )
        
        chest.rewards = generateRewards(for: forcedType, level: level)
        return chest
    }
    
    private static func determineTreasureChestType(forLevel level: Int) -> TreasureChestType {
        let randomChance = Double.random(in: 0...1)
        
        // Fixed probability distribution for all levels
        switch randomChance {
        case 0.97...1.0: return .mythic      // 3% chance
        case 0.90...0.97: return .epic       // 7% chance
        case 0.75...0.90: return .rare       // 15% chance
        case 0.45...0.75: return .uncommon   // 30% chance
        default: return .common              // 45% chance
        }
    }
    
    private static func generateRewards(for chestType: TreasureChestType, level: Int) -> [TreasureReward] {
        var rewards: [TreasureReward] = []
        
        // Always give one bonus XP reward
        let bonusXPReward = generateSingleReward(for: chestType, level: level, forceType: .bonus_xp)
        rewards.append(bonusXPReward)
        
        // Always give one coins reward
        let coinsReward = generateSingleReward(for: chestType, level: level, forceType: .coins)
        rewards.append(coinsReward)
        
        // Chest-specific chance to get an item reward
        let itemChance = itemDropChance(for: chestType)
        if Double.random(in: 0...1) < itemChance {
            let itemReward = generateSingleReward(for: chestType, level: level, forceType: .item)
            rewards.append(itemReward)
        }
        
        return rewards
    }
    
    // Helper function to get the item drop chance for each chest type
    private static func itemDropChance(for chestType: TreasureChestType) -> Double {
        switch chestType {
        case .common: return 0.60     // 60% chance (100% - 40% nothing)
        case .uncommon: return 0.70   // 70% chance (100% - 30% nothing)
        case .rare: return 0.80       // 80% chance (100% - 20% nothing)
        case .epic: return 0.90       // 90% chance (100% - 10% nothing)
        case .mythic: return 0.95     // 95% chance (100% - 5% nothing)
        }
    }
    
    private static func rewardCountForChest(_ type: TreasureChestType) -> Int {
        switch type {
        case .common: return Int.random(in: 1...2)
        case .uncommon: return Int.random(in: 2...3)
        case .rare: return Int.random(in: 3...4)
        case .epic: return Int.random(in: 4...5)
        case .mythic: return Int.random(in: 5...6)
        }
    }
    
    private static func generateSingleReward(for chestType: TreasureChestType, level: Int, excludeTypes: Set<RewardType> = [], forceType: RewardType? = nil) -> TreasureReward {
        let type: RewardType
        if let forceType = forceType {
            type = forceType
        } else {
            let allRewardTypes: [RewardType] = [.bonus_xp, .coins, .item]
            let availableTypes = allRewardTypes.filter { !excludeTypes.contains($0) }
            type = availableTypes.randomElement() ?? .bonus_xp
        }
        
        let (amount, description, itemInfo) = generateRewardValue(type: type, chestType: chestType, level: level)
        
        return TreasureReward(
            type: type,
            amount: amount,
            description: description,
            itemInfo: itemInfo
        )
    }
    
    private static func generateRewardValue(type: RewardType, chestType: TreasureChestType, level: Int) -> (Double, String, ItemInfo?) {
        switch type {
        case .bonus_xp:
            let amount = fixedXPValue(for: chestType)
            return (amount, "\(Int(amount)) XP", nil)
            
        case .coins:
            let amount = generateCoinsReward(for: chestType)
            return (amount, "\(Int(amount)) Gold Coins", nil)
            
        case .item:
            return generateItemByChestRarity(chestType: chestType)
        }
    }
    
    // Fixed XP values by rarity
    private static func fixedXPValue(for chestType: TreasureChestType) -> Double {
        switch chestType {
        case .common: return 25
        case .uncommon: return 50
        case .rare: return 100
        case .epic: return 200
        case .mythic: return 400
        }
    }
    
    // Tiered coin generation with set values
    private static func generateCoinsReward(for chestType: TreasureChestType) -> Double {
        let randomValue = Double.random(in: 0...1)
        
        switch chestType {
        case .common:
            if randomValue < 0.6 {
                return 45 // Normal (60%)
            } else if randomValue < 0.9 {
                return 90 // Large (30%)
            } else {
                return 135 // Jackpot (10%)
            }
        case .uncommon:
            if randomValue < 0.6 {
                return 135 // Normal (60%)
            } else if randomValue < 0.9 {
                return 180 // Large (30%)
            } else {
                return 225 // Jackpot (10%)
            }
        case .rare:
            if randomValue < 0.6 {
                return 225 // Normal (60%)
            } else if randomValue < 0.9 {
                return 270 // Large (30%)
            } else {
                return 315 // Jackpot (10%)
            }
        case .epic:
            if randomValue < 0.6 {
                return 315 // Normal (60%)
            } else if randomValue < 0.9 {
                return 360 // Large (30%)
            } else {
                return 405 // Jackpot (10%)
            }
        case .mythic:
            if randomValue < 0.6 {
                return 405 // Normal (60%)
            } else if randomValue < 0.9 {
                return 450 // Large (30%)
            } else {
                return 495 // Jackpot (10%)
            }
        }
    }
    
    // Generate item rewards based on chest rarity (when an item is guaranteed)
    private static func generateItemByChestRarity(chestType: TreasureChestType) -> (Double, String, ItemInfo?) {
        let randomValue = Double.random(in: 0...1)
        
        switch chestType {
        case .common:
            // Common Chest: 83.3% Common (50/60), 15% Rare (9/60), 1.7% Epic (1/60)
            if randomValue < 0.833 {
                return generateRandomItem(rarity: "uncommon")
            } else if randomValue < 0.983 {
                return generateRandomItem(rarity: "rare")
            } else {
                return generateRandomItem(rarity: "epic")
            }
            
        case .uncommon:
            // Uncommon Chest: 57.1% Common (40/70), 35.7% Rare (25/70), 5.7% Epic (4/70), 1.4% Legendary (1/70)
            if randomValue < 0.571 {
                return generateRandomItem(rarity: "uncommon")
            } else if randomValue < 0.928 {
                return generateRandomItem(rarity: "rare")
            } else if randomValue < 0.985 {
                return generateRandomItem(rarity: "epic")
            } else {
                return generateRandomItem(rarity: "legendary")
            }
            
        case .rare:
            // Rare Chest: 25% Common (20/80), 50% Rare (40/80), 18.75% Epic (15/80), 5% Legendary (4/80), 1.25% Mythic (1/80)
            if randomValue < 0.25 {
                return generateRandomItem(rarity: "uncommon")
            } else if randomValue < 0.75 {
                return generateRandomItem(rarity: "rare")
            } else if randomValue < 0.9375 {
                return generateRandomItem(rarity: "epic")
            } else if randomValue < 0.9875 {
                return generateRandomItem(rarity: "legendary")
            } else {
                return generateRandomItem(rarity: "mythic")
            }
            
        case .epic:
            // Epic Chest: 11.1% Common (10/90), 22.2% Rare (20/90), 44.4% Epic (40/90), 16.7% Legendary (15/90), 5.6% Mythic (5/90)
            if randomValue < 0.111 {
                return generateRandomItem(rarity: "uncommon")
            } else if randomValue < 0.333 {
                return generateRandomItem(rarity: "rare")
            } else if randomValue < 0.777 {
                return generateRandomItem(rarity: "epic")
            } else if randomValue < 0.944 {
                return generateRandomItem(rarity: "legendary")
            } else {
                return generateRandomItem(rarity: "mythic")
            }
            
        case .mythic:
            // Mythic Chest: 5.3% Common (5/95), 10.5% Rare (10/95), 26.3% Epic (25/95), 36.8% Legendary (35/95), 21.1% Mythic (20/95)
            if randomValue < 0.053 {
                return generateRandomItem(rarity: "uncommon")
            } else if randomValue < 0.158 {
                return generateRandomItem(rarity: "rare")
            } else if randomValue < 0.421 {
                return generateRandomItem(rarity: "epic")
            } else if randomValue < 0.789 {
                return generateRandomItem(rarity: "legendary")
            } else {
                return generateRandomItem(rarity: "mythic")
            }
        }
    }
    
    // Helper function to generate a random item of specific rarity
    private static func generateRandomItem(rarity: String) -> (Double, String, ItemInfo?) {
        switch rarity {
        case "uncommon":
            let items: [UncommonTierItem] = [.soccerball, .basketball, .volleyball]
            let randomItem = items.randomElement()!
            let itemInfo = ItemInfo.uncommon(randomItem)
            return (1, randomItem.displayName, itemInfo)
            
        case "rare":
            let items: [RareTierItem] = [.puzzlepiece, .balloon]
            let randomItem = items.randomElement()!
            let itemInfo = ItemInfo.rare(randomItem)
            return (1, randomItem.displayName, itemInfo)
            
        case "epic":
            let items: [EpicTierItem] = [.birthdaycake, .gamecontroller]
            let randomItem = items.randomElement()!
            let itemInfo = ItemInfo.epic(randomItem)
            return (1, randomItem.displayName, itemInfo)
            
        case "legendary":
            let items: [LegendaryTierItem] = [.trophy, .wand]
            let randomItem = items.randomElement()!
            let itemInfo = ItemInfo.legendary(randomItem)
            return (1, randomItem.displayName, itemInfo)
            
        case "mythic":
            let items: [MythicTierItem] = [.teddybear]
            let randomItem = items.randomElement()!
            let itemInfo = ItemInfo.mythic(randomItem)
            return (1, randomItem.displayName, itemInfo)
            
        default:
            return (0, "Nothing", nil)
        }
    }
    
    private static func chestMultiplier(for type: TreasureChestType) -> Double {
        switch type {
        case .common: return 1.0
        case .uncommon: return 1.4
        case .rare: return 2.0
        case .epic: return 3.0
        case .mythic: return 4.5
        }
    }

    // Cumulative XP helpers
    static func cumulativeXP(toLevel level: Int) -> Double {
        guard level > 1 else { return 0 }
        var sum: Double = 0
        for l in 1..<(level) {
            sum += xpNeeded(forNextLevel: l)
        }
        return sum
    }

    static func cumulativeXP(level: Int, xpWithin: Double) -> Double {
        return cumulativeXP(toLevel: level) + xpWithin
    }

    static func xpNeeded(forNextLevel level: Int) -> Double {
        if level <= 0 { return 50 }
        // Use display level for XP calculation to reset requirements after prestige
        let displayLevel = level <= 10 ? level : ((level - 1) % 10) + 1
        return 50 * pow(Double(displayLevel), 1.2)
    }
}

// MARK: - App State & Persistence
final class AppState: ObservableObject {
    @Published var user: UserProfile
    @Published var history: [WorkoutEntry] {
        didSet {
            clearCache()
        }
    }
    
    // Cache for expensive operations
    private var cachedSortedHistory: [WorkoutEntry]?
    private var cachedGroupedWorkouts: [(String, [WorkoutEntry])]?
    private var cacheValidationTime: Date?
    private let cacheExpirationInterval: TimeInterval = 300 // 5 minutes

    func seedSampleData() {
        _ = history.count
        // Simple demo data (uses current units for input, but we convert to kg)
        _ = logWorkout(name: "Bench", category: .benchPress, reps: 5, weight: user.units == .kg ? 80 : 176, durationMinutes: nil, distanceKm: nil)
        // Distances entered in the user's display units, then converted to km for storage
        let runDisplayDist = user.units == .kg ? 4.2 : 2.6   // ~4.2 km ≈ 2.6 mi
        let cycleDisplayDist = user.units == .kg ? 18.0 : 11.2 // ~18 km ≈ 11.2 mi
        let runKm = user.units.toKm(runDisplayDist)
        let cycleKm = user.units.toKm(cycleDisplayDist)
        _ = logWorkout(name: "Run", category: .run, reps: nil, weight: nil, durationMinutes: 25, distanceKm: runKm)
        _ = logWorkout(name: "Squat", category: .squat, reps: 5, weight: user.units == .kg ? 120 : 265, durationMinutes: nil, distanceKm: nil)
        _ = logWorkout(name: "Pull-Ups", category: .pullUp, reps: 10, weight: nil, durationMinutes: nil, distanceKm: nil)
        _ = logWorkout(name: "Cycle", category: .cycle, reps: nil, weight: nil, durationMinutes: 40, distanceKm: cycleKm)
        
        // Add sample treasure chests for demo
        let sampleChest1 = StatEngine.generateTreasureChest(forLevel: 2)
        let sampleChest2 = StatEngine.generateTreasureChest(forLevel: 5)
        let sampleChest3 = StatEngine.generateTreasureChest(forLevel: 25) // Special level for higher tier
        user.treasureChests.append(contentsOf: [sampleChest1, sampleChest2, sampleChest3])
        
    }

    func resetAll() {
        self.user = UserProfile()
        self.history = []
        save()
        
        // Reset AppStorage values
        UserDefaults.standard.removeObject(forKey: "hasSeenOnboarding")
    }

    init() {
        if let loaded = Self.load() {
            self.user = loaded.user
            self.history = loaded.history
        } else {
            self.user = UserProfile()
            self.history = []
        }
    }

    // Input validation for workout values
    private func validateWorkoutInputs(reps: Int?, weight: Double?, durationMinutes: Double?, distanceKm: Double?) -> (reps: Int?, weight: Double?, duration: Double?, distance: Double?, isValid: Bool, error: String?) {
        var validatedReps = reps
        var validatedWeight = weight
        var validatedDuration = durationMinutes
        var validatedDistance = distanceKm
        var errors: [String] = []
        
        // Validate reps (1-9999)
        if let r = reps {
            if r < 1 {
                validatedReps = 1
                errors.append("Reps must be at least 1")
            } else if r > 9999 {
                validatedReps = 9999
                errors.append("Reps cannot exceed 9999")
            }
        }
        
        // Validate weight (0.1-9999 kg)
        if let w = weight {
            if w < 0 {
                validatedWeight = 0
                errors.append("Weight cannot be negative")
            } else if w > 9999 {
                validatedWeight = 9999
                errors.append("Weight cannot exceed 9999 kg")
            }
        }
        
        // Validate duration (0.1-1440 minutes = 24 hours)
        if let d = durationMinutes {
            if d < 0 {
                validatedDuration = 0
                errors.append("Duration cannot be negative")
            } else if d > 1440 {
                validatedDuration = 1440
                errors.append("Duration cannot exceed 24 hours")
            }
        }
        
        // Validate distance (0.001-9999 km)
        if let dist = distanceKm {
            if dist < 0 {
                validatedDistance = 0
                errors.append("Distance cannot be negative")
            } else if dist > 9999 {
                validatedDistance = 9999
                errors.append("Distance cannot exceed 9999 km")
            }
        }
        
        let errorMessage = errors.isEmpty ? nil : errors.joined(separator: "; ")
        return (validatedReps, validatedWeight, validatedDuration, validatedDistance, errors.isEmpty, errorMessage)
    }
    
    // Logging workflow
    @discardableResult
    func logWorkout(name: String, category: ExerciseCategory, reps: Int?, weight: Double?, durationMinutes: Double?, distanceKm: Double?) -> WorkoutEntry {
        // Validate inputs
        let validation = validateWorkoutInputs(reps: reps, weight: weight, durationMinutes: durationMinutes, distanceKm: distanceKm)
        let (validatedReps, validatedWeight, validatedDuration, validatedDistance, isValid, validationError) = validation
        
        if !isValid, let error = validationError {
            persistenceError = "Input validation: \(error)"
        }
        // Base scores (use validated inputs)
        let levelBefore = user.level
        let xpBefore = user.xp
        let score = StatEngine.intensityScore(category: category, reps: validatedReps, weight: validatedWeight, durationMin: validatedDuration, distanceKm: validatedDistance)
        // Performance & PR logic (for barbell lifts)
        let est1RM = StatEngine.estimate1RM(category: category, reps: validatedReps, weight: validatedWeight)
        let prevBest = user.best1RM[category] ?? 0
        var prRatio: Double = 1.0
        if est1RM > 0 {
            if est1RM > prevBest { user.best1RM[category] = est1RM }
            // Use a softer baseline when there's no prior best to simulate a time‑skip update
            let effectivePrev = prevBest > 0 ? prevBest : max(1.0, est1RM * 0.05)
            prRatio = max(1.0, est1RM / effectivePrev)
        }
        let prevBestForEntry = prevBest > 0 ? prevBest : nil
        let est1RMForEntry = est1RM > 0 ? est1RM : nil

        // Relative XP vs personal baseline (first‑time banding handled inside)
        let perf = StatEngine.placementMetric(category: category,
                                              reps: validatedReps,
                                              weight: validatedWeight,
                                              durationMin: validatedDuration,
                                              distanceKm: validatedDistance,
                                              bodyweightKg: user.bodyweightKg)
        let prevBaseline = user.xpBaselines[category]
        // Apply weekly decay to baseline when there was a gap since the last session of this category
        var decayedBaseline = prevBaseline
        if let base = prevBaseline, let lastSame = history.first(where: { $0.category == category })?.date {
            let days = Date().timeIntervalSince(lastSame) / 86400.0
            if days > 0 {
                let rate = (category.focus == .endurance || category.focus == .mobility) ? 0.04 : 0.02
                let weeks = days / 7.0
                decayedBaseline = base * pow(1.0 - rate, weeks)
            }
        }
        let isFirstEver = history.isEmpty
        let isFirstTimeForThisExercise = !history.contains { $0.category == category }
        var gainedXP = StatEngine.relativeXP(category: category,
                                             perf: perf,
                                             baseline: decayedBaseline,
                                             isFirstEver: isFirstEver)
        // Streak bonus (MVP-light): small daily streaks, with decay rules
        func streakInfo(for focus: FocusGroup) -> (streak: Int, gapDays: Double) {
            let sameFocus = history.filter { $0.category.focus == focus }.sorted { $0.date > $1.date }
            guard let last = sameFocus.first else { return (0, .infinity) }
            let gap = Date().timeIntervalSince(last.date) / 86400.0
            // Count consecutive-day chain with a 36h window between logs
            var streak = 0
            var prevDate: Date? = nil
            for e in sameFocus {
                if prevDate == nil {
                    streak += 1; prevDate = e.date; continue
                }
                guard let prev = prevDate else { continue }
                let diff = prev.timeIntervalSince(e.date) / 3600.0
                if diff <= 36 { streak += 1; prevDate = e.date } else { break }
            }
            return (streak, gap)
        }
        let info = streakInfo(for: category.focus)
        if category.focus == .endurance {
            var s = info.streak
            if info.gapDays >= 2 { s = Int(Double(s) * 0.5) } // next bonus effectively halved
            let mult = 1.0 + min(0.20, 0.02 * Double(s))
            gainedXP *= mult
        } else if category.focus == .mobility {
            var s = info.streak
            if info.gapDays >= 1 { s = max(0, s - 1) } // miss a day → streak −1
            let mult = 1.0 + min(0.30, 0.03 * Double(s))
            gainedXP *= mult
        }
        addXP(gainedXP)

        // Update personal baseline with EMA using μ based on improvement/regression
        if perf > 0 {
            let base = decayedBaseline ?? perf
            let ratio = max(0.0001, perf / max(0.0001, base))
            let mu: Double = (ratio >= 1.10) ? 0.50 : (ratio < 0.95 ? 0.10 : 0.25)
            let newBase = base * (1.0 - mu) + perf * mu
            user.xpBaselines[category] = newBase
        }

        // Track if catch-up was applied

        // Placement candidate from this entry (supports all categories)
        let candidate = StatEngine.placementLevelCandidate(category: category,
                                                           reps: validatedReps, weight: validatedWeight,
                                                           durationMin: validatedDuration, distanceKm: validatedDistance,
                                                           bodyweightKg: user.bodyweightKg)
        // Update simple per-stat rank (1–10) based on the candidate placement per focus
        let tier = max(1, min(10, Int(round(Double(candidate) / 10.0))))
        func bump(_ old: inout Int, to new: Int, label: String) {
            if new > old { old = new }
        }
        switch category.focus {
        case .strength:   bump(&user.ranks.strength, to: tier, label: "STR")
        case .hypertrophy:bump(&user.ranks.size,     to: tier, label: "SIZ")
        case .bodyweight: bump(&user.ranks.dexterity,to: tier, label: "DEX")
        case .explosive:  bump(&user.ranks.agility,  to: tier, label: "AGI")
        case .endurance:  bump(&user.ranks.endurance,to: tier, label: "END")
        case .mobility:   bump(&user.ranks.vitality, to: tier, label: "VIT")
        }
        // (No level catch-up; we only use candidate for ranks/telemetry)

        // Maintain best metric log for transparency (repurposes best1RM storage)
        let perfMetric = StatEngine.placementMetric(category: category, reps: validatedReps, weight: validatedWeight, durationMin: validatedDuration, distanceKm: validatedDistance, bodyweightKg: user.bodyweightKg)
        if perfMetric > (user.best1RM[category] ?? 0) {
            user.best1RM[category] = perfMetric
        }

        let levelAfter = user.level
        let xpAfter = user.xp
        let totalDeltaXP = StatEngine.cumulativeXP(level: levelAfter, xpWithin: xpAfter) -
                           StatEngine.cumulativeXP(level: levelBefore, xpWithin: xpBefore)

        let prevBase = prevBaseline ?? 0
        let perfRatio = (prevBase > 0 && perf > 0) ? max(0.5, min(perf / prevBase, 2.0)) : 1.0
        // Combine PR from barbell estimate with relative improvement vs personal baseline
        let prBoost = max(0.0, max(log2(prRatio), log2(perfRatio)))

        let baseBudget = StatEngine.statBudget(forXPDelta: totalDeltaXP, level: levelAfter)
        let minBudget  = StatEngine.minimumSessionBudget(for: category, score: score)
        // Always award at least a small, visible gain each session
        let finalBudget = max(baseBudget, minBudget)
        let profile = StatEngine.statWeights(for: category)
        var distributedGains = StatEngine.distribute(budget: finalBudget, weights: profile, prBoost: prBoost)

        // First time logging this exercise? Use the fixed first-time grant **instead of** normal distribution.
        if isFirstTimeForThisExercise {
            distributedGains = StatEngine.firstTimeGrant(for: category)
        } else {
            // Apply the x10 display scale for all non-first logs
            distributedGains = distributedGains.scaled(10.0)
        }

        // Apply gains AFTER we know the true total XP progress for this entry
        user.stats.add(distributedGains)

        // Record entry (using validated inputs)
        let entry = WorkoutEntry(
            id: UUID(),
            date: Date(),
            name: name.isEmpty ? category.displayName : name,
            category: category,
            reps: validatedReps,
            weight: validatedWeight,
            durationMinutes: validatedDuration,
            distanceKm: validatedDistance,
            statGains: distributedGains,
            expGained: gainedXP,
            catchUpLevel: nil,
            prevLevel: levelBefore,
            newLevel: levelAfter,
            prevBest1RM: prevBestForEntry,
            est1RM: est1RMForEntry,
            totalProgressXP: totalDeltaXP
        )
        history.insert(entry, at: 0)

        // Update challenge progress based on the workout
        updateChallengeProgressFromWorkout(category: category, reps: validatedReps, weight: validatedWeight, durationMinutes: validatedDuration, distanceKm: validatedDistance)

        save()
        return entry
    }

    func addXP(_ delta: Double) {
        guard user.level < StatEngine.maxLevel else { return }
        user.xp += delta
        while user.level < StatEngine.maxLevel && user.xp >= user.nextLevelXP {
            user.xp -= user.nextLevelXP
            user.level += 1
            
            // Generate treasure chest for level up
            let newChest = StatEngine.generateTreasureChest(forLevel: user.level)
            user.treasureChests.append(newChest)
            
            if user.level >= StatEngine.maxLevel {
                user.level = StatEngine.maxLevel
                // Lock progress bar at full
                user.xp = 1
                user.nextLevelXP = 1
            } else {
                user.nextLevelXP = StatEngine.xpNeeded(forNextLevel: user.level)
            }
        }
    }
    
    // Delete workout from history
    func deleteWorkout(at offsets: IndexSet) {
        history.remove(atOffsets: offsets)
        recalculateStatsAndXP()
        save()
    }
    
    // Update existing workout
    func updateWorkout(_ workout: WorkoutEntry) {
        if let index = history.firstIndex(where: { $0.id == workout.id }) {
            history[index] = workout
            recalculateStatsAndXP()
            save()
        }
    }
    
    // Recalculate all stats and XP from history
    func recalculateStatsAndXP() {
        // Reset user stats and XP to initial state
        user.level = 1
        user.xp = 0
        user.nextLevelXP = StatEngine.xpNeeded(forNextLevel: 1)
        user.stats = .zero
        
        // Reset ranks
        user.ranks = StatRanks()
        
        // Recalculate from history (oldest to newest)
        let sortedHistory = history.sorted { $0.date < $1.date }
        
        for entry in sortedHistory {
            // Add XP
            addXP(entry.expGained)
            
            // Add stats
            user.stats.add(entry.statGains)
            
            // Update ranks based on exercise category
            let category = entry.category
            let candidate = StatEngine.placementLevelCandidate(
                category: category,
                reps: entry.reps,
                weight: entry.weight,
                durationMin: entry.durationMinutes,
                distanceKm: entry.distanceKm,
                bodyweightKg: user.bodyweightKg
            )
            let tier = max(1, min(10, Int(round(Double(candidate) / 10.0))))
            
            switch category.focus {
            case .strength:
                if tier > user.ranks.strength { user.ranks.strength = tier }
            case .hypertrophy:
                if tier > user.ranks.size { user.ranks.size = tier }
            case .bodyweight:
                if tier > user.ranks.dexterity { user.ranks.dexterity = tier }
            case .explosive:
                if tier > user.ranks.agility { user.ranks.agility = tier }
            case .endurance:
                if tier > user.ranks.endurance { user.ranks.endurance = tier }
            case .mobility:
                if tier > user.ranks.vitality { user.ranks.vitality = tier }
            }
        }
    }

    // Persistence
    private static var saveURL: URL? {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return url.appendingPathComponent("rpgfit_mvp_state.json")
    }
    
    private static var fallbackURL: URL? {
        guard let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return url.appendingPathComponent("rpgfit_mvp_fallback.json")
    }
    
    private static var backupURL: URL? {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return url.appendingPathComponent("rpgfit_mvp_backup.json")
    }

    @Published var persistenceError: String?
    
    // Cache management
    private func clearCache() {
        cachedSortedHistory = nil
        cachedGroupedWorkouts = nil
        cacheValidationTime = nil
    }
    
    private func isCacheValid() -> Bool {
        guard let validationTime = cacheValidationTime else { return false }
        return Date().timeIntervalSince(validationTime) < cacheExpirationInterval
    }
    
    // Cached sorted history (most recent first)
    func getSortedHistory() -> [WorkoutEntry] {
        if let cached = cachedSortedHistory, isCacheValid() {
            return cached
        }
        
        let sorted = history.sorted { $0.date > $1.date }
        cachedSortedHistory = sorted
        cacheValidationTime = Date()
        return sorted
    }
    
    // Cached grouped workouts by date
    func getGroupedWorkouts() -> [(String, [WorkoutEntry])] {
        if let cached = cachedGroupedWorkouts, isCacheValid() {
            return cached
        }
        
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: getSortedHistory()) { entry in
            calendar.dateInterval(of: .day, for: entry.date)?.start ?? entry.date
        }
        .sorted { $0.key > $1.key }
        .map { (key, value) in
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return (formatter.string(from: key), value.sorted { $0.date > $1.date })
        }
        
        cachedGroupedWorkouts = grouped
        return grouped
    }
    
    // MARK: - Challenge System
    
    func setRPGClass(_ classType: RPGClass) {
        user.rpgClass = classType
        generateDailyChallenges()
        generateWeeklyChallenges()
        save()
    }
    
    func changeRPGClassWithQuestReset(_ classType: RPGClass) {
        let newClassCategories = Set(classType.focusCategories)
        
        // Update class first
        user.rpgClass = classType
        
        // Handle daily challenges
        var newDailyChallenges: [Challenge] = []
        for challenge in user.dailyChallenges {
            if challenge.isCompleted {
                // Keep all completed challenges (preserve XP already earned)
                newDailyChallenges.append(challenge)
            } else if newClassCategories.contains(challenge.targetCategory) {
                // Keep active challenges that match new class categories (preserve progress)
                newDailyChallenges.append(challenge)
            }
            // Drop active challenges that don't match new class (lose progress as warned)
        }
        user.dailyChallenges = newDailyChallenges
        
        // Handle weekly challenges
        var newWeeklyChallenges: [Challenge] = []
        for challenge in user.weeklyChallenges {
            if challenge.isCompleted {
                // Keep all completed challenges (preserve XP already earned)
                newWeeklyChallenges.append(challenge)
            } else if newClassCategories.contains(challenge.targetCategory) {
                // Keep active challenges that match new class categories (preserve progress)
                newWeeklyChallenges.append(challenge)
            }
            // Drop active challenges that don't match new class (lose progress as warned)
        }
        user.weeklyChallenges = newWeeklyChallenges
        
        // Generate new challenges for missing categories
        generateMissingChallenges(for: classType)
        save()
    }
    
    private func generateMissingChallenges(for classType: RPGClass) {
        let requiredCategories = Set(classType.focusCategories)
        
        // Check which categories are missing from active daily challenges
        let existingDailyCategories = Set(user.dailyChallenges.filter { $0.isActive }.map { $0.targetCategory })
        let missingDailyCategories = requiredCategories.subtracting(existingDailyCategories)
        
        // Generate daily challenges for missing categories: 2 per missing category (amount + variety)
        for category in missingDailyCategories {
            // Amount challenge
            let amountChallenge = createDailyAmountChallenge(for: category, classType: classType)
            user.dailyChallenges.append(amountChallenge)
            
            // Variety challenge
            let varietyChallenge = createDailyVarietyChallenge(for: category, classType: classType)
            user.dailyChallenges.append(varietyChallenge)
        }
        
        // Check which categories are missing from active weekly challenges
        let existingWeeklyCategories = Set(user.weeklyChallenges.filter { $0.isActive }.map { $0.targetCategory })
        let missingWeeklyCategories = requiredCategories.subtracting(existingWeeklyCategories)
        
        // Generate weekly challenges for missing categories: 1 per missing category
        for category in missingWeeklyCategories {
            let challenge = createWeeklyChallenge(for: category, classType: classType)
            user.weeklyChallenges.append(challenge)
        }
        
        // Update generation timestamps to prevent normal generation from running
        user.lastDailyChallengeGeneration = Date()
        user.lastWeeklyChallengeGeneration = Date()
    }
    
    func updateExistingChallengeXP() {
        // Update existing daily challenges to consistent 25 XP
        for i in 0..<user.dailyChallenges.count {
            if user.dailyChallenges[i].isActive {
                user.dailyChallenges[i] = Challenge(
                    id: user.dailyChallenges[i].id,
                    type: user.dailyChallenges[i].type,
                    title: user.dailyChallenges[i].title,
                    description: user.dailyChallenges[i].description,
                    targetCategory: user.dailyChallenges[i].targetCategory,
                    targetAmount: user.dailyChallenges[i].targetAmount,
                    unit: user.dailyChallenges[i].unit,
                    expReward: 25, // Updated to consistent XP
                    classType: user.dailyChallenges[i].classType,
                    createdAt: user.dailyChallenges[i].createdAt,
                    expiresAt: user.dailyChallenges[i].expiresAt,
                    completedAt: user.dailyChallenges[i].completedAt,
                    progress: user.dailyChallenges[i].progress,
                    uniqueExercises: user.dailyChallenges[i].uniqueExercises
                )
            }
        }
        
        // Update existing weekly challenges to consistent 100 XP
        for i in 0..<user.weeklyChallenges.count {
            if user.weeklyChallenges[i].isActive {
                user.weeklyChallenges[i] = Challenge(
                    id: user.weeklyChallenges[i].id,
                    type: user.weeklyChallenges[i].type,
                    title: user.weeklyChallenges[i].title,
                    description: user.weeklyChallenges[i].description,
                    targetCategory: user.weeklyChallenges[i].targetCategory,
                    targetAmount: user.weeklyChallenges[i].targetAmount,
                    unit: user.weeklyChallenges[i].unit,
                    expReward: 100, // Updated to consistent XP
                    classType: user.weeklyChallenges[i].classType,
                    createdAt: user.weeklyChallenges[i].createdAt,
                    expiresAt: user.weeklyChallenges[i].expiresAt,
                    completedAt: user.weeklyChallenges[i].completedAt,
                    progress: user.weeklyChallenges[i].progress,
                    uniqueExercises: user.weeklyChallenges[i].uniqueExercises
                )
            }
        }
        
        save()
    }

    func generateDailyChallenges() {
        guard let rpgClass = user.rpgClass else { return }
        
        // Check if we need to generate new dailies (once per day)
        if let lastGeneration = user.lastDailyChallengeGeneration,
           Calendar.current.isDateInToday(lastGeneration),
           !user.dailyChallenges.filter({ $0.isActive }).isEmpty {
            return // Already generated today
        }
        
        // Clear old challenges
        user.dailyChallenges.removeAll { $0.isExpired }
        
        // Generate exactly 4 daily challenges: 2 per category (amount + variety)
        let categories = rpgClass.focusCategories.shuffled()
        
        // Create 2 challenges per category (amount + variety)
        for category in categories {
            // Amount challenge (reps/sets/minutes/etc.)
            let amountChallenge = createDailyAmountChallenge(for: category, classType: rpgClass)
            user.dailyChallenges.append(amountChallenge)
            
            // Variety challenge (number of different exercises)
            let varietyChallenge = createDailyVarietyChallenge(for: category, classType: rpgClass)
            user.dailyChallenges.append(varietyChallenge)
        }
        
        user.lastDailyChallengeGeneration = Date()
        save()
    }
    
    func generateWeeklyChallenges() {
        guard let rpgClass = user.rpgClass else { return }
        
        // Check if we need to generate new weeklies (once per week)
        if let lastGeneration = user.lastWeeklyChallengeGeneration {
            let weeksSince = Calendar.current.dateComponents([.weekOfYear], from: lastGeneration, to: Date()).weekOfYear ?? 0
            if weeksSince < 1 && !user.weeklyChallenges.filter({ $0.isActive }).isEmpty {
                return // Already generated this week
            }
        }
        
        // Clear old challenges
        user.weeklyChallenges.removeAll { $0.isExpired }
        
        // Generate 2 weekly challenges based on focus categories
        let categories = rpgClass.focusCategories.shuffled()
        let numChallenges = min(2, categories.count)
        
        for i in 0..<numChallenges {
            let category = categories[i]
            let challenge = createWeeklyChallenge(for: category, classType: rpgClass)
            user.weeklyChallenges.append(challenge)
        }
        
        user.lastWeeklyChallengeGeneration = Date()
        save()
    }
    
    private func createDailyAmountChallenge(for category: FocusGroup, classType: RPGClass) -> Challenge {
        let (title, amount, unit) = getDailyAmountChallengeDetails(for: category, classType: classType)
        let expReward = 25 // Consistent daily XP
        
        return Challenge(
            id: UUID(),
            type: .daily,
            title: title,
            description: "Complete this quest before the day ends!",
            targetCategory: category,
            targetAmount: amount,
            unit: unit,
            expReward: expReward,
            classType: classType,
            createdAt: Date(),
            expiresAt: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
        )
    }
    
    private func createDailyVarietyChallenge(for category: FocusGroup, classType: RPGClass) -> Challenge {
        let (title, amount, unit) = getDailyVarietyChallengeDetails(for: category, classType: classType)
        let expReward = 25 // Consistent daily XP
        
        return Challenge(
            id: UUID(),
            type: .daily,
            title: title,
            description: "Complete this quest before the day ends!",
            targetCategory: category,
            targetAmount: amount,
            unit: unit,
            expReward: expReward,
            classType: classType,
            createdAt: Date(),
            expiresAt: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
        )
    }
    
    private func createWeeklyChallenge(for category: FocusGroup, classType: RPGClass) -> Challenge {
        let (title, amount, unit) = getWeeklyChallengeDetails(for: category, classType: classType)
        let expReward = 100 // Consistent weekly XP
        
        return Challenge(
            id: UUID(),
            type: .weekly,
            title: title,
            description: "Complete this epic quest before the week ends!",
            targetCategory: category,
            targetAmount: amount,
            unit: unit,
            expReward: expReward,
            classType: classType,
            createdAt: Date(),
            expiresAt: Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Calendar.current.startOfDay(for: Date()))!
        )
    }
    
    // MARK: - Challenge Preference Helpers
    
    func getAvailablePreferences(for category: FocusGroup) -> [ChallengePreference] {
        switch category {
        case .endurance:
            return [.time, .distance]
        case .mobility:
            return [.frequency, .sets]
        case .explosive:
            return [.sets, .times]
        case .strength, .hypertrophy, .bodyweight:
            return [.sets, .reps]
        }
    }
    
    func getPreference(for category: FocusGroup) -> ChallengePreference {
        return user.challengePreferences[category] ?? getDefaultPreference(for: category)
    }
    
    func setPreference(_ preference: ChallengePreference, for category: FocusGroup) {
        user.challengePreferences[category] = preference
        save()
    }
    
    private func getDefaultPreference(for category: FocusGroup) -> ChallengePreference {
        switch category {
        case .endurance: return .time
        case .mobility: return .sets
        case .explosive: return .sets
        case .strength, .hypertrophy, .bodyweight: return .sets
        }
    }
    
    func getStatName(for category: FocusGroup) -> String {
        switch category {
        case .strength: return "Strength"
        case .hypertrophy: return "Hypertrophy"
        case .endurance: return "Endurance"
        case .explosive: return "Explosive"
        case .mobility: return "Mobility"
        case .bodyweight: return "Bodyweight"
        }
    }
    
    private func getAmountChallenge(statName: String, preference: ChallengePreference, baseAmount: Int) -> (String, Int, ChallengeUnit) {
        let title = "\(statName) \(preference.displayName)"
        return (title, baseAmount, preference.unit)
    }
    
    private func getWeeklyChallenge(statName: String, preference: ChallengePreference, baseAmount: Int) -> (String, Int, ChallengeUnit) {
        let title = "\(statName) Mastery"
        return (title, baseAmount, preference.unit)
    }
    
    private func getDailyAmountChallengeDetails(for category: FocusGroup, classType: RPGClass) -> (String, Int, ChallengeUnit) {
        let preference = getPreference(for: category)
        let statName = getStatName(for: category)
        
        switch category {
        case .strength:
            return getAmountChallenge(statName: statName, preference: preference, baseAmount: 8)
        case .hypertrophy:
            return getAmountChallenge(statName: statName, preference: preference, baseAmount: 12)
        case .endurance:
            return getAmountChallenge(statName: statName, preference: preference, baseAmount: preference == .time ? 20 : 5)
        case .explosive:
            return getAmountChallenge(statName: statName, preference: preference, baseAmount: 6)
        case .mobility:
            return getAmountChallenge(statName: statName, preference: preference, baseAmount: preference == .frequency ? 3 : 5)
        case .bodyweight:
            return getAmountChallenge(statName: statName, preference: preference, baseAmount: 8)
        }
    }
    
    private func getDailyVarietyChallengeDetails(for category: FocusGroup, classType: RPGClass) -> (String, Int, ChallengeUnit) {
        switch category {
        case .strength:
            return ("Strength Variety", 4, .exercises)
        case .hypertrophy:
            return ("Hypertrophy Mix", 4, .exercises)
        case .endurance:
            return ("Endurance Variety", 2, .exercises)
        case .explosive:
            return ("Explosive Variety", 3, .exercises)
        case .mobility:
            return ("Mobility Flow", 3, .exercises)
        case .bodyweight:
            return ("Bodyweight Mix", 4, .exercises)
        }
    }
    
    private func getWeeklyChallengeDetails(for category: FocusGroup, classType: RPGClass) -> (String, Int, ChallengeUnit) {
        let preference = getPreference(for: category)
        let statName = getStatName(for: category)
        
        switch category {
        case .strength:
            let amount = preference == .sets ? 25 : (preference == .reps ? 120 : 20)
            return getWeeklyChallenge(statName: statName, preference: preference, baseAmount: amount)
        case .hypertrophy:
            let amount = preference == .sets ? 40 : (preference == .reps ? 200 : 18)
            return getWeeklyChallenge(statName: statName, preference: preference, baseAmount: amount)
        case .endurance:
            let amount = preference == .time ? 90 : (preference == .distance ? 20 : 8)
            return getWeeklyChallenge(statName: statName, preference: preference, baseAmount: amount)
        case .explosive:
            let amount = preference == .sets ? 20 : (preference == .times ? 25 : 12)
            return getWeeklyChallenge(statName: statName, preference: preference, baseAmount: amount)
        case .mobility:
            let amount = preference == .frequency ? 10 : (preference == .sets ? 25 : 10)
            return getWeeklyChallenge(statName: statName, preference: preference, baseAmount: amount)
        case .bodyweight:
            let amount = preference == .sets ? 30 : (preference == .reps ? 150 : 15)
            return getWeeklyChallenge(statName: statName, preference: preference, baseAmount: amount)
        }
    }
    
    private func focusGroupForExercise(_ exercise: ExerciseCategory) -> FocusGroup {
        switch exercise {
        // Strength exercises (compound lifts)
        case .squat, .frontSquat, .deadlift, .romanianDeadlift, .benchPress, .overheadPress, .row, .hipThrust, .powerClean:
            return .strength
            
        // Hypertrophy exercises (isolation and accessories)
        case .bulgarianSplitSquat, .legPress, .latPulldown, .cableRow, .chestFly,
             .lateralRaise, .curl, .tricepsExtension, .legExtension, .legCurl, .calfRaiseStanding:
            return .hypertrophy
            
        // Bodyweight exercises
        case .pullUp, .dip, .pushUp, .plank, .hangingLegRaise, .abWheel, .handstand, .pistolSquat:
            return .bodyweight
            
        // Endurance exercises
        case .run, .cycle, .rower, .swimming, .hikingStairs:
            return .endurance
            
        // Explosive exercises
        case .sprint, .boxJump, .jumpRope, .battleRopes, .kettlebellSwing, .medBallSlam, .sledPush:
            return .explosive
            
        // Mobility exercises
        case .yoga, .hip90_90, .couchStretch, .cars, .thoracicRotation, .externalRotation,
             .monsterWalks, .nordicHamstring, .copenhagenPlank, .tibialisRaise, .mcgillBig3, .hipAirplanes:
            return .mobility
        }
    }
    
    private func updateChallengeProgressFromWorkout(category: ExerciseCategory, reps: Int?, weight: Double?, durationMinutes: Double?, distanceKm: Double?) {
        let focusGroup = focusGroupForExercise(category)
        
        // Convert workout data to challenge progress based on type
        if let reps = reps, reps > 0 {
            updateChallengeProgress(for: focusGroup, amount: reps, unit: .reps)
            // Also count as 1 set completed
            updateChallengeProgress(for: focusGroup, amount: 1, unit: .sets)
        }
        
        if let duration = durationMinutes, duration > 0 {
            updateChallengeProgress(for: focusGroup, amount: Int(ceil(duration)), unit: .minutes)
        }
        
        if let distance = distanceKm, distance > 0 {
            updateChallengeProgress(for: focusGroup, amount: Int(ceil(distance)), unit: .kilometers)
        }
        
        // Count sprint intervals or similar "times" based challenges
        if category == .sprint || category == .boxJump {
            updateChallengeProgress(for: focusGroup, amount: 1, unit: .times)
        }
        
        // Count explosive exercises as "times" for agility challenges
        if focusGroup == .explosive {
            updateChallengeProgress(for: focusGroup, amount: 1, unit: .times)
        }
        
        // Count mobility/recovery exercises as frequency (sessions)
        if focusGroup == .mobility {
            updateChallengeProgress(for: focusGroup, amount: 1, unit: .times) // frequency uses .times unit
        }
        
        // Count this exercise toward variety challenges (unique exercises in this focus group)
        updateExerciseVarietyProgress(for: focusGroup, exercise: category)
    }
    
    func updateChallengeProgress(for category: FocusGroup, amount: Int, unit: ChallengeUnit) {
        // Update daily challenges
        for i in 0..<user.dailyChallenges.count {
            if user.dailyChallenges[i].isActive &&
               user.dailyChallenges[i].targetCategory == category &&
               user.dailyChallenges[i].unit == unit {
                user.dailyChallenges[i].progress += amount
                
                // Check if completed
                if user.dailyChallenges[i].progress >= user.dailyChallenges[i].targetAmount &&
                   user.dailyChallenges[i].completedAt == nil {
                    user.dailyChallenges[i].completedAt = Date()
                    addXP(Double(user.dailyChallenges[i].expReward))
                }
            }
        }
        
        // Update weekly challenges
        for i in 0..<user.weeklyChallenges.count {
            if user.weeklyChallenges[i].isActive &&
               user.weeklyChallenges[i].targetCategory == category &&
               user.weeklyChallenges[i].unit == unit {
                user.weeklyChallenges[i].progress += amount
                
                // Check if completed
                if user.weeklyChallenges[i].progress >= user.weeklyChallenges[i].targetAmount &&
                   user.weeklyChallenges[i].completedAt == nil {
                    user.weeklyChallenges[i].completedAt = Date()
                    addXP(Double(user.weeklyChallenges[i].expReward))
                }
            }
        }
        
        save()
    }
    
    private func updateExerciseVarietyProgress(for category: FocusGroup, exercise: ExerciseCategory) {
        let exerciseName = exercise.rawValue
        
        // Update daily challenges
        for i in 0..<user.dailyChallenges.count {
            if user.dailyChallenges[i].isActive &&
               user.dailyChallenges[i].targetCategory == category &&
               user.dailyChallenges[i].unit == .exercises {
                
                // Add the exercise to the unique set
                let beforeCount = user.dailyChallenges[i].uniqueExercises.count
                user.dailyChallenges[i].uniqueExercises.insert(exerciseName)
                let afterCount = user.dailyChallenges[i].uniqueExercises.count
                
                // Update progress if we added a new unique exercise
                if afterCount > beforeCount {
                    user.dailyChallenges[i].progress = afterCount
                    
                    // Check if completed
                    if user.dailyChallenges[i].uniqueExercises.count >= user.dailyChallenges[i].targetAmount &&
                       user.dailyChallenges[i].completedAt == nil {
                        user.dailyChallenges[i].completedAt = Date()
                        addXP(Double(user.dailyChallenges[i].expReward))
                    }
                }
            }
        }
        
        // Update weekly challenges
        for i in 0..<user.weeklyChallenges.count {
            if user.weeklyChallenges[i].isActive &&
               user.weeklyChallenges[i].targetCategory == category &&
               user.weeklyChallenges[i].unit == .exercises {
                
                // Add the exercise to the unique set
                let beforeCount = user.weeklyChallenges[i].uniqueExercises.count
                user.weeklyChallenges[i].uniqueExercises.insert(exerciseName)
                let afterCount = user.weeklyChallenges[i].uniqueExercises.count
                
                // Update progress if we added a new unique exercise
                if afterCount > beforeCount {
                    user.weeklyChallenges[i].progress = afterCount
                    
                    // Check if completed
                    if user.weeklyChallenges[i].uniqueExercises.count >= user.weeklyChallenges[i].targetAmount &&
                       user.weeklyChallenges[i].completedAt == nil {
                        user.weeklyChallenges[i].completedAt = Date()
                        addXP(Double(user.weeklyChallenges[i].expReward))
                    }
                }
            }
        }
    }
    
    func save() {
        let data = PersistedData(user: user, history: history)
        DispatchQueue.global(qos: .utility).async {
            do {
                let encoded = try JSONEncoder().encode(data)
                
                if let primaryURL = Self.saveURL {
                    // Create backup before saving new data
                    self.createBackup()
                    
                    try encoded.write(to: primaryURL, options: [.atomic])
                    DispatchQueue.main.async {
                        self.persistenceError = nil
                    }
                } else if let fallbackURL = Self.fallbackURL {
                    try encoded.write(to: fallbackURL, options: [.atomic])
                    DispatchQueue.main.async {
                        self.persistenceError = "Using temporary storage - data may not persist"
                    }
                } else {
                    DispatchQueue.main.async {
                        self.persistenceError = "Unable to save data - storage unavailable"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.persistenceError = "Failed to save: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func createBackup() {
        guard let primaryURL = Self.saveURL,
              let backupURL = Self.backupURL,
              FileManager.default.fileExists(atPath: primaryURL.path) else { return }
        
        do {
            if FileManager.default.fileExists(atPath: backupURL.path) {
                try FileManager.default.removeItem(at: backupURL)
            }
            try FileManager.default.copyItem(at: primaryURL, to: backupURL)
        } catch {
            #if DEBUG
            print("Failed to create backup: \(error)")
            #endif
        }
    }
    
    private static func validateData(_ data: Data) -> Bool {
        do {
            let decoded = try JSONDecoder().decode(PersistedData.self, from: data)
            // Basic validation: ensure we have valid user data
            return decoded.user.bodyweightKg ?? 0 > 0 && decoded.history.count >= 0
        } catch {
            return false
        }
    }

    private static func load() -> PersistedData? {
        // Try primary storage with validation
        if let primaryURL = saveURL {
            do {
                let data = try Data(contentsOf: primaryURL)
                if validateData(data) {
                    return try JSONDecoder().decode(PersistedData.self, from: data)
                } else {
                    #if DEBUG
                    print("Primary storage data validation failed, trying backup")
                    #endif
                }
            } catch {
                #if DEBUG
                print("Failed to load from primary storage: \(error)")
                #endif
            }
        }
        
        // Try backup if primary failed
        if let backupURL = backupURL {
            do {
                let data = try Data(contentsOf: backupURL)
                if validateData(data) {
                    #if DEBUG
                    print("Successfully loaded from backup")
                    #endif
                    return try JSONDecoder().decode(PersistedData.self, from: data)
                }
            } catch {
                #if DEBUG
                print("Failed to load from backup storage: \(error)")
                #endif
            }
        }
        
        // Try fallback (cache) storage
        if let fallbackURL = fallbackURL {
            do {
                let data = try Data(contentsOf: fallbackURL)
                if validateData(data) {
                    return try JSONDecoder().decode(PersistedData.self, from: data)
                }
            } catch {
                #if DEBUG
                print("Failed to load from fallback storage: \(error)")
                #endif
            }
        }
        
        return nil
    }
}

// MARK: - UI
struct ContentView: View {
    @StateObject private var state = AppState()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @State private var keyboardPrewarmField = ""
    @FocusState private var isKeyboardPrewarmFocused: Bool

    var body: some View {
        ZStack {
            // Hidden TextField for keyboard prewarming
            TextField("", text: $keyboardPrewarmField)
                .focused($isKeyboardPrewarmFocused)
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
            
            TabView {
                DashboardView()
                    .tabItem { Label("Skills", systemImage: "chart.bar.fill") }
                    .environmentObject(state)

                LogWorkoutView()
                    .tabItem { Label("Train", systemImage: "plus.circle.fill") }
                    .environmentObject(state)

                QuestsView()
                    .tabItem { Label("Quests", systemImage: "scroll.fill") }
                    .environmentObject(state)
                    .badge(state.user.dailyChallenges.filter { $0.isActive && !$0.isCompleted }.count + state.user.weeklyChallenges.filter { $0.isActive && !$0.isCompleted }.count)

                HistoryView()
                    .tabItem { Label("Skillbook", systemImage: "book.fill") }
                    .environmentObject(state)
                
                InventoryView()
                    .tabItem {
                        Label("Inventory", systemImage: "list.dash")
                    }
                    .environmentObject(state)
                    .badge(state.user.treasureChests.filter { !$0.isOpened }.count)
            }
            
            // Error banner
            if let error = state.persistenceError {
                VStack {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Button("Dismiss") {
                            state.persistenceError = nil
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: state.persistenceError)
            }
        }
        .fullScreenCover(
            isPresented: Binding(get: { !hasSeenOnboarding || (state.user.bodyweightKg ?? 0) <= 0 }, set: { _ in }),
            onDismiss: {}
        ) {
            OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
                .environmentObject(state)
        }
        .onAppear {
            // Prewarm keyboard to reduce first-show lag
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isKeyboardPrewarmFocused = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isKeyboardPrewarmFocused = false
                }
            }
        }
    }
}


struct DashboardView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var animateProgress = false
    @State private var animateBars = false
    @State private var showSparkle = false
    @State private var displayLevel: Int = 0
    @State private var displayXP: Double = 0
    @State private var displayNextLevelXP: Double = 100
    @State private var displayPrestigeLevel: Int = 0
    @State private var isAnimatingLevelUp = false
    @AppStorage("lastViewedLevel") private var lastViewedLevel: Int = 1
    @State private var xpAnimationTimer: Timer?
    
    // Animate XP count up
    private func animateXPCount(from startValue: Double, to endValue: Double, duration: Double) {
        let steps = 30 // Number of steps in the animation
        let stepDuration = duration / Double(steps)
        
        displayXP = startValue
        var currentStep = 0
        
        xpAnimationTimer?.invalidate()
        xpAnimationTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
            currentStep += 1
            if currentStep >= steps {
                // Cap at the actual intended value (remove any overshoot for final value)
                displayXP = min(endValue, displayNextLevelXP)
                timer.invalidate()
                xpAnimationTimer = nil
            } else {
                // Ease out calculation for smoother counting
                let progress = Double(currentStep) / Double(steps)
                let easedProgress = 1 - pow(1 - progress, 3) // Cubic ease out
                displayXP = startValue + (endValue - startValue) * easedProgress
            }
        }
    }
    
    // Animate through multiple level ups sequentially
    private func animateMultipleLevelUps(from startLevel: Int, to endLevel: Int, hasPrestiged: Bool) {
        let levelsToAnimate = endLevel - startLevel
        
        func animateSingleLevelUp(currentAnimLevel: Int, levelsRemaining: Int) {
            // Check if animation was cancelled
            guard isAnimatingLevelUp else { return }
            
            // Calculate display level (1-10) accounting for prestige
            let calculatedDisplayLevel = currentAnimLevel <= 10 ? currentAnimLevel : ((currentAnimLevel - 1) % 10) + 1
            let calculatedPrestigeLevel = currentAnimLevel > 10 ? (currentAnimLevel - 1) / 10 : 0
            
            // Set current display level and prestige
            displayLevel = calculatedDisplayLevel
            displayPrestigeLevel = calculatedPrestigeLevel
            displayXP = 0
            displayNextLevelXP = StatEngine.xpNeeded(forNextLevel: currentAnimLevel)
            
            // Animate XP bar from 0 to 100%
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                guard isAnimatingLevelUp else { return }
                
                withAnimation(.easeOut(duration: 1.0)) {
                    animateProgress = true
                    animateBars = true
                }
                animateXPCount(from: 0, to: displayNextLevelXP, duration: 1.0)
            }
            
            // After animation completes, move to next level or finish
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                guard isAnimatingLevelUp else { return }
                
                if levelsRemaining > 1 {
                    // More levels to animate
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.success)
                    
                    // Continue to next level
                    animateSingleLevelUp(currentAnimLevel: currentAnimLevel + 1, levelsRemaining: levelsRemaining - 1)
                } else {
                    // Final level reached, show current XP
                    displayLevel = state.user.displayLevel
                    displayPrestigeLevel = state.user.prestigeLevel
                    
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.success)
                    displayXP = 0
                    displayNextLevelXP = state.user.nextLevelXP
                    
                    let targetXP = hasPrestiged ? 0 : state.user.xp
                    animateXPCount(from: 0, to: targetXP, duration: 0.8)
                    
                    // Show sparkle when complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        guard isAnimatingLevelUp else { return }
                        isAnimatingLevelUp = false
                        showSparkle = true
                    }
                }
            }
        }
        
        // Start the animation sequence
        animateSingleLevelUp(currentAnimLevel: startLevel, levelsRemaining: levelsToAnimate)
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 20) {
                    // Hero Level Card
                    VStack(spacing: 16) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 4) {
                                    Text("Level \(displayLevel)")
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                    if (isAnimatingLevelUp ? displayPrestigeLevel : state.user.prestigeLevel) > 0 {
                                        // Prestige stars instead of + signs
                                        HStack(spacing: 2) {
                                            ForEach(0..<min(isAnimatingLevelUp ? displayPrestigeLevel : state.user.prestigeLevel, 5), id: \.self) { _ in
                                                Image(systemName: "star.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.yellow)
                                                    .shadow(color: .yellow.opacity(0.5), radius: 2)
                                            }
                                        }
                                    }
                                }
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "sparkles")
                                        .font(.caption)
                                        .foregroundColor(.green.opacity(0.8))
                                        .shadow(color: .green.opacity(0.3), radius: 2)
                                    Text("Experience Points")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 8) {
                                // Prestige section with star icon
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Prestige")
                                        .font(.caption2)
                                        .foregroundColor(.secondary.opacity(0.8))
                                    
                                    PrestigeBadge(prestigeLevel: isAnimatingLevelUp ? displayPrestigeLevel : state.user.prestigeLevel)
                                }
                                
                            }
                        }
                        
                        // Modern XP Progress Bar
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("XP: \(Int(displayXP)) / \(Int(displayNextLevelXP))")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.secondary)
                                    .animation(nil, value: displayXP) // Disable default animation
                                    .transition(.identity)
                                Spacer()
                                Text("\(Int((displayXP / displayNextLevelXP) * 100))%")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.green)
                                    .animation(nil, value: displayXP) // Disable default animation
                                    .transition(.identity)
                            }
                            
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.green.opacity(0.1))
                                    .frame(height: 12)
                                
                                // Gradient progress bar with glow
                                GeometryReader { geo in
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            LinearGradient(
                                                colors: [.green.opacity(0.9), .green, .mint],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: animateProgress ? (displayXP >= displayNextLevelXP ? geo.size.width : max(12, CGFloat(displayXP / displayNextLevelXP) * geo.size.width)) : 0, height: 12)
                                        .shadow(color: .green.opacity(0.5), radius: 4)
                                    
                                    // Sparkle effect at the end of the bar
                                    if displayXP > 0 {
                                        Image(systemName: "sparkle")
                                            .font(.caption2)
                                            .foregroundColor(.white)
                                            .offset(x: displayXP >= displayNextLevelXP ? geo.size.width - 15 : max(0, CGFloat(displayXP / displayNextLevelXP) * geo.size.width - 15))
                                            .opacity(showSparkle && !isAnimatingLevelUp ? 1 : 0)
                                            .animation(.easeIn(duration: 0.2), value: showSparkle)
                                    }
                                }
                                .frame(height: 12)
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: UIScreen.main.bounds.width - 32)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)

                    // Radar Chart Card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Attribute Overview")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 18) {
                            // Radar Chart (slightly larger)
                            RadarChartView(stats: state.user.stats)
                                .frame(width: 155, height: 145)
                            
                            // Horizontal Bar Chart (slightly larger)
                            AttributeBarChart(stats: state.user.stats)
                                .frame(width: 150, height: 145)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: UIScreen.main.bounds.width - 32)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)

                    // Modern Stats Grid
                    ModernStatGrid(stats: state.user.stats, userProfile: state.user, animateBars: animateBars)

                    // Motivational Card with quest theme
                    if state.history.isEmpty {
                        HStack(spacing: 12) {
                            ZStack {
                                Image(systemName: "scroll.fill")
                                    .font(.title)
                                    .foregroundColor(.yellow.opacity(0.8))
                                Image(systemName: "exclamationmark")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "flag.checkered")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                    Text("Ready to Start Your Journey?")
                                        .font(.subheadline.weight(.semibold))
                                }
                                Text("Log your first exercise to gain XP and level up!")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .frame(maxWidth: UIScreen.main.bounds.width - 32)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.yellow.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Skills")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 3) {
                        Image(systemName: "circle.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)
                            .shadow(color: .yellow.opacity(0.3), radius: 2)
                        Text("\(state.user.coins)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("Coins")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .onAppear {
                // Reset sparkle immediately
                showSparkle = false
                
                // Check if user has leveled up since last view
                let currentLevel = state.user.level
                let hasLeveledUp = currentLevel > lastViewedLevel && lastViewedLevel > 0
                let currentPrestigeLevel = state.user.prestigeLevel
                let lastPrestigeLevel = lastViewedLevel > 10 ? (lastViewedLevel - 1) / 10 : 0
                let hasPrestiged = currentPrestigeLevel > lastPrestigeLevel
                
                if hasLeveledUp {
                    // User has leveled up! Show special animation sequence
                    isAnimatingLevelUp = true
                    
                    // Animate through each level sequentially
                    animateMultipleLevelUps(from: lastViewedLevel, to: currentLevel, hasPrestiged: hasPrestiged)
                } else {
                    // Normal animation (no level up)
                    displayLevel = state.user.displayLevel
                    displayPrestigeLevel = state.user.prestigeLevel
                    displayXP = 0
                    displayNextLevelXP = state.user.nextLevelXP
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeOut(duration: 1.0)) {
                            animateProgress = true
                            animateBars = true
                        }
                        // Count up the XP numbers
                        animateXPCount(from: 0, to: state.user.xp, duration: 1.0)
                    }
                    
                    // Sparkle fades in after 0.9 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                        showSparkle = true
                    }
                }
                
                // Update last viewed level for next time
                lastViewedLevel = currentLevel
            }
            .onDisappear {
                cleanupTimers()
                
                // If we're in the middle of a level up animation, cancel it and jump to final state
                if isAnimatingLevelUp {
                    // Stop level up animation (this cancels all pending DispatchQueue calls)
                    isAnimatingLevelUp = false
                    
                    // Update last viewed level to current level to prevent re-animation
                    lastViewedLevel = state.user.level
                    
                    // Jump to final state immediately
                    displayLevel = state.user.displayLevel
                    displayPrestigeLevel = state.user.prestigeLevel
                    displayXP = state.user.xp
                    displayNextLevelXP = state.user.nextLevelXP
                }
                
                // Reset animations when leaving the view
                animateProgress = false
                animateBars = false
                showSparkle = false
            }
        }
    }
    
    private func cleanupTimers() {
        xpAnimationTimer?.invalidate()
        xpAnimationTimer = nil
    }
}

struct ModernStatGrid: View {
    let stats: StatBlock
    let userProfile: UserProfile
    var animateBars: Bool = false
    @Environment(\.colorScheme) var colorScheme

    private func statColor(for name: String) -> Color {
        switch name {
        case "Size": return colorScheme == .dark ? .white : .black
        case "Strength": return .red
        case "Dexterity": return .orange
        case "Agility": return .yellow
        case "Endurance": return .blue
        case "Vitality": return Color.green
        default: return .primary
        }
    }
    
    private func statIcon(for name: String) -> String {
        switch name {
        case "Size": return "arrow.up.left.and.down.right.magnifyingglass"
        case "Strength": return "dumbbell.fill"
        case "Dexterity": return "hand.palm.facing.fill"
        case "Agility": return "hare.fill"
        case "Endurance": return "infinity"
        case "Vitality": return "heart.fill"
        default: return "circle.fill"
        }
    }
    
    private func getRankTier(for name: String) -> RankTier {
        switch name {
        case "Size": return userProfile.sizeRank
        case "Strength": return userProfile.strengthRank
        case "Dexterity": return userProfile.dexterityRank
        case "Agility": return userProfile.agilityRank
        case "Endurance": return userProfile.enduranceRank
        case "Vitality": return userProfile.vitalityRank
        default: return .bronze
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Attributes")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                NavigationLink(destination: RanksExplanationView()) {
                    HStack(spacing: 4) {
                        Text("Ranks")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.blue)
                        
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                let rows = [
                    ("Size", stats.size),
                    ("Strength", stats.strength),
                    ("Dexterity", stats.dexterity),
                    ("Agility", stats.agility),
                    ("Endurance", stats.endurance),
                    ("Vitality", stats.vitality)
                ]
                
                ForEach(rows, id: \.0) { (name, value) in
                    ZStack {
                        VStack(spacing: 12) {
                            // Header with icon and name
                            HStack(spacing: 8) {
                                Image(systemName: statIcon(for: name))
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(statColor(for: name))
                                    .frame(width: 24, height: 24)
                                
                                Text(name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            
                            // Value display
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(String(format: "%.1f", value))
                                        .font(.title2.weight(.bold))
                                        .foregroundColor(statColor(for: name))
                                    Spacer()
                                }
                                
                                // Progress bar showing relative strength
                                let maxValue = max(stats.size, stats.strength, stats.dexterity, stats.agility, stats.endurance, stats.vitality)
                                let progress = maxValue > 0 ? value / maxValue : 0
                                
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(statColor(for: name).opacity(0.1))
                                            .frame(height: 4)
                                        
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(statColor(for: name))
                                            .frame(width: animateBars ? max(4, min(geo.size.width, progress * geo.size.width)) : 0, height: 4)
                                    }
                                }
                                .frame(height: 4)
                            }
                        }
                        
                        // Rank badge positioned in the middle-right
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                AttributeRankBadge(tier: getRankTier(for: name))
                                    .scaleEffect(0.9) // Slightly smaller so it doesn't dominate
                            }
                            Spacer()
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(statColor(for: name).opacity(0.2), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: UIScreen.main.bounds.width - 32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

struct RanksExplanationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 20) {
                        // Header Card
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(.blue)
                                    .frame(width: 80, height: 80)
                                    .shadow(color: .blue.opacity(0.3), radius: 12, x: 0, y: 6)
                                
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(spacing: 8) {
                                Text("Attribute Ranks")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Text("Your attributes are ranked based on their values relative to other fitness enthusiasts. Each rank represents your progress and dedication.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                        }
                        .padding(24)
                        .frame(maxWidth: UIScreen.main.bounds.width - 40)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                        )
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                        
                        // Ranks Grid
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Rank Tiers")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 20)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 12) {
                                ForEach(RankTier.allCases, id: \.self) { rank in
                                    RankExplanationCard(rank: rank)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // How Ranks Work Card
                        VStack(alignment: .leading, spacing: 16) {
                            Text("How Rankings Work")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                RankFeatureRow(
                                    icon: "chart.line.uptrend.xyaxis",
                                    title: "Based on Progress",
                                    description: "Your rank increases as you build each attribute through consistent training"
                                )
                                
                                RankFeatureRow(
                                    icon: "person.2.fill",
                                    title: "Individual Attributes",
                                    description: "Each attribute (Strength, Endurance, etc.) has its own independent rank"
                                )
                                
                                RankFeatureRow(
                                    icon: "target",
                                    title: "Achievable Goals",
                                    description: "Every rank is attainable through dedication and consistent workouts"
                                )
                                
                                RankFeatureRow(
                                    icon: "arrow.up.circle.fill",
                                    title: "Always Improving",
                                    description: "Your ranks update automatically as you log workouts and gain experience"
                                )
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                        )
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Ranks")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct RankExplanationCard: View {
    let rank: RankTier
    
    var body: some View {
        VStack(spacing: 12) {
            // Rank Icon and Name
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(rank.color.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: rank.icon)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(rank.color)
                }
                
                Text(rank.rawValue)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
            }
            
            // Description
            Text(rank.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(rank.color.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}

struct RankFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
    }
}

// RadarChartView for attribute overview

struct RadarChartView: View {
    let stats: StatBlock
    @Environment(\.colorScheme) var colorScheme
    private let labels = ["Size", "Strength", "Dexterity", "Agility", "Endurance", "Vitality"]

    // Map stat label → color (match app's stat colors)
    private func colorForLabel(_ label: String) -> Color {
        switch label {
        case "Size": return colorScheme == .dark ? .white : .black
        case "Strength": return .red
        case "Dexterity": return .orange
        case "Agility": return .yellow
        case "Endurance": return .blue
        case "Vitality": return Color.green
        default: return .green
        }
    }
    
    // Map stat label → symbol
    private func symbolForLabel(_ label: String) -> String {
        switch label {
        case "Size": return "arrow.up.left.and.down.right.magnifyingglass"
        case "Strength": return "dumbbell.fill"
        case "Dexterity": return "hand.palm.facing.fill"
        case "Agility": return "hare.fill"
        case "Endurance": return "infinity"
        case "Vitality": return "heart.fill"
        default: return "circle.fill"
        }
    }

    // Determine which stat is currently highest and use its color for the polygon
    private var dominantColor: Color {
        let pairs: [(String, Double)] = [
            ("Size", stats.size),
            ("Strength", stats.strength),
            ("Dexterity", stats.dexterity),
            ("Agility", stats.agility),
            ("Endurance", stats.endurance),
            ("Vitality", stats.vitality)
        ]
        // Pick first in case of ties for stability
        let top = pairs.max { a, b in a.1 < b.1 }?.0 ?? "Vitality"
        return colorForLabel(top)
    }

    private var values: [Double] {
        [stats.size, stats.strength, stats.dexterity, stats.agility, stats.endurance, stats.vitality]
    }

    var body: some View {
        GeometryReader { geo in
            let n = labels.count
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width/2, y: geo.size.height/2)
            let radius = size * 0.42
            let maxVal = max(values.max() ?? 1, 0.0001)
            let normalized = values.map { $0 / maxVal }
            let ringCount = 4
            let borderOpacity: Double = colorScheme == .dark ? 0.35 : 0.2

            ZStack {
                // Rings (grid)
                ForEach(1...ringCount, id: \.self) { i in
                    let frac = CGFloat(i) / CGFloat(ringCount)
                    let lineWidth: CGFloat = i == ringCount ? 2.5 : 1 // Thicker outer border
                    Polygon(sides: n)
                        .stroke(Color.secondary.opacity(borderOpacity), lineWidth: lineWidth)
                        .frame(width: radius*2*frac, height: radius*2*frac)
                        .position(center)
                }

                // Spokes
                ForEach(0..<n, id: \.self) { i in
                    Path { p in
                        p.move(to: center)
                        let pt = point(for: Double(i), total: n, center: center, radius: radius)
                        p.addLine(to: pt)
                    }
                    .stroke(Color.secondary.opacity(borderOpacity), lineWidth: 1)
                }

                // Filled shape for user's stats
                Path { p in
                    for i in 0..<n {
                        let r = radius * normalized[i]
                        let pt = point(for: Double(i), total: n, center: center, radius: r)
                        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                    }
                    p.closeSubpath()
                }
                .fill(dominantColor.opacity(0.18))
                .overlay(
                    Path { p in
                        for i in 0..<n {
                            let r = radius * normalized[i]
                            let pt = point(for: Double(i), total: n, center: center, radius: r)
                            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                        }
                        p.closeSubpath()
                    }
                    .stroke(dominantColor.opacity(0.8), lineWidth: 2)
                )

                // Axis symbols
                ForEach(0..<n, id: \.self) { i in
                    let labelPt = point(for: Double(i), total: n, center: center, radius: radius + 16)
                    Image(systemName: symbolForLabel(labels[i]))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(colorForLabel(labels[i]))
                        .position(labelPt)
                }
            }
        }
    }

    private func point(for index: Double, total: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        // Start at top (-90°) and go clockwise
        let angle = (-Double.pi / 2) + (2 * Double.pi) * (index / Double(total))
        let x = center.x + CGFloat(cos(angle)) * radius
        let y = center.y + CGFloat(sin(angle)) * radius
        return CGPoint(x: x, y: y)
    }
}

struct Polygon: Shape {
    var sides: Int
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        guard sides > 2 else { return p }
        for i in 0..<sides {
            let angle = (-Double.pi / 2) + 2 * Double.pi * Double(i) / Double(sides)
            let pt = CGPoint(x: c.x + CGFloat(cos(angle)) * r, y: c.y + CGFloat(sin(angle)) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

struct AttributeBarChart: View {
    let stats: StatBlock
    @Environment(\.colorScheme) var colorScheme
    
    private var sortedAttributes: [(String, Double, Color)] {
        let attributes = [
            ("Size", stats.size, colorScheme == .dark ? Color.white : Color.black),
            ("Strength", stats.strength, Color.red),
            ("Dexterity", stats.dexterity, Color.orange),
            ("Agility", stats.agility, Color.yellow),
            ("Endurance", stats.endurance, Color.blue),
            ("Vitality", stats.vitality, Color.green)
        ]
        // Filter out zero values and sort by value (highest to lowest)
        return attributes
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
    }
    
    private func statIcon(for name: String) -> String {
        switch name {
        case "Size": return "arrow.up.left.and.down.right.magnifyingglass"
        case "Strength": return "dumbbell.fill"
        case "Dexterity": return "hand.palm.facing.fill"
        case "Agility": return "hare.fill"
        case "Endurance": return "infinity"
        case "Vitality": return "heart.fill"
        default: return "circle.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                if sortedAttributes.isEmpty {
                    // Empty state
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar")
                            .font(.title2)
                            .foregroundColor(.secondary.opacity(0.6))
                        
                        Text("No attributes yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    let maxValue = sortedAttributes.first?.1 ?? 1.0
                    
                    VStack(spacing: 6) {
                        ForEach(Array(sortedAttributes.enumerated()), id: \.offset) { index, attribute in
                            let (_, value, color) = attribute
                            let barWidth = max(0.02, value / maxValue) // Minimum 2% width for visibility
                            
                            // Just the colored bar without background or value text
                            HStack {
                                Rectangle()
                                    .fill(color)
                                    .frame(width: max(3, barWidth * 95), height: 14) // Adjusted for slightly larger container
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                                
                                Spacer(minLength: 0)
                            }
                            .animation(.easeInOut(duration: 0.6).delay(Double(index) * 0.1), value: value)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            // Icon for strongest attribute
            if let topStat = sortedAttributes.first {
                Image(systemName: statIcon(for: topStat.0))
                    .font(.title)
                    .foregroundColor(topStat.2)
                    .animation(.easeInOut(duration: 0.3), value: topStat.0)
            }
        }
    }
}

struct LogWorkoutView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.colorScheme) var colorScheme

    @State private var name: String = ""
    @State private var focus: FocusGroup = .strength
    @State private var category: ExerciseCategory = .squat
    @State private var reps: String = ""
    @State private var weight: String = ""
    @State private var duration: String = ""
    @State private var distance: String = ""
    @State private var showPopup: Bool = false
    @State private var popupEntry: WorkoutEntry? = nil
    @State private var showValidationAlert = false
    @State private var validationMessage = ""
    @State private var searchText: String = ""

    private var filteredExercises: [ExerciseCategory] {
        let base = searchText.isEmpty ? ExerciseCategory.allCases.filter { $0.focus == focus } : ExerciseCategory.allCases
        return base.filter { searchText.isEmpty || $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    private func bestMatch(for query: String) -> ExerciseCategory? {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return nil }
        // Score each exercise name: prefix gets highest weight, word-prefix next, substring last.
        let scored: [(cat: ExerciseCategory, score: Int)] = ExerciseCategory.allCases.map { cat in
            let name = cat.displayName.lowercased()
            var s = 0
            if name.hasPrefix(q) { s += 3 }
            if name.split(separator: " ").contains(where: { $0.hasPrefix(Substring(q)) }) { s += 2 }
            if name.contains(q) { s += 1 }
            return (cat, s)
        }.filter { $0.score > 0 }
        return scored.sorted { a, b in
            if a.score == b.score { return a.cat.displayName < b.cat.displayName }
            return a.score > b.score
        }.first?.cat
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 20) {
                        // Bodyweight reminder banner
                        if state.user.bodyweightKg == nil {
                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.title2)
                                        .foregroundColor(.orange)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Setup Required")
                                            .font(.headline.weight(.semibold))
                                            .foregroundColor(.primary)
                                        Text("Set your bodyweight in Settings to get accurate scaling.")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                        }

                        // Modern Focus Selection
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 8) {
                                Image(systemName: "scope")
                                    .font(.title3)
                                    .foregroundColor(.red)
                                Text("Challenge Focus")
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 20)
                            
                            ModernFocusChips(selection: $focus)
                        }

                        // Exercise Selection Card
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Training Plan")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.primary)
                            
                            VStack(spacing: 16) {
                                // Exercise Name Field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Name")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.secondary)
                                    
                                    TextField("Optional custom name", text: $name)
                                        .textFieldStyle(ModernTextFieldStyle())
                                }
                                
                                // Exercise Category Picker
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Challenge Type")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.secondary)
                                    
                                    Menu {
                                        ForEach(filteredExercises) { cat in
                                            Button(cat.displayName) {
                                                category = cat
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(category.displayName)
                                                .foregroundColor(.primary)
                                            Spacer()
                                            Image(systemName: "chevron.down")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(.secondarySystemBackground))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color(.separator), lineWidth: 0.5)
                                                )
                                        )
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: UIScreen.main.bounds.width - 32)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                        )
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)

                        // Performance Inputs Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 8) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.title3)
                                    .foregroundColor(.green)
                                Text("Training Stats")
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(.primary)
                            }
                            
                            VStack(spacing: 16) {
                                ModernInputRow(
                                    title: "Reps",
                                    placeholder: "e.g. 8",
                                    text: $reps,
                                    keyboardType: .numberPad
                                )
                                
                                ModernInputRow(
                                    title: "Weight",
                                    subtitle: state.user.units.displayName,
                                    placeholder: "e.g. 60",
                                    text: $weight,
                                    keyboardType: .decimalPad
                                )
                                
                                ModernInputRow(
                                    title: "Duration",
                                    subtitle: "minutes",
                                    placeholder: "e.g. 20",
                                    text: $duration,
                                    keyboardType: .decimalPad
                                )
                                
                                ModernInputRow(
                                    title: "Distance",
                                    subtitle: state.user.units.distanceDisplayName,
                                    placeholder: "e.g. 3.2",
                                    text: $distance,
                                    keyboardType: .decimalPad
                                )
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: UIScreen.main.bounds.width - 32)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                        )
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)

                        // Log Button Card
                        Button(action: save) {
                            HStack(spacing: 8) {
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                Text("Complete Training")
                                    .font(.headline.weight(.semibold))
                                Image(systemName: "bolt.circle.fill")
                                    .font(.title3)
                                Spacer()
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 18)
                            .background(hasAtLeastOneInput && state.user.bodyweightKg != nil ? .green : .gray)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                            .scaleEffect(hasAtLeastOneInput && state.user.bodyweightKg != nil ? 1.0 : 0.95)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hasAtLeastOneInput)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.user.bodyweightKg != nil)
                        }
                        .frame(maxWidth: UIScreen.main.bounds.width - 32)
                        .disabled(state.user.bodyweightKg == nil || !hasAtLeastOneInput)
                        
                        // Helper Text
                        Text("Record your training session. For strength: reps × weight. For endurance: duration and/or distance. Weight uses \(state.user.units.displayName).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: UIScreen.main.bounds.width - 32)
                            .padding(.bottom, 20)
                    }
                }
                .dismissKeyboardOnTap()
                .dismissKeyboardOnSwipe()

                // Popup overlay
                if showPopup, let entry = popupEntry {
                    Color.black.opacity(0)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .zIndex(1)

                    GainPopupView(entry: entry, onDismiss: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                            showPopup = false
                        }
                    })
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(2)
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search exercises")
            .navigationTitle("Complete Training")
            .alert("Check your input", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage)
            }
        }
        .onChangeCompat(of: focus) { _, newFocus in
            let list = ExerciseCategory.allCases.filter { $0.focus == newFocus }
            if !list.contains(category), let first = list.first {
                category = first
            }
        }
        .onChangeCompat(of: searchText) { _, newText in
            if let best = bestMatch(for: newText) {
                if focus != best.focus { focus = best.focus }
                category = best
            }
            if !filteredExercises.contains(category), let first = filteredExercises.first {
                category = first
            }
        }
    }

    private func celebrate() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
    }

    private var hasAtLeastOneInput: Bool {
        !(reps.isEmpty && weight.isEmpty && duration.isEmpty && distance.isEmpty)
    }


    private func save() {
        // Validation
        let repsVal = Int(reps)
        let weightRaw = Double(weight)
        let durVal = Double(duration)
        let distRaw = Double(distance)
        let distKm: Double? = {
            guard let d = distRaw else { return nil }
            return state.user.units.toKm(d) // mi → km when units == .lb
        }()

        // Convert weight to kg based on settings
        let weightValKg: Double? = {
            guard let w = weightRaw else { return nil }
            return state.user.units.toKg(w)
        }()

        func invalid(_ msg: String) {
            validationMessage = msg
            showValidationAlert = true
        }

        if let r = repsVal, r < 0 || r > 1000 { invalid("Reps must be between 0 and 1000."); return }
        if let w = weightValKg, w < 0 || w > 700 { invalid("Weight seems unrealistic. Please check units."); return }
        if let d = durVal, d < 0 || d > 600 { invalid("Duration must be between 0 and 600 minutes."); return }
        if let entered = distRaw {
            let km = state.user.units.toKm(entered)
            let maxKm = 200.0
            if km < 0 || km > maxKm {
                let maxDisplay = state.user.units == .kg ? maxKm : maxKm / 1.6
                invalid(String(format: "Distance must be between 0 and %.0f %@", maxDisplay, state.user.units.distanceDisplayName))
                return
            }
        }

        let entry = state.logWorkout(name: name, category: category, reps: repsVal, weight: weightValKg, durationMinutes: durVal, distanceKm: distKm)
        popupEntry = entry
        
        // Dismiss keyboard before showing popup
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showPopup = true
        }
        celebrate()

        // Auto-dismiss popup
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                showPopup = false
            }
        }

        // Reset inputs (keep category for convenience)
        name = ""
        reps = ""
        weight = ""
        duration = ""
        distance = ""
    }
}
struct GainPopupView: View {
    let entry: WorkoutEntry
    let onDismiss: () -> Void
    @State private var showInfo: Bool = false
    @State private var animateIn: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var state: AppState

    private func formatXP(_ value: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.usesGroupingSeparator = true
        nf.maximumFractionDigits = value < 1000 ? 1 : 0
        return nf.string(from: NSNumber(value: value)) ?? String(format: value < 1000 ? "%.1f" : "%.0f", value)
    }

    private var gainRows: [(String, Double, Color, String)] {
        let g = entry.statGains
        let raw: [(String, Double, Color, String)] = [
            ("Size", g.size, colorScheme == .dark ? .white : .black, "arrow.up.left.and.down.right.magnifyingglass"),
            ("Strength", g.strength, .red, "dumbbell.fill"),
            ("Dexterity", g.dexterity, .orange, "hand.palm.facing.fill"),
            ("Agility", g.agility, .yellow, "hare.fill"),
            ("Endurance", g.endurance, .blue, "lungs.fill"),
            ("Vitality", g.vitality, .green, "heart.fill")
        ]
        .filter { $0.1 > 0.005 } // Only show gains of 0.01 or higher
        return raw.sorted { $0.1 > $1.1 }
    }
    
    private var isLevelUp: Bool {
        if let from = entry.prevLevel, let to = entry.newLevel, to > from {
            return true
        }
        return false
    }
    
    private func chestRarityColor(_ type: TreasureChestType) -> Color {
        switch type {
        case .common: return .brown
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .mythic: return .red
        }
    }

    var body: some View {
        ZStack {
            // Modern background
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)

            VStack(spacing: 20) {
                // Celebration header with RPG flair
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        ZStack {
                            // Glow effect for level up
                            if isLevelUp {
                                Image(systemName: "sparkle")
                                    .font(.largeTitle)
                                    .foregroundColor(.yellow.opacity(0.3))
                                    .blur(radius: 8)
                                    .scaleEffect(animateIn ? 1.2 : 0.5)
                                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animateIn)
                            }
                            
                            Image(systemName: isLevelUp ? "crown.fill" : "checkmark.seal.fill")
                                .font(.title2)
                                .foregroundColor(isLevelUp ? .yellow : .green)
                                .scaleEffect(animateIn ? 1.0 : 0.5)
                                .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1), value: animateIn)
                        }
                        
                        Text(isLevelUp ? "Level Up!" : "Challenge Completed!")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.primary)
                    }
                    
                    // XP Display with sparkles
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.title3)
                                .foregroundColor(.green.opacity(0.9))
                                .shadow(color: .green.opacity(0.4), radius: 3)
                                .rotationEffect(.degrees(animateIn ? 15 : -15))
                                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: animateIn)
                            
                            Text("+\(formatXP(entry.totalProgressXP ?? entry.expGained))")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                                .scaleEffect(animateIn ? 1.0 : 0.8)
                                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: animateIn)
                            
                            Text("XP")
                                .font(.title2.weight(.bold))
                                .foregroundColor(.green.opacity(0.8))
                        }
                        
                        Text("Experience Gained")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 4)
                
                // Level up information with fanfare
                if let from = entry.prevLevel, let to = entry.newLevel, to > from {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.up.circle.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Level \(from) → \(to)")
                                .font(.subheadline.weight(.semibold))
                            if entry.catchUpLevel != nil {
                                Text("Catch-up bonus applied")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Button {
                            showInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Treasure chest notification for level ups
                if isLevelUp, let latestChest = state.user.treasureChests.last {
                    HStack(spacing: 8) {
                        Image(systemName: "giftcard.fill")
                            .foregroundColor(chestRarityColor(latestChest.type))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(latestChest.type.displayName) Card Collected!")
                                .font(.subheadline.weight(.semibold))
                            Text("Check the Inventory tab to claim your rewards")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "sparkles")
                            .foregroundColor(chestRarityColor(latestChest.type))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(chestRarityColor(latestChest.type).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // 1RM information (only for relevant compound lifts)
                if let est = entry.est1RM, let prev = entry.prevBest1RM, est > 0, est > prev {
                    let oneRMLifts: Set<ExerciseCategory> = [.squat, .frontSquat, .deadlift, .romanianDeadlift, .benchPress, .overheadPress, .powerClean]
                    if oneRMLifts.contains(entry.category) {
                        HStack(spacing: 8) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundColor(.purple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("New 1RM Personal Best!")
                                    .font(.subheadline.weight(.semibold))
                                // Convert from kg to user's preferred units for display
                                let units = state.user.units
                                let displayEst = units.fromKg(est)
                                let displayPrev = units.fromKg(prev)
                                Text(String(format: "Est. 1RM: %.0f %@ (prev %.0f %@)", displayEst, units.displayName, displayPrev, units.displayName))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.purple.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                // Enhanced stat gains
                if !gainRows.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Attribute Gains")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(Array(gainRows.enumerated()), id: \.offset) { index, row in
                                let (name, value, color, icon) = row
                                HStack(spacing: 10) {
                                    Image(systemName: icon)
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(color)
                                        .frame(width: 20)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(name)
                                            .font(.caption2.weight(.medium))
                                            .foregroundColor(.secondary)
                                        Text(String(format: "+%.2f", value))
                                            .font(.caption.weight(.bold))
                                            .foregroundColor(color)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(color.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .scaleEffect(animateIn ? 1.0 : 0.9)
                                .opacity(animateIn ? 1.0 : 0.0)
                                .animation(.easeOut(duration: 0.3).delay(Double(index) * 0.1), value: animateIn)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .frame(maxWidth: 360)
        .padding(.horizontal, 20)
        .onTapGesture {
            onDismiss()
        }
        .onAppear {
            withAnimation {
                animateIn = true
            }
        }
        .alert("About XP", isPresented: $showInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("XP scales with how hard the session was for you (reps × weight, pace, time). Beat your baseline and you'll see bigger gains; easy or off days still give a little progress.")
        }
    }
}

// A simple flexible chip wrapper for one-line/second-line layout
struct WrapChips: View {
    let items: [String]

    private func color(for item: String) -> Color {
        if item.contains("+SIZ") { return .black }       // Size
        if item.contains("+STR") { return .red }         // Strength
        if item.contains("+DEX") { return .orange }      // Dexterity
        if item.contains("+AGI") { return .yellow }      // Agility
        if item.contains("+END") { return .blue }        // Endurance
        if item.contains("+VIT") { return Color.green.opacity(0.85) } // Vitality (lighter green)
        return .primary
    }

    var body: some View {
        FlexibleView(data: items, spacing: 8, alignment: .leading) { item in
            let c = color(for: item)
            Text(item)
                .font(.caption).bold()
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .foregroundColor(c)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(c.opacity(0.5), lineWidth: 1)
                )
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(10)
        }
    }
}

// Generic flexible layout to wrap chips
struct FlexibleView<Data: Collection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Data.Element) -> Content

    init(data: Data, spacing: CGFloat, alignment: HorizontalAlignment, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.spacing = spacing
        self.alignment = alignment
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func generateContent(in g: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var rows: [[Data.Element]] = [[]]

        for item in data {
            guard let str = item as? String else { continue }
            let itemWidth = str.size(withAttributes: [.font: UIFont.preferredFont(forTextStyle: .caption1)]).width + 20
            if width + itemWidth + spacing > g.size.width {
                rows.append([item])
                width = itemWidth + spacing
            } else {
                rows[rows.count - 1].append(item)
                width += itemWidth + spacing
            }
        }

        return VStack(alignment: alignment, spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(row, id: \.self) { item in
                        content(item)
                    }
                }
            }
        }
    }
}

struct EditWorkoutView: View {
    @State var workout: WorkoutEntry
    var onSave: (WorkoutEntry) -> Void
    var onCancel: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var state: AppState
    
    @State private var name: String = ""
    @State private var reps: String = ""
    @State private var weight: String = ""
    @State private var duration: String = ""
    @State private var distance: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Exercise Details") {
                    TextField("Custom Name", text: $name)
                    Text("Category: \(workout.category.displayName)")
                        .foregroundColor(.secondary)
                }
                
                Section("Performance") {
                    HStack {
                        Text("Reps")
                        Spacer()
                        TextField("0", text: $reps)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Weight (\(state.user.units.displayName))")
                        Spacer()
                        TextField("0", text: $weight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Duration (minutes)")
                        Spacer()
                        TextField("0", text: $duration)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Distance (\(state.user.units.distanceDisplayName))")
                        Spacer()
                        TextField("0", text: $distance)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveWorkout()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            name = workout.name
            if let r = workout.reps {
                reps = "\(r)"
            }
            if let w = workout.weight {
                weight = String(format: "%.1f", state.user.units.fromKg(w))
            }
            if let d = workout.durationMinutes {
                duration = String(format: "%.0f", d)
            }
            if let dist = workout.distanceKm {
                distance = String(format: "%.2f", state.user.units.fromKm(dist))
            }
        }
    }
    
    private func saveWorkout() {
        var updatedWorkout = workout
        updatedWorkout.name = name
        updatedWorkout.reps = Int(reps)
        updatedWorkout.weight = Double(weight).map { state.user.units.toKg($0) }
        updatedWorkout.durationMinutes = Double(duration)
        updatedWorkout.distanceKm = Double(distance).map { state.user.units.toKm($0) }
        
        // Recalculate stats based on new values
        let score = StatEngine.intensityScore(
            category: updatedWorkout.category,
            reps: updatedWorkout.reps,
            weight: updatedWorkout.weight,
            durationMin: updatedWorkout.durationMinutes,
            distanceKm: updatedWorkout.distanceKm
        )
        updatedWorkout.statGains = StatEngine.statGains(
            for: updatedWorkout.category,
            score: score
        )
        updatedWorkout.expGained = score * 10
        
        onSave(updatedWorkout)
    }
}

enum WorkoutGrouping: String, CaseIterable {
    case all = "All"
    case day = "Day"
    case week = "Week"
}

struct HistoryView: View {
    @EnvironmentObject var state: AppState
    @State private var showSettings = false
    @State private var showEditSheet = false
    @State private var editingWorkout: WorkoutEntry?
    @State private var workoutToDelete: WorkoutEntry?
    @State private var showDeleteConfirmation = false
    @State private var groupingMode: WorkoutGrouping = .day
    @AppStorage("hasUsedWorkoutContextMenu") private var hasUsedWorkoutContextMenu = false
    @Environment(\.colorScheme) var colorScheme
    
    private var groupedWorkouts: [(String, [WorkoutEntry])] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        switch groupingMode {
        case .all:
            return [("All Workouts", state.getSortedHistory())]
            
        case .day:
            formatter.dateFormat = "EEEE" // Just day of week (e.g., "Monday")
            let grouped = Dictionary(grouping: state.getSortedHistory()) { workout in
                calendar.startOfDay(for: workout.date)
            }
            return grouped.map { (date, workouts) in
                (formatter.string(from: date), workouts) // Already sorted from cache
            }.sorted { $0.0 > $1.0 }
            
        case .week:
            formatter.dateFormat = "MMMM d"
            let grouped = Dictionary(grouping: state.getSortedHistory()) { workout in
                calendar.dateInterval(of: .weekOfYear, for: workout.date)?.start ?? workout.date
            }
            return grouped.map { (weekStart, workouts) in
                let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
                let weekLabel = "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
                return (weekLabel, workouts) // Already sorted from cache
            }.sorted { $0.0 > $1.0 }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if state.history.isEmpty {
                    // Empty state
                    VStack(spacing: 24) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary.opacity(0.6))
                        
                        VStack(spacing: 12) {
                            Text("No Workouts Yet")
                                .font(.title2.weight(.semibold))
                                .foregroundColor(.primary)
                            
                            Text("Your workout history will appear here after you log your first workout.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            // Stats Summary Card
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Your Progress")
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 20) {
                                    ModernStatChip(
                                        title: "Total Workouts",
                                        value: "\(state.history.count)",
                                        color: .blue
                                    )
                                    
                                    ModernStatChip(
                                        title: "Total XP Gained",
                                        value: String(format: "%.0f", state.history.map(\.expGained).reduce(0, +)),
                                        color: .green
                                    )
                                }
                                
                                HStack(spacing: 20) {
                                    ModernStatChip(
                                        title: "This Week",
                                        value: "\(workoutsThisWeek())",
                                        color: .purple
                                    )
                                    
                                    ModernStatChip(
                                        title: "Best Session",
                                        value: String(format: "%.0f XP", state.history.map(\.expGained).max() ?? 0),
                                        color: .orange
                                    )
                                }
                            }
                            .padding(20)
                            .frame(maxWidth: UIScreen.main.bounds.width - 32)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                    )
                            )
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                            
                            // Workout History Header with Grouping Control
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Recent Workouts")
                                        .font(.title3.weight(.semibold))
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                
                                HStack {
                                    Text("Group by:")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Picker("Grouping", selection: $groupingMode) {
                                        ForEach(WorkoutGrouping.allCases, id: \.self) { mode in
                                            Text(mode.rawValue).tag(mode)
                                        }
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                    .frame(width: 180)
                                    
                                    Spacer()
                                }
                                
                                if !hasUsedWorkoutContextMenu {
                                    HStack {
                                        Image(systemName: "hand.tap")
                                            .font(.caption)
                                            .foregroundColor(.secondary.opacity(0.7))
                                        Text("Long press workouts to edit or delete")
                                            .font(.caption)
                                            .foregroundColor(.secondary.opacity(0.7))
                                        Spacer()
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            // Grouped Workout History Items
                            ForEach(groupedWorkouts, id: \.0) { group in
                                VStack(alignment: .center, spacing: 12) {
                                    // Group Header
                                    HStack {
                                        Text(group.0)
                                            .font(.headline.weight(.semibold))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text("\(group.1.count) workout\(group.1.count == 1 ? "" : "s")")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.top, group.0 == groupedWorkouts.first?.0 ? 0 : 16)
                                    
                                    // Workouts in this group
                                    ForEach(group.1) { entry in
                                        ModernHistoryCard(entry: entry, units: state.user.units, onEdit: {
                                            editingWorkout = entry
                                            showEditSheet = true
                                        })
                                        .contextMenu {
                                            Button {
                                                hasUsedWorkoutContextMenu = true
                                                editingWorkout = entry
                                                showEditSheet = true
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            
                                            Button(role: .destructive) {
                                                hasUsedWorkoutContextMenu = true
                                                workoutToDelete = entry
                                                showDeleteConfirmation = true
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .bottom).combined(with: .opacity),
                                            removal: .move(edge: .trailing).combined(with: .opacity)
                                        ))
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 20)
                    }
                }
            }
            .navigationTitle("Skillbook")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(state)
            }
            .sheet(isPresented: $showEditSheet) {
                if let workout = editingWorkout {
                    EditWorkoutView(workout: workout, onSave: { updatedWorkout in
                        state.updateWorkout(updatedWorkout)
                        showEditSheet = false
                    }, onCancel: {
                        showEditSheet = false
                    })
                    .environmentObject(state)
                }
            }
            .confirmationDialog("Delete Workout", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let workout = workoutToDelete,
                       let index = state.history.firstIndex(where: { $0.id == workout.id }) {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            state.deleteWorkout(at: IndexSet(integer: index))
                        }
                        workoutToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    workoutToDelete = nil
                }
            } message: {
                if let workout = workoutToDelete {
                    Text("Are you sure you want to delete this \(workout.category.displayName) workout? This action cannot be undone.")
                }
            }
        }
    }
    
    private func workoutsThisWeek() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
        return state.getSortedHistory().prefix(while: { $0.date >= weekAgo }).count
    }

    private func chipItems(_ e: WorkoutEntry) -> [String] {
        let g = e.statGains
        let w = StatEngine.statWeights(for: e.category)
        // Build (abbr, weight, value) tuples
        var tuples: [(abbr: String, weight: Double, val: Double)] = [
            ("SIZ", w.size, g.size),
            ("STR", w.strength, g.strength),
            ("DEX", w.dexterity, g.dexterity),
            ("AGI", w.agility, g.agility),
            ("END", w.endurance, g.endurance),
            ("VIT", w.vitality, g.vitality)
        ]
        // Sort by the exercise's emphasis weights (primary muscles first)
        tuples.sort { $0.weight > $1.weight }
        // Take per-exercise primary count (2 or 3)
        let count = StatEngine.primaryDisplayCount(for: e.category)
        let primaries = Array(tuples.prefix(count))
        // Within the chosen primaries, sort by actual gained value for this entry
        let sortedByGain = primaries.sorted { $0.val > $1.val }
        // Map to chips, skipping trivial ~zero gains
        return sortedByGain.filter { $0.val > 0.0001 }
                           .map { String(format: "+%@ %.2f", $0.abbr, $0.val) }
    }
}


struct XPChip: View {
    let value: Double
    var body: some View {
        Text(String(format: "+XP %.1f", value))
            .font(.caption).bold()
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .foregroundColor(.green)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.green.opacity(0.5), lineWidth: 1)
            )
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(10)
    }
}

struct ModernXPChip: View {
    let value: Double
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundColor(.green)
            
            Text(String(format: "+%.0f XP", value))
                .font(.caption.weight(.semibold))
                .foregroundColor(.green)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct ModernStatChip: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct ModernHistoryCard: View {
    let entry: WorkoutEntry
    let units: Units
    var onEdit: (() -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 16) {
                // Header with exercise name and date
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.name.isEmpty ? entry.category.displayName : entry.name)
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        Text(entry.category.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(entry.date, style: .date)
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        Text(entry.date, style: .time)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        ModernXPChip(value: entry.expGained)
                    }
                }
                
                // Performance metrics
                if hasPerformanceData {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Performance")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        HStack(spacing: 12) {
                            if let r = entry.reps {
                                ModernMetricBadge(icon: "number", title: "Reps", value: "\(r)")
                            }
                            if let wKg = entry.weight, wKg > 0 {
                                let wDisp = units.fromKg(wKg)
                                ModernMetricBadge(icon: "scalemass", title: "Weight", value: "\(String(format: "%.1f", wDisp)) \(units.displayName)")
                            }
                            if let d = entry.durationMinutes, d > 0 {
                                ModernMetricBadge(icon: "clock", title: "Duration", value: String(format: "%.0f min", d))
                            }
                            if let km = entry.distanceKm, km > 0 {
                                let d = units.fromKm(km)
                                ModernMetricBadge(icon: "location", title: "Distance", value: String(format: "%.2f %@", d, units.distanceDisplayName))
                            }
                        }
                    }
                }
                
                // Attribute gains
                if !chipItems.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(chipItems, id: \.self) { item in
                            ModernAttributeChip(text: item)
                        }
                        Spacer()
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: UIScreen.main.bounds.width - 32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }
    
    private var hasPerformanceData: Bool {
        entry.reps != nil || (entry.weight ?? 0) > 0 || (entry.durationMinutes ?? 0) > 0 || (entry.distanceKm ?? 0) > 0
    }
    
    private var chipItems: [String] {
        let g = entry.statGains
        let w = StatEngine.statWeights(for: entry.category)
        var tuples: [(abbr: String, weight: Double, val: Double)] = [
            ("SIZ", w.size, g.size),
            ("STR", w.strength, g.strength),
            ("DEX", w.dexterity, g.dexterity),
            ("AGI", w.agility, g.agility),
            ("END", w.endurance, g.endurance),
            ("VIT", w.vitality, g.vitality)
        ]
        tuples.sort { $0.weight > $1.weight }
        let count = StatEngine.primaryDisplayCount(for: entry.category)
        let primaries = Array(tuples.prefix(count))
        let sortedByGain = primaries.sorted { $0.val > $1.val }
        return sortedByGain.filter { $0.val > 0.0001 }
                          .map { String(format: "+%@ %.2f", $0.abbr, $0.val) }
    }
}

struct ModernMetricBadge: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 16, height: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )
        )
    }
}

struct ModernAttributeChip: View {
    let text: String
    @Environment(\.colorScheme) var colorScheme
    
    private func color(for item: String) -> Color {
        if item.contains("+SIZ") { return colorScheme == .dark ? .white : .black }
        if item.contains("+STR") { return .red }
        if item.contains("+DEX") { return .orange }
        if item.contains("+AGI") { return .yellow }
        if item.contains("+END") { return .blue }
        if item.contains("+VIT") { return .green }
        return .primary
    }
    
    var body: some View {
        let c = color(for: text)
        Text(text)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .foregroundColor(c)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(c.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(c.opacity(0.3), lineWidth: 0.5)
                    )
            )
    }
}

struct Badge: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption).bold()
            .padding(.vertical, 4).padding(.horizontal, 8)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
    }
}

struct ModernActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.medium))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - App Entry
@main
struct FRPGMVPApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Keyboard Dismiss Toolbar


// MARK: - Rank Badge System

enum RankTier: String, CaseIterable {
    case bronze = "Bronze"
    case silver = "Silver"
    case gold = "Gold"
    case platinum = "Platinum"
    case diamond = "Diamond"
    case master = "Master"
    case grandmaster = "Grandmaster"
    
    var color: Color {
        switch self {
        case .bronze: return Color.brown
        case .silver: return Color.gray
        case .gold: return Color.yellow
        case .platinum: return Color.cyan
        case .diamond: return Color.blue
        case .master: return Color.purple
        case .grandmaster: return Color.red
        }
    }
    
    var icon: String {
        switch self {
        case .bronze: return "shield.fill"
        case .silver: return "shield.lefthalf.filled"
        case .gold: return "circle.circle.fill"
        case .platinum: return "lifepreserver"
        case .diamond: return "diamond.circle.fill"
        case .master: return "crown"
        case .grandmaster: return "crown.fill"
        }
    }
    
    var description: String {
        switch self {
        case .bronze: return "Starting your fitness journey with dedication and consistency"
        case .silver: return "Building solid foundations and seeing real progress"
        case .gold: return "Achieving impressive strength and athletic performance"
        case .platinum: return "Elite fitness levels and exceptional discipline"
        case .diamond: return "Demonstrating exceptional athletic prowess"
        case .master: return "Approaching peak human physical performance"
        case .grandmaster: return "Legendary status - the pinnacle of fitness achievement"
        }
    }
}

struct PrestigeBadge: View {
    let prestigeLevel: Int
    
    var body: some View {
        HStack(spacing: 4) {
            if prestigeLevel > 0 {
                // Show stars based on prestige level
                HStack(spacing: 2) {
                    ForEach(0..<min(prestigeLevel, 5), id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption2)
                    }
                    // If more than 5 stars, show number
                    if prestigeLevel > 5 {
                        Text("×\(prestigeLevel)")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.yellow)
                    }
                }
            }
            Text(prestigeLevel > 0 ? "P\(prestigeLevel)" : "None")
                .font(.caption2.weight(.semibold))
                .foregroundColor(prestigeLevel > 0 ? .yellow : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((prestigeLevel > 0 ? Color.yellow : Color.gray).opacity(0.15))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke((prestigeLevel > 0 ? Color.yellow : Color.gray).opacity(0.6), lineWidth: 1)
        )
        .cornerRadius(8)
    }
}

struct RankBadge: View {
    let tier: RankTier
    let level: Int?
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: tier.icon)
                .foregroundColor(tier.color)
                .font(.caption.weight(.bold))
            Text(tier.rawValue)
                .font(.caption2.weight(.semibold))
                .foregroundColor(tier.color)
            if let level = level {
                Text("\(level)")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(tier.color)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tier.color.opacity(0.15))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(tier.color.opacity(0.6), lineWidth: 1)
        )
        .cornerRadius(8)
    }
}

struct AttributeRankBadge: View {
    let tier: RankTier
    
    var body: some View {
        Image(systemName: tier.icon)
            .foregroundColor(tier.color)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(tier.color.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(tier.color.opacity(0.6), lineWidth: 1)
            )
            .cornerRadius(6)
    }
}

extension UserProfile {
    var prestigeLevel: Int {
        // Start with prestige 0, increase every 10 levels after level 10
        return level > 10 ? (level - 1) / 10 : 0
    }
    
    var displayLevel: Int {
        // Display level resets every 10 levels but shows 1-10
        if level <= 10 {
            return level
        } else {
            let displayLvl = ((level - 1) % 10) + 1
            return displayLvl
        }
    }
    
    var levelDisplayText: String {
        let plusCount = prestigeLevel
        let plusSigns = plusCount > 0 ? String(repeating: "+", count: plusCount) : ""
        return "Level \(displayLevel)\(plusSigns)"
    }
    
    var levelRank: (tier: RankTier, level: Int) {
        let level = self.level
        switch level {
        case 1..<10: return (.bronze, level)
        case 10..<25: return (.silver, level)
        case 25..<50: return (.gold, level)
        case 50..<75: return (.platinum, level)
        case 75..<90: return (.diamond, level)
        default: return (.master, level)
        }
    }
    
    func attributeRank(for value: Double) -> RankTier {
        switch value {
        case 0..<10: return .bronze
        case 10..<25: return .silver
        case 25..<50: return .gold
        case 50..<100: return .platinum
        case 100..<200: return .diamond
        case 200..<350: return .master
        default: return .grandmaster
        }
    }
    
    var sizeRank: RankTier { attributeRank(for: stats.size) }
    var strengthRank: RankTier { attributeRank(for: stats.strength) }
    var dexterityRank: RankTier { attributeRank(for: stats.dexterity) }
    var agilityRank: RankTier { attributeRank(for: stats.agility) }
    var enduranceRank: RankTier { attributeRank(for: stats.endurance) }
    var vitalityRank: RankTier { attributeRank(for: stats.vitality) }
}

// MARK: - Onboarding
struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @EnvironmentObject var state: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var page = 0
    @State private var isMovingForward = true
    @State private var bodyweightValue: Double = 150.0
    @State private var selectedGoals: [FitnessGoal] = []
    @State private var showWelcomeAnimation = false
    @State private var showFeatures = false
    @State private var showClassReveal = false

    // Helper function for goal selection
    private func toggleGoalSelection(_ goal: FitnessGoal) {
        if selectedGoals.contains(goal) {
            selectedGoals.removeAll { $0 == goal }
        } else if selectedGoals.count < 2 {
            selectedGoals.append(goal)
        }
    }

    // Bodyweight validator: must be in 25–350 kg
    private var bodyweightValid: Bool {
        let kg = state.user.units.toKg(bodyweightValue)
        return kg >= 25 && kg <= 350
    }
    
    // Get appropriate range for the slider based on units
    private var weightRange: ClosedRange<Double> {
        switch state.user.units {
        case .kg:
            return 25...200 // kg
        case .lb:
            return 55...440 // lbs
        }
    }
    
    private let totalPages = 5 // Welcome, Features, Class Placement, Class Reveal, Setup
    
    private var canProceed: Bool {
        switch page {
        case 0, 1: return true // Welcome and Features pages
        case 2: return selectedGoals.count == 2 // Goal selection (need exactly 2)
        case 3: return true // Class reveal page
        case 4: return bodyweightValid // Setup page
        default: return false
        }
    }
    
    private var buttonTitle: String {
        switch page {
        case 0: return "Get Started"
        case 1: return "Continue"
        case 2:
            if selectedGoals.count == 0 {
                return "Select Your Goals"
            } else if selectedGoals.count == 1 {
                return "Select One More"
            } else if selectedGoals.count == 2 {
                return "Reveal My Class"
            } else {
                return "Select Only 2 Goals"
            }
        case 3: return "Continue"
        case 4: return "Start Your Journey"
        default: return "Continue"
        }
    }
    
    private var buttonIcon: String {
        switch page {
        case 0, 1, 2, 3: return "arrow.right"
        case 4: return "checkmark"
        default: return "arrow.right"
        }
    }
    
    private let features: [(icon: String, title: String, description: String, color: Color)] = [
        ("chart.line.uptrend.xyaxis", "Track Progress", "Build stats over time", .blue),
        ("scroll.fill", "Daily Quests", "Class-specific challenges", .orange),
        ("giftcard.fill", "Earn Rewards", "Acquire treasure cards", .purple),
        ("trophy.fill", "Achievements", "Hit major milestones", .yellow),
        ("sparkles", "Level System", "100s of levels to conquer", .green)
    ]
    
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Capsule()
                    .fill(index <= page ? Color.blue : Color.gray.opacity(0.3))
                    .frame(height: 4)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: page)
            }
        }
        .padding(.horizontal, 40)
        .padding(.top, 20)
    }
    
    private var welcomeHeroIcon: some View {
        let ringGradient = LinearGradient(
            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        let circleGradient = LinearGradient(
            colors: [Color.blue, Color.purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        return ZStack {
            // Animated rings
            ForEach(0..<3) { index in
                Circle()
                    .stroke(ringGradient, lineWidth: 2)
                    .frame(width: 120 + CGFloat(index * 30), height: 120 + CGFloat(index * 30))
                    .scaleEffect(showWelcomeAnimation ? 1.0 : 0.5)
                    .opacity(showWelcomeAnimation ? 0.0 : 1.0)
                    .animation(
                        Animation.easeOut(duration: 2.0)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.3),
                        value: showWelcomeAnimation
                    )
            }
            
            Circle()
                .fill(circleGradient)
                .frame(width: 120, height: 120)
                .shadow(color: .blue.opacity(0.5), radius: 30, x: 0, y: 15)
                .scaleEffect(showWelcomeAnimation ? 1.0 : 0.8)
                .animation(.spring(response: 0.8, dampingFraction: 0.6), value: showWelcomeAnimation)
            
            Image(systemName: "crown.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundColor(.white)
                .scaleEffect(showWelcomeAnimation ? 1.0 : 0.5)
                .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2), value: showWelcomeAnimation)
        }
    }
    
    private var welcomeTitleSection: some View {
        VStack(spacing: 16) {
            Text("Welcome to")
                .font(.title2)
                .foregroundColor(.secondary)
                .opacity(showWelcomeAnimation ? 1.0 : 0.0)
                .animation(.easeIn(duration: 0.5), value: showWelcomeAnimation)
            
            Text("FRPG")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .leading, endPoint: .trailing))
                .opacity(showWelcomeAnimation ? 1.0 : 0.0)
                .animation(.easeIn(duration: 0.5).delay(0.2), value: showWelcomeAnimation)
            
            Text("Your Fitness Adventure Begins")
                .font(.title3)
                .foregroundColor(.secondary)
                .opacity(showWelcomeAnimation ? 1.0 : 0.0)
                .animation(.easeIn(duration: 0.5).delay(0.4), value: showWelcomeAnimation)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
    }
    
    private var welcomePage: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 24) {
                welcomeHeroIcon
                welcomeTitleSection
            }
            
            Spacer()
        }
        .tag(0)
        .onAppear {
            withAnimation {
                showWelcomeAnimation = true
            }
        }
    }
    
    private var backgroundView: some View {
        LinearGradient(
            colors: [
                Color.blue.opacity(0.1),
                Color.purple.opacity(0.05),
                Color(.systemGroupedBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            progressIndicator
            
            TabView(selection: $page) {
                welcomePage
                // Additional pages will be added here by the remaining body content
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.5), value: page)
        }
    }
    
    private var featuresPage: some View {
        VStack(spacing: 30) {
            Spacer()
            
            VStack(spacing: 20) {
                Text("Level Up Your Life")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                
                Text("Track your progress like never before")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .opacity(showFeatures ? 1.0 : 0.0)
            .offset(y: showFeatures ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showFeatures)
            
            VStack(spacing: 20) {
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    OnboardingFeature(
                        icon: feature.icon,
                        title: feature.title,
                        subtitle: feature.description,
                        color: feature.color
                    )
                    .opacity(showFeatures ? 1.0 : 0.0)
                    .offset(x: showFeatures ? 0 : -30)
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.8)
                            .delay(Double(index) * 0.1),
                        value: showFeatures
                    )
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .tag(1)
        .onAppear {
            withAnimation {
                showFeatures = true
            }
        }
    }
    
    private var classPlacementPage: some View {
        VStack(spacing: 30) {
            Spacer()
            
            VStack(spacing: 20) {
                Text("Class Placement")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                
                Text("Choose 2 fitness goals to find your perfect class")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 30)
            
            // Goal selection using VStack/HStack for better reliability
            VStack(spacing: 16) {
                // Row 1
                HStack(spacing: 16) {
                    GoalSelectionCard(
                        goal: .strength,
                        isSelected: selectedGoals.contains(.strength)
                    ) {
                        toggleGoalSelection(.strength)
                    }
                    
                    GoalSelectionCard(
                        goal: .hypertrophy,
                        isSelected: selectedGoals.contains(.hypertrophy)
                    ) {
                        toggleGoalSelection(.hypertrophy)
                    }
                }
                
                // Row 2
                HStack(spacing: 16) {
                    GoalSelectionCard(
                        goal: .endurance,
                        isSelected: selectedGoals.contains(.endurance)
                    ) {
                        toggleGoalSelection(.endurance)
                    }
                    
                    GoalSelectionCard(
                        goal: .explosive,
                        isSelected: selectedGoals.contains(.explosive)
                    ) {
                        toggleGoalSelection(.explosive)
                    }
                }
                
                // Row 3
                HStack(spacing: 16) {
                    GoalSelectionCard(
                        goal: .mobility,
                        isSelected: selectedGoals.contains(.mobility)
                    ) {
                        toggleGoalSelection(.mobility)
                    }
                    
                    GoalSelectionCard(
                        goal: .bodyweight,
                        isSelected: selectedGoals.contains(.bodyweight)
                    ) {
                        toggleGoalSelection(.bodyweight)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .tag(2)
    }
    
    private var classRevealPage: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 20) {
                Text("Your Class")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                
                Text("Based on your goals, you are a...")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 30)
            
            // Class reveal without animations
            if let assignedClass = RPGClass.classPlacement(from: Set(selectedGoals)) {
                ClassPreviewCard(rpgClass: assignedClass)
                    .padding(.horizontal, 20)
            }
            
            Spacer()
        }
        .tag(3)
    }
    
    private var setupPage: some View {
        VStack(spacing: 30) {
            Spacer()
            
            VStack(spacing: 20) {
                Text("Almost There!")
                    .font(.largeTitle.bold())
                
                Text("Tell us your bodyweight to get started")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 24) {
                // Units picker
                Picker("Units", selection: $state.user.units) {
                    ForEach(Units.allCases, id: \.self) { u in
                        Text(u.displayName).tag(u)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
                
                // Weight display
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text("\(Int(bodyweightValue))")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .leading, endPoint: .trailing))
                        
                        Text(state.user.units.displayName.lowercased())
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Slider
                    Slider(value: $bodyweightValue, in: weightRange, step: 1)
                        .accentColor(.blue)
                        .frame(maxWidth: 300)
                    
                    // Range labels
                    HStack {
                        Text("\(Int(weightRange.lowerBound))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(weightRange.upperBound))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: 300)
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .tag(4)
    }
    
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            progressIndicator
            
            // Use TabView with native animations but block swipe gestures
            TabView(selection: $page) {
                welcomePage
                    .tag(0)
                featuresPage
                    .tag(1)
                classPlacementPage
                    .tag(2)
                classRevealPage
                    .tag(3)
                setupPage
                    .tag(4)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .onAppear {
                // Disable the swipe gesture on TabView
                UIScrollView.appearance().isScrollEnabled = false
            }
            .onDisappear {
                // Re-enable when leaving onboarding
                UIScrollView.appearance().isScrollEnabled = true
            }
            
            // Action Button
            VStack(spacing: 16) {
                Button(action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        if page < totalPages - 1 {
                            isMovingForward = true
                            page += 1
                        } else if bodyweightValid && selectedGoals.count == 2 {
                            // Complete onboarding
                            let kg = state.user.units.toKg(bodyweightValue)
                            state.user.bodyweightKg = kg
                            
                            // Assign the class based on selected goals
                            if let assignedClass = RPGClass.classPlacement(from: Set(selectedGoals)) {
                                state.user.rpgClass = assignedClass
                            }
                            
                            hasSeenOnboarding = true
                        }
                    }
                }) {
                    HStack {
                        Text(buttonTitle)
                            .font(.headline)
                        
                        Image(systemName: buttonIcon)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 32)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(canProceed ? Color.blue : Color.gray)
                    )
                }
                .disabled(!canProceed)
                .scaleEffect(canProceed ? 1.0 : 0.95)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: canProceed)
                
                if page > 0 {
                    Button("Back") {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            isMovingForward = false
                            page -= 1
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 30)
        }
    }

    var body: some View {
        backgroundView.overlay(mainContent)
        .onAppear {
            // Prefill from stored value (if any) or set default based on units
            if let bw = state.user.bodyweightKg {
                bodyweightValue = state.user.units.fromKg(bw)
            } else {
                // Set a reasonable default
                bodyweightValue = state.user.units == .kg ? 70 : 150
            }
        }
        .onChangeCompat(of: state.user.units) { oldU, newU in
            // Convert the slider value to the newly selected units
            let kg = oldU.toKg(bodyweightValue)
            bodyweightValue = newU.fromKg(kg)
        }
    }
}

struct OnboardingFeature: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var showConfirmReset = false
    @State private var bodyweightInput: String = ""
    @State private var showWeightError = false
    @State private var isEditingWeight = false
    @State private var isInitializing = false
    
    // Weight validation (same as onboarding)
    private var bodyweightValid: Bool {
        if let v = Double(bodyweightInput) {
            let kg = state.user.units.toKg(v)
            return kg >= 25 && kg <= 350
        }
        return false
    }
    
    private func levelTitle(for level: Int) -> String {
        switch level {
        case 1...10: return "Novice"
        case 11...20: return "Apprentice"
        case 21...30: return "Challenger"
        case 31...40: return "Warrior"
        case 41...50: return "Hero"
        case 51...60: return "Champion"
        default: return "Legend"
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 20) {
                        // Profile Summary Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(.blue)
                                        .frame(width: 60, height: 60)
                                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                                    
                                    Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    let level = state.user.displayLevel
                                    let title = levelTitle(for: level)
                                    Text("Level \(level) \(title)")
                                        .font(.title3.weight(.semibold))
                                        .foregroundColor(.primary)
                                    
                                    let prestige = state.user.prestigeLevel
                                    if prestige > 0 {
                                        Text("Prestige: \(prestige)")
                                            .font(.subheadline)
                                            .foregroundColor(.yellow)
                                    } else {
                                        Text("Ready for adventure")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("\(Int(state.user.xp)) XP")
                                        .font(.headline.weight(.semibold))
                                        .foregroundColor(.green)
                                    
                                    Text("\(state.history.count) workouts")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                        )
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                        
                        // Units & Profile Settings Card
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Profile Settings")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.primary)
                            
                            VStack(spacing: 16) {
                                // Units Selection
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "ruler")
                                            .font(.title3)
                                            .foregroundColor(.blue)
                                            .frame(width: 24)
                                        
                                        Text("Preferred Units")
                                            .font(.headline.weight(.medium))
                                            .foregroundColor(.primary)
                                    }
                                    
                                    Picker("Units", selection: $state.user.units) {
                                        ForEach(Units.allCases) { u in
                                            Text(u.displayName).tag(u)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                
                                Divider()
                                    .padding(.horizontal, -4)
                                
                                // Bodyweight Input
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "scalemass")
                                            .font(.title3)
                                            .foregroundColor(.green)
                                            .frame(width: 24)
                                        
                                        Text("Bodyweight")
                                            .font(.headline.weight(.medium))
                                            .foregroundColor(.primary)
                                    }
                                    
                                    VStack(spacing: 8) {
                                        HStack(spacing: 12) {
                                            TextField(
                                                state.user.units == .kg ? "e.g. 70" : "e.g. 155",
                                                text: $bodyweightInput
                                            )
                                            .keyboardType(.decimalPad)
                                            .font(.title3.weight(.medium))
                                            .multilineTextAlignment(.center)
                                            .textFieldStyle(ModernTextFieldStyle())
                                            .onTapGesture {
                                                isEditingWeight = true
                                            }
                                            .onSubmit {
                                                isEditingWeight = false
                                            }
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(
                                                        isEditingWeight ? (bodyweightValid && !bodyweightInput.isEmpty ? Color.green : (!bodyweightInput.isEmpty ? Color.red : Color.clear)) : Color.clear,
                                                        lineWidth: isEditingWeight && !bodyweightInput.isEmpty ? 2 : 0
                                                    )
                                            )
                                            .onChangeCompat(of: bodyweightInput) { _, _ in
                                                // Set editing state when user types (but not during initialization)
                                                if !isEditingWeight && !isInitializing {
                                                    isEditingWeight = true
                                                }
                                                
                                                if bodyweightValid, let v = Double(bodyweightInput) {
                                                    let kg = state.user.units.toKg(v)
                                                    state.user.bodyweightKg = kg
                                                    showWeightError = false
                                                    state.save()
                                                } else if !bodyweightInput.isEmpty {
                                                    showWeightError = true
                                                }
                                            }
                                            
                                            Text(state.user.units.displayName)
                                                .font(.headline.weight(.semibold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 12)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(.green)
                                                )
                                        }
                                        
                                        // Error message
                                        if showWeightError && !bodyweightInput.isEmpty && !bodyweightValid {
                                            let rangeText = (state.user.units == .kg) ? "25–350 kg" : "55–770 lb"
                                            HStack(spacing: 8) {
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .foregroundColor(.red)
                                                    .font(.caption)
                                                Text("Weight must be between \(rangeText)")
                                                    .font(.caption.weight(.medium))
                                                    .foregroundColor(.red)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                        )
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                        
                        // Developer Tools Card
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Developer Tools")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.primary)
                            
                            VStack(spacing: 12) {
                                ModernActionButton(
                                    title: "Add 50 XP",
                                    subtitle: "Quick experience boost",
                                    icon: "star.fill",
                                    color: .blue,
                                    action: { state.addXP(50) }
                                )
                                
                                ModernActionButton(
                                    title: "Boost All Stats",
                                    subtitle: "+10 to all attributes",
                                    icon: "chart.bar.fill",
                                    color: .green,
                                    action: {
                                        state.user.stats.size += 10
                                        state.user.stats.strength += 10
                                        state.user.stats.dexterity += 10
                                        state.user.stats.agility += 10
                                        state.user.stats.endurance += 10
                                        state.user.stats.vitality += 10
                                        state.save()
                                    }
                                )
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                        )
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                        
                        // Danger Zone Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.title3)
                                    .foregroundColor(.red)
                                
                                Text("Danger Zone")
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(.primary)
                            }
                            
                            ModernActionButton(
                                title: "Reset All Data",
                                subtitle: "This cannot be undone",
                                icon: "trash.fill",
                                color: .red,
                                action: { showConfirmReset = true }
                            )
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                        
                        // App Info
                        VStack(spacing: 8) {
                            Text("FRPG")
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.primary)
                            
                            Text("Version 0.1 • MVP Build")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Transform your fitness into an epic adventure")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Settings")
            .dismissKeyboardOnTap()
            .dismissKeyboardOnSwipe()
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        isEditingWeight = false
                    }
            )
            .onAppear {
                // Set initialization flag to prevent editing state during setup
                isInitializing = true
                isEditingWeight = false
                
                // Initialize bodyweight input from stored value
                if let bw = state.user.bodyweightKg {
                    bodyweightInput = String(format: "%.0f", state.user.units.fromKg(bw))
                }
                
                // Clear initialization flag after a brief delay to ensure all setup is done
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isInitializing = false
                }
            }
            .onChangeCompat(of: state.user.units) { oldU, newU in
                // Convert input when units change (also during initialization)
                if !bodyweightInput.isEmpty, let currentValue = Double(bodyweightInput) {
                    isInitializing = true // Prevent editing state during units conversion
                    let kgValue = oldU.toKg(currentValue)
                    bodyweightInput = String(format: "%.0f", newU.fromKg(kgValue))
                    
                    // Clear initialization flag after conversion
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isInitializing = false
                    }
                }
            }
            .alert("Reset all data?", isPresented: $showConfirmReset) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) { state.resetAll() }
            } message: {
                Text("This will permanently delete all your workouts, progress, and settings. This action cannot be undone.")
            }
        }
    }
}

// MARK: - Quests/Challenges UI

struct QuestsView: View {
    @EnvironmentObject var state: AppState
    @State private var showClassSelection = false
    @State private var showChallengeSettings = false
    
    var body: some View {
        NavigationView {
            if state.user.rpgClass == nil {
                // No class selected - show class selection prompt
                VStack(spacing: 30) {
                    Spacer()
                    
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 12) {
                        Text("Choose Your Class")
                            .font(.title.bold())
                        
                        Text("Select a class to receive daily and weekly quests tailored to your preferred training style.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Button(action: { showClassSelection = true }) {
                        Text("Select Class")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: 200)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    
                    Spacer()
                }
                .navigationTitle("Quests")
                .sheet(isPresented: $showClassSelection) {
                    ClassSelectionView()
                        .environmentObject(state)
                }
            } else {
                // Class selected - show challenges
                ScrollView {
                    VStack(spacing: 20) {
                        // Class Header
                        ClassHeaderCard()
                            .environmentObject(state)
                        
                        // Daily Quests
                        QuestSection(
                            title: "Daily Quests",
                            icon: "sun.max.fill",
                            challenges: state.user.dailyChallenges.filter { $0.isActive }
                        )
                        .environmentObject(state)
                        
                        // Weekly Quests
                        QuestSection(
                            title: "Weekly Quests",
                            icon: "calendar.badge.clock",
                            challenges: state.user.weeklyChallenges.filter { $0.isActive }
                        )
                        .environmentObject(state)
                        
                        // Completed Quests
                        if !state.user.dailyChallenges.filter({ $0.isCompleted }).isEmpty ||
                           !state.user.weeklyChallenges.filter({ $0.isCompleted }).isEmpty {
                            CompletedQuestsSection()
                                .environmentObject(state)
                        }
                    }
                    .padding()
                }
                .navigationTitle("Quests")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button(action: { showChallengeSettings = true }) {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundColor(.blue)
                        }
                        
                        Button(action: { showClassSelection = true }) {
                            Image(systemName: "person.crop.circle")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .sheet(isPresented: $showClassSelection) {
                    ClassSelectionView()
                        .environmentObject(state)
                }
                .sheet(isPresented: $showChallengeSettings) {
                    ChallengeSettingsView()
                        .environmentObject(state)
                }
                .onAppear {
                    // Update existing challenges to consistent XP first
                    state.updateExistingChallengeXP()
                    // Generate challenges if needed
                    state.generateDailyChallenges()
                    state.generateWeeklyChallenges()
                }
            }
        }
    }
}

struct ClassHeaderCard: View {
    @EnvironmentObject var state: AppState
    
    var body: some View {
        if let rpgClass = state.user.rpgClass {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: rpgClass.icon)
                        .font(.system(size: 30))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        Text(rpgClass.displayName)
                            .font(.title2.bold())
                        Text(rpgClass.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.blue.opacity(0.1))
                )
            }
        }
    }
}

struct QuestSection: View {
    let title: String
    let icon: String
    let challenges: [Challenge]
    @EnvironmentObject var state: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.orange)
                Text(title)
                    .font(.title3.bold())
                Spacer()
            }
            
            if challenges.isEmpty {
                Text("No active \(title.lowercased())")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical)
            } else {
                ForEach(challenges) { challenge in
                    ChallengeCard(challenge: challenge)
                        .environmentObject(state)
                }
            }
        }
    }
}

struct ChallengeCard: View {
    let challenge: Challenge
    @EnvironmentObject var state: AppState
    @Environment(\.colorScheme) var colorScheme
    
    var progressColor: Color {
        if challenge.isCompleted { return .green }
        // Use stat color for progress bar
        return statColor
    }
    
    // Get stat color based on challenge category
    var statColor: Color {
        switch challenge.targetCategory {
        case .strength: return .red
        case .hypertrophy: return colorScheme == .dark ? .white : .black
        case .endurance: return .blue
        case .explosive: return .yellow  // Agility
        case .mobility: return .green  // Vitality
        case .bodyweight: return .orange  // Dexterity
        }
    }
    
    // Get stat icon based on challenge category (matching stats screen icons)
    var statIcon: String {
        switch challenge.targetCategory {
        case .strength: return "dumbbell.fill" // Strength stat
        case .hypertrophy: return "arrow.up.left.and.down.right.magnifyingglass" // Size stat
        case .endurance: return "infinity" // Endurance stat
        case .explosive: return "hare.fill" // Agility stat
        case .mobility: return "heart.fill" // Vitality stat
        case .bodyweight: return "hand.palm.facing.fill" // Dexterity stat
        }
    }
    
    // Get border color based on challenge type (softer gold tones)
    var borderColor: Color {
        challenge.type == .daily ? Color(red: 0.9, green: 0.75, blue: 0.3) : Color(red: 0.85, green: 0.65, blue: 0.25)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(challenge.title)
                            .font(.headline)
                            .foregroundColor(challenge.isCompleted ? .green : .primary)
                        
                        // Daily/Weekly badge
                        Text(challenge.type == .daily ? "DAILY" : "WEEKLY")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(borderColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(borderColor.opacity(0.2))
                                    .overlay(
                                        Capsule()
                                            .stroke(borderColor.opacity(0.5), lineWidth: 0.5)
                                    )
                            )
                    }
                    
                    Text(challenge.unit == .exercises ?
                         "\(challenge.uniqueExercises.count)/\(challenge.targetAmount) \(challenge.unit.displayName)" :
                         "\(challenge.progress)/\(challenge.targetAmount) \(challenge.unit.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 8) {
                        // XP and completion status
                        if challenge.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                        } else {
                            Text("+\(challenge.expReward) XP")
                                .font(.caption.bold())
                                .foregroundColor(.green)
                        }
                        
                        // Smaller stat icon badge on the right
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(statColor.opacity(0.15))
                                .frame(width: 24, height: 24)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(statColor.opacity(0.3), lineWidth: 1)
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: statIcon)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(statColor)
                        }
                    }
                    
                    if !challenge.isCompleted {
                        Text(timeRemaining(until: challenge.expiresAt))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(width: geometry.size.width * challenge.progressPercentage, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(
            ZStack {
                // Outer gold border
                RoundedRectangle(cornerRadius: 14)
                    .fill(borderColor.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(borderColor, lineWidth: 2)
                    )
                
                // Inner background (neutral color)
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(borderColor.opacity(0.5), lineWidth: 1)
                    )
                    .padding(2)
            }
        )
        .shadow(color: borderColor.opacity(0.2), radius: 4, x: 0, y: 2)
    }
    
    func timeRemaining(until date: Date) -> String {
        let interval = date.timeIntervalSince(Date())
        if interval <= 0 { return "Expired" }
        
        let hours = Int(interval) / 3600
        let days = hours / 24
        
        if days > 0 {
            return "\(days)d remaining"
        } else {
            return "\(hours)h remaining"
        }
    }
}

struct CompletedQuestsSection: View {
    @EnvironmentObject var state: AppState
    
    var completedChallenges: [Challenge] {
        (state.user.dailyChallenges + state.user.weeklyChallenges)
            .filter { $0.isCompleted }
            .sorted { $0.completedAt ?? Date() > $1.completedAt ?? Date() }
            .prefix(5)
            .map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3)
                    .foregroundColor(.green)
                Text("Completed")
                    .font(.title3.bold())
                Spacer()
            }
            
            ForEach(completedChallenges) { challenge in
                HStack {
                    VStack(alignment: .leading) {
                        Text(challenge.title)
                            .font(.subheadline)
                            .strikethrough()
                            .foregroundColor(.secondary)
                        Text("+\(challenge.expReward) XP earned")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green.opacity(0.1))
                )
            }
        }
    }
}

struct ClassSelectionView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @State private var selectedClass: RPGClass?
    @State private var showChangeClassAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Choose Your Class")
                        .font(.largeTitle.bold())
                        .padding(.top)
                    
                    Text("Your class determines the types of quests you'll receive")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    ForEach(RPGClass.allCases, id: \.self) { rpgClass in
                        ClassSelectionCard(
                            rpgClass: rpgClass,
                            isSelected: selectedClass == rpgClass,
                            onTap: {
                                selectedClass = rpgClass
                            }
                        )
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Confirm") {
                        if let selectedClass = selectedClass {
                            // Check if user already has a class (changing classes)
                            if state.user.rpgClass != nil {
                                showChangeClassAlert = true
                            } else {
                                // First time selecting class
                                state.setRPGClass(selectedClass)
                                dismiss()
                            }
                        }
                    }
                    .disabled(selectedClass == nil)
                    .font(.headline)
                }
            }
            .alert("Change Class?", isPresented: $showChangeClassAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Change Class", role: .destructive) {
                    if let selectedClass = selectedClass {
                        state.changeRPGClassWithQuestReset(selectedClass)
                        dismiss()
                    }
                }
            } message: {
                Text("Changing your class will reset your current quest progress but keep the quest timers. Are you sure you want to continue?")
            }
        }
    }
}

struct ClassSelectionCard: View {
    let rpgClass: RPGClass
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: rpgClass.icon)
                        .font(.system(size: 30))
                        .foregroundColor(isSelected ? .white : .blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rpgClass.displayName)
                            .font(.headline)
                            .foregroundColor(isSelected ? .white : .primary)
                        
                        Text(rpgClass.description)
                            .font(.caption)
                            .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                
                // Preview exercises
                HStack {
                    Text("Focus:")
                        .font(.caption2.bold())
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    
                    ForEach(Array(rpgClass.preferredExercises.prefix(3)), id: \.self) { exercise in
                        Text(exercise.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.white.opacity(0.2) : Color.blue.opacity(0.1))
                            )
                            .foregroundColor(isSelected ? .white : .blue)
                    }
                    
                    if rpgClass.preferredExercises.count > 3 {
                        Text("+\(rpgClass.preferredExercises.count - 3)")
                            .font(.caption2)
                            .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue : Color(UIColor.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Inventory UI Components

struct InventoryView: View {
    @EnvironmentObject var state: AppState
    @State private var showTreasureVault = false
    @State private var selectedChest: TreasureChest?
    @State private var showChestRewards = false
    @State private var chestOpeningStep = 0 // 0 = closed, 1 = white screen, 2 = chest opening
    @State private var chestSpinRotation: Double = 0
    @State private var isSpinning = false
    @State private var isDraggedOver = false
    @State private var showDeleteInstructions = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Content based on selection
                if showTreasureVault {
                    TreasureVaultView(selectedChest: $selectedChest, showChestRewards: $showChestRewards, chestOpeningStep: $chestOpeningStep, showTreasureVault: $showTreasureVault)
                } else {
                    InventoryItemsView(showTreasureVault: $showTreasureVault)
                }
            }
            .navigationTitle(showTreasureVault ? "Card Deck" : "Inventory")
            .navigationBarTitleDisplayMode(.large)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Debug") {
                        generateTestChests()
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !showTreasureVault {
                        // Only show trash can in inventory view - acts as drop zone
                        Image(systemName: "trash.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(isDraggedOver ? .orange : .red)
                            .scaleEffect(isDraggedOver ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDraggedOver)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    showDeleteInstructions = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        showDeleteInstructions = false
                                    }
                                }
                            }
                            .dropDestination(for: String.self) { items, location in
                                // Handle dropped items
                                for itemIdString in items {
                                    if let itemId = UUID(uuidString: itemIdString) {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            state.user.inventory.removeAll { $0.id == itemId }
                                        }
                                    }
                                }
                                return true
                            } isTargeted: { targeted in
                                isDraggedOver = targeted
                            }
                    }
                }
                
            })
            .background(Color(UIColor.systemGroupedBackground))
        }
        .overlay(
            // Apple-style delete instructions alert
            showDeleteInstructions ? ZStack {
                // Background overlay
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    VStack(spacing: 16) {
                        Image(systemName: "hand.draw")
                            .font(.system(size: 50, weight: .regular))
                            .foregroundColor(.blue)
                        
                        VStack(spacing: 8) {
                            Text("Drag to Delete")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("Drag items to the trash icon to delete them from your inventory.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                        }
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 20)
                }
                .frame(maxWidth: 270)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(UIColor.systemBackground))
                )
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                .scaleEffect(showDeleteInstructions ? 1.0 : 0.8)
                .opacity(showDeleteInstructions ? 1.0 : 0.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showDeleteInstructions)
            } : nil
        )
        .overlay(
            // Two-step chest opening popup
            showChestRewards && selectedChest != nil ? ZStack {
                // Adaptive background overlay
                (colorScheme == .dark ? Color.black : Color.white).opacity(1.0)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Allow dismissing on any step by tapping outside
                        showChestRewards = false
                        selectedChest = nil
                        chestOpeningStep = 0
                        isSpinning = false
                        chestSpinRotation = 0
                    }
                
                if chestOpeningStep == 1, let chest = selectedChest {
                    // Step 1: Scaled up version of the chest card
                    ZStack {
                        // Stationary glow effect for Epic and Mythic chests
                        if chest.type == .epic || chest.type == .mythic {
                            RoundedRectangle(cornerRadius: ChestCardDesign.cornerRadius * 2.2)
                                .fill(chestColorForType(chest.type).opacity(isSpinning ? 0.3 : 0.1))
                                .frame(width: ChestCardDesign.cardWidth * 2.2 * 1.15,
                                       height: ChestCardDesign.cardHeight * 2.2 * 1.15)
                                .blur(radius: isSpinning ? 30 : 20)
                                .scaleEffect(isSpinning ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isSpinning)
                                .allowsHitTesting(false)  // Glow doesn't block taps
                        }
                        
                        // Spinning chest card
                        TreasureChestCardDisplay(chest: chest, scale: 2.2, hideGlow: true)
                            .rotation3DEffect(
                                .degrees(chestSpinRotation),
                                axis: (x: 0, y: 1, z: 0)
                            )
                            .onTapGesture {
                                if isSpinning {
                                    // If spinning, tap to skip and go straight to opening
                                    chestOpeningStep = 2
                                    isSpinning = false
                                    chestSpinRotation = 0
                                } else {
                                    // If not spinning, start the spin animation
                                    isSpinning = true
                                    
                                    // Single smooth acceleration curve from slow to fast
                                    withAnimation(.timingCurve(0.1, 0, 0.25, 1, duration: 1.8)) {
                                        chestSpinRotation += 4680  // 13 total rotations
                                    }
                                    
                                    // Transition to next step after spinning completes
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                        // Only transition if we haven't already skipped
                                        if isSpinning {
                                            chestOpeningStep = 2
                                            isSpinning = false
                                            chestSpinRotation = 0
                                        }
                                    }
                                }
                            }
                    }
                    .scaleEffect(chestOpeningStep == 1 ? 1.0 : 0.8)
                    .opacity(chestOpeningStep == 1 ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: chestOpeningStep)
                } else if chestOpeningStep == 2, let chest = selectedChest {
                    // Step 2: Chest opening animation and rewards (compact card view)
                    TreasureChestRewardsView(chest: chest) {
                        openChest(chest)
                        // Don't auto-dismiss - let user tap outside to dismiss manually
                    }
                    .scaleEffect(chestOpeningStep == 2 ? 1.0 : 0.8)
                    .opacity(chestOpeningStep == 2 ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: chestOpeningStep)
                }
            } : nil
        )
    }
    
    // Debug function to generate test chests of each rarity
    private func generateTestChests() {
        let rarities: [TreasureChestType] = [.common, .uncommon, .rare, .epic, .mythic]
        
        for rarity in rarities {
            let testChest = StatEngine.generateTreasureChest(forLevel: state.user.level, forcedType: rarity)
            state.user.treasureChests.append(testChest)
        }
        
        state.save()
    }
    
    private func openChest(_ chest: TreasureChest) {
        if let index = state.user.treasureChests.firstIndex(where: { $0.id == chest.id }) {
            state.user.treasureChests[index].isOpened = true
            applyRewards(chest.rewards)
            state.save()
        }
    }
    
    private func chestColorForType(_ type: TreasureChestType) -> Color {
        switch type {
        case .common: return .brown
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .mythic: return .red
        }
    }
    
    private func applyRewards(_ rewards: [TreasureReward]) {
        for reward in rewards {
            switch reward.type {
            case .bonus_xp:
                state.addXP(reward.amount)
                
            case .coins:
                // Add coins to user's collection
                state.user.coins += Int(reward.amount)
                
            case .item:
                // Add item to inventory
                if let itemInfo = reward.itemInfo {
                    let inventoryItem = createInventoryItem(from: itemInfo)
                    addItemToInventory(inventoryItem)
                }
            }
        }
    }
    
    // Helper function to convert ItemInfo to InventoryItem
    private func createInventoryItem(from itemInfo: ItemInfo) -> InventoryItem {
        let name = itemInfo.displayName
        let iconName = itemInfo.iconName
        let rarity = mapItemInfoToInventoryRarity(itemInfo)
        
        return InventoryItem(
            name: name,
            description: "A \(rarity.rawValue) \(name.lowercased())",
            type: .collectible, // All our items are collectibles for now
            rarity: rarity,
            iconName: iconName,
            quantity: 1,
            dateObtained: Date(),
            value: valueForRarity(rarity)
        )
    }
    
    // Helper function to map ItemInfo rarity to InventoryItemRarity
    private func mapItemInfoToInventoryRarity(_ itemInfo: ItemInfo) -> InventoryItemRarity {
        let rarityString = itemInfo.rarity.lowercased()
        switch rarityString {
        case "uncommon": return .uncommon
        case "rare": return .rare
        case "epic": return .epic
        case "legendary": return .legendary
        case "mythic": return .mythic
        default: return .common
        }
    }
    
    // Helper function to assign value based on rarity
    private func valueForRarity(_ rarity: InventoryItemRarity) -> Int {
        switch rarity {
        case .common: return 10
        case .uncommon: return 25
        case .rare: return 50
        case .epic: return 100
        case .legendary: return 200
        case .mythic: return 250
        }
    }
    
    // Helper function to add item to inventory (no stacking - each item separate)
    private func addItemToInventory(_ newItem: InventoryItem) {
        // Always add as new item, no stacking
        state.user.inventory.append(newItem)
    }
}

struct TreasureVaultView: View {
    @EnvironmentObject var state: AppState
    @Binding var selectedChest: TreasureChest?
    @Binding var showChestRewards: Bool
    @Binding var chestOpeningStep: Int
    @Binding var showTreasureVault: Bool
    @State private var showTitle = false
    @Environment(\.colorScheme) var colorScheme
    
    // Simple deck browsing
    @State private var topCardIndex = 0
    @State private var dragOffset: CGFloat = 0
    @State private var cardSwitchAnimation: Bool = false
    @State private var swipeDirection: CGFloat = 0 // Positive for right swipe, negative for left swipe
    
    // Sorting state
    @State private var sortByRarity = false
    @State private var rarestFirst = true // true = rarest first, false = most common first
    
    var unopenedChests: [TreasureChest] {
        let filtered = state.user.treasureChests.filter { !$0.isOpened }
        
        if sortByRarity {
            return filtered.sorted { chest1, chest2 in
                let rarity1 = rarityValue(chest1.type)
                let rarity2 = rarityValue(chest2.type)
                
                if rarestFirst {
                    return rarity1 > rarity2 // Higher value = rarer
                } else {
                    return rarity1 < rarity2 // Lower value = more common
                }
            }
        } else {
            return filtered // Original order (by date earned)
        }
    }
    
    // Rarity ranking: higher number = rarer
    private func rarityValue(_ type: TreasureChestType) -> Int {
        switch type {
        case .common: return 1
        case .uncommon: return 2
        case .rare: return 3
        case .epic: return 4
        case .mythic: return 5
        }
    }
    
    var body: some View {
        ZStack {
            
            VStack(spacing: 20) {
                    // Epic title with animation
                    
                    if unopenedChests.isEmpty {
                        EmptyTreasureStateAnimated(isVisible: showTitle)
                    } else {
                        VStack(spacing: 0) {
                            // Fixed position card deck container
                            ZStack {
                                // Only render up to 20 cards (no fade, all fully visible)
                                ForEach(0..<min(unopenedChests.count, 20), id: \.self) { index in
                                    let chestIndex = (topCardIndex + index) % unopenedChests.count
                                    
                                    DeckCard(
                                        chest: unopenedChests[chestIndex],
                                        index: index,
                                        dragOffset: index == 0 ? dragOffset : 0,
                                        isVisible: true,
                                        cardSwitchAnimation: cardSwitchAnimation,
                                        totalCards: unopenedChests.count,
                                        swipeDirection: swipeDirection
                                    ) {
                                        selectedChest = unopenedChests[chestIndex]
                                        showChestRewards = true
                                        chestOpeningStep = 1
                                    }
                                }
                            }
                            .id("\(sortByRarity)-\(rarestFirst)") // Force re-render when sort changes
                            .frame(maxWidth: .infinity, minHeight: 370) // Fixed height for consistent positioning
                            .padding(.top, 60) // Fixed top padding that won't change
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        if unopenedChests.count > 1 {
                                            dragOffset = value.translation.width
                                        }
                                    }
                                    .onEnded { value in
                                        guard unopenedChests.count > 1 else { return }
                                        let swipeThreshold: CGFloat = 60
                                        let velocity = abs(value.velocity.width)
                                        let dragDistance = abs(value.translation.width)
                                        
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            if dragDistance > swipeThreshold || velocity > 300 {
                                                // This is a swipe gesture - trigger back card animation
                                                cardSwitchAnimation = true
                                                swipeDirection = value.translation.width > 0 ? 1 : -1 // Track swipe direction
                                                if value.translation.width > 0 {
                                                    // Swipe right - show previous card (loop to end if at beginning)
                                                    topCardIndex = (topCardIndex - 1 + unopenedChests.count) % unopenedChests.count
                                                } else if value.translation.width < 0 {
                                                    // Swipe left - show next card (loop to beginning if at end)
                                                    topCardIndex = (topCardIndex + 1) % unopenedChests.count
                                                }
                                                // Reset animation flag after a short delay
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                                    cardSwitchAnimation = false
                                                }
                                            }
                                            dragOffset = 0
                                        }
                                    }
                            )
                            
                            // Controls container below the card deck
                            VStack(spacing: 12) {
                                // Sort controls - now below the cards
                                HStack(spacing: 8) {
                                    Button(action: {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            sortByRarity.toggle()
                                            topCardIndex = 0 // Reset to first card when sorting changes
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: sortByRarity ? "line.3.horizontal.decrease" : "calendar")
                                            Text(sortByRarity ? "By Rarity" : "By Date")
                                        }
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(sortByRarity ? .white : .primary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(sortByRarity ? .blue : .clear)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(sortByRarity ? .clear : Color(.separator), lineWidth: 0.5)
                                                )
                                        )
                                    }
                                    .disabled(unopenedChests.count <= 1)
                                    .opacity(unopenedChests.count > 1 ? 1.0 : 0.0)
                                    
                                    if sortByRarity && unopenedChests.count > 1 {
                                        Button(action: {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                rarestFirst.toggle()
                                                topCardIndex = 0 // Reset to first card when sort order changes
                                            }
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: rarestFirst ? "arrow.up" : "arrow.down")
                                                Text(rarestFirst ? "Rare→Common" : "Common→Rare")
                                            }
                                            .font(.caption.weight(.medium))
                                            .foregroundColor(.primary)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(.ultraThinMaterial)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                    }
                                }
                                .frame(height: unopenedChests.count > 1 ? nil : 0) // Collapse when only 1 card
                                
                                // Swipe instruction - show when 2-20 cards, hide when slider appears
                                if unopenedChests.count > 1 && unopenedChests.count <= 20 {
                                    Text("← Swipe to browse deck →")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 5)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Capsule())
                                }
                                
                                // Slider for quick navigation through cards - only show when cards exceed visible limit
                                if unopenedChests.count > 20 {
                                    HStack(spacing: 12) {
                                        // Start dot with number
                                        Text("1")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        
                                        Circle()
                                            .fill(Color.white.opacity(0.3))
                                            .frame(width: 4, height: 4)
                                        
                                        Slider(
                                            value: Binding(
                                                get: {
                                                    // Invert the slider position
                                                    Double(unopenedChests.count - 1 - topCardIndex)
                                                },
                                                set: { newValue in
                                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                        // Invert back when setting
                                                        topCardIndex = unopenedChests.count - 1 - Int(newValue)
                                                    }
                                                }
                                            ),
                                            in: 0...Double(unopenedChests.count - 1),
                                            step: 1
                                        )
                                        .tint(.white)
                                        
                                        // End dot with number
                                        Circle()
                                            .fill(Color.white.opacity(0.3))
                                            .frame(width: 4, height: 4)
                                        
                                        Text("\(unopenedChests.count)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 40)
                                }
                            }
                            .padding(.top, -40) // Bring controls closer to cards
                        }
                    }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // Apple-style segmented control overlay at top
            VStack {
                HStack(spacing: 0) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showTreasureVault = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "bag")
                                .font(.system(size: 14, weight: .medium))
                            Text("Inventory")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(.blue)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(Color.clear)
                    }
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showTreasureVault = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "rectangle.stack.badge.plus")
                                .font(.system(size: 14, weight: .medium))
                            Text("Card Deck")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color.blue)
                        )
                    }
                }
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                )
                .padding(.horizontal, 20.5)
                .padding(.top, 16)
                
                Spacer()
            }
        }
        .onChangeCompat(of: sortByRarity) { _, _ in
            // Reset to top when sort method changes
            topCardIndex = 0
        }
        .onChangeCompat(of: rarestFirst) { _, _ in
            // Reset to top when sort direction changes
            topCardIndex = 0
        }
        .onAppear {
            startEntranceAnimation()
        }
    }
    
    private func startEntranceAnimation() {
        // Reset animation states
        showTitle = false
        topCardIndex = 0
        
        // Animate title
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
            showTitle = true
        }
    }
    
    
}

struct DeckCard: View {
    let chest: TreasureChest
    let index: Int
    let dragOffset: CGFloat
    let isVisible: Bool
    let cardSwitchAnimation: Bool
    let totalCards: Int
    let swipeDirection: CGFloat
    let onTap: () -> Void
    
    private var opacity: Double {
        cardOpacity(for: index)
    }
    
    var body: some View {
        // Don't render anything if completely invisible
        if opacity <= 0 {
            EmptyView()
        } else {
            TreasureChestCard(chest: chest, onTap: onTap, index: index)
                .scaleEffect(1.4) // Scale up the entire card and all its contents
                .opacity(opacity)
                .scaleEffect(1.0 - CGFloat(index) * 0.02) // Additional scale for depth
                .rotation3DEffect(.degrees(Double(index) * 5), axis: (x: 0, y: 0, z: 1)) // Increased rotation for more spiral
                .offset(
                    x: dragOffset * 0.3, // Keep centered on vertical axis - no horizontal offset for spiral
                    y: CGFloat(index) * -10 // Adjusted for larger cards
                )
                // Add movement only to the last visible card in the deck - opposite to swipe direction
                .offset(x: cardSwitchAnimation && index == min(19, totalCards - 1) && index > 0 ? -swipeDirection * 4.0 : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: cardSwitchAnimation)
                .zIndex(Double(10 - index))
                .shadow(
                    color: .black.opacity(0.2),
                    radius: 4 + CGFloat(index) * 1.5,
                    x: 2 + CGFloat(index),
                    y: 3 + CGFloat(index) * 1.5
                )
        }
    }
    
    // Calculate opacity based on card position in stack
    private func cardOpacity(for index: Int) -> Double {
        if !isVisible { return 0.0 }
        // No fade - all cards up to index 20 are fully visible
        // Cards 20+: Invisible (0.0)
        return index < 20 ? 1.0 : 0.0
    }
}

struct InventoryItemsView: View {
    @EnvironmentObject var state: AppState
    @Binding var showTreasureVault: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Apple-style segmented control
                HStack(spacing: 0) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showTreasureVault = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "bag")
                                .font(.system(size: 14, weight: .medium))
                            Text("Inventory")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color.blue)
                        )
                    }
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showTreasureVault = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "rectangle.stack.badge.plus")
                                .font(.system(size: 14, weight: .medium))
                            Text("Card Deck")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(.blue)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.clear)
                    }
                }
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                )
                .padding(.horizontal, 20)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    // Show actual inventory items and empty slots up to 32 total (4x8)
                    ForEach(0..<32, id: \.self) { index in
                        if index < state.user.inventory.count {
                            // Show actual inventory item
                            let item = state.user.inventory[index]
                            InventoryItemCard(item: item)
                        } else {
                            // Show empty inventory slot
                            EmptyInventorySlot()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .padding(.vertical, 16)
        }
    }
    
}

// MARK: - Standardized Treasure Chest Card Design
/*
 * LOCKED DESIGN SPECIFICATIONS:
 *
 * DIMENSIONS:
 * - Card: 160x200 total frame
 * - Chest: 120x160 rounded rectangle (cornerRadius: 16)
 *
 * BORDERS & OVERLAYS:
 * - Inner white border: 6pt strokeBorder
 * - Outer colored border: 2-3pt stroke (animated for Epic/Mythic)
 * - Card pattern: RadialGradient + diagonal lines
 * - Shine effect: Linear gradient overlay
 *
 * RARITY SYSTEM:
 * - Common: Heart (♥️) - Brown gradient
 * - Uncommon: Club (♣️) - Green gradient
 * - Rare: Diamond (♦️) - Blue gradient
 * - Epic: Spade (♠️) - Purple gradient + glow
 * - Mythic: Crown (👑) - Red gradient + glow + sparkles
 *
 * ANIMATIONS:
 * - Tap bounce: 0.95 scale + 3D rotation
 * - Icon: 42pt size, white color
 * - Epic/Mythic: Pulsing glow effect
 * - Mythic only: 6 stationary fade sparkles
 *
 * LAYOUT:
 * - Vertical stack with 12pt spacing
 * - Icon centered in card
 * - Text below: headline.semibold, primary color
 */

// MARK: - Shared Card Surface Design
struct EnhancedCardSurface: View {
    let chest: TreasureChest
    let scale: CGFloat
    
    var body: some View {
        // Multi-layered surface design
        ZStack {
            // Base metallic shimmer
            RoundedRectangle(cornerRadius: ChestCardDesign.cornerRadius * scale)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.35),
                            Color.clear,
                            Color.white.opacity(0.25),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Radial highlight from top-left
            RoundedRectangle(cornerRadius: ChestCardDesign.cornerRadius * scale)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.4),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 20 * scale,
                        endRadius: 100 * scale
                    )
                )
            
            // Crosshatch pattern overlay
            Path { path in
                // Diagonal lines going down-right
                for i in stride(from: -40 * scale, through: 160 * scale, by: 12 * scale) {
                    path.move(to: CGPoint(x: i, y: 0))
                    path.addLine(to: CGPoint(x: i + 160 * scale, y: 160 * scale))
                }
                // Diagonal lines going down-left
                for i in stride(from: -40 * scale, through: 160 * scale, by: 12 * scale) {
                    path.move(to: CGPoint(x: i, y: 160 * scale))
                    path.addLine(to: CGPoint(x: i + 160 * scale, y: 0))
                }
            }
            .stroke(Color.white.opacity(0.15), lineWidth: 0.8 * scale)
            .clipShape(RoundedRectangle(cornerRadius: ChestCardDesign.cornerRadius * scale))
            
            // Corner decorations for all rarities
            VStack {
                HStack {
                    // Top-left ornament
                    Image(systemName: "sparkle")
                        .font(.system(size: 8 * scale))
                        .foregroundColor(.white.opacity(0.6))
                        .offset(x: 8 * scale, y: 8 * scale)
                    Spacer()
                    // Top-right ornament
                    Image(systemName: "sparkle")
                        .font(.system(size: 8 * scale))
                        .foregroundColor(.white.opacity(0.6))
                        .offset(x: -8 * scale, y: 8 * scale)
                }
                Spacer()
                HStack {
                    // Bottom-left ornament
                    Image(systemName: "sparkle")
                        .font(.system(size: 8 * scale))
                        .foregroundColor(.white.opacity(0.6))
                        .offset(x: 8 * scale, y: -8 * scale)
                    Spacer()
                    // Bottom-right ornament
                    Image(systemName: "sparkle")
                        .font(.system(size: 8 * scale))
                        .foregroundColor(.white.opacity(0.6))
                        .offset(x: -8 * scale, y: -8 * scale)
                }
            }
            
            // Central embossed circle pattern
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.25), Color.clear, Color.black.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5 * scale
                )
                .frame(width: 60 * scale, height: 60 * scale)
                .opacity(0.8)
            
            // Inner circle
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 1.0 * scale)
                .frame(width: 40 * scale, height: 40 * scale)
        }
    }
}

struct TreasureChestCard: View {
    let chest: TreasureChest
    let onTap: () -> Void
    let index: Int
    @Environment(\.colorScheme) var colorScheme
    @State private var isAnimating = false
    @State private var bounceAnimation = false
    @State private var glowPulse = false
    @State private var sparkleOffset = 0.0
    
    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                // Main chest container with all effects
                ZStack {
                    // Background glow effect (only for Epic and Mythic on top card)
                    if shouldShowGlow {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(chestColor.opacity(glowPulse ? 0.7 : 0.25))
                            .blur(radius: glowPulse ? 20 : 12)
                            .scaleEffect(glowPulse ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: glowPulse)
                    }
                    
                    // Sparkles for Mythic chests only (top card only)
                    if chest.type == .mythic && shouldShowGlow {
                        ForEach(0..<6, id: \.self) { index in
                            let sparkleIcons = ["sparkle", "sparkles", "sparkles.2"]
                            let positions = [
                                CGPoint(x: -25, y: -30), CGPoint(x: 30, y: -20),
                                CGPoint(x: -30, y: 10), CGPoint(x: 25, y: 15),
                                CGPoint(x: 0, y: -35), CGPoint(x: 0, y: 30)
                            ]
                            Image(systemName: sparkleIcons[index % sparkleIcons.count])
                                .font(.system(size: CGFloat.random(in: 8...14)))
                                .foregroundColor(.white)
                                .offset(x: positions[index].x, y: positions[index].y)
                                .opacity(isAnimating ? 0.8 : 0.3)
                                .scaleEffect(isAnimating ? 1.0 : 0.7)
                                .animation(
                                    .easeInOut(duration: Double.random(in: 1.5...3.0))
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.3),
                                    value: isAnimating
                                )
                        }
                    }
                    
                    
                    // Main gradient chest container with card pattern
                    RoundedRectangle(cornerRadius: ChestCardDesign.cornerRadius)
                        .fill(chestGradient)
                        .frame(width: ChestCardDesign.chestWidth, height: ChestCardDesign.chestHeight)
                        .overlay(
                            EnhancedCardSurface(chest: chest, scale: 1.0)
                        )
                        .overlay(
                            // Inner white border for playing card look
                            RoundedRectangle(cornerRadius: ChestCardDesign.cornerRadius)
                                .strokeBorder(.white, lineWidth: ChestCardDesign.innerBorderWidth)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: ChestCardDesign.cornerRadius)
                                .stroke(
                                    chestColor.opacity(shouldShowGlow && isAnimating ? 0.6 : 0.3),
                                    lineWidth: shouldShowGlow && isAnimating ? 3 : 2
                                )
                                .animation(shouldShowGlow ? .easeInOut(duration: 1.5).repeatForever(autoreverses: true) : .none, value: isAnimating)
                        )
                        .scaleEffect(bounceAnimation ? ChestCardDesign.bounceScale : 1.0)
                        .rotation3DEffect(
                            .degrees(bounceAnimation ? -5 : 0),
                            axis: (x: 1, y: 0, z: 0)
                        )
                        .shadow(
                            color: shouldShowGlow ? chestColor.opacity(isAnimating ? 0.4 : 0.2) : Color.clear,
                            radius: shouldShowGlow ? (isAnimating ? 12 : 8) : 0,
                            x: 0, y: 4
                        )
                    
                    // Chest icon with bounce
                    Image(systemName: chest.rarityIcon)
                        .font(.system(size: ChestCardDesign.iconSize))
                        .foregroundColor(.white)
                        .scaleEffect(bounceAnimation ? ChestCardDesign.iconBounceScale : 1.0)
                        .rotation3DEffect(
                            .degrees(bounceAnimation ? 10 : 0),
                            axis: (x: 0, y: 1, z: 0)
                        )
                    
                    // Shine effect
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.6), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: ChestCardDesign.chestWidth, height: ChestCardDesign.chestHeight)
                        .opacity(isAnimating ? 0.8 : 0.3)
                }
                .scaleEffect(isAnimating ? 1.05 : 1.0)
                .scaleEffect(bounceAnimation ? 0.98 : 1.0)
                .onTapGesture {
                    // Only respond to taps on the top card
                    if index == 0 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0)) {
                            bounceAnimation = true
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            onTap()
                            bounceAnimation = false
                        }
                    }
                }
                
                // Chest name (visible for top card, invisible for others to maintain spacing)
                Text(index == 0 ? chest.type.displayName : " ")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(index == 0 ? .primary : .clear)
                    .scaleEffect(index == 0 ? 0.71 : 1.0) // Scale down to original size when in deck view
                    .scaleEffect(bounceAnimation ? 1.05 : 1.0)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(width: ChestCardDesign.cardWidth, height: ChestCardDesign.cardHeight)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).delay(Double.random(in: 0...0.5))) {
                isAnimating = true
            }
            
            // Start glow animation for top card
            if shouldShowGlow {
                // Toggle to trigger the animation
                DispatchQueue.main.async {
                    glowPulse.toggle()
                }
            }
            
            // Only start sparkle animation for mythic top cards
            if chest.type == .mythic && shouldShowGlow {
                withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                    sparkleOffset = 2 * .pi
                }
            }
        }
        .onChangeCompat(of: index) { _, newIndex in
            // When card position changes, update glow animation based on new position
            // Note: shouldShowGlow will be recalculated with the new index
            if shouldShowGlow {
                DispatchQueue.main.async {
                    glowPulse.toggle()
                }
            } else {
                glowPulse = false
            }
        }
    }
    
    private var chestColor: Color {
        switch chest.type {
        case .common: return .brown
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .mythic: return .red
        }
    }
    
    private var chestGradient: LinearGradient {
        LinearGradient(
            colors: [chestColor, chestColor.opacity(0.95)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var shouldShowGlow: Bool {
        index == 0 && (chest.type == .epic || chest.type == .mythic)
    }
}

// MARK: - Display-only Chest Card (Non-interactive)
struct TreasureChestCardDisplay: View {
    let chest: TreasureChest
    let scale: CGFloat
    var hideGlow: Bool = false
    @State private var isAnimating = true
    @State private var glowPulse = true
    @State private var sparkleOffset = 0.0
    
    var body: some View {
        VStack(spacing: ChestCardDesign.cardSpacing * scale) {
            // Main chest container with all effects
            ZStack {
                // Background glow effect (only for Epic and Mythic, and not hidden)
                if shouldShowGlow && !hideGlow {
                    RoundedRectangle(cornerRadius: ChestCardDesign.cornerRadius * scale)
                        .fill(chestColor.opacity(glowPulse ? 0.3 : 0.1))
                        .blur(radius: glowPulse ? 12 * scale : 8 * scale)
                        .scaleEffect(glowPulse ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: glowPulse)
                }
                
                // Sparkles for Mythic chests only
                if chest.type == .mythic {
                    ForEach(0..<6, id: \.self) { index in
                        let sparkleIcons = ["sparkle", "sparkles", "sparkles.2"]
                        let positions = [
                            CGPoint(x: -25 * scale, y: -30 * scale), CGPoint(x: 30 * scale, y: -20 * scale),
                            CGPoint(x: -30 * scale, y: 10 * scale), CGPoint(x: 25 * scale, y: 15 * scale),
                            CGPoint(x: 0, y: -35 * scale), CGPoint(x: 0, y: 30 * scale)
                        ]
                        Image(systemName: sparkleIcons[index % sparkleIcons.count])
                            .font(.system(size: CGFloat.random(in: 8...14) * scale))
                            .foregroundColor(.white)
                            .offset(x: positions[index].x, y: positions[index].y)
                            .opacity(isAnimating ? 0.8 : 0.3)
                            .scaleEffect(isAnimating ? 1.0 : 0.7)
                            .animation(
                                .easeInOut(duration: Double.random(in: 1.5...3.0))
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.3),
                                value: isAnimating
                            )
                    }
                }
                
                // Main gradient chest container with card pattern
                RoundedRectangle(cornerRadius: ChestCardDesign.cornerRadius * scale)
                    .fill(chestGradient)
                    .frame(width: ChestCardDesign.chestWidth * scale, height: ChestCardDesign.chestHeight * scale)
                    .overlay(
                        EnhancedCardSurface(chest: chest, scale: scale)
                    )
                    .overlay(
                        // Inner white border for playing card look
                        RoundedRectangle(cornerRadius: ChestCardDesign.cornerRadius * scale)
                            .strokeBorder(.white, lineWidth: ChestCardDesign.innerBorderWidth * scale)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ChestCardDesign.cornerRadius * scale)
                            .stroke(
                                chestColor.opacity(shouldShowGlow && isAnimating ? 0.6 : 0.3),
                                lineWidth: (shouldShowGlow && isAnimating ? 3 : 2) * scale
                            )
                            .animation(shouldShowGlow ? .easeInOut(duration: 1.5).repeatForever(autoreverses: true) : .none, value: isAnimating)
                    )
                    .shadow(
                        color: shouldShowGlow ? chestColor.opacity(isAnimating ? 0.4 : 0.2) : Color.clear,
                        radius: shouldShowGlow ? (isAnimating ? 12 * scale : 8 * scale) : 0,
                        x: 0, y: 4 * scale
                    )
                
                // Chest icon
                Image(systemName: chest.rarityIcon)
                    .font(.system(size: ChestCardDesign.iconSize * scale))
                    .foregroundColor(.white)
                
                // Shine effect
                RoundedRectangle(cornerRadius: ChestCardDesign.cornerRadius * scale)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.6), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: ChestCardDesign.chestWidth * scale, height: ChestCardDesign.chestHeight * scale)
                    .opacity(isAnimating ? 0.8 : 0.3)
            }
            .scaleEffect(isAnimating ? 1.05 : 1.0)
        }
        .frame(width: ChestCardDesign.cardWidth * scale, height: ChestCardDesign.cardHeight * scale)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5)) {
                isAnimating = true
                glowPulse = true
            }
            
            withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                sparkleOffset = 2 * .pi
            }
        }
    }
    
    private var chestColor: Color {
        switch chest.type {
        case .common: return .brown
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .mythic: return .red
        }
    }
    
    private var chestGradient: LinearGradient {
        LinearGradient(
            colors: [chestColor, chestColor.opacity(0.95)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var shouldShowGlow: Bool {
        chest.type == .epic || chest.type == .mythic
    }
}

struct EmptyTreasureState: View {
    var body: some View {
        EmptyTreasureStateAnimated(isVisible: true)
    }
}

struct EmptyTreasureStateAnimated: View {
    let isVisible: Bool
    @State private var floating = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Empty deck illustration
            ZStack {
                // Stack of empty card outlines
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: ChestCardDesign.cornerRadius)
                        .strokeBorder(.gray.opacity(0.3), lineWidth: 2)
                        .fill(.gray.opacity(0.05))
                        .frame(width: ChestCardDesign.chestWidth * 0.7,
                               height: ChestCardDesign.chestHeight * 0.7)
                        .offset(
                            x: CGFloat(index) * 4,
                            y: CGFloat(index) * -6
                        )
                        .rotationEffect(.degrees(Double(index - 1) * 2))
                        .shadow(
                            color: .black.opacity(0.1),
                            radius: 2 + CGFloat(index),
                            x: 1 + CGFloat(index),
                            y: 2 + CGFloat(index)
                        )
                        .zIndex(Double(3 - index))
                }
                
                // Dashed outline for "add card" effect
                RoundedRectangle(cornerRadius: ChestCardDesign.cornerRadius)
                    .strokeBorder(.gray.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    .fill(.clear)
                    .frame(width: ChestCardDesign.chestWidth * 0.7,
                           height: ChestCardDesign.chestHeight * 0.7)
                
                // Plus icon in center
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .scaleEffect(isVisible ? 1.0 : 0.5)
            .opacity(isVisible ? 1.0 : 0.0)
            
            Text("Empty Deck")
                .font(.title2.weight(.semibold))
                .foregroundColor(.primary)
                .scaleEffect(isVisible ? 1.0 : 0.8)
                .opacity(isVisible ? 1.0 : 0.0)
            
            Text("Complete workouts and level up to add treasure cards to your deck!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .opacity(isVisible ? 1.0 : 0.0)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 60)
    }
}

// MARK: - Confetti Particle System
struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGSize
    var position: CGPoint
    var velocity: CGVector
    var rotation: Double
    var rotationSpeed: Double
    var opacity: Double
    
    static func random(centerX: CGFloat, centerY: CGFloat) -> ConfettiParticle {
        let colors: [Color] = [.red, .yellow, .green, .blue, .purple, .orange, .pink]
        return ConfettiParticle(
            color: colors.randomElement() ?? .yellow,
            size: CGSize(width: CGFloat.random(in: 8...12), height: CGFloat.random(in: 4...6)),
            position: CGPoint(
                x: centerX + CGFloat.random(in: -20...20), // Tight spawn area around center
                y: centerY
            ),
            velocity: CGVector(
                dx: CGFloat.random(in: -200...200), // Wider spread
                dy: CGFloat.random(in: -350...(-150)) // More upward initial velocity
            ),
            rotation: Double.random(in: 0...360),
            rotationSpeed: Double.random(in: -15...15),
            opacity: 1.0
        )
    }
}

struct ConfettiView: View {
    let particle: ConfettiParticle
    
    var body: some View {
        Rectangle()
            .fill(particle.color)
            .frame(width: particle.size.width, height: particle.size.height)
            .rotationEffect(.degrees(particle.rotation))
            .position(particle.position)
            .opacity(particle.opacity)
    }
}

struct TreasureChestRewardsView: View {
    let chest: TreasureChest
    let onClaim: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showRewards = false
    @State private var showClaimButton = false
    @State private var sparkleAnimation = false
    @State private var rewardAnimationStates: [Bool] = []
    @State private var confettiParticles: [ConfettiParticle] = []
    
    // Corner icons (non-filled versions)
    private var cornerIconName: String {
        switch chest.type {
        case .common: return "suit.heart"
        case .uncommon: return "suit.club"
        case .rare: return "suit.diamond"
        case .epic: return "suit.spade"
        case .mythic: return "crown"
        }
    }
    
    var body: some View {
        // Full screen container for confetti
        ZStack {
            // Confetti particles (full screen coverage)
            ForEach(confettiParticles) { particle in
                ConfettiView(particle: particle)
            }
            
            // Compact chest-sized view (slightly larger than 264x352)
            ZStack {
                // Card background
                RoundedRectangle(cornerRadius: ChestCardDesign.cornerRadius * 2.3)
                    .fill(.ultraThinMaterial)
                    .frame(width: ChestCardDesign.chestWidth * 2.3,
                           height: ChestCardDesign.chestHeight * 2.3)
                    .overlay(
                        RoundedRectangle(cornerRadius: ChestCardDesign.cornerRadius * 2.3)
                            .strokeBorder(chestGradient, lineWidth: 3)
                    )
            
            // Particle effects within card bounds
            if sparkleAnimation {
                ForEach(0..<12, id: \.self) { index in
                    Image(systemName: "sparkle")
                        .font(.system(size: CGFloat.random(in: 6...14)))
                        .foregroundColor(chestColor.opacity(0.8))
                        .position(
                            x: CGFloat.random(in: 20...(ChestCardDesign.chestWidth * 2.3 - 20)), // Within chest width
                            y: CGFloat.random(in: 20...(ChestCardDesign.chestHeight * 2.3 - 20))  // Within chest height
                        )
                        .opacity(sparkleAnimation ? 0.0 : 1.0)
                        .animation(
                            .easeOut(duration: Double.random(in: 1.5...2.5))
                            .delay(Double.random(in: 0...0.5)),
                            value: sparkleAnimation
                        )
                }
            }
            
            ZStack {
                // Top-left corner icon (normal orientation)
                VStack {
                    HStack {
                        Image(systemName: cornerIconName)
                            .font(.system(size: 18))
                            .foregroundColor(chestColor)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.top, 16)
                .padding(.leading, 16)
                
                // Bottom-right corner icon (flipped)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: cornerIconName)
                            .font(.system(size: 18))
                            .foregroundColor(chestColor)
                            .rotationEffect(.degrees(180))
                    }
                }
                .padding(.bottom, 16)
                .padding(.trailing, 16)
                
                // Main content
                VStack(spacing: 12) {
                    // Compact header
                    VStack(spacing: 4) {
                        Image(systemName: chest.rarityIcon)
                            .font(.system(size: 28))
                            .foregroundColor(chestColor)
                        
                        Text(chest.type.displayName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Level \(chest.earnedAtLevel)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                
                Divider()
                    .padding(.horizontal, 30)
                
                // Compact Rewards List
                if showRewards {
                    VStack(spacing: 8) {
                        Text("Rewards")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                            .scaleEffect(showRewards ? 1.0 : 0.8)
                        
                        VStack(spacing: 6) {
                            ForEach(Array(chest.rewards.enumerated()), id: \.element.id) { index, reward in
                                CompactRewardRow(
                                    reward: reward,
                                    isVisible: index < rewardAnimationStates.count ? rewardAnimationStates[index] : false
                                )
                            }
                        }
                        .frame(height: 90) // Always use 2-reward height: 2*42 + 1*6 = 90pt, allow overlap for 3rd item
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
                
                // Auto-claim message (no button needed) - hidden but keeps the space
                if showClaimButton {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(chestColor)
                        
                        Text("Rewards Claimed!")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .scaleEffect(showClaimButton ? 1.0 : 0.8)
                    .padding(.bottom, 20)
                    .opacity(0) // Make invisible while keeping function
                }
                } // Close main content VStack
            } // Close ZStack with corner icons
                .frame(width: ChestCardDesign.chestWidth * 2.3,
                       height: ChestCardDesign.chestHeight * 2.3)
            }
        }
        .onAppear {
            startOpeningSequence()
        }
    }
    
    private func startOpeningSequence() {
        // Initialize reward animation states
        rewardAnimationStates = Array(repeating: false, count: chest.rewards.count)
        
        // Immediately show rewards
        showRewards = true
        
        // Launch confetti
        launchConfetti()
        
        // Animate each reward in sequence with a slight delay
        for (index, _) in chest.rewards.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    if index < rewardAnimationStates.count {
                        rewardAnimationStates[index] = true
                    }
                }
            }
        }
        
        // Auto-claim rewards instantly when screen appears
        onClaim()
        
        // Show claim message after rewards are shown (for visual feedback)
        let rewardDisplayDelay = 0.3 + Double(chest.rewards.count) * 0.15
        DispatchQueue.main.asyncAfter(deadline: .now() + rewardDisplayDelay) {
            showClaimButton = true
            sparkleAnimation = true
        }
    }
    
    private func launchConfetti() {
        // Spawn confetti from center of screen (where chest appears)
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let centerX = screenWidth / 2
        let centerY = (screenHeight / 2.5) - 120 // Much higher so it peaks well above the card
        
        // Create confetti particles
        let particleCount = chest.type == .mythic ? 50 : chest.type == .epic ? 40 : 30
        for _ in 0..<particleCount {
            confettiParticles.append(ConfettiParticle.random(centerX: centerX, centerY: centerY))
        }
        
        // Animate confetti falling
        animateConfetti()
    }
    
    private func animateConfetti() {
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in // ~60fps
            for i in confettiParticles.indices.reversed() {
                // Apply gravity
                confettiParticles[i].velocity.dy += 12.0 // Stronger gravity
                
                // Apply air resistance to horizontal movement
                confettiParticles[i].velocity.dx *= 0.999
                
                // Update position
                confettiParticles[i].position.x += confettiParticles[i].velocity.dx * 0.016
                confettiParticles[i].position.y += confettiParticles[i].velocity.dy * 0.016
                
                // Update rotation
                confettiParticles[i].rotation += confettiParticles[i].rotationSpeed
                
                // Fade out slowly (let them fall further before fading)
                if confettiParticles[i].position.y > 400 { // Start fading after falling a bit
                    confettiParticles[i].opacity *= 0.99
                }
                
                // Remove if fallen way off screen or too faded
                if confettiParticles[i].position.y > UIScreen.main.bounds.height + 200 ||
                   confettiParticles[i].opacity < 0.01 {
                    confettiParticles.remove(at: i)
                }
            }
            
            // Stop timer when no particles left
            if confettiParticles.isEmpty {
                timer.invalidate()
            }
        }
    }
    
    private var chestColor: Color {
        switch chest.type {
        case .common: return .brown
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .mythic: return .red
        }
    }
    
    private var chestGradient: LinearGradient {
        LinearGradient(
            colors: [chestColor, chestColor.opacity(0.95)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct RewardRow: View {
    let reward: TreasureReward
    
    var body: some View {
        RewardRowAnimated(reward: reward, isVisible: true)
    }
}

struct RewardRowAnimated: View {
    let reward: TreasureReward
    let isVisible: Bool
    @State private var shimmerOffset: CGFloat = -100
    
    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(rewardBackgroundColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: rewardIcon)
                    .font(.title2)
                    .foregroundColor(rewardColor)
            }
            .opacity(isVisible ? 1.0 : 0.0)
            .rotation3DEffect(
                .degrees(isVisible ? 0 : 180),
                axis: (x: 0, y: 1, z: 0)
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(reward.type == .coins && reward.type.isJackpotAmount(reward.amount) ? "Jackpot!" : rewardTypeDisplayName)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(reward.type == .coins && reward.type.isJackpotAmount(reward.amount) ? .yellow : .primary)
                    .opacity(isVisible ? (reward.type == .coins && reward.type.isJackpotAmount(reward.amount) ? 1.0 : 1.0) : 0.0)
                    .zIndex(reward.type == .coins && reward.type.isJackpotAmount(reward.amount) ? 10 : 0)
                
                Text(reward.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .opacity(isVisible ? 1.0 : 0.0)
            }
            .offset(x: isVisible ? 0 : 20)
            
            Spacer()
            
            // Floating sparkle effect
            if isVisible {
                Image(systemName: "sparkle")
                    .font(.caption)
                    .foregroundColor(rewardColor.opacity(0.7))
                    .offset(y: sin(Date().timeIntervalSince1970 * 2) * 3)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isVisible)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(rewardColor.opacity(isVisible ? 0.5 : 0.1), lineWidth: isVisible ? 2 : 1)
                    )
                
                // Shimmer effect
                if isVisible {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.3), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: shimmerOffset)
                        .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: shimmerOffset)
                }
            }
        )
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .onAppear {
            // Start shimmer animation immediately to sync all rewards
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: true)) {
                shimmerOffset = 100
            }
        }
    }
    
    private var rewardIcon: String {
        switch reward.type {
        case .bonus_xp: return "star.fill"
        case .coins: return "circle.circle.fill"
        case .item: return reward.itemInfo?.iconName ?? "questionmark"
        }
    }
    
    private var rewardColor: Color {
        switch reward.type {
        case .bonus_xp: return .green
        case .coins: return .yellow
        case .item: return reward.itemInfo?.iconColor ?? .gray
        }
    }
    
    private var rewardBackgroundColor: Color {
        switch reward.type {
        case .bonus_xp: return .green
        case .coins: return .yellow
        case .item: return reward.itemInfo?.rarityColor ?? Color(red: 0.95, green: 0.95, blue: 0.95)
        }
    }
    
    private var rewardTypeDisplayName: String {
        switch reward.type {
        case .bonus_xp: return "Bonus Exp"
        case .coins: return "Coins"
        case .item: return reward.itemInfo?.rarity ?? "Common"
        }
    }
    
    private var sparkleColor: Color {
        switch reward.type {
        case .bonus_xp: return .green
        case .coins: return .yellow
        case .item: return reward.itemInfo?.rarityColor ?? Color(red: 0.95, green: 0.95, blue: 0.95)
        }
    }
}

// Compact version for the card-sized view
struct CompactRewardRow: View {
    let reward: TreasureReward
    let isVisible: Bool
    @State private var shimmerOffset: CGFloat = -50
    @State private var sparkleRotation: Double = 0
    
    var body: some View {
        HStack(spacing: 8) {
            // Smaller icon
            ZStack {
                Circle()
                    .fill(rewardBackgroundColor.opacity(0.15))
                    .frame(width: 28, height: 28)
                
                Image(systemName: rewardIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(rewardColor)
            }
            .opacity(isVisible ? 1.0 : 0.0)
            .rotation3DEffect(
                .degrees(isVisible ? 0 : 180),
                axis: (x: 0, y: 1, z: 0)
            )
            
            // Compact text
            HStack(spacing: 4) {
                Text(reward.description)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .opacity(isVisible ? 1.0 : 0.0)
                
                // Inline type indicator
                Text("•")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.5))
                
                Text(reward.type == .coins && reward.type.isJackpotAmount(reward.amount) ? "Jackpot!" : rewardTypeDisplayName)
                    .font(.system(size: 11))
                    .foregroundColor(reward.type == .coins && reward.type.isJackpotAmount(reward.amount) ? .yellow : .secondary)
                    .opacity(isVisible ? (reward.type == .coins && reward.type.isJackpotAmount(reward.amount) ? 1.0 : 0.7) : 0.0)
                    .zIndex(reward.type == .coins && reward.type.isJackpotAmount(reward.amount) ? 10 : 0)
            }
            
            Spacer()
            
            // Small sparkle
            Image(systemName: "sparkle")
                .font(.system(size: 10))
                .foregroundColor(sparkleColor.opacity(0.6))
                .rotationEffect(.degrees(sparkleRotation))
                .opacity(isVisible ? 1.0 : 0.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isVisible)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(rewardBackgroundColor.opacity(0.2), lineWidth: 0.5)
                    )
                
                // Subtle shimmer
                LinearGradient(
                    colors: [Color.clear, rewardBackgroundColor.opacity(0.1), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 30)
                .offset(x: shimmerOffset)
                .opacity(isVisible ? 1.0 : 0.0)
            }
        )
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isVisible)
        .onAppear {
            // Start shimmer animation immediately to sync all rewards
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: true)) {
                shimmerOffset = 150
            }
            // Start continuous sparkle rotation
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                sparkleRotation = 360
            }
        }
    }
    
    private var rewardIcon: String {
        switch reward.type {
        case .bonus_xp: return "star.fill"
        case .coins: return "circle.circle.fill"
        case .item: return reward.itemInfo?.iconName ?? "questionmark"
        }
    }
    
    private var rewardColor: Color {
        switch reward.type {
        case .bonus_xp: return .green
        case .coins: return .yellow
        case .item: return reward.itemInfo?.iconColor ?? .gray
        }
    }
    
    private var rewardBackgroundColor: Color {
        switch reward.type {
        case .bonus_xp: return .green
        case .coins: return .yellow
        case .item: return reward.itemInfo?.rarityColor ?? Color(red: 0.95, green: 0.95, blue: 0.95)
        }
    }
    
    private var rewardTypeDisplayName: String {
        switch reward.type {
        case .bonus_xp: return "Bonus Exp"
        case .coins: return "Coins"
        case .item: return reward.itemInfo?.rarity ?? "Common"
        }
    }
    
    private var sparkleColor: Color {
        switch reward.type {
        case .bonus_xp: return .green
        case .coins: return .yellow
        case .item: return reward.itemInfo?.rarityColor ?? Color(red: 0.95, green: 0.95, blue: 0.95)
        }
    }
}

// MARK: - Inventory UI Helper Components

struct FilterButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? .blue : .gray.opacity(0.2))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EmptyInventorySlot: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemGray6))
            .aspectRatio(1.0, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            )
            .overlay(
                Image(systemName: "plus")
                    .font(.title3)
                    .foregroundColor(.gray.opacity(0.5))
            )
    }
}

struct InventoryItemCard: View {
    let item: InventoryItem
    @State private var isDragging = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .aspectRatio(1.0, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(rarityColor.opacity(0.3), lineWidth: 1)
            )
            .overlay(
                Image(systemName: item.iconName)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(itemColor)
            )
            .overlay(
                // Rarity indicator in top-right corner
                Group {
                    if item.rarity == .mythic {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.red)
                    } else if item.rarity == .legendary {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.2)) // Gold
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 4)
                .padding(.trailing, 4)
            )
            .scaleEffect(isDragging ? 1.1 : 1.0)
            .opacity(isDragging ? 0.7 : 1.0)
            .draggable(item.id.uuidString) {
                // Drag preview
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Image(systemName: item.iconName)
                            .font(.system(size: 30))
                            .foregroundColor(itemColor)
                    )
                    .frame(width: 60, height: 60)
            }
            .onDrag {
                isDragging = true
                return NSItemProvider(object: item.id.uuidString as NSString)
            }
            .onChange(of: isDragging) { _, newValue in
                if !newValue {
                    // Drag ended
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isDragging = false
                    }
                }
            }
    }
    
    private var itemColor: Color {
        // Extract item color based on the item name and icon
        // Since we don't store ItemInfo in InventoryItem, we need to map by name/icon
        switch item.iconName {
        case "soccerball.fill": return .black
        case "basketball.fill": return Color(red: 0.8, green: 0.4, blue: 0.1) // Basketball orange-brown
        case "volleyball.fill": return .white
        case "puzzlepiece.fill": return Color(red: 1.0, green: 1.0, blue: 0.8) // Pale yellow
        case "balloon.fill": return .red
        case "birthday.cake.fill": return Color(red: 1.0, green: 0.8, blue: 0.9) // Pink
        case "gamecontroller.fill": return .black
        case "trophy.fill": return Color(red: 1.0, green: 0.8, blue: 0.2) // Gold
        case "wand.and.stars": return Color(red: 0.9, green: 0.7, blue: 1.0) // Light purple/magical
        case "teddybear.fill": return Color(red: 0.6, green: 0.4, blue: 0.2) // Brown
        default: return .primary
        }
    }
    
    private var rarityColor: Color {
        switch item.rarity {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return Color(red: 1.0, green: 0.8, blue: 0.2) // Gold
        case .mythic: return .red
        }
    }
}


struct EmptyInventoryView: View {
    @State private var floating = false
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.gray.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .blur(radius: 10)
                    .scaleEffect(floating ? 1.2 : 1.0)
                
                Image(systemName: "backpack")
                    .font(.system(size: 64))
                    .foregroundColor(.gray)
                    .offset(y: floating ? -5 : 5)
            }
            
            Text("Empty Inventory")
                .font(.title2.weight(.semibold))
                .foregroundColor(.primary)
            
            Text("Earn items by opening treasure chests and completing achievements!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 60)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                floating = true
            }
        }
    }
}

struct OnboardingClassCard: View {
    let rpgClass: RPGClass
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Class icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : Color.blue.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: rpgClass.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .blue)
                }
                
                // Class info
                VStack(alignment: .leading, spacing: 4) {
                    Text(rpgClass.displayName)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(rpgClass.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Goal Selection Components

struct GoalSelectionCard: View {
    let goal: FitnessGoal
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    private var goalColor: Color {
        if goal == .hypertrophy {
            return colorScheme == .dark ? .white : .black
        }
        return goal.color
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: goal.icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(isSelected ? (goal == .hypertrophy ? (colorScheme == .dark ? .black : .white) : .white) : goalColor)
            
            Text(goal.displayName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? (goal == .hypertrophy ? (colorScheme == .dark ? .black : .white) : .white) : .primary)
            
            Text(goal.description)
                .font(.caption2)
                .foregroundColor(isSelected ? (goal == .hypertrophy ? (colorScheme == .dark ? .black.opacity(0.8) : .white.opacity(0.8)) : .white.opacity(0.8)) : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 100)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? goalColor : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? goalColor : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
        )
        .onTapGesture {
            onTap()
        }
    }
}

struct ClassPreviewCard: View {
    let rpgClass: RPGClass
    @Environment(\.colorScheme) var colorScheme
    
    private func statColor(for statName: String) -> Color {
        switch statName {
        case "Size": return colorScheme == .dark ? .white : .black
        case "Strength": return .red
        case "Dexterity": return .orange
        case "Agility": return .yellow
        case "Endurance": return .blue
        case "Vitality": return .green
        default: return .primary
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Class Icon and Name
            VStack(spacing: 8) {
                Image(systemName: rpgClass.icon)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(rpgClass.color)
                
                Text(rpgClass.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            // Class Description
            Text(rpgClass.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
            
            // Skill Focus
            VStack(spacing: 8) {
                Text("Skill Focus")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    ForEach(rpgClass.primarySkills, id: \.self) { skill in
                        Text(skill)
                            .font(.body)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(statColor(for: skill).opacity(0.15))
                            .foregroundColor(statColor(for: skill))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(rpgClass.color.opacity(0.3), lineWidth: 2)
        )
    }
}





























// MARK: - Challenge Settings View
struct ChallengeSettingsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                if let rpgClass = state.user.rpgClass {
                    ForEach(rpgClass.focusCategories, id: \.self) { category in
                        ChallengePreferenceRow(category: category)
                            .environmentObject(state)
                    }
                }
            }
            .navigationTitle("Challenge Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Regenerate challenges with new preferences
                        state.generateDailyChallenges()
                        state.generateWeeklyChallenges()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

struct ChallengePreferenceRow: View {
    @EnvironmentObject var state: AppState
    let category: FocusGroup
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(state.getStatName(for: category))
                    .font(.headline)
                Spacer()
            }
            
            let availablePreferences = state.getAvailablePreferences(for: category)
            let currentPreference = state.getPreference(for: category)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(availablePreferences, id: \.self) { preference in
                        Button(action: {
                            state.setPreference(preference, for: category)
                        }) {
                            Text(preference.displayName)
                                .font(.subheadline)
                                .fontWeight(currentPreference == preference ? .semibold : .regular)
                                .foregroundColor(currentPreference == preference ? .white : .blue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(currentPreference == preference ? Color.blue : Color.blue.opacity(0.1))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 1)
            }
            
            Text(getPreferenceDescription(for: category, preference: currentPreference))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding(.vertical, 8)
    }
    
    private func getPreferenceDescription(for category: FocusGroup, preference: ChallengePreference) -> String {
        let statName = state.getStatName(for: category).lowercased()
        
        switch preference {
        case .time:
            return "Track \(statName) challenges by time spent"
        case .distance:
            return "Track \(statName) challenges by distance covered"
        case .frequency:
            return "Track \(statName) challenges by number of sessions"
        case .sets:
            return "Track \(statName) challenges by sets completed"
        case .reps:
            return "Track \(statName) challenges by repetitions completed"
        case .times:
            return "Track \(statName) challenges by rounds completed"
        }
    }
}

