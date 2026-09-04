// FRPG MVP shared models, helpers, and UI building blocks


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
                        .foregroundColor(RPGTheme.accent)
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

struct AppLayout {
    static let horizontalPadding: CGFloat = 16
    /// Readable column for single-column screens; two-column layouts on
    /// regular width use the wider `wideMaxWidth`.
    static let contentMaxWidth: CGFloat = 720
    static let wideMaxWidth: CGFloat = 1040
}

/// Parses user-typed numbers from decimal-pad fields. Decimal-comma locales
/// produce "70,5", which Double(String) rejects — normalize first.
func flexibleDouble(_ text: String) -> Double? {
    Double(text.replacingOccurrences(of: ",", with: "."))
}

private extension KeyedDecodingContainer {
    func decodeValue<T: Decodable>(_ type: T.Type, forKey key: Key, default defaultValue: @autoclosure () -> T) -> T {
        (try? decodeIfPresent(type, forKey: key)) ?? defaultValue()
    }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FocusGroup.allCases) { focus in
                        let statColor = focus.primaryStat.color
                        let isSelected = selection == focus
                        Button {
                            Haptics.tap()
                            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) {
                                selection = focus
                            }
                        } label: {
                            HStack(spacing: 6) {
                                RPGSymbolIcon(
                                    symbol: focus.rpgSymbol,
                                    size: 15,
                                    presentation: .compact,
                                    palette: .monochrome(isSelected ? RPGTheme.onPlate : statColor)
                                )
                                    .frame(width: 16, height: 16)

                                Text(focus.shortDisplayName)
                                    .font(RPGTheme.label(13, weight: .semibold))
                                    .foregroundColor(isSelected ? .white : .primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(
                                Capsule()
                                    .fill(isSelected ? RPGTheme.accentFill : RPGTheme.surfaceInner)
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(
                                                isSelected ? Color.clear : RPGTheme.frame.opacity(RPGTheme.hairline),
                                                lineWidth: 1
                                            )
                                    )
                            )
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .id(focus)
                        .accessibilityLabel(focus.displayName)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
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
}

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(RPGTheme.display(17))
            .monospacedDigit()
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: RPGTheme.innerRadius, style: .continuous)
                    .fill(RPGTheme.surfaceInner)
                    .overlay(
                        RoundedRectangle(cornerRadius: RPGTheme.innerRadius, style: .continuous)
                            .strokeBorder(RPGTheme.frame.opacity(RPGTheme.hairline), lineWidth: 1)
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title.uppercased())
                    .font(RPGTheme.label(11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(.secondary)
                    .accessibilityLabel(title)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                }

                Spacer(minLength: 0)
            }

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textFieldStyle(ModernTextFieldStyle())
                .accessibilityLabel(subtitle.map { "\(title), \($0)" } ?? title)
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

    // MARK: - Expanded catalog
    // Appended rather than interleaved: `allCases` order is load-bearing for
    // first-match lookups (picker replacement, tests), so existing indices stay put.

    // Strength / Compounds & Accessories (expanded)
    case andersonSquat, atlasStone, behindTheNeckPress, beltSquat
    case boardPress, boxSquat, closeGripBenchPress, declineBenchPress
    case deficitDeadlift, farmersWalk, frontRackCarry, gobletSquat
    case goodMorning, hackSquat, inclineBenchPress, jeffersonDeadlift
    case landminePress, logPress, overheadCarry, pauseSquat
    case pendlayRow, rackPull, safetyBarSquat, seatedBarbellPress
    case singleArmRow, snatchPull, sumoDeadlift, tBarRow
    case trapBarDeadlift, walkingLunge, yokeWalk, zercherSquat
    case floorPress, lunge, overheadSquat, pushPress
    case singleLegRDL, snatchGripDeadlift, stepUp, suitcaseCarry
    case turkishGetUp

    // Hypertrophy / Isolation (expanded)
    case chestPressMachine, platePinch, arnoldPress, barbellCurl
    case cableCrunch, cablePullThrough, calfRaiseSeated, gluteKickback
    case hammerCurl, hipAbduction, hipAdduction, jmPress
    case landmineRotation, neckCurl, pullover, rearDeltFly
    case reverseHyper, shoulderPressMachine, shrug, sideBend
    case sissySquat, skullcrusher, straightArmPulldown, wristCurl
    case backExtension, cableWoodchop, chestSupportedRow, facePull
    case renegadeRow, uprightRow

    // Bodyweight & Rings (expanded)
    case lateralLunge, archerPullUp, archerPushUp, backLever
    case bicycleCrunch, bodyweightSquat, climbing, frontLever
    case gripHold, gymnastics, hollowHold, humanFlag
    case lyingLegRaise, muscleUp, pikePushUp, planche
    case skinTheCat, vUp, wallSit, windshieldWiper
    case deadHang, dragonFlag, invertedRow, lSit
    case russianTwist, sitUp

    // Explosive / Athleticism (expanded)
    case cleanPull, baseballSoftball, bounding, boxing
    case cleanAndJerk, cleanAndPress, depthJump, dumbbellSnatch
    case hangClean, hangSnatch, highPull, hillSprint
    case hurdleHop, ladderDrill, lateralBound, pogoHop
    case powerSnatch, pushJerk, resistedSprint, sandbagShoulder
    case shuttleRun, singleLegHop, skateboarding, sledgehammerStrikes
    case snatch, snatchBalance, splitJerk, splitSquatJump
    case sprintDrills, squatClean, tireFlip, tuckJump
    case volleyball, jumpSquat, plyoPushUp, thruster

    // Endurance / Conditioning (expanded)
    case aquaJogging, assaultBike, badminton, basketball
    case burpee, crossCountrySki, dance, golf
    case grappling, heavyBag, hiitCircuit, hockey
    case mountainBike, mountainClimber, openWaterSwim, paddling
    case pickleball, ruckMarch, rugby, skating
    case skiErg, skiing, soccer, squash
    case surfing, tennis, trailRun, ultimateFrisbee
    case versaClimber, walk, bearCrawl, elliptical

    // Mobility / Prehab (expanded)
    case deadBug, adductorRockback, ankleDorsiflexion, atgSplitSquat
    case bandPullApart, catCow, deepSquatHold, dropLanding
    case foamRolling, hamstringStretch, hipFlexorMarch, jeffersonCurl
    case kettlebellWindmill, pilates, proneYTW, reverseNordic
    case scapularPushUp, shoulderDislocates, wallSlides, worldsGreatestStretch
    case pallofPress, scapularPullUp

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

        // MARK: Expanded catalog
        // Strength
        case .andersonSquat: return "Anderson Squat"
        case .atlasStone: return "Atlas Stone Lift"
        case .behindTheNeckPress: return "Behind-the-Neck Press"
        case .beltSquat: return "Belt Squat"
        case .boardPress: return "Board / Pin Press"
        case .boxSquat: return "Box Squat"
        case .closeGripBenchPress: return "Close-Grip Bench Press"
        case .declineBenchPress: return "Decline Bench Press"
        case .deficitDeadlift: return "Deficit Deadlift"
        case .farmersWalk: return "Farmer's Walk"
        case .floorPress: return "Floor Press"
        case .frontRackCarry: return "Front-Rack / Bear-Hug Carry"
        case .gobletSquat: return "Goblet Squat"
        case .goodMorning: return "Good Morning"
        case .hackSquat: return "Hack Squat (Machine)"
        case .inclineBenchPress: return "Incline Bench Press"
        case .jeffersonDeadlift: return "Jefferson Deadlift"
        case .landminePress: return "Landmine Press"
        case .logPress: return "Log / Axle Press"
        case .lunge: return "Lunge (Forward/Reverse)"
        case .overheadCarry: return "Overhead / Waiter Carry"
        case .overheadSquat: return "Overhead Squat"
        case .pauseSquat: return "Pause Squat"
        case .pendlayRow: return "Pendlay Row"
        case .pushPress: return "Push Press"
        case .rackPull: return "Rack Pull"
        case .safetyBarSquat: return "Safety-Bar Squat"
        case .seatedBarbellPress: return "Seated Barbell Press"
        case .singleArmRow: return "Single-Arm Dumbbell Row"
        case .singleLegRDL: return "Single-Leg Romanian Deadlift"
        case .snatchGripDeadlift: return "Snatch-Grip Deadlift"
        case .snatchPull: return "Snatch Pull"
        case .stepUp: return "Step-Up (Box/Bench)"
        case .suitcaseCarry: return "Suitcase Carry / Hold (one-arm)"
        case .sumoDeadlift: return "Sumo Deadlift"
        case .tBarRow: return "T-Bar Row"
        case .trapBarDeadlift: return "Trap-Bar Deadlift"
        case .turkishGetUp: return "Turkish Get-Up"
        case .walkingLunge: return "Walking Lunge"
        case .yokeWalk: return "Yoke Walk"
        case .zercherSquat: return "Zercher Squat"
        // Hypertrophy
        case .arnoldPress: return "Arnold Press"
        case .backExtension: return "Back Extension / Hyperextension"
        case .barbellCurl: return "Barbell / EZ-Bar Curl"
        case .cableCrunch: return "Cable Crunch (kneeling)"
        case .cablePullThrough: return "Cable Pull-Through"
        case .cableWoodchop: return "Cable Woodchop / Lift"
        case .calfRaiseSeated: return "Calf Raise (Seated)"
        case .chestPressMachine: return "Chest Press Machine"
        case .chestSupportedRow: return "Chest-Supported / Seal Row"
        case .facePull: return "Face Pull (rope/band)"
        case .gluteKickback: return "Cable Glute Kickback"
        case .hammerCurl: return "Hammer Curl"
        case .hipAbduction: return "Hip Abduction Machine"
        case .hipAdduction: return "Hip Adduction Machine"
        case .jmPress: return "JM Press"
        case .landmineRotation: return "Landmine Rotation"
        case .neckCurl: return "Neck Curl / Extension"
        case .platePinch: return "Plate Pinch Hold"
        case .pullover: return "Pullover (DB/Barbell)"
        case .rearDeltFly: return "Rear Delt Fly / Reverse Fly"
        case .renegadeRow: return "Renegade Row"
        case .reverseHyper: return "Reverse Hyperextension"
        case .shoulderPressMachine: return "Shoulder Press Machine"
        case .shrug: return "Shrug (Barbell/DB)"
        case .sideBend: return "Side Bend (DB/Cable)"
        case .sissySquat: return "Sissy Squat"
        case .skullcrusher: return "Skullcrusher (EZ/Barbell)"
        case .straightArmPulldown: return "Straight-Arm Pulldown"
        case .uprightRow: return "Upright Row"
        case .wristCurl: return "Wrist Curl / Reverse Wrist Curl"
        // Bodyweight
        case .archerPullUp: return "Archer / One-Arm Pull-Up"
        case .archerPushUp: return "Archer / One-Arm Push-Up"
        case .backLever: return "Back Lever (tuck→full)"
        case .bicycleCrunch: return "Bicycle Crunch"
        case .bodyweightSquat: return "Air Squat / Bodyweight Squat"
        case .climbing: return "Rock Climbing / Bouldering"
        case .deadHang: return "Dead Hang"
        case .dragonFlag: return "Dragon Flag"
        case .frontLever: return "Front Lever (tuck→full)"
        case .gripHold: return "Grip Hold (farmer / plate pinch / hang)"
        case .gymnastics: return "Gymnastics / Tumbling"
        case .hollowHold: return "Hollow Hold / Rock"
        case .humanFlag: return "Human Flag"
        case .invertedRow: return "Inverted Row / Ring Row"
        case .lSit: return "L-Sit"
        case .lateralLunge: return "Lateral Lunge / Cossack Squat"
        case .lyingLegRaise: return "Lying Leg Raise / Reverse Crunch"
        case .muscleUp: return "Muscle-Up (bar/rings)"
        case .pikePushUp: return "Pike / Handstand Push-Up"
        case .planche: return "Planche (tuck→full)"
        case .russianTwist: return "Russian Twist / Seated Rotation"
        case .sitUp: return "Sit-Ups / Crunches"
        case .skinTheCat: return "Skin the Cat"
        case .vUp: return "V-Up"
        case .wallSit: return "Wall Sit"
        case .windshieldWiper: return "Windshield Wiper"
        // Explosive
        case .baseballSoftball: return "Baseball / Softball"
        case .bounding: return "Bounding"
        case .boxing: return "Boxing / Kickboxing / Striking"
        case .cleanAndJerk: return "Clean & Jerk"
        case .cleanAndPress: return "Clean & Press (DB/KB)"
        case .cleanPull: return "Clean Pull"
        case .depthJump: return "Depth Jump (drop jump)"
        case .dumbbellSnatch: return "Dumbbell / KB Snatch (single-arm)"
        case .hangClean: return "Hang Clean"
        case .hangSnatch: return "Hang Snatch"
        case .highPull: return "High Pull (Barbell/KB)"
        case .hillSprint: return "Hill Sprints"
        case .hurdleHop: return "Hurdle Hops"
        case .jumpSquat: return "Jump Squat"
        case .ladderDrill: return "Agility Ladder Footwork"
        case .lateralBound: return "Lateral Bound / Skater Jump"
        case .plyoPushUp: return "Plyo/Clap Push-Ups"
        case .pogoHop: return "Pogo Hops (ankle stiffness)"
        case .powerSnatch: return "Power Snatch"
        case .pushJerk: return "Push Jerk"
        case .resistedSprint: return "Resisted Sprint (sled / band / parachute)"
        case .sandbagShoulder: return "Sandbag Over-Shoulder"
        case .shuttleRun: return "Shuttle Run / Cone Drill (5-10-5)"
        case .singleLegHop: return "Single-Leg Hop"
        case .skateboarding: return "Skateboarding / BMX"
        case .sledgehammerStrikes: return "Sledgehammer Strikes"
        case .snatch: return "Snatch (full)"
        case .snatchBalance: return "Snatch Balance"
        case .splitJerk: return "Split Jerk"
        case .splitSquatJump: return "Split-Squat Jump / Jump Lunge"
        case .sprintDrills: return "Sprint Drills (A-skips, high knees)"
        case .squatClean: return "Squat Clean (full)"
        case .thruster: return "Thruster"
        case .tireFlip: return "Tire Flip"
        case .tuckJump: return "Tuck Jumps"
        case .volleyball: return "Volleyball (Indoor / Beach)"
        // Endurance
        case .aquaJogging: return "Aqua Jogging (deep water)"
        case .assaultBike: return "Air Bike (Assault/Echo)"
        case .badminton: return "Badminton"
        case .basketball: return "Basketball"
        case .bearCrawl: return "Bear Crawl / Crab Walk"
        case .burpee: return "Burpees"
        case .crossCountrySki: return "Cross-Country Skiing"
        case .dance: return "Dance (Class / Cardio)"
        case .elliptical: return "Elliptical Trainer"
        case .golf: return "Golf (Walking 18)"
        case .grappling: return "BJJ / Wrestling / Grappling"
        case .heavyBag: return "Heavy Bag/Shadowboxing"
        case .hiitCircuit: return "HIIT/Metcon Circuit"
        case .hockey: return "Ice / Roller Hockey"
        case .mountainBike: return "Mountain Biking"
        case .mountainClimber: return "Mountain Climbers"
        case .openWaterSwim: return "Open-Water Swim"
        case .paddling: return "Kayak / Canoe / Paddleboard"
        case .pickleball: return "Pickleball / Padel"
        case .ruckMarch: return "Ruck March (loaded)"
        case .rugby: return "Rugby / American Football"
        case .skating: return "Skating (Inline / Ice / Roller)"
        case .skiErg: return "Ski Erg"
        case .skiing: return "Skiing / Snowboarding (Downhill)"
        case .soccer: return "Soccer / Football"
        case .squash: return "Squash / Racquetball"
        case .surfing: return "Surfing / Bodyboarding"
        case .tennis: return "Tennis"
        case .trailRun: return "Trail Running"
        case .ultimateFrisbee: return "Ultimate Frisbee"
        case .versaClimber: return "Vertical Climber (VersaClimber)"
        case .walk: return "Walking (Zone 1)"
        // Mobility
        case .adductorRockback: return "Adductor Rockback"
        case .ankleDorsiflexion: return "Ankle Dorsiflexion Drill"
        case .atgSplitSquat: return "ATG Split Squat"
        case .bandPullApart: return "Band Pull-Apart"
        case .catCow: return "Cat-Cow"
        case .deadBug: return "Dead Bug"
        case .deepSquatHold: return "Deep Squat Hold"
        case .dropLanding: return "Drop Landing / Snap-Down"
        case .foamRolling: return "Foam Rolling"
        case .hamstringStretch: return "Hamstring Stretch"
        case .hipFlexorMarch: return "Hip Flexor March"
        case .jeffersonCurl: return "Jefferson Curl"
        case .kettlebellWindmill: return "Windmill"
        case .pallofPress: return "Pallof Press (cable/band)"
        case .pilates: return "Pilates"
        case .proneYTW: return "Prone Y-T-W Raises"
        case .reverseNordic: return "Reverse Nordic Curl"
        case .scapularPullUp: return "Scapular Pull-Ups"
        case .scapularPushUp: return "Scapular Push-Up"
        case .shoulderDislocates: return "Shoulder Pass-Throughs"
        case .wallSlides: return "Wall Slides"
        case .worldsGreatestStretch: return "World's Greatest Stretch"
        }
    }

    var focus: FocusGroup {
        switch self {
        case .squat, .frontSquat, .deadlift, .romanianDeadlift, .benchPress, .overheadPress, .row, .hipThrust, .bulgarianSplitSquat, .legPress,
             .andersonSquat, .atlasStone, .behindTheNeckPress, .beltSquat,
             .boardPress, .boxSquat, .closeGripBenchPress, .declineBenchPress,
             .deficitDeadlift, .farmersWalk, .frontRackCarry, .gobletSquat,
             .goodMorning, .hackSquat, .inclineBenchPress, .jeffersonDeadlift,
             .landminePress, .logPress, .overheadCarry, .pauseSquat,
             .pendlayRow, .rackPull, .safetyBarSquat, .seatedBarbellPress,
             .singleArmRow, .snatchPull, .sumoDeadlift, .tBarRow,
             .trapBarDeadlift, .walkingLunge, .yokeWalk, .zercherSquat,
             .floorPress, .lunge, .overheadSquat, .pushPress,
             .singleLegRDL, .snatchGripDeadlift, .stepUp, .suitcaseCarry,
             .turkishGetUp:
            return .strength
        case .latPulldown, .cableRow, .chestFly, .lateralRaise, .curl, .tricepsExtension, .legExtension, .legCurl, .calfRaiseStanding,
             .chestPressMachine, .platePinch, .arnoldPress, .barbellCurl,
             .cableCrunch, .cablePullThrough, .calfRaiseSeated, .gluteKickback,
             .hammerCurl, .hipAbduction, .hipAdduction, .jmPress,
             .landmineRotation, .neckCurl, .pullover, .rearDeltFly,
             .reverseHyper, .shoulderPressMachine, .shrug, .sideBend,
             .sissySquat, .skullcrusher, .straightArmPulldown, .wristCurl,
             .backExtension, .cableWoodchop, .chestSupportedRow, .facePull,
             .renegadeRow, .uprightRow:
            return .hypertrophy
        case .pushUp, .dip, .pullUp, .plank, .hangingLegRaise, .abWheel, .handstand, .pistolSquat,
             .lateralLunge, .archerPullUp, .archerPushUp, .backLever,
             .bicycleCrunch, .bodyweightSquat, .climbing, .frontLever,
             .gripHold, .gymnastics, .hollowHold, .humanFlag,
             .lyingLegRaise, .muscleUp, .pikePushUp, .planche,
             .skinTheCat, .vUp, .wallSit, .windshieldWiper,
             .deadHang, .dragonFlag, .invertedRow, .lSit,
             .russianTwist, .sitUp:
            return .bodyweight
        case .kettlebellSwing, .boxJump, .medBallSlam, .sprint, .powerClean, .sledPush, .jumpRope,
             .cleanPull, .baseballSoftball, .bounding, .boxing,
             .cleanAndJerk, .cleanAndPress, .depthJump, .dumbbellSnatch,
             .hangClean, .hangSnatch, .highPull, .hillSprint,
             .hurdleHop, .ladderDrill, .lateralBound, .pogoHop,
             .powerSnatch, .pushJerk, .resistedSprint, .sandbagShoulder,
             .shuttleRun, .singleLegHop, .skateboarding, .sledgehammerStrikes,
             .snatch, .snatchBalance, .splitJerk, .splitSquatJump,
             .sprintDrills, .squatClean, .tireFlip, .tuckJump,
             .volleyball, .jumpSquat, .plyoPushUp, .thruster:
            return .explosive
        case .run, .cycle, .rower, .swimming, .hikingStairs, .battleRopes,
             .aquaJogging, .assaultBike, .badminton, .basketball,
             .burpee, .crossCountrySki, .dance, .golf,
             .grappling, .heavyBag, .hiitCircuit, .hockey,
             .mountainBike, .mountainClimber, .openWaterSwim, .paddling,
             .pickleball, .ruckMarch, .rugby, .skating,
             .skiErg, .skiing, .soccer, .squash,
             .surfing, .tennis, .trailRun, .ultimateFrisbee,
             .versaClimber, .walk, .bearCrawl, .elliptical:
            return .endurance
        case .hip90_90, .couchStretch, .cars, .thoracicRotation, .externalRotation, .monsterWalks, .nordicHamstring, .copenhagenPlank, .tibialisRaise, .mcgillBig3, .hipAirplanes, .yoga,
             .deadBug, .adductorRockback, .ankleDorsiflexion, .atgSplitSquat,
             .bandPullApart, .catCow, .deepSquatHold, .dropLanding,
             .foamRolling, .hamstringStretch, .hipFlexorMarch, .jeffersonCurl,
             .kettlebellWindmill, .pilates, .proneYTW, .reverseNordic,
             .scapularPushUp, .shoulderDislocates, .wallSlides, .worldsGreatestStretch,
             .pallofPress, .scapularPullUp:
            return .mobility
        }
    }
}

/// One actually-performed set, in kilograms like WorkoutEntry.weight.
/// RPE, notes, and warm-up marking get their UI later; the fields exist now
/// so per-set storage never needs a second migration.
struct PerformedSet: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var reps: Int? = nil
    var weightKg: Double? = nil
    var rpe: Double? = nil
    var note: String? = nil
    var isWarmup: Bool = false
    /// True when this set was reconstructed from a summary entry
    /// (representative set × count) rather than individually recorded —
    /// PR detection and trend analytics should exclude estimated sets.
    var estimated: Bool = false
}

struct WorkoutEntry: Codable, Identifiable {
    let id: UUID
    var date: Date
    var name: String
    var category: ExerciseCategory
    /// Groups entries logged in one training session (nil = quick log).
    var sessionID: UUID? = nil
    /// Set when this entry was logged as a user-defined exercise — history,
    /// ghosting, and charts key on (category, customExerciseID) pairs.
    var customExerciseID: UUID? = nil
    var sets: Int? // number of sets at these reps (nil = 1, pre-sets entries)
    var reps: Int? // per-set reps for resistance/bodyweight
    var weight: Double? // kg (or lbs if you prefer — treat consistently in app settings)
    var durationMinutes: Double? // for cardio/core/yoga
    var distanceKm: Double? // optional for cardio
    /// Real per-set records (v4+ guided sessions). nil for quick logs and
    /// pre-v4 entries — read through `resolvedSets`, never directly.
    var performedSets: [PerformedSet]? = nil

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

    /// Gameplay currency minted by this specific workout. Optional keeps
    /// pre-v5 saves decodable; migration fills legacy entries before their
    /// history can be edited or deleted.
    var trialMightGained: Double? = nil
    var endgameCoinsGained: Int? = nil

    /// The truthful set list: real per-set records when present, otherwise
    /// the stored summary expanded to `sets` copies of the representative
    /// set, each flagged `estimated`. Storage never contains fabricated
    /// sets — the expansion happens only here, on read.
    var resolvedSets: [PerformedSet] {
        if let performedSets, !performedSets.isEmpty { return performedSets }
        let count = max(1, sets ?? 1)
        return (0..<count).map { _ in
            PerformedSet(reps: reps, weightKg: weight, estimated: true)
        }
    }
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


    /// Canonical rarity order — higher is rarer. Used for sorting.
    var sortRank: Int {
        switch self {
        case .common: return 0
        case .uncommon: return 1
        case .rare: return 2
        case .epic: return 3
        case .mythic: return 4
        }
    }

    /// The top coin roll for this chest tier (see generateCoinsReward) —
    /// only this amount counts as a jackpot for this chest.
    var jackpotCoinAmount: Double {
        switch self {
        case .common: return 135
        case .uncommon: return 225
        case .rare: return 315
        case .epic: return 405
        case .mythic: return 495
        }
    }

    /// Rarity tint used across chest cards, glows, and reward rows.
    /// Tuned so white icons/text stay legible on top of the fill.
    var rarityColor: Color {
        switch self {
        case .common:
            return Color(light: Color(red: 0.58, green: 0.40, blue: 0.22),
                         dark: Color(red: 0.70, green: 0.50, blue: 0.30))
        case .uncommon:
            return Color(light: Color(red: 0.16, green: 0.56, blue: 0.30),
                         dark: Color(red: 0.24, green: 0.66, blue: 0.38))
        case .rare:
            return Color(light: Color(red: 0.13, green: 0.42, blue: 0.83),
                         dark: Color(red: 0.28, green: 0.53, blue: 0.95))
        case .epic:
            return Color(light: Color(red: 0.49, green: 0.24, blue: 0.80),
                         dark: Color(red: 0.60, green: 0.38, blue: 0.92))
        case .mythic:
            return Color(light: Color(red: 0.78, green: 0.16, blue: 0.24),
                         dark: Color(red: 0.90, green: 0.28, blue: 0.34))
        }
    }
}

enum RewardType: String, Codable {
    case bonus_xp
    case coins
    case item
    case egg

    var displayName: String {
        switch self {
        case .bonus_xp: return "Experience"
        case .coins: return "Coins"
        case .item: return "Item"
        case .egg: return "Companion Egg"
        }
    }
}

enum EpicTierItem: String, CaseIterable, Codable {
    case birthdaycake
    case gamecontroller

    var displayName: String {
        switch self {
        case .birthdaycake: return "Gilded Chalice"
        case .gamecontroller: return "Arcane Tome"
        }
    }

    var iconName: String {
        switch self {
        case .birthdaycake: return "glyph:chalice"
        case .gamecontroller: return "glyph:book"
        }
    }

    var iconColor: Color {
        switch self {
        case .birthdaycake: return RPGTheme.gold
        case .gamecontroller: return RPGTheme.arcane
        }
    }

    var rarity: String {
        return "Epic"
    }

    var rarityColor: Color {
        return TreasureChestType.epic.rarityColor
    }
}

enum LegendaryTierItem: String, CaseIterable, Codable {
    case trophy
    case wand

    var displayName: String {
        switch self {
        case .trophy: return "Champion's Trophy"
        case .wand: return "Wand of Stars"
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
        case .trophy: return RPGTheme.gold
        case .wand: return RPGTheme.arcane
        }
    }

    var rarity: String {
        return "Legendary"
    }

    var rarityColor: Color {
        return RPGTheme.gold
    }
}

enum MythicTierItem: String, CaseIterable, Codable {
    case teddybear

    var displayName: String {
        switch self {
        case .teddybear: return "Ancient Crown"
        }
    }

    var iconName: String {
        switch self {
        case .teddybear: return "glyph:crown"
        }
    }

    var iconColor: Color {
        switch self {
        case .teddybear: return TreasureChestType.mythic.rarityColor
        }
    }

    var rarity: String {
        return "Mythic"
    }

    var rarityColor: Color {
        return TreasureChestType.mythic.rarityColor
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

    /// The attribute this goal trains — drives its color, glyph, and fill.
    var stat: Stat {
        switch self {
        case .strength: return .strength
        case .hypertrophy: return .size
        case .endurance: return .endurance
        case .explosive: return .agility
        case .mobility: return .vitality
        case .bodyweight: return .dexterity
        }
    }

    var color: Color { stat.color }
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

    // rawValue doubles as the persistence key, so renames happen here only.
    var displayName: String { self == .quality ? "Duelist" : rawValue }

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


    // Class hues belong on crest rails and restrained selection washes. Large
    // surfaces stay parchment/charcoal so all fifteen classes share one world.
    var color: Color {
        switch self {
        case .warrior: return Color(red: 0.85, green: 0.18, blue: 0.18) // Red
        case .quality: return Color(red: 0.80, green: 0.40, blue: 0.00) // Deep orange
        case .berserker: return Color(red: 0.85, green: 0.28, blue: 0.02) // Red-orange
        case .paladin: return Color(red: 0.66, green: 0.50, blue: 0.02) // Gold
        case .assassin: return Color(red: 0.55, green: 0.05, blue: 0.78) // Deep purple
        case .monk: return Color(red: 0.02, green: 0.42, blue: 0.85) // Blue
        case .ranger: return Color(red: 0.12, green: 0.55, blue: 0.18) // Forest green
        case .scout: return Color(red: 0.00, green: 0.55, blue: 0.36) // Deep mint
        case .tank: return Color(red: 0.78, green: 0.44, blue: 0.00) // Amber
        case .brawler: return Color(red: 0.75, green: 0.32, blue: 0.02) // Burnt orange
        case .titan: return Color(red: 0.46, green: 0.10, blue: 0.85) // Royal purple
        case .juggernaut: return Color(red: 0.38, green: 0.38, blue: 0.50) // Steel
        case .spartan: return Color(red: 0.78, green: 0.10, blue: 0.12) // Crimson
        case .druid: return Color(red: 0.02, green: 0.52, blue: 0.24) // Vibrant forest
        case .healer: return Color(red: 0.00, green: 0.48, blue: 0.65) // Sea blue
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

    /// The two attributes this class trains — derived from its focus pair so
    /// emblem, skills, and quests can never drift apart.
    var trainedStats: [Stat] {
        focusCategories.map(\.primaryStat)
    }

    var primarySkills: [String] {
        trainedStats.map(\.name)
    }

    /// "Strength & Endurance" — used in affinity copy.
    var focusPairText: String {
        focusCategories.map(\.shortDisplayName).joined(separator: " & ")
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
    /// Comeback quests welcome a lapsed adventurer back — never punish.
    /// Optional so files written before this field decode cleanly.
    var isComeback: Bool? = nil

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

enum ItemInfo: Codable, Equatable {
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

    /// Every item in the shipped loot catalog participates in the loadout and
    /// grants Might. Keep the category behavioral: a tonic does not become a
    /// consumable until the game actually offers a consume action.
    var inventoryType: InventoryItemType {
        switch self {
        case .uncommon(.soccerball),
             .uncommon(.basketball),
             .uncommon(.volleyball),
             .rare(.dice),
             .rare(.puzzlepiece),
             .rare(.balloon),
             .epic(.birthdaycake),
             .epic(.gamecontroller),
             .legendary(.trophy),
             .legendary(.wand),
             .mythic(.teddybear):
            return .equipment
        }
    }

    /// Semantic artwork for the authored loot catalog. The deliberately odd
    /// tier-case raw values remain untouched because they are persisted.
    var rpgSymbol: RPGSymbol {
        switch self {
        case .uncommon(.soccerball): return .lootBuckler
        case .uncommon(.basketball): return .lootTonic
        case .uncommon(.volleyball): return .lootMap
        case .rare(.dice): return .lootDice
        case .rare(.puzzlepiece): return .lootRuneFragment
        case .rare(.balloon): return .lootPhoenixFeather
        case .epic(.birthdaycake): return .lootChalice
        case .epic(.gamecontroller): return .lootTome
        case .legendary(.trophy): return .lootTrophy
        case .legendary(.wand): return .lootWand
        case .mythic(.teddybear): return .lootCrown
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

struct TreasureReward: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    let type: RewardType
    let amount: Double
    let description: String
    let itemInfo: ItemInfo?

    private enum CodingKeys: String, CodingKey {
        case id, type, amount, description, itemInfo
    }
}

extension TreasureReward {
    // Hand-written so pre-v4 saves (no id key) decode with a fresh id instead
    // of failing; lives in an extension to keep the memberwise init.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        type = try container.decode(RewardType.self, forKey: .type)
        amount = try container.decode(Double.self, forKey: .amount)
        description = try container.decode(String.self, forKey: .description)
        itemInfo = try container.decodeIfPresent(ItemInfo.self, forKey: .itemInfo)
    }
}

struct TreasureChest: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    let type: TreasureChestType
    let earnedAtLevel: Int
    let dateEarned: Date
    var isOpened: Bool = false
    var rewards: [TreasureReward] = []

    private enum CodingKeys: String, CodingKey {
        case id, type, earnedAtLevel, dateEarned, isOpened, rewards
    }

}

extension TreasureChest {
    // Hand-written so pre-v4 saves (no id key) decode with a fresh id instead
    // of failing; lives in an extension to keep the memberwise init.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        type = try container.decode(TreasureChestType.self, forKey: .type)
        earnedAtLevel = try container.decode(Int.self, forKey: .earnedAtLevel)
        dateEarned = try container.decode(Date.self, forKey: .dateEarned)
        isOpened = try container.decode(Bool.self, forKey: .isOpened)
        rewards = try container.decode([TreasureReward].self, forKey: .rewards)
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

    var rpgSymbol: RPGSymbol {
        switch self {
        case .consumable: return .lootConsumable
        case .equipment: return .lootEquipment
        case .material: return .lootMaterial
        case .collectible: return .lootCollectible
        }
    }

    /// Returns the canonical category only when both the shipped item name and
    /// its persisted icon identify the same catalog entry. Requiring both keeps
    /// unrelated/debug items that reuse a rune or SF Symbol untouched.
    static func canonical(
        forItemNamed name: String,
        persistedIconName iconName: String
    ) -> InventoryItemType? {
        RPGSymbol.lootSymbol(
            forItemNamed: name,
            persistedIconName: iconName
        ) == nil ? nil : .equipment
    }
}

enum InventoryItemRarity: String, CaseIterable, Codable {
    case common = "common"
    case uncommon = "uncommon"
    case rare = "rare"
    case epic = "epic"
    case legendary = "legendary"
    case mythic = "mythic"

}

struct InventoryItem: Codable, Identifiable {
    var id: UUID = UUID()
    let name: String
    let description: String
    let type: InventoryItemType
    let rarity: InventoryItemRarity
    let iconName: String // Specific SF Symbol icon name
    var quantity: Int
    let dateObtained: Date
    let value: Int // For future trading/selling

    private enum CodingKeys: String, CodingKey {
        case id, name, description, type, rarity, iconName, quantity, dateObtained, value
    }

    /// The single construction boundary for inventory records. Catalog items
    /// are normalized here so every acquisition path agrees, while unknown
    /// records keep the category supplied by their caller or save file.
    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        type: InventoryItemType,
        rarity: InventoryItemRarity,
        iconName: String,
        quantity: Int,
        dateObtained: Date,
        value: Int
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = InventoryItemType.canonical(
            forItemNamed: name,
            persistedIconName: iconName
        ) ?? type
        self.rarity = rarity
        self.iconName = iconName
        self.quantity = quantity
        self.dateObtained = dateObtained
        self.value = value
    }
}

extension InventoryItem {
    /// Known catalog entries get their authored symbol only when their stored
    /// name and icon identify the same item. Unknown items retain a useful
    /// category identity instead of inheriting another item's artwork.
    var rpgSymbol: RPGSymbol {
        RPGSymbol.lootSymbol(
            forItemNamed: name,
            persistedIconName: iconName
        ) ?? type.rpgSymbol
    }

    // Hand-written so pre-v4 saves (no id key) decode with a fresh id instead
    // of failing — equippedItems references these ids, so ids must survive
    // every encode/decode round-trip from here on. Delegating through the
    // construction boundary also repairs stale chest-era categories on load.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: (try? container.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID(),
            name: try container.decode(String.self, forKey: .name),
            description: try container.decode(String.self, forKey: .description),
            type: try container.decode(InventoryItemType.self, forKey: .type),
            rarity: try container.decode(InventoryItemRarity.self, forKey: .rarity),
            iconName: try container.decode(String.self, forKey: .iconName),
            quantity: try container.decode(Int.self, forKey: .quantity),
            dateObtained: try container.decode(Date.self, forKey: .dateObtained),
            value: try container.decode(Int.self, forKey: .value)
        )
    }
}

extension RPGSymbol {
    /// Resolves the current catalog and its pre-semantic-icon save format.
    /// Both persisted fields are required because icon strings are not unique
    /// item identities (debug and future loot may legitimately reuse them).
    static func lootSymbol(
        forItemNamed name: String,
        persistedIconName iconName: String
    ) -> RPGSymbol? {
        switch name {
        case "Bronze Buckler", "Soccer Ball":
            return ["glyph:shield", "soccerball"].contains(iconName) ? .lootBuckler : nil
        case "Strength Tonic", "Basketball":
            return ["glyph:potion", "basketball.fill"].contains(iconName) ? .lootTonic : nil
        case "Traveler's Map", "Volleyball":
            return ["glyph:scroll", "volleyball.fill"].contains(iconName) ? .lootMap : nil
        case "Enchanted Dice", "Dice":
            return iconName == "dice.fill" ? .lootDice : nil
        case "Rune Fragment", "Puzzle Piece":
            return ["glyph:rune", "puzzlepiece.fill"].contains(iconName) ? .lootRuneFragment : nil
        case "Phoenix Feather", "Balloon":
            return ["glyph:wing", "balloon.fill"].contains(iconName) ? .lootPhoenixFeather : nil
        case "Gilded Chalice", "Birthday Cake":
            return ["glyph:chalice", "birthday.cake.fill"].contains(iconName) ? .lootChalice : nil
        case "Arcane Tome", "Game Controller":
            return ["glyph:book", "gamecontroller.fill"].contains(iconName) ? .lootTome : nil
        case "Champion's Trophy", "Trophy":
            return iconName == "trophy.fill" ? .lootTrophy : nil
        case "Wand of Stars", "Magic Wand":
            return iconName == "wand.and.stars" ? .lootWand : nil
        case "Ancient Crown", "Teddy Bear":
            return ["glyph:crown", "teddybear.fill"].contains(iconName) ? .lootCrown : nil
        default: return nil
        }
    }
}

enum UncommonTierItem: String, CaseIterable, Codable {
    case soccerball
    case basketball
    case volleyball

    var displayName: String {
        switch self {
        case .soccerball: return "Bronze Buckler"
        case .basketball: return "Strength Tonic"
        case .volleyball: return "Traveler's Map"
        }
    }

    var iconName: String {
        switch self {
        case .soccerball: return "glyph:shield"
        case .basketball: return "glyph:potion"
        case .volleyball: return "glyph:scroll"
        }
    }

    var iconColor: Color {
        switch self {
        case .soccerball: return TreasureChestType.common.rarityColor // bronze
        case .basketball: return Stat.strength.color
        case .volleyball: return RPGTheme.frame
        }
    }

    var rarity: String {
        return "Uncommon"  // All current items are uncommon tier
    }

    var rarityColor: Color {
        return TreasureChestType.uncommon.rarityColor
    }
}

enum RareTierItem: String, CaseIterable, Codable {
    case dice
    case puzzlepiece
    case balloon

    var displayName: String {
        switch self {
        case .dice: return "Enchanted Dice"
        case .puzzlepiece: return "Rune Fragment"
        case .balloon: return "Phoenix Feather"
        }
    }

    var iconName: String {
        switch self {
        case .dice: return "dice.fill"
        case .puzzlepiece: return "glyph:rune"
        case .balloon: return "glyph:wing"
        }
    }

    var iconColor: Color {
        switch self {
        case .dice: return .primary // adapts to light/dark backgrounds
        case .puzzlepiece: return RPGTheme.arcane
        case .balloon: return Stat.dexterity.color // phoenix flame
        }
    }

    var rarity: String {
        return "Rare"
    }

    var rarityColor: Color {
        return TreasureChestType.rare.rarityColor
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
    // XP earned outside workouts (quests, chest bonuses) — replayed on
    // recalculation so edits/deletes can't erase it.
    var bonusXP: Double = 0
    // Highest level that has ever minted a chest — prevents farming chests
    // by deleting and re-logging workouts across the same level boundary.
    var chestHighWaterLevel: Int = 0
    // Companion system
    var companionEggs: Int = 0
    var hatchedCompanions: [String] = []
    var activeCompanion: String? = nil
    var ownedAccessories: [String] = []
    var petAccessories: [String: String] = [:]
    // Training streak: freezes cover a single missed day so one bad day
    // never erases a habit. Earned by consistency, buyable with coins.
    var streakFreezes: Int = 1
    var freezeDaysUsed: [Date] = []
    var lastFreezeEarnedAtStreak: Int = 0
    // The Trial: banked might (damage) from logged training, spent on the
    // boss ladder. If history-backed rewards have already been spent when
    // their workout is removed, debt preserves the loot/balance while future
    // training repays that deleted contribution before minting more.
    var trialRung: Int = 0
    var trialMight: Double = 0
    var trialMightDebt: Double = 0
    var endgameCoinDebt: Int = 0
    var trialVictories: [TrialVictory] = []
    // Equipment loadout: slot rawValue → equipped InventoryItem id string.
    var equippedItems: [String: String] = [:]
    // Reusable session templates, newest first.
    var routines: [Routine] = []
    // User-defined exercises, newest first.
    var customExercises: [CustomExercise] = []
    // EquipmentKind rawValues the user trains with. nil = not configured.
    var availableEquipment: [String]? = nil
    // Species rawValue → the user's chosen name for that spirit.
    var companionNames: [String: String] = [:]
    // Companion bond: distinct training DAYS per species while active.
    var companionBondDays: [String: Int] = [:]
    var lastBondDay: Date? = nil
    // Comeback quests mint once per absence, tracked by mint date.
    var lastComebackQuestDate: Date? = nil
    // The Weighing at the Ledgerstone: bands, epithet and the seeds the recalc
    // fold-in re-applies. nil = never weighed.
    var placement: PlacementRecord? = nil

    enum CodingKeys: String, CodingKey {
        case bestPerf
        case level
        case xp
        case nextLevelXP
        case stats
        case coins
        case units
        case bodyweightKg
        case best1RM
        case xpBaselines
        case ranks
        case mobilityStreakCount
        case lastMobilityDay
        case firstStatGrantApplied
        case treasureChests
        case inventory
        case rpgClass
        case dailyChallenges
        case weeklyChallenges
        case lastDailyChallengeGeneration
        case lastWeeklyChallengeGeneration
        case challengePreferences
        case bonusXP
        case chestHighWaterLevel
        case companionEggs
        case hatchedCompanions
        case activeCompanion
        case ownedAccessories
        case petAccessories
        case streakFreezes
        case freezeDaysUsed
        case lastFreezeEarnedAtStreak
        case trialRung
        case trialMight
        case trialMightDebt
        case endgameCoinDebt
        case trialVictories
        case equippedItems
        case routines
        case customExercises
        case availableEquipment
        case companionNames
        case companionBondDays
        case lastBondDay
        case lastComebackQuestDate
        case placement
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bestPerf = container.decodeValue([ExerciseCategory: Double].self, forKey: .bestPerf, default: [:])
        level = container.decodeValue(Int.self, forKey: .level, default: 1)
        xp = container.decodeValue(Double.self, forKey: .xp, default: 0)
        nextLevelXP = container.decodeValue(Double.self, forKey: .nextLevelXP, default: StatEngine.xpNeeded(forNextLevel: max(1, level)))
        stats = container.decodeValue(StatBlock.self, forKey: .stats, default: .zero)
        coins = container.decodeValue(Int.self, forKey: .coins, default: 0)
        units = container.decodeValue(Units.self, forKey: .units, default: .kg)
        // Every field decodes with a fallback: one corrupt value must degrade
        // to its default, never throw and silently replace the whole profile
        // with a fresh one (which validateData would then endorse).
        bodyweightKg = (try? container.decodeIfPresent(Double.self, forKey: .bodyweightKg)) ?? nil
        best1RM = container.decodeValue([ExerciseCategory: Double].self, forKey: .best1RM, default: [:])
        xpBaselines = container.decodeValue([ExerciseCategory: Double].self, forKey: .xpBaselines, default: [:])
        ranks = container.decodeValue(StatRanks.self, forKey: .ranks, default: StatRanks())
        mobilityStreakCount = container.decodeValue(Int.self, forKey: .mobilityStreakCount, default: 0)
        lastMobilityDay = (try? container.decodeIfPresent(Date.self, forKey: .lastMobilityDay)) ?? nil
        firstStatGrantApplied = container.decodeValue(Set<ExerciseCategory>.self, forKey: .firstStatGrantApplied, default: [])
        treasureChests = container.decodeValue([TreasureChest].self, forKey: .treasureChests, default: [])
        inventory = container.decodeValue([InventoryItem].self, forKey: .inventory, default: [])
        // An unrecognized class raw value (e.g. from a rename) degrades to
        // "no class chosen" instead of throwing the whole profile away.
        rpgClass = (try? container.decodeIfPresent(RPGClass.self, forKey: .rpgClass)) ?? nil
        dailyChallenges = container.decodeValue([Challenge].self, forKey: .dailyChallenges, default: [])
        weeklyChallenges = container.decodeValue([Challenge].self, forKey: .weeklyChallenges, default: [])
        lastDailyChallengeGeneration = (try? container.decodeIfPresent(Date.self, forKey: .lastDailyChallengeGeneration)) ?? nil
        lastWeeklyChallengeGeneration = (try? container.decodeIfPresent(Date.self, forKey: .lastWeeklyChallengeGeneration)) ?? nil
        challengePreferences = container.decodeValue([FocusGroup: ChallengePreference].self, forKey: .challengePreferences, default: [:])
        bonusXP = container.decodeValue(Double.self, forKey: .bonusXP, default: 0)
        chestHighWaterLevel = container.decodeValue(Int.self, forKey: .chestHighWaterLevel, default: 0)
        companionEggs = container.decodeValue(Int.self, forKey: .companionEggs, default: 0)
        hatchedCompanions = container.decodeValue([String].self, forKey: .hatchedCompanions, default: [])
        activeCompanion = try? container.decodeIfPresent(String.self, forKey: .activeCompanion)
        ownedAccessories = container.decodeValue([String].self, forKey: .ownedAccessories, default: [])
        petAccessories = container.decodeValue([String: String].self, forKey: .petAccessories, default: [:])
        streakFreezes = container.decodeValue(Int.self, forKey: .streakFreezes, default: 1)
        freezeDaysUsed = container.decodeValue([Date].self, forKey: .freezeDaysUsed, default: [])
        lastFreezeEarnedAtStreak = container.decodeValue(Int.self, forKey: .lastFreezeEarnedAtStreak, default: 0)
        trialRung = container.decodeValue(Int.self, forKey: .trialRung, default: 0)
        trialMight = container.decodeValue(Double.self, forKey: .trialMight, default: 0)
        trialMightDebt = container.decodeValue(Double.self, forKey: .trialMightDebt, default: 0)
        endgameCoinDebt = container.decodeValue(Int.self, forKey: .endgameCoinDebt, default: 0)
        trialVictories = container.decodeValue([TrialVictory].self, forKey: .trialVictories, default: [])
        equippedItems = container.decodeValue([String: String].self, forKey: .equippedItems, default: [:])
        routines = container.decodeValue([Routine].self, forKey: .routines, default: [])
        customExercises = container.decodeValue([CustomExercise].self, forKey: .customExercises, default: [])
        availableEquipment = try? container.decodeIfPresent([String].self, forKey: .availableEquipment)
        companionNames = container.decodeValue([String: String].self, forKey: .companionNames, default: [:])
        companionBondDays = container.decodeValue([String: Int].self, forKey: .companionBondDays, default: [:])
        lastBondDay = (try? container.decodeIfPresent(Date.self, forKey: .lastBondDay)) ?? nil
        lastComebackQuestDate = (try? container.decodeIfPresent(Date.self, forKey: .lastComebackQuestDate)) ?? nil
        // A corrupt record degrades to "never weighed" — losing the epithet is
        // survivable; losing the profile is not.
        placement = (try? container.decodeIfPresent(PlacementRecord.self, forKey: .placement)) ?? nil
    }
}

/// A defeated Trial boss — the trophy record.
struct TrialVictory: Codable, Identifiable, Equatable {
    var id: Int { rung }
    let rung: Int
    let bossName: String
    let date: Date
}

struct PersistedData: Codable {
    // v3: smooth global XP curve (levels are recalculated once on migration)
    // v4: inventory/chest/reward ids are persisted (equippedItems references
    // survive relaunch) and history entries carry real per-set data.
    // v5: workout-backed Trial/endgame rewards are attributed per entry and
    // weekly quest windows use calendar-week boundaries.
    static let currentSchemaVersion = 5

    var schemaVersion: Int = currentSchemaVersion
    var user: UserProfile
    var history: [WorkoutEntry]

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case user
        case history
    }

    init(user: UserProfile, history: [WorkoutEntry], schemaVersion: Int = currentSchemaVersion) {
        self.schemaVersion = schemaVersion
        self.user = user
        self.history = history
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Absent key = old schema (tolerate); corrupt value = broken file
        // (THROW, so load()'s primary → backup → fallback ladder advances).
        // Swallowing decode errors here is how a single malformed workout
        // used to silently erase the entire visible history.
        schemaVersion = container.decodeValue(Int.self, forKey: .schemaVersion, default: 1)
        user = try container.decode(UserProfile.self, forKey: .user)
        history = try container.decodeIfPresent([WorkoutEntry].self, forKey: .history) ?? []
    }
}

// MARK: - Stat/EXP Engine
enum StatEngine {
    // Specify how many primary stats to display per exercise in History
    static func primaryDisplayCount(for category: ExerciseCategory) -> Int {
        switch category {
        // Mostly two-attribute moves
        case .benchPress, .overheadPress, .row, .latPulldown, .cableRow, .chestFly,
             .lateralRaise, .curl, .tricepsExtension, .legExtension, .legCurl, .calfRaiseStanding,
             .plank, .hangingLegRaise, .abWheel, .handstand, .pistolSquat,
             .behindTheNeckPress, .boardPress, .chestPressMachine, .closeGripBenchPress,
             .declineBenchPress, .inclineBenchPress, .pendlayRow, .platePinch,
             .seatedBarbellPress, .singleArmRow, .tBarRow, .arnoldPress,
             .barbellCurl, .cableCrunch, .cablePullThrough, .calfRaiseSeated,
             .gluteKickback, .hammerCurl, .hipAbduction, .hipAdduction,
             .jmPress, .landmineRotation, .neckCurl, .pullover,
             .rearDeltFly, .reverseHyper, .shoulderPressMachine, .shrug,
             .sideBend, .sissySquat, .skullcrusher, .straightArmPulldown,
             .wristCurl, .backLever, .bicycleCrunch, .deadBug,
             .frontLever, .gripHold, .hollowHold, .humanFlag,
             .lyingLegRaise, .planche, .skinTheCat, .vUp,
             .wallSit, .windshieldWiper, .backExtension, .chestSupportedRow,
             .deadHang, .dragonFlag, .floorPress, .lSit,
             .pushPress, .russianTwist, .sitUp, .uprightRow:
            return 2
        default:
            return 3
        }
    }
    // MARK: - Stat/EXP Engine
    static let maxLevel = 100
    /// Prestige tiers run 0–9; with 10 display levels each, total level caps at 100.
    static let maxPrestige = 9

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

    /// est-1RM/bodyweight anchors for the barbell lifts — the single source
    /// for placement AND for milestone targets (inverted), so the "you're
    /// close to Gold" math can never drift from the placement math.
    static func strengthAnchors(for category: ExerciseCategory) -> [(Double, Int)]? {
        switch category {
        case .benchPress:
            return [(0.60, 10), (0.80, 25), (1.00, 40), (1.25, 55), (1.50, 70), (2.00, 90), (2.50, 98)]
        case .squat:
            return [(0.80, 15), (1.00, 25), (1.50, 45), (2.00, 65), (2.50, 85), (3.00, 97)]
        case .deadlift:
            return [(1.00, 20), (1.25, 35), (1.75, 55), (2.25, 75), (2.75, 90), (3.00, 96)]
        case .overheadPress:
            return [(0.40, 10), (0.60, 25), (0.80, 45), (1.00, 65), (1.20, 85), (1.40, 96)]
        default:
            return nil
        }
    }

    /// The four lifts that get their own leveling and milestone targets.
    static let signatureLifts: [ExerciseCategory] = [.benchPress, .squat, .deadlift, .overheadPress]

    /// Placement level (0-100) for a signature lift from best est-1RM.
    static func liftLevel(category: ExerciseCategory, oneRM: Double, bodyweightKg: Double) -> Int {
        guard let anchors = strengthAnchors(for: category), bodyweightKg > 0, oneRM > 0 else { return 0 }
        return interpLevel(x: oneRM / bodyweightKg, anchors: anchors)
    }

    /// Inverse of the anchor interpolation: the est-1RM needed to reach a
    /// placement level on a signature lift. Nil beyond the anchor range.
    static func requiredOneRM(category: ExerciseCategory, level: Int, bodyweightKg: Double) -> Double? {
        guard let anchors = strengthAnchors(for: category), bodyweightKg > 0,
              let first = anchors.first, let last = anchors.last,
              level >= first.1, level <= last.1 else { return nil }
        for i in 0..<(anchors.count - 1) {
            let (x0, y0) = anchors[i]
            let (x1, y1) = anchors[i + 1]
            if level >= y0 && level <= y1 {
                let t = Double(level - y0) / max(1e-9, Double(y1 - y0))
                return (x0 + t * (x1 - x0)) * bodyweightKg
            }
        }
        return nil
    }

    private static func levelFromBenchRatio(_ ratio: Double) -> Int {
        interpLevel(x: ratio, anchors: strengthAnchors(for: .benchPress)!)
    }

    private static func levelFromSquatRatio(_ ratio: Double) -> Int {
        interpLevel(x: ratio, anchors: strengthAnchors(for: .squat)!)
    }

    private static func levelFromDeadliftRatio(_ ratio: Double) -> Int {
        interpLevel(x: ratio, anchors: strengthAnchors(for: .deadlift)!)
    }

    private static func levelFromOHPRatio(_ ratio: Double) -> Int {
        interpLevel(x: ratio, anchors: strengthAnchors(for: .overheadPress)!)
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
             .pushUp, .dip, .pullUp, .handstand, .pistolSquat, .plank, .copenhagenPlank, .mcgillBig3,
             .andersonSquat, .boardPress, .closeGripBenchPress, .declineBenchPress,
             .deficitDeadlift, .inclineBenchPress, .lateralLunge, .logPress,
             .pauseSquat, .platePinch, .rackPull, .safetyBarSquat,
             .seatedBarbellPress, .sumoDeadlift, .trapBarDeadlift, .sissySquat,
             .archerPullUp, .archerPushUp, .backLever, .frontLever,
             .gripHold, .hollowHold, .humanFlag, .muscleUp,
             .pikePushUp, .planche, .wallSit, .cleanAndJerk,
             .hangClean, .hangSnatch, .powerSnatch, .pushJerk,
             .snatch, .splitJerk, .squatClean, .backExtension,
             .deadHang, .floorPress, .invertedRow, .lSit,
             .lunge, .overheadSquat, .pushPress, .snatchGripDeadlift,
             .stepUp:
            return levelFromBest1RM(metric)
        // endurance categories have separate scales (tuned for placement extremes)
        case .run,
             .crossCountrySki, .trailRun, .elliptical:
            S = 500 // speed*distance; ~80–90 for elite marathon
        case .cycle,
             .mountainBike, .skating:
            S = 80000 // TDF‑scale ends ~90+
        case .rower,
             .skiErg:
            S = 15000
        case .swimming,
             .openWaterSwim:
            S = 7000
        case .hikingStairs, .battleRopes, .jumpRope, .sledPush,
             .farmersWalk, .frontRackCarry, .overheadCarry, .yokeWalk,
             .climbing, .gymnastics, .baseballSoftball, .boxing,
             .ladderDrill, .skateboarding, .sprintDrills, .volleyball,
             .aquaJogging, .assaultBike, .badminton, .basketball,
             .burpee, .dance, .golf, .grappling,
             .heavyBag, .hiitCircuit, .hockey, .mountainClimber,
             .paddling, .pickleball, .ruckMarch, .rugby,
             .skiing, .soccer, .squash, .surfing,
             .tennis, .ultimateFrisbee, .versaClimber, .walk,
             .bearCrawl, .suitcaseCarry:
            S = 8000
        default:
            S = 10000
        }
        let x = pow(metric / S, alpha)
        let frac = 1.0 - Foundation.exp(-max(0, x))
        let lvl = Int(round(Double(maxLevel) * frac))
        return max(0, min(maxLevel, lvl))
    }

    /// Placement for movements that do not have an authored lift- or
    /// pace-specific standard. These movements are logged in different units
    /// (reps, load x reps, or minutes), but `intensityScore` already converts
    /// each of those inputs onto a shared work scale. Keeping the placement
    /// curve on that scale avoids comparing raw minutes or reps with constants
    /// that were calibrated for work scores.
    private static func placementLevelFromTrainingScore(
        category: ExerciseCategory,
        score: Double
    ) -> Int {
        guard score > 0 else { return 0 }

        // Mobility is intentionally consistency-led: it contributes through
        // XP, stats, quests, and streaks rather than establishing a starting
        // level from one session.
        guard category.focus != .mobility else { return 0 }

        // S is the score that lands at roughly level 63 on the saturating
        // curve. The focus-specific values keep a plausible introductory
        // session in the single digits/teens while leaving ample headroom for
        // genuinely large sessions.
        let scale: Double
        switch category.focus {
        case .strength:    scale = 5_000
        case .hypertrophy: scale = 4_000
        case .bodyweight:  scale = 3_500
        case .explosive:   scale = 5_000
        case .endurance:   scale = 8_000
        case .mobility:    return 0
        }

        let normalized = pow(score / scale, 1.1)
        let fraction = 1.0 - Foundation.exp(-normalized)
        return max(0, min(maxLevel, Int(round(Double(maxLevel) * fraction))))
    }

    static func placementLevelCandidate(category: ExerciseCategory,
                                        reps: Int?, weight: Double?,
                                        durationMin: Double?, distanceKm: Double?,
                                        bodyweightKg: Double?) -> Int {
        switch category {
        case .squat,
             .andersonSquat, .pauseSquat, .safetyBarSquat:
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
        case .deadlift,
             .deficitDeadlift, .sumoDeadlift, .trapBarDeadlift:
            let est = estimate1RM(category: category, reps: reps, weight: weight)
            guard let bw = bodyweightKg, bw > 0, est > 0 else {
                return placementLevel(for: category, metric: est)
            }
            return levelFromDeadliftRatio(est / bw)
        case .romanianDeadlift,
             .snatchGripDeadlift:
            let est = estimate1RM(category: category, reps: reps, weight: weight)
            guard let bw = bodyweightKg, bw > 0, est > 0 else {
                return placementLevel(for: category, metric: est)
            }
            return levelFromRDLRatio(est / bw)
        case .overheadPress,
             .seatedBarbellPress:
            let est = estimate1RM(category: category, reps: reps, weight: weight)
            guard let bw = bodyweightKg, bw > 0, est > 0 else {
                return placementLevel(for: category, metric: est)
            }
            return levelFromOHPRatio(est / bw)
        case .powerClean,
             .cleanAndJerk, .hangClean, .hangSnatch, .powerSnatch,
             .pushJerk, .snatch, .splitJerk, .squatClean,
             .pushPress:
            let est = estimate1RM(category: category, reps: reps, weight: weight)
            guard let bw = bodyweightKg, bw > 0, est > 0 else {
                return placementLevel(for: category, metric: est)
            }
            return levelFromPowerCleanRatio(est / bw)
        case .benchPress,
             .closeGripBenchPress, .declineBenchPress, .inclineBenchPress:
            let est = estimate1RM(category: category, reps: reps, weight: weight)
            guard let bw = bodyweightKg, bw > 0, est > 0 else {
                return placementLevel(for: category, metric: est)
            }
            let ratio = est / bw
            return levelFromBenchRatio(ratio)
        case .cycle,
             .mountainBike, .skating:
            let d = max(0, distanceKm ?? 0)
            let tHr = max(0.0, (durationMin ?? 0) / 60.0)
            guard d > 0, tHr > 0 else { return 0 }
            let speed = d / tHr
            return levelFromCycling(speedKPH: speed, distanceKm: d)
        case .run,
             .crossCountrySki, .trailRun:
            let d = max(0, distanceKm ?? 0)
            let tHr = max(0.0, (durationMin ?? 0) / 60.0)
            guard d > 0, tHr > 0 else { return 0 }
            let speed = d / tHr
            return levelFromRunning(speedKPH: speed, distanceKm: d)
        case .rower,
             .skiErg:
            let d = max(0, distanceKm ?? 0)
            let tHr = max(0.0, (durationMin ?? 0) / 60.0)
            guard d > 0, tHr > 0 else { return 0 }
            let speed = d / tHr
            return levelFromRowing(speedKPH: speed, distanceKm: d)
        case .swimming,
             .openWaterSwim:
            let d = max(0, distanceKm ?? 0)
            let tHr = max(0.0, (durationMin ?? 0) / 60.0)
            guard d > 0, tHr > 0 else { return 0 }
            let speed = d / tHr
            return levelFromSwimming(speedKPH: speed, distanceKm: d)
        default:
            // A few secondary barbell/Olympic variations still have a real
            // 1RM model even though they do not need their own bodyweight
            // anchor table. Preserve that authored path before falling back
            // to the shared work-score curve.
            let estimatedOneRM = estimate1RM(
                category: category,
                reps: reps,
                weight: weight
            )
            if estimatedOneRM > 0 {
                return placementLevel(for: category, metric: estimatedOneRM)
            }

            let score = intensityScore(
                category: category,
                reps: reps,
                weight: weight,
                durationMin: durationMin,
                distanceKm: distanceKm
            )
            return placementLevelFromTrainingScore(category: category, score: score)
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

        // MARK: Expanded catalog
        // Strength
        case .andersonSquat:         return StatBlock(size: 0.35, strength: 0.50, dexterity: 0.05, agility: 0.10, endurance: 0.00, vitality: 0.00)
        case .atlasStone:            return StatBlock(size: 0.25, strength: 0.50, dexterity: 0.10, agility: 0.05, endurance: 0.00, vitality: 0.10)
        case .behindTheNeckPress:    return StatBlock(size: 0.40, strength: 0.40, dexterity: 0.20, agility: 0.00, endurance: 0.00, vitality: 0.00)
        case .beltSquat:             return StatBlock(size: 0.45, strength: 0.40, dexterity: 0.05, agility: 0.00, endurance: 0.00, vitality: 0.10)
        case .boardPress:            return StatBlock(size: 0.30, strength: 0.50, dexterity: 0.15, agility: 0.00, endurance: 0.00, vitality: 0.05)
        case .boxSquat:              return StatBlock(size: 0.35, strength: 0.50, dexterity: 0.05, agility: 0.10, endurance: 0.00, vitality: 0.00)
        case .closeGripBenchPress:   return StatBlock(size: 0.35, strength: 0.50, dexterity: 0.15, agility: 0.00, endurance: 0.00, vitality: 0.00)
        case .declineBenchPress:     return StatBlock(size: 0.45, strength: 0.50, dexterity: 0.00, agility: 0.00, endurance: 0.00, vitality: 0.05)
        case .deficitDeadlift:       return StatBlock(size: 0.30, strength: 0.55, dexterity: 0.05, agility: 0.00, endurance: 0.00, vitality: 0.10)
        case .farmersWalk:           return StatBlock(size: 0.15, strength: 0.40, dexterity: 0.20, agility: 0.00, endurance: 0.15, vitality: 0.10)
        case .floorPress:            return StatBlock(size: 0.35, strength: 0.50, dexterity: 0.10, agility: 0.00, endurance: 0.00, vitality: 0.05)
        case .frontRackCarry:        return StatBlock(size: 0.10, strength: 0.30, dexterity: 0.15, agility: 0.00, endurance: 0.20, vitality: 0.25)
        case .gobletSquat:           return StatBlock(size: 0.35, strength: 0.35, dexterity: 0.15, agility: 0.00, endurance: 0.00, vitality: 0.15)
        case .goodMorning:           return StatBlock(size: 0.35, strength: 0.45, dexterity: 0.00, agility: 0.00, endurance: 0.00, vitality: 0.20)
        case .hackSquat:             return StatBlock(size: 0.45, strength: 0.45, dexterity: 0.05, agility: 0.00, endurance: 0.00, vitality: 0.05)
        case .inclineBenchPress:     return StatBlock(size: 0.45, strength: 0.50, dexterity: 0.05, agility: 0.00, endurance: 0.00, vitality: 0.00)
        case .jeffersonDeadlift:     return StatBlock(size: 0.30, strength: 0.45, dexterity: 0.20, agility: 0.00, endurance: 0.00, vitality: 0.05)
        case .landminePress:         return StatBlock(size: 0.30, strength: 0.40, dexterity: 0.20, agility: 0.00, endurance: 0.00, vitality: 0.10)
        case .logPress:              return StatBlock(size: 0.25, strength: 0.45, dexterity: 0.20, agility: 0.10, endurance: 0.00, vitality: 0.00)
        case .lunge:                 return StatBlock(size: 0.30, strength: 0.35, dexterity: 0.25, agility: 0.10, endurance: 0.00, vitality: 0.00)
        case .overheadCarry:         return StatBlock(size: 0.05, strength: 0.25, dexterity: 0.40, agility: 0.00, endurance: 0.10, vitality: 0.20)
        case .overheadSquat:         return StatBlock(size: 0.20, strength: 0.30, dexterity: 0.40, agility: 0.00, endurance: 0.00, vitality: 0.10)
        case .pauseSquat:            return StatBlock(size: 0.35, strength: 0.50, dexterity: 0.05, agility: 0.00, endurance: 0.00, vitality: 0.10)
        case .pendlayRow:            return StatBlock(size: 0.30, strength: 0.45, dexterity: 0.25, agility: 0.00, endurance: 0.00, vitality: 0.00)
        case .pushPress:             return StatBlock(size: 0.30, strength: 0.50, dexterity: 0.10, agility: 0.10, endurance: 0.00, vitality: 0.00)
        case .rackPull:              return StatBlock(size: 0.40, strength: 0.50, dexterity: 0.05, agility: 0.00, endurance: 0.00, vitality: 0.05)
        case .safetyBarSquat:        return StatBlock(size: 0.40, strength: 0.50, dexterity: 0.05, agility: 0.00, endurance: 0.00, vitality: 0.05)
        case .seatedBarbellPress:    return StatBlock(size: 0.45, strength: 0.50, dexterity: 0.05, agility: 0.00, endurance: 0.00, vitality: 0.00)
        case .singleArmRow:          return StatBlock(size: 0.35, strength: 0.40, dexterity: 0.25, agility: 0.00, endurance: 0.00, vitality: 0.00)
        case .singleLegRDL:          return StatBlock(size: 0.25, strength: 0.30, dexterity: 0.30, agility: 0.00, endurance: 0.00, vitality: 0.15)
        case .snatchGripDeadlift:    return StatBlock(size: 0.35, strength: 0.50, dexterity: 0.10, agility: 0.00, endurance: 0.00, vitality: 0.05)
        case .snatchPull:            return StatBlock(size: 0.30, strength: 0.45, dexterity: 0.15, agility: 0.10, endurance: 0.00, vitality: 0.00)
        case .stepUp:                return StatBlock(size: 0.30, strength: 0.40, dexterity: 0.20, agility: 0.10, endurance: 0.00, vitality: 0.00)
        case .suitcaseCarry:         return StatBlock(size: 0.00, strength: 0.30, dexterity: 0.25, agility: 0.00, endurance: 0.15, vitality: 0.30)
        case .sumoDeadlift:          return StatBlock(size: 0.30, strength: 0.55, dexterity: 0.10, agility: 0.00, endurance: 0.00, vitality: 0.05)
        case .tBarRow:               return StatBlock(size: 0.40, strength: 0.45, dexterity: 0.15, agility: 0.00, endurance: 0.00, vitality: 0.00)
        case .trapBarDeadlift:       return StatBlock(size: 0.35, strength: 0.55, dexterity: 0.00, agility: 0.00, endurance: 0.00, vitality: 0.10)
        case .turkishGetUp:          return StatBlock(size: 0.00, strength: 0.35, dexterity: 0.40, agility: 0.00, endurance: 0.00, vitality: 0.25)
        case .walkingLunge:          return StatBlock(size: 0.30, strength: 0.35, dexterity: 0.20, agility: 0.10, endurance: 0.05, vitality: 0.00)
        case .yokeWalk:              return StatBlock(size: 0.20, strength: 0.45, dexterity: 0.00, agility: 0.10, endurance: 0.10, vitality: 0.15)
        case .zercherSquat:          return StatBlock(size: 0.35, strength: 0.45, dexterity: 0.10, agility: 0.00, endurance: 0.00, vitality: 0.10)
        // Hypertrophy
        case .arnoldPress:           return StatBlock(size: 0.55, strength: 0.30, dexterity: 0.15, agility: 0.00, endurance: 0.00, vitality: 0.00)
        case .backExtension:         return StatBlock(size: 0.40, strength: 0.25, dexterity: 0.00, agility: 0.00, endurance: 0.00, vitality: 0.35)
        case .barbellCurl:           return StatBlock(size: 0.65, strength: 0.30, dexterity: 0.00, agility: 0.00, endurance: 0.00, vitality: 0.05)
        case .cableCrunch:           return StatBlock(size: 0.50, strength: 0.25, dexterity: 0.10, agility: 0.00, endurance: 0.00, vitality: 0.15)
        case .cablePullThrough:      return StatBlock(size: 0.45, strength: 0.30, dexterity: 0.05, agility: 0.15, endurance: 0.00, vitality: 0.05)
        case .cableWoodchop:         return StatBlock(size: 0.20, strength: 0.15, dexterity: 0.40, agility: 0.10, endurance: 0.00, vitality: 0.15)
        case .calfRaiseSeated:       return StatBlock(size: 0.45, strength: 0.35, dexterity: 0.00, agility: 0.00, endurance: 0.20, vitality: 0.00)
        case .chestPressMachine:     return StatBlock(size: 0.45, strength: 0.50, dexterity: 0.00, agility: 0.00, endurance: 0.00, vitality: 0.05)
        case .chestSupportedRow:     return StatBlock(size: 0.50, strength: 0.40, dexterity: 0.10, agility: 0.00, endurance: 0.00, vitality: 0.00)
        case .facePull:              return StatBlock(size: 0.50, strength: 0.10, dexterity: 0.20, agility: 0.00, endurance: 0.00, vitality: 0.20)
        case .gluteKickback:         return StatBlock(size: 0.55, strength: 0.20, dexterity: 0.05, agility: 0.15, endurance: 0.00, vitality: 0.05)
        case .hammerCurl:            return StatBlock(size: 0.65, strength: 0.20, dexterity: 0.15, agility: 0.00, endurance: 0.00, vitality: 0.00)
        case .hipAbduction:          return StatBlock(size: 0.55, strength: 0.20, dexterity: 0.00, agility: 0.10, endurance: 0.00, vitality: 0.15)
        case .hipAdduction:          return StatBlock(size: 0.55, strength: 0.20, dexterity: 0.00, agility: 0.05, endurance: 0.00, vitality: 0.20)
        case .jmPress:               return StatBlock(size: 0.55, strength: 0.35, dexterity: 0.10, agility: 0.00, endurance: 0.00, vitality: 0.00)
        case .landmineRotation:      return StatBlock(size: 0.30, strength: 0.25, dexterity: 0.30, agility: 0.05, endurance: 0.00, vitality: 0.10)
        case .neckCurl:              return StatBlock(size: 0.50, strength: 0.30, dexterity: 0.00, agility: 0.00, endurance: 0.00, vitality: 0.20)
        case .platePinch:            return StatBlock(size: 0.10, strength: 0.55, dexterity: 0.25, agility: 0.00, endurance: 0.10, vitality: 0.00)
        case .pullover:              return StatBlock(size: 0.60, strength: 0.20, dexterity: 0.10, agility: 0.00, endurance: 0.00, vitality: 0.10)
        case .rearDeltFly:           return StatBlock(size: 0.60, strength: 0.00, dexterity: 0.25, agility: 0.00, endurance: 0.00, vitality: 0.15)
        case .renegadeRow:           return StatBlock(size: 0.25, strength: 0.30, dexterity: 0.25, agility: 0.00, endurance: 0.00, vitality: 0.20)
        case .reverseHyper:          return StatBlock(size: 0.35, strength: 0.25, dexterity: 0.00, agility: 0.10, endurance: 0.00, vitality: 0.30)
        case .shoulderPressMachine:  return StatBlock(size: 0.55, strength: 0.40, dexterity: 0.00, agility: 0.00, endurance: 0.00, vitality: 0.05)
        case .shrug:                 return StatBlock(size: 0.45, strength: 0.45, dexterity: 0.10, agility: 0.00, endurance: 0.00, vitality: 0.00)
        case .sideBend:              return StatBlock(size: 0.50, strength: 0.20, dexterity: 0.15, agility: 0.00, endurance: 0.00, vitality: 0.15)
        case .sissySquat:            return StatBlock(size: 0.55, strength: 0.25, dexterity: 0.05, agility: 0.00, endurance: 0.00, vitality: 0.15)
        case .skullcrusher:          return StatBlock(size: 0.65, strength: 0.30, dexterity: 0.05, agility: 0.00, endurance: 0.00, vitality: 0.00)
        case .straightArmPulldown:   return StatBlock(size: 0.60, strength: 0.25, dexterity: 0.05, agility: 0.00, endurance: 0.00, vitality: 0.10)
        case .uprightRow:            return StatBlock(size: 0.55, strength: 0.25, dexterity: 0.15, agility: 0.00, endurance: 0.00, vitality: 0.05)
        case .wristCurl:             return StatBlock(size: 0.65, strength: 0.25, dexterity: 0.10, agility: 0.00, endurance: 0.00, vitality: 0.00)
        // Bodyweight
        case .archerPullUp:          return StatBlock(size: 0.15, strength: 0.50, dexterity: 0.35, agility: 0.00, endurance: 0.00, vitality: 0.00)
        case .archerPushUp:          return StatBlock(size: 0.20, strength: 0.50, dexterity: 0.30, agility: 0.00, endurance: 0.00, vitality: 0.00)
        case .backLever:             return StatBlock(size: 0.10, strength: 0.35, dexterity: 0.40, agility: 0.00, endurance: 0.00, vitality: 0.15)
        case .bicycleCrunch:         return StatBlock(size: 0.00, strength: 0.10, dexterity: 0.45, agility: 0.10, endurance: 0.25, vitality: 0.10)
        case .bodyweightSquat:       return StatBlock(size: 0.20, strength: 0.30, dexterity: 0.15, agility: 0.00, endurance: 0.35, vitality: 0.00)
        case .climbing:              return StatBlock(size: 0.10, strength: 0.35, dexterity: 0.35, agility: 0.00, endurance: 0.20, vitality: 0.00)
        case .deadHang:              return StatBlock(size: 0.00, strength: 0.35, dexterity: 0.20, agility: 0.00, endurance: 0.30, vitality: 0.15)
        case .dragonFlag:            return StatBlock(size: 0.00, strength: 0.30, dexterity: 0.45, agility: 0.00, endurance: 0.00, vitality: 0.25)
        case .frontLever:            return StatBlock(size: 0.10, strength: 0.35, dexterity: 0.45, agility: 0.00, endurance: 0.00, vitality: 0.10)
        case .gripHold:              return StatBlock(size: 0.15, strength: 0.25, dexterity: 0.45, agility: 0.00, endurance: 0.15, vitality: 0.00)
        case .gymnastics:            return StatBlock(size: 0.00, strength: 0.25, dexterity: 0.45, agility: 0.20, endurance: 0.00, vitality: 0.10)
        case .hollowHold:            return StatBlock(size: 0.00, strength: 0.10, dexterity: 0.45, agility: 0.00, endurance: 0.20, vitality: 0.25)
        case .humanFlag:             return StatBlock(size: 0.00, strength: 0.35, dexterity: 0.45, agility: 0.00, endurance: 0.00, vitality: 0.20)
        case .invertedRow:           return StatBlock(size: 0.30, strength: 0.40, dexterity: 0.30, agility: 0.00, endurance: 0.00, vitality: 0.00)
        case .lSit:                  return StatBlock(size: 0.00, strength: 0.25, dexterity: 0.45, agility: 0.00, endurance: 0.10, vitality: 0.20)
        case .lateralLunge:          return StatBlock(size: 0.25, strength: 0.30, dexterity: 0.20, agility: 0.15, endurance: 0.00, vitality: 0.10)
        case .lyingLegRaise:         return StatBlock(size: 0.00, strength: 0.20, dexterity: 0.50, agility: 0.00, endurance: 0.00, vitality: 0.30)
        case .muscleUp:              return StatBlock(size: 0.15, strength: 0.45, dexterity: 0.30, agility: 0.10, endurance: 0.00, vitality: 0.00)
        case .pikePushUp:            return StatBlock(size: 0.25, strength: 0.45, dexterity: 0.30, agility: 0.00, endurance: 0.00, vitality: 0.00)
        case .planche:               return StatBlock(size: 0.10, strength: 0.40, dexterity: 0.45, agility: 0.00, endurance: 0.00, vitality: 0.05)
        case .russianTwist:          return StatBlock(size: 0.00, strength: 0.15, dexterity: 0.50, agility: 0.00, endurance: 0.10, vitality: 0.25)
        case .sitUp:                 return StatBlock(size: 0.00, strength: 0.20, dexterity: 0.45, agility: 0.00, endurance: 0.10, vitality: 0.25)
        case .skinTheCat:            return StatBlock(size: 0.00, strength: 0.20, dexterity: 0.40, agility: 0.00, endurance: 0.00, vitality: 0.40)
        case .vUp:                   return StatBlock(size: 0.00, strength: 0.25, dexterity: 0.50, agility: 0.05, endurance: 0.00, vitality: 0.20)
        case .wallSit:               return StatBlock(size: 0.00, strength: 0.30, dexterity: 0.00, agility: 0.00, endurance: 0.50, vitality: 0.20)
        case .windshieldWiper:       return StatBlock(size: 0.00, strength: 0.25, dexterity: 0.45, agility: 0.00, endurance: 0.00, vitality: 0.30)
        // Explosive
        case .baseballSoftball:      return StatBlock(size: 0.00, strength: 0.15, dexterity: 0.30, agility: 0.35, endurance: 0.20, vitality: 0.00)
        case .bounding:              return StatBlock(size: 0.00, strength: 0.15, dexterity: 0.20, agility: 0.55, endurance: 0.10, vitality: 0.00)
        case .boxing:                return StatBlock(size: 0.00, strength: 0.15, dexterity: 0.20, agility: 0.35, endurance: 0.30, vitality: 0.00)
        case .cleanAndJerk:          return StatBlock(size: 0.00, strength: 0.30, dexterity: 0.30, agility: 0.40, endurance: 0.00, vitality: 0.00)
        case .cleanAndPress:         return StatBlock(size: 0.00, strength: 0.35, dexterity: 0.20, agility: 0.35, endurance: 0.10, vitality: 0.00)
        case .cleanPull:             return StatBlock(size: 0.10, strength: 0.40, dexterity: 0.20, agility: 0.30, endurance: 0.00, vitality: 0.00)
        case .depthJump:             return StatBlock(size: 0.00, strength: 0.20, dexterity: 0.25, agility: 0.55, endurance: 0.00, vitality: 0.00)
        case .dumbbellSnatch:        return StatBlock(size: 0.00, strength: 0.20, dexterity: 0.30, agility: 0.35, endurance: 0.15, vitality: 0.00)
        case .hangClean:             return StatBlock(size: 0.00, strength: 0.20, dexterity: 0.30, agility: 0.50, endurance: 0.00, vitality: 0.00)
        case .hangSnatch:            return StatBlock(size: 0.00, strength: 0.15, dexterity: 0.40, agility: 0.45, endurance: 0.00, vitality: 0.00)
        case .highPull:              return StatBlock(size: 0.00, strength: 0.35, dexterity: 0.20, agility: 0.45, endurance: 0.00, vitality: 0.00)
        case .hillSprint:            return StatBlock(size: 0.00, strength: 0.25, dexterity: 0.00, agility: 0.45, endurance: 0.30, vitality: 0.00)
        case .hurdleHop:             return StatBlock(size: 0.00, strength: 0.10, dexterity: 0.30, agility: 0.55, endurance: 0.05, vitality: 0.00)
        case .jumpSquat:             return StatBlock(size: 0.00, strength: 0.25, dexterity: 0.15, agility: 0.55, endurance: 0.05, vitality: 0.00)
        case .ladderDrill:           return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.50, agility: 0.35, endurance: 0.15, vitality: 0.00)
        case .lateralBound:          return StatBlock(size: 0.00, strength: 0.10, dexterity: 0.35, agility: 0.55, endurance: 0.00, vitality: 0.00)
        case .plyoPushUp:            return StatBlock(size: 0.00, strength: 0.35, dexterity: 0.20, agility: 0.45, endurance: 0.00, vitality: 0.00)
        case .pogoHop:               return StatBlock(size: 0.00, strength: 0.15, dexterity: 0.30, agility: 0.45, endurance: 0.10, vitality: 0.00)
        case .powerSnatch:           return StatBlock(size: 0.00, strength: 0.20, dexterity: 0.35, agility: 0.45, endurance: 0.00, vitality: 0.00)
        case .pushJerk:              return StatBlock(size: 0.10, strength: 0.35, dexterity: 0.20, agility: 0.35, endurance: 0.00, vitality: 0.00)
        case .resistedSprint:        return StatBlock(size: 0.00, strength: 0.30, dexterity: 0.00, agility: 0.50, endurance: 0.20, vitality: 0.00)
        case .sandbagShoulder:       return StatBlock(size: 0.10, strength: 0.30, dexterity: 0.20, agility: 0.35, endurance: 0.05, vitality: 0.00)
        case .shuttleRun:            return StatBlock(size: 0.00, strength: 0.15, dexterity: 0.20, agility: 0.55, endurance: 0.10, vitality: 0.00)
        case .singleLegHop:          return StatBlock(size: 0.00, strength: 0.15, dexterity: 0.35, agility: 0.45, endurance: 0.00, vitality: 0.05)
        case .skateboarding:         return StatBlock(size: 0.00, strength: 0.10, dexterity: 0.35, agility: 0.40, endurance: 0.05, vitality: 0.10)
        case .sledgehammerStrikes:   return StatBlock(size: 0.00, strength: 0.20, dexterity: 0.25, agility: 0.40, endurance: 0.15, vitality: 0.00)
        case .snatch:                return StatBlock(size: 0.00, strength: 0.20, dexterity: 0.40, agility: 0.40, endurance: 0.00, vitality: 0.00)
        case .snatchBalance:         return StatBlock(size: 0.00, strength: 0.25, dexterity: 0.45, agility: 0.30, endurance: 0.00, vitality: 0.00)
        case .splitJerk:             return StatBlock(size: 0.10, strength: 0.30, dexterity: 0.30, agility: 0.30, endurance: 0.00, vitality: 0.00)
        case .splitSquatJump:        return StatBlock(size: 0.00, strength: 0.15, dexterity: 0.30, agility: 0.50, endurance: 0.05, vitality: 0.00)
        case .sprintDrills:          return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.40, agility: 0.40, endurance: 0.20, vitality: 0.00)
        case .squatClean:            return StatBlock(size: 0.00, strength: 0.35, dexterity: 0.25, agility: 0.40, endurance: 0.00, vitality: 0.00)
        case .thruster:              return StatBlock(size: 0.00, strength: 0.30, dexterity: 0.10, agility: 0.40, endurance: 0.20, vitality: 0.00)
        case .tireFlip:              return StatBlock(size: 0.10, strength: 0.35, dexterity: 0.10, agility: 0.35, endurance: 0.10, vitality: 0.00)
        case .tuckJump:              return StatBlock(size: 0.00, strength: 0.10, dexterity: 0.25, agility: 0.55, endurance: 0.10, vitality: 0.00)
        case .volleyball:            return StatBlock(size: 0.00, strength: 0.10, dexterity: 0.25, agility: 0.45, endurance: 0.15, vitality: 0.05)
        // Endurance
        case .aquaJogging:           return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.00, agility: 0.15, endurance: 0.55, vitality: 0.30)
        case .assaultBike:           return StatBlock(size: 0.00, strength: 0.15, dexterity: 0.00, agility: 0.20, endurance: 0.55, vitality: 0.10)
        case .badminton:             return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.25, agility: 0.25, endurance: 0.45, vitality: 0.05)
        case .basketball:            return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.10, agility: 0.40, endurance: 0.40, vitality: 0.10)
        case .bearCrawl:             return StatBlock(size: 0.00, strength: 0.15, dexterity: 0.30, agility: 0.20, endurance: 0.35, vitality: 0.00)
        case .burpee:                return StatBlock(size: 0.00, strength: 0.10, dexterity: 0.10, agility: 0.30, endurance: 0.50, vitality: 0.00)
        case .crossCountrySki:       return StatBlock(size: 0.00, strength: 0.20, dexterity: 0.15, agility: 0.15, endurance: 0.50, vitality: 0.00)
        case .dance:                 return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.30, agility: 0.20, endurance: 0.35, vitality: 0.15)
        case .elliptical:            return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.00, agility: 0.15, endurance: 0.65, vitality: 0.20)
        case .golf:                  return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.20, agility: 0.15, endurance: 0.45, vitality: 0.20)
        case .grappling:             return StatBlock(size: 0.00, strength: 0.25, dexterity: 0.20, agility: 0.00, endurance: 0.35, vitality: 0.20)
        case .heavyBag:              return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.30, agility: 0.30, endurance: 0.40, vitality: 0.00)
        case .hiitCircuit:           return StatBlock(size: 0.00, strength: 0.10, dexterity: 0.10, agility: 0.35, endurance: 0.45, vitality: 0.00)
        case .hockey:                return StatBlock(size: 0.00, strength: 0.15, dexterity: 0.00, agility: 0.25, endurance: 0.45, vitality: 0.15)
        case .mountainBike:          return StatBlock(size: 0.00, strength: 0.10, dexterity: 0.20, agility: 0.25, endurance: 0.45, vitality: 0.00)
        case .mountainClimber:       return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.20, agility: 0.25, endurance: 0.45, vitality: 0.10)
        case .openWaterSwim:         return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.25, agility: 0.15, endurance: 0.50, vitality: 0.10)
        case .paddling:              return StatBlock(size: 0.00, strength: 0.20, dexterity: 0.20, agility: 0.00, endurance: 0.50, vitality: 0.10)
        case .pickleball:            return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.30, agility: 0.20, endurance: 0.40, vitality: 0.10)
        case .ruckMarch:             return StatBlock(size: 0.00, strength: 0.25, dexterity: 0.00, agility: 0.00, endurance: 0.55, vitality: 0.20)
        case .rugby:                 return StatBlock(size: 0.00, strength: 0.20, dexterity: 0.00, agility: 0.25, endurance: 0.35, vitality: 0.20)
        case .skating:               return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.10, agility: 0.20, endurance: 0.55, vitality: 0.15)
        case .skiErg:                return StatBlock(size: 0.00, strength: 0.30, dexterity: 0.15, agility: 0.00, endurance: 0.55, vitality: 0.00)
        case .skiing:                return StatBlock(size: 0.00, strength: 0.10, dexterity: 0.10, agility: 0.20, endurance: 0.35, vitality: 0.25)
        case .soccer:                return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.10, agility: 0.30, endurance: 0.50, vitality: 0.10)
        case .squash:                return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.15, agility: 0.25, endurance: 0.50, vitality: 0.10)
        case .surfing:               return StatBlock(size: 0.00, strength: 0.20, dexterity: 0.25, agility: 0.15, endurance: 0.40, vitality: 0.00)
        case .tennis:                return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.25, agility: 0.25, endurance: 0.40, vitality: 0.10)
        case .trailRun:              return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.15, agility: 0.25, endurance: 0.55, vitality: 0.05)
        case .ultimateFrisbee:       return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.15, agility: 0.40, endurance: 0.45, vitality: 0.00)
        case .versaClimber:          return StatBlock(size: 0.00, strength: 0.20, dexterity: 0.15, agility: 0.00, endurance: 0.55, vitality: 0.10)
        case .walk:                  return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.00, agility: 0.10, endurance: 0.60, vitality: 0.30)
        // Mobility
        case .adductorRockback:      return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.40, agility: 0.00, endurance: 0.00, vitality: 0.60)
        case .ankleDorsiflexion:     return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.35, agility: 0.00, endurance: 0.00, vitality: 0.65)
        case .atgSplitSquat:         return StatBlock(size: 0.00, strength: 0.25, dexterity: 0.30, agility: 0.00, endurance: 0.00, vitality: 0.45)
        case .bandPullApart:         return StatBlock(size: 0.00, strength: 0.20, dexterity: 0.20, agility: 0.00, endurance: 0.00, vitality: 0.60)
        case .catCow:                return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.45, agility: 0.00, endurance: 0.00, vitality: 0.55)
        case .deadBug:               return StatBlock(size: 0.00, strength: 0.10, dexterity: 0.40, agility: 0.00, endurance: 0.00, vitality: 0.50)
        case .deepSquatHold:         return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.45, agility: 0.00, endurance: 0.00, vitality: 0.55)
        case .dropLanding:           return StatBlock(size: 0.00, strength: 0.15, dexterity: 0.35, agility: 0.10, endurance: 0.00, vitality: 0.40)
        case .foamRolling:           return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.25, agility: 0.00, endurance: 0.00, vitality: 0.75)
        case .hamstringStretch:      return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.40, agility: 0.00, endurance: 0.00, vitality: 0.60)
        case .hipFlexorMarch:        return StatBlock(size: 0.00, strength: 0.25, dexterity: 0.25, agility: 0.00, endurance: 0.00, vitality: 0.50)
        case .jeffersonCurl:         return StatBlock(size: 0.00, strength: 0.15, dexterity: 0.45, agility: 0.00, endurance: 0.00, vitality: 0.40)
        case .kettlebellWindmill:    return StatBlock(size: 0.00, strength: 0.15, dexterity: 0.45, agility: 0.00, endurance: 0.00, vitality: 0.40)
        case .pallofPress:           return StatBlock(size: 0.00, strength: 0.15, dexterity: 0.35, agility: 0.00, endurance: 0.00, vitality: 0.50)
        case .pilates:               return StatBlock(size: 0.00, strength: 0.10, dexterity: 0.50, agility: 0.05, endurance: 0.00, vitality: 0.35)
        case .proneYTW:              return StatBlock(size: 0.00, strength: 0.20, dexterity: 0.25, agility: 0.00, endurance: 0.00, vitality: 0.55)
        case .reverseNordic:         return StatBlock(size: 0.15, strength: 0.30, dexterity: 0.10, agility: 0.00, endurance: 0.00, vitality: 0.45)
        case .scapularPullUp:        return StatBlock(size: 0.00, strength: 0.25, dexterity: 0.30, agility: 0.00, endurance: 0.00, vitality: 0.45)
        case .scapularPushUp:        return StatBlock(size: 0.00, strength: 0.20, dexterity: 0.35, agility: 0.00, endurance: 0.00, vitality: 0.45)
        case .shoulderDislocates:    return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.60, agility: 0.00, endurance: 0.00, vitality: 0.40)
        case .wallSlides:            return StatBlock(size: 0.00, strength: 0.10, dexterity: 0.35, agility: 0.00, endurance: 0.00, vitality: 0.55)
        case .worldsGreatestStretch: return StatBlock(size: 0.00, strength: 0.00, dexterity: 0.50, agility: 0.10, endurance: 0.00, vitality: 0.40)
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

        // =============================
        // Expanded catalog
        // =============================
        // Strength
        case .andersonSquat:
            return StatBlock(size: 1.0, strength: 1.6, dexterity: 0.1, agility: 0.1, endurance: 0.0, vitality: 0.0)
        case .atlasStone:
            return StatBlock(size: 0.7, strength: 1.4, dexterity: 0.3, agility: 0.1, endurance: 0.0, vitality: 0.3)
        case .behindTheNeckPress:
            return StatBlock(size: 1.0, strength: 1.0, dexterity: 0.5, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .beltSquat:
            return StatBlock(size: 1.2, strength: 1.2, dexterity: 0.1, agility: 0.0, endurance: 0.0, vitality: 0.1)
        case .boardPress:
            return StatBlock(size: 0.7, strength: 1.4, dexterity: 0.3, agility: 0.0, endurance: 0.0, vitality: 0.1)
        case .boxSquat:
            return StatBlock(size: 1.1, strength: 1.7, dexterity: 0.1, agility: 0.1, endurance: 0.0, vitality: 0.0)
        case .closeGripBenchPress:
            return StatBlock(size: 0.9, strength: 1.4, dexterity: 0.3, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .declineBenchPress:
            return StatBlock(size: 1.2, strength: 1.3, dexterity: 0.0, agility: 0.0, endurance: 0.0, vitality: 0.1)
        case .deficitDeadlift:
            return StatBlock(size: 0.9, strength: 1.6, dexterity: 0.1, agility: 0.0, endurance: 0.0, vitality: 0.2)
        case .farmersWalk:
            return StatBlock(size: 0.4, strength: 1.0, dexterity: 0.6, agility: 0.0, endurance: 0.4, vitality: 0.2)
        case .floorPress:
            return StatBlock(size: 0.9, strength: 1.3, dexterity: 0.3, agility: 0.0, endurance: 0.0, vitality: 0.1)
        case .frontRackCarry:
            return StatBlock(size: 0.3, strength: 0.7, dexterity: 0.4, agility: 0.0, endurance: 0.5, vitality: 0.6)
        case .gobletSquat:
            return StatBlock(size: 0.8, strength: 1.0, dexterity: 0.3, agility: 0.0, endurance: 0.0, vitality: 0.3)
        case .goodMorning:
            return StatBlock(size: 0.9, strength: 1.4, dexterity: 0.0, agility: 0.0, endurance: 0.0, vitality: 0.3)
        case .hackSquat:
            return StatBlock(size: 1.1, strength: 1.3, dexterity: 0.1, agility: 0.0, endurance: 0.0, vitality: 0.1)
        case .inclineBenchPress:
            return StatBlock(size: 1.2, strength: 1.4, dexterity: 0.1, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .jeffersonDeadlift:
            return StatBlock(size: 0.7, strength: 1.3, dexterity: 0.5, agility: 0.0, endurance: 0.0, vitality: 0.1)
        case .landminePress:
            return StatBlock(size: 0.7, strength: 1.0, dexterity: 0.5, agility: 0.0, endurance: 0.0, vitality: 0.2)
        case .logPress:
            return StatBlock(size: 0.7, strength: 1.3, dexterity: 0.6, agility: 0.3, endurance: 0.0, vitality: 0.0)
        case .lunge:
            return StatBlock(size: 0.3, strength: 1.1, dexterity: 0.7, agility: 0.3, endurance: 0.0, vitality: 0.0)
        case .overheadCarry:
            return StatBlock(size: 0.1, strength: 0.6, dexterity: 1.0, agility: 0.0, endurance: 0.2, vitality: 0.5)
        case .overheadSquat:
            return StatBlock(size: 0.5, strength: 0.9, dexterity: 1.0, agility: 0.0, endurance: 0.0, vitality: 0.2)
        case .pauseSquat:
            return StatBlock(size: 1.0, strength: 1.7, dexterity: 0.1, agility: 0.0, endurance: 0.0, vitality: 0.2)
        case .pendlayRow:
            return StatBlock(size: 0.8, strength: 1.3, dexterity: 0.5, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .pushPress:
            return StatBlock(size: 0.8, strength: 1.4, dexterity: 0.3, agility: 0.2, endurance: 0.0, vitality: 0.0)
        case .rackPull:
            return StatBlock(size: 1.0, strength: 1.4, dexterity: 0.1, agility: 0.0, endurance: 0.0, vitality: 0.1)
        case .safetyBarSquat:
            return StatBlock(size: 1.1, strength: 1.7, dexterity: 0.1, agility: 0.0, endurance: 0.0, vitality: 0.1)
        case .seatedBarbellPress:
            return StatBlock(size: 1.2, strength: 1.3, dexterity: 0.1, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .singleArmRow:
            return StatBlock(size: 0.9, strength: 1.2, dexterity: 0.4, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .singleLegRDL:
            return StatBlock(size: 0.6, strength: 0.8, dexterity: 0.8, agility: 0.0, endurance: 0.0, vitality: 0.2)
        case .snatchGripDeadlift:
            return StatBlock(size: 1.0, strength: 1.6, dexterity: 0.2, agility: 0.0, endurance: 0.0, vitality: 0.1)
        case .snatchPull:
            return StatBlock(size: 0.8, strength: 1.4, dexterity: 0.2, agility: 0.2, endurance: 0.0, vitality: 0.0)
        case .stepUp:
            return StatBlock(size: 0.4, strength: 1.1, dexterity: 0.6, agility: 0.3, endurance: 0.0, vitality: 0.0)
        case .suitcaseCarry:
            return StatBlock(size: 0.0, strength: 0.7, dexterity: 0.6, agility: 0.0, endurance: 0.4, vitality: 0.7)
        case .sumoDeadlift:
            return StatBlock(size: 1.0, strength: 1.8, dexterity: 0.2, agility: 0.0, endurance: 0.0, vitality: 0.1)
        case .tBarRow:
            return StatBlock(size: 1.1, strength: 1.2, dexterity: 0.4, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .trapBarDeadlift:
            return StatBlock(size: 1.1, strength: 1.8, dexterity: 0.0, agility: 0.0, endurance: 0.0, vitality: 0.2)
        case .turkishGetUp:
            return StatBlock(size: 0.0, strength: 0.8, dexterity: 1.0, agility: 0.0, endurance: 0.0, vitality: 0.6)
        case .walkingLunge:
            return StatBlock(size: 0.5, strength: 1.0, dexterity: 0.6, agility: 0.2, endurance: 0.1, vitality: 0.0)
        case .yokeWalk:
            return StatBlock(size: 0.6, strength: 1.2, dexterity: 0.0, agility: 0.3, endurance: 0.3, vitality: 0.4)
        case .zercherSquat:
            return StatBlock(size: 1.0, strength: 1.4, dexterity: 0.2, agility: 0.0, endurance: 0.0, vitality: 0.2)
        // Hypertrophy
        case .arnoldPress:
            return StatBlock(size: 1.4, strength: 0.8, dexterity: 0.2, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .backExtension:
            return StatBlock(size: 0.8, strength: 0.5, dexterity: 0.0, agility: 0.0, endurance: 0.0, vitality: 0.6)
        case .barbellCurl:
            return StatBlock(size: 1.2, strength: 0.6, dexterity: 0.0, agility: 0.0, endurance: 0.0, vitality: 0.1)
        case .cableCrunch:
            return StatBlock(size: 1.1, strength: 0.4, dexterity: 0.1, agility: 0.0, endurance: 0.0, vitality: 0.3)
        case .cablePullThrough:
            return StatBlock(size: 1.1, strength: 0.5, dexterity: 0.1, agility: 0.3, endurance: 0.0, vitality: 0.1)
        case .cableWoodchop:
            return StatBlock(size: 0.3, strength: 0.3, dexterity: 0.8, agility: 0.2, endurance: 0.0, vitality: 0.3)
        case .calfRaiseSeated:
            return StatBlock(size: 0.8, strength: 0.7, dexterity: 0.0, agility: 0.0, endurance: 0.3, vitality: 0.0)
        case .chestPressMachine:
            return StatBlock(size: 1.0, strength: 1.2, dexterity: 0.0, agility: 0.0, endurance: 0.0, vitality: 0.1)
        case .chestSupportedRow:
            return StatBlock(size: 1.2, strength: 1.0, dexterity: 0.2, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .facePull:
            return StatBlock(size: 1.0, strength: 0.2, dexterity: 0.3, agility: 0.0, endurance: 0.0, vitality: 0.3)
        case .gluteKickback:
            return StatBlock(size: 1.1, strength: 0.3, dexterity: 0.0, agility: 0.3, endurance: 0.0, vitality: 0.1)
        case .hammerCurl:
            return StatBlock(size: 1.3, strength: 0.4, dexterity: 0.2, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .hipAbduction:
            return StatBlock(size: 1.1, strength: 0.2, dexterity: 0.0, agility: 0.2, endurance: 0.0, vitality: 0.3)
        case .hipAdduction:
            return StatBlock(size: 1.0, strength: 0.2, dexterity: 0.0, agility: 0.1, endurance: 0.0, vitality: 0.4)
        case .jmPress:
            return StatBlock(size: 1.2, strength: 0.7, dexterity: 0.2, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .landmineRotation:
            return StatBlock(size: 0.6, strength: 0.5, dexterity: 0.5, agility: 0.1, endurance: 0.0, vitality: 0.2)
        case .neckCurl:
            return StatBlock(size: 1.0, strength: 0.5, dexterity: 0.0, agility: 0.0, endurance: 0.0, vitality: 0.3)
        case .platePinch:
            return StatBlock(size: 0.2, strength: 1.1, dexterity: 0.5, agility: 0.0, endurance: 0.1, vitality: 0.0)
        case .pullover:
            return StatBlock(size: 1.5, strength: 0.3, dexterity: 0.1, agility: 0.0, endurance: 0.0, vitality: 0.2)
        case .rearDeltFly:
            return StatBlock(size: 1.3, strength: 0.0, dexterity: 0.3, agility: 0.0, endurance: 0.0, vitality: 0.1)
        case .renegadeRow:
            return StatBlock(size: 0.5, strength: 0.7, dexterity: 0.5, agility: 0.0, endurance: 0.0, vitality: 0.4)
        case .reverseHyper:
            return StatBlock(size: 0.9, strength: 0.4, dexterity: 0.0, agility: 0.2, endurance: 0.0, vitality: 0.4)
        case .shoulderPressMachine:
            return StatBlock(size: 1.3, strength: 1.0, dexterity: 0.0, agility: 0.0, endurance: 0.0, vitality: 0.1)
        case .shrug:
            return StatBlock(size: 0.9, strength: 0.8, dexterity: 0.1, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .sideBend:
            return StatBlock(size: 1.0, strength: 0.4, dexterity: 0.1, agility: 0.0, endurance: 0.0, vitality: 0.3)
        case .sissySquat:
            return StatBlock(size: 1.3, strength: 0.2, dexterity: 0.0, agility: 0.0, endurance: 0.0, vitality: 0.3)
        case .skullcrusher:
            return StatBlock(size: 1.3, strength: 0.5, dexterity: 0.1, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .straightArmPulldown:
            return StatBlock(size: 1.5, strength: 0.3, dexterity: 0.0, agility: 0.0, endurance: 0.0, vitality: 0.1)
        case .uprightRow:
            return StatBlock(size: 1.1, strength: 0.4, dexterity: 0.3, agility: 0.0, endurance: 0.0, vitality: 0.1)
        case .wristCurl:
            return StatBlock(size: 1.2, strength: 0.4, dexterity: 0.2, agility: 0.0, endurance: 0.0, vitality: 0.0)
        // Bodyweight
        case .archerPullUp:
            return StatBlock(size: 0.2, strength: 1.1, dexterity: 0.8, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .archerPushUp:
            return StatBlock(size: 0.2, strength: 1.0, dexterity: 0.8, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .backLever:
            return StatBlock(size: 0.1, strength: 0.7, dexterity: 0.9, agility: 0.0, endurance: 0.0, vitality: 0.3)
        case .bicycleCrunch:
            return StatBlock(size: 0.0, strength: 0.1, dexterity: 0.7, agility: 0.2, endurance: 0.4, vitality: 0.2)
        case .bodyweightSquat:
            return StatBlock(size: 0.3, strength: 0.5, dexterity: 0.2, agility: 0.0, endurance: 0.6, vitality: 0.0)
        case .climbing:
            return StatBlock(size: 0.2, strength: 0.8, dexterity: 0.7, agility: 0.0, endurance: 0.3, vitality: 0.0)
        case .deadHang:
            return StatBlock(size: 0.0, strength: 0.6, dexterity: 0.3, agility: 0.0, endurance: 0.5, vitality: 0.2)
        case .dragonFlag:
            return StatBlock(size: 0.0, strength: 0.6, dexterity: 0.9, agility: 0.0, endurance: 0.0, vitality: 0.4)
        case .frontLever:
            return StatBlock(size: 0.1, strength: 0.8, dexterity: 1.0, agility: 0.0, endurance: 0.0, vitality: 0.2)
        case .gripHold:
            return StatBlock(size: 0.3, strength: 0.4, dexterity: 0.8, agility: 0.0, endurance: 0.2, vitality: 0.0)
        case .gymnastics:
            return StatBlock(size: 0.0, strength: 0.6, dexterity: 0.9, agility: 0.4, endurance: 0.0, vitality: 0.1)
        case .hollowHold:
            return StatBlock(size: 0.0, strength: 0.2, dexterity: 0.8, agility: 0.0, endurance: 0.2, vitality: 0.7)
        case .humanFlag:
            return StatBlock(size: 0.0, strength: 0.7, dexterity: 1.0, agility: 0.0, endurance: 0.0, vitality: 0.4)
        case .invertedRow:
            return StatBlock(size: 0.4, strength: 0.8, dexterity: 0.6, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .lSit:
            return StatBlock(size: 0.0, strength: 0.4, dexterity: 0.8, agility: 0.0, endurance: 0.2, vitality: 0.4)
        case .lateralLunge:
            return StatBlock(size: 0.3, strength: 0.5, dexterity: 0.4, agility: 0.3, endurance: 0.0, vitality: 0.2)
        case .lyingLegRaise:
            return StatBlock(size: 0.0, strength: 0.3, dexterity: 0.8, agility: 0.0, endurance: 0.0, vitality: 0.5)
        case .muscleUp:
            return StatBlock(size: 0.2, strength: 1.0, dexterity: 0.7, agility: 0.2, endurance: 0.0, vitality: 0.0)
        case .pikePushUp:
            return StatBlock(size: 0.4, strength: 1.0, dexterity: 0.6, agility: 0.0, endurance: 0.0, vitality: 0.0)
        case .planche:
            return StatBlock(size: 0.1, strength: 0.9, dexterity: 1.0, agility: 0.0, endurance: 0.0, vitality: 0.1)
        case .russianTwist:
            return StatBlock(size: 0.0, strength: 0.2, dexterity: 0.8, agility: 0.0, endurance: 0.2, vitality: 0.4)
        case .sitUp:
            return StatBlock(size: 0.0, strength: 0.3, dexterity: 0.7, agility: 0.0, endurance: 0.2, vitality: 0.4)
        case .skinTheCat:
            return StatBlock(size: 0.0, strength: 0.3, dexterity: 0.6, agility: 0.0, endurance: 0.0, vitality: 0.7)
        case .vUp:
            return StatBlock(size: 0.0, strength: 0.3, dexterity: 0.8, agility: 0.1, endurance: 0.0, vitality: 0.4)
        case .wallSit:
            return StatBlock(size: 0.0, strength: 0.5, dexterity: 0.0, agility: 0.0, endurance: 0.9, vitality: 0.3)
        case .windshieldWiper:
            return StatBlock(size: 0.0, strength: 0.4, dexterity: 0.8, agility: 0.0, endurance: 0.0, vitality: 0.5)
        // Explosive
        case .baseballSoftball:
            return StatBlock(size: 0.0, strength: 0.3, dexterity: 0.6, agility: 0.7, endurance: 0.3, vitality: 0.0)
        case .bounding:
            return StatBlock(size: 0.0, strength: 0.2, dexterity: 0.4, agility: 1.2, endurance: 0.2, vitality: 0.0)
        case .boxing:
            return StatBlock(size: 0.0, strength: 0.2, dexterity: 0.4, agility: 0.8, endurance: 0.6, vitality: 0.0)
        case .cleanAndJerk:
            return StatBlock(size: 0.0, strength: 0.6, dexterity: 0.6, agility: 0.9, endurance: 0.0, vitality: 0.0)
        case .cleanAndPress:
            return StatBlock(size: 0.0, strength: 0.6, dexterity: 0.4, agility: 0.7, endurance: 0.2, vitality: 0.0)
        case .cleanPull:
            return StatBlock(size: 0.2, strength: 0.9, dexterity: 0.3, agility: 0.6, endurance: 0.0, vitality: 0.0)
        case .depthJump:
            return StatBlock(size: 0.0, strength: 0.3, dexterity: 0.5, agility: 1.2, endurance: 0.0, vitality: 0.0)
        case .dumbbellSnatch:
            return StatBlock(size: 0.0, strength: 0.4, dexterity: 0.6, agility: 0.7, endurance: 0.2, vitality: 0.0)
        case .hangClean:
            return StatBlock(size: 0.0, strength: 0.5, dexterity: 0.5, agility: 0.9, endurance: 0.0, vitality: 0.0)
        case .hangSnatch:
            return StatBlock(size: 0.0, strength: 0.4, dexterity: 0.6, agility: 0.9, endurance: 0.0, vitality: 0.0)
        case .highPull:
            return StatBlock(size: 0.0, strength: 0.5, dexterity: 0.4, agility: 0.9, endurance: 0.0, vitality: 0.0)
        case .hillSprint:
            return StatBlock(size: 0.0, strength: 0.4, dexterity: 0.0, agility: 0.9, endurance: 0.6, vitality: 0.0)
        case .hurdleHop:
            return StatBlock(size: 0.0, strength: 0.1, dexterity: 0.6, agility: 1.1, endurance: 0.1, vitality: 0.0)
        case .jumpSquat:
            return StatBlock(size: 0.0, strength: 0.5, dexterity: 0.3, agility: 1.0, endurance: 0.1, vitality: 0.0)
        case .ladderDrill:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.9, agility: 0.6, endurance: 0.3, vitality: 0.0)
        case .lateralBound:
            return StatBlock(size: 0.0, strength: 0.2, dexterity: 0.7, agility: 1.0, endurance: 0.0, vitality: 0.0)
        case .plyoPushUp:
            return StatBlock(size: 0.0, strength: 0.7, dexterity: 0.4, agility: 0.8, endurance: 0.0, vitality: 0.0)
        case .pogoHop:
            return StatBlock(size: 0.0, strength: 0.2, dexterity: 0.5, agility: 0.9, endurance: 0.2, vitality: 0.0)
        case .powerSnatch:
            return StatBlock(size: 0.0, strength: 0.4, dexterity: 0.6, agility: 1.0, endurance: 0.0, vitality: 0.0)
        case .pushJerk:
            return StatBlock(size: 0.2, strength: 0.6, dexterity: 0.4, agility: 0.7, endurance: 0.0, vitality: 0.0)
        case .resistedSprint:
            return StatBlock(size: 0.0, strength: 0.5, dexterity: 0.0, agility: 1.0, endurance: 0.4, vitality: 0.0)
        case .sandbagShoulder:
            return StatBlock(size: 0.2, strength: 0.6, dexterity: 0.4, agility: 0.7, endurance: 0.1, vitality: 0.0)
        case .shuttleRun:
            return StatBlock(size: 0.0, strength: 0.2, dexterity: 0.4, agility: 1.1, endurance: 0.2, vitality: 0.0)
        case .singleLegHop:
            return StatBlock(size: 0.0, strength: 0.2, dexterity: 0.7, agility: 0.9, endurance: 0.0, vitality: 0.1)
        case .skateboarding:
            return StatBlock(size: 0.0, strength: 0.1, dexterity: 0.7, agility: 0.8, endurance: 0.1, vitality: 0.2)
        case .sledgehammerStrikes:
            return StatBlock(size: 0.0, strength: 0.4, dexterity: 0.5, agility: 0.7, endurance: 0.2, vitality: 0.0)
        case .snatch:
            return StatBlock(size: 0.0, strength: 0.5, dexterity: 0.7, agility: 0.9, endurance: 0.0, vitality: 0.0)
        case .snatchBalance:
            return StatBlock(size: 0.0, strength: 0.4, dexterity: 0.9, agility: 0.6, endurance: 0.0, vitality: 0.0)
        case .splitJerk:
            return StatBlock(size: 0.2, strength: 0.6, dexterity: 0.5, agility: 0.7, endurance: 0.0, vitality: 0.0)
        case .splitSquatJump:
            return StatBlock(size: 0.0, strength: 0.2, dexterity: 0.6, agility: 1.0, endurance: 0.1, vitality: 0.0)
        case .sprintDrills:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.7, agility: 0.7, endurance: 0.4, vitality: 0.0)
        case .squatClean:
            return StatBlock(size: 0.0, strength: 0.7, dexterity: 0.5, agility: 0.9, endurance: 0.0, vitality: 0.0)
        case .thruster:
            return StatBlock(size: 0.0, strength: 0.6, dexterity: 0.2, agility: 0.8, endurance: 0.4, vitality: 0.0)
        case .tireFlip:
            return StatBlock(size: 0.2, strength: 0.7, dexterity: 0.2, agility: 0.7, endurance: 0.2, vitality: 0.0)
        case .tuckJump:
            return StatBlock(size: 0.0, strength: 0.1, dexterity: 0.5, agility: 1.1, endurance: 0.2, vitality: 0.0)
        case .volleyball:
            return StatBlock(size: 0.0, strength: 0.1, dexterity: 0.5, agility: 0.9, endurance: 0.3, vitality: 0.1)
        // Endurance
        case .aquaJogging:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.0, agility: 0.3, endurance: 1.0, vitality: 0.6)
        case .assaultBike:
            return StatBlock(size: 0.0, strength: 0.3, dexterity: 0.0, agility: 0.4, endurance: 1.2, vitality: 0.2)
        case .badminton:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.5, agility: 0.5, endurance: 0.8, vitality: 0.1)
        case .basketball:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.2, agility: 0.7, endurance: 0.9, vitality: 0.2)
        case .bearCrawl:
            return StatBlock(size: 0.0, strength: 0.3, dexterity: 0.5, agility: 0.3, endurance: 0.8, vitality: 0.0)
        case .burpee:
            return StatBlock(size: 0.0, strength: 0.2, dexterity: 0.2, agility: 0.6, endurance: 1.0, vitality: 0.0)
        case .crossCountrySki:
            return StatBlock(size: 0.0, strength: 0.4, dexterity: 0.3, agility: 0.3, endurance: 1.2, vitality: 0.0)
        case .dance:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.6, agility: 0.3, endurance: 0.9, vitality: 0.2)
        case .elliptical:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.0, agility: 0.3, endurance: 1.4, vitality: 0.3)
        case .golf:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.3, agility: 0.1, endurance: 1.1, vitality: 0.4)
        case .grappling:
            return StatBlock(size: 0.0, strength: 0.5, dexterity: 0.3, agility: 0.0, endurance: 0.9, vitality: 0.4)
        case .heavyBag:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.6, agility: 0.6, endurance: 0.7, vitality: 0.0)
        case .hiitCircuit:
            return StatBlock(size: 0.0, strength: 0.2, dexterity: 0.2, agility: 0.7, endurance: 0.9, vitality: 0.0)
        case .hockey:
            return StatBlock(size: 0.0, strength: 0.3, dexterity: 0.0, agility: 0.5, endurance: 1.0, vitality: 0.2)
        case .mountainBike:
            return StatBlock(size: 0.0, strength: 0.2, dexterity: 0.4, agility: 0.5, endurance: 1.0, vitality: 0.0)
        case .mountainClimber:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.3, agility: 0.5, endurance: 1.0, vitality: 0.1)
        case .openWaterSwim:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.4, agility: 0.3, endurance: 1.2, vitality: 0.2)
        case .paddling:
            return StatBlock(size: 0.0, strength: 0.4, dexterity: 0.3, agility: 0.0, endurance: 1.1, vitality: 0.2)
        case .pickleball:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.5, agility: 0.3, endurance: 1.0, vitality: 0.1)
        case .ruckMarch:
            return StatBlock(size: 0.0, strength: 0.5, dexterity: 0.0, agility: 0.0, endurance: 1.2, vitality: 0.4)
        case .rugby:
            return StatBlock(size: 0.0, strength: 0.4, dexterity: 0.0, agility: 0.5, endurance: 0.9, vitality: 0.3)
        case .skating:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.2, agility: 0.3, endurance: 1.3, vitality: 0.1)
        case .skiErg:
            return StatBlock(size: 0.0, strength: 0.5, dexterity: 0.3, agility: 0.0, endurance: 1.2, vitality: 0.0)
        case .skiing:
            return StatBlock(size: 0.0, strength: 0.2, dexterity: 0.2, agility: 0.4, endurance: 0.9, vitality: 0.3)
        case .soccer:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.2, agility: 0.6, endurance: 1.1, vitality: 0.2)
        case .squash:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.3, agility: 0.5, endurance: 1.2, vitality: 0.1)
        case .surfing:
            return StatBlock(size: 0.0, strength: 0.4, dexterity: 0.5, agility: 0.1, endurance: 1.0, vitality: 0.0)
        case .tennis:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.4, agility: 0.4, endurance: 1.0, vitality: 0.2)
        case .trailRun:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.3, agility: 0.5, endurance: 1.2, vitality: 0.1)
        case .ultimateFrisbee:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.3, agility: 0.7, endurance: 1.0, vitality: 0.0)
        case .versaClimber:
            return StatBlock(size: 0.0, strength: 0.4, dexterity: 0.3, agility: 0.0, endurance: 1.1, vitality: 0.2)
        case .walk:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.0, agility: 0.2, endurance: 1.1, vitality: 0.6)
        // Mobility
        case .adductorRockback:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.6, agility: 0.0, endurance: 0.0, vitality: 0.8)
        case .ankleDorsiflexion:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.5, agility: 0.0, endurance: 0.0, vitality: 0.9)
        case .atgSplitSquat:
            return StatBlock(size: 0.0, strength: 0.4, dexterity: 0.4, agility: 0.0, endurance: 0.0, vitality: 0.6)
        case .bandPullApart:
            return StatBlock(size: 0.0, strength: 0.3, dexterity: 0.3, agility: 0.0, endurance: 0.0, vitality: 0.8)
        case .catCow:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.6, agility: 0.0, endurance: 0.0, vitality: 0.8)
        case .deadBug:
            return StatBlock(size: 0.0, strength: 0.1, dexterity: 0.6, agility: 0.0, endurance: 0.0, vitality: 0.8)
        case .deepSquatHold:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.6, agility: 0.0, endurance: 0.0, vitality: 0.8)
        case .dropLanding:
            return StatBlock(size: 0.0, strength: 0.2, dexterity: 0.5, agility: 0.1, endurance: 0.0, vitality: 0.7)
        case .foamRolling:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.4, agility: 0.0, endurance: 0.0, vitality: 1.0)
        case .hamstringStretch:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.6, agility: 0.0, endurance: 0.0, vitality: 0.8)
        case .hipFlexorMarch:
            return StatBlock(size: 0.0, strength: 0.4, dexterity: 0.3, agility: 0.0, endurance: 0.0, vitality: 0.7)
        case .jeffersonCurl:
            return StatBlock(size: 0.0, strength: 0.2, dexterity: 0.5, agility: 0.0, endurance: 0.0, vitality: 0.7)
        case .kettlebellWindmill:
            return StatBlock(size: 0.0, strength: 0.2, dexterity: 0.7, agility: 0.0, endurance: 0.0, vitality: 0.7)
        case .pallofPress:
            return StatBlock(size: 0.0, strength: 0.2, dexterity: 0.5, agility: 0.0, endurance: 0.0, vitality: 0.8)
        case .pilates:
            return StatBlock(size: 0.0, strength: 0.1, dexterity: 0.7, agility: 0.1, endurance: 0.0, vitality: 0.7)
        case .proneYTW:
            return StatBlock(size: 0.0, strength: 0.3, dexterity: 0.4, agility: 0.0, endurance: 0.0, vitality: 0.7)
        case .reverseNordic:
            return StatBlock(size: 0.1, strength: 0.4, dexterity: 0.2, agility: 0.0, endurance: 0.0, vitality: 0.7)
        case .scapularPullUp:
            return StatBlock(size: 0.0, strength: 0.4, dexterity: 0.4, agility: 0.0, endurance: 0.0, vitality: 0.6)
        case .scapularPushUp:
            return StatBlock(size: 0.0, strength: 0.3, dexterity: 0.5, agility: 0.0, endurance: 0.0, vitality: 0.6)
        case .shoulderDislocates:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.7, agility: 0.0, endurance: 0.0, vitality: 0.7)
        case .wallSlides:
            return StatBlock(size: 0.0, strength: 0.1, dexterity: 0.5, agility: 0.0, endurance: 0.0, vitality: 0.8)
        case .worldsGreatestStretch:
            return StatBlock(size: 0.0, strength: 0.0, dexterity: 0.7, agility: 0.1, endurance: 0.0, vitality: 0.7)
        }
    }

    // Primary volume estimators
    static func intensityScore(category: ExerciseCategory, reps: Int?, weight: Double?, durationMin: Double?, distanceKm: Double?) -> Double {
        switch category {
        // Weight × reps tonnage style
        case .squat, .frontSquat, .deadlift, .romanianDeadlift, .benchPress, .overheadPress, .row, .hipThrust, .bulgarianSplitSquat, .legPress,
             .latPulldown, .cableRow, .chestFly, .lateralRaise, .curl, .tricepsExtension, .legExtension, .legCurl, .calfRaiseStanding,
             .kettlebellSwing, .powerClean,
             .andersonSquat, .atlasStone, .behindTheNeckPress, .beltSquat,
             .boardPress, .boxSquat, .chestPressMachine, .cleanPull,
             .closeGripBenchPress, .declineBenchPress, .deficitDeadlift, .gobletSquat,
             .goodMorning, .hackSquat, .inclineBenchPress, .jeffersonDeadlift,
             .landminePress, .logPress, .pauseSquat, .pendlayRow,
             .rackPull, .safetyBarSquat, .seatedBarbellPress, .singleArmRow,
             .snatchPull, .sumoDeadlift, .tBarRow, .trapBarDeadlift,
             .walkingLunge, .zercherSquat, .arnoldPress, .barbellCurl,
             .cableCrunch, .cablePullThrough, .calfRaiseSeated, .gluteKickback,
             .hammerCurl, .hipAbduction, .hipAdduction, .jmPress,
             .landmineRotation, .neckCurl, .pullover, .rearDeltFly,
             .reverseHyper, .shoulderPressMachine, .shrug, .sideBend,
             .skullcrusher, .straightArmPulldown, .wristCurl, .cleanAndJerk,
             .cleanAndPress, .dumbbellSnatch, .hangClean, .hangSnatch,
             .highPull, .powerSnatch, .pushJerk, .sandbagShoulder,
             .snatch, .snatchBalance, .splitJerk, .squatClean,
             .cableWoodchop, .chestSupportedRow, .facePull, .floorPress,
             .overheadSquat, .pallofPress, .pushPress, .renegadeRow,
             .singleLegRDL, .snatchGripDeadlift, .thruster, .turkishGetUp,
             .uprightRow:
            let r = max(0, Double(reps ?? 0))
            let w = max(0, weight ?? 0)
            return r * w

        // Bodyweight reps with added load support
        case .pushUp, .dip, .pullUp, .handstand, .pistolSquat,
             .lateralLunge, .sissySquat, .archerPullUp, .archerPushUp,
             .bodyweightSquat, .muscleUp, .pikePushUp, .backExtension,
             .invertedRow, .jumpSquat, .lunge, .sitUp,
             .stepUp:
            let r1 = max(0, Double(reps ?? 0))
            let add = max(0, weight ?? 0) // treat as weighted if provided
            return r1 * (60 + add * 2)

        case .hangingLegRaise, .abWheel,
             .bicycleCrunch, .deadBug, .lyingLegRaise, .skinTheCat,
             .vUp, .windshieldWiper, .dragonFlag, .russianTwist,
             .scapularPullUp:
            let r2 = max(0, Double(reps ?? 0))
            return r2 * 60

        // Time-based core holds / mobility
        case .plank, .copenhagenPlank, .mcgillBig3, .hip90_90, .couchStretch, .cars, .thoracicRotation, .externalRotation, .monsterWalks, .tibialisRaise, .hipAirplanes, .yoga,
             .platePinch, .backLever, .climbing, .frontLever,
             .gripHold, .gymnastics, .hollowHold, .humanFlag,
             .planche, .wallSit, .badminton, .dance,
             .surfing, .tennis, .adductorRockback, .ankleDorsiflexion,
             .bandPullApart, .catCow, .deepSquatHold, .foamRolling,
             .hamstringStretch, .hipFlexorMarch, .pilates, .proneYTW,
             .scapularPushUp, .shoulderDislocates, .wallSlides, .worldsGreatestStretch,
             .deadHang, .lSit:
            let t = max(0, durationMin ?? 0)
            return t * 35

        // Explosive reps without meaningful load
        case .boxJump,
             .bounding, .depthJump, .hurdleHop, .lateralBound,
             .pogoHop, .singleLegHop, .splitSquatJump, .tuckJump,
             .plyoPushUp:
            let r = max(0, Double(reps ?? 0))
            return r * 70

        // Med-ball with load (if weight provided)
        case .medBallSlam,
             .sledgehammerStrikes, .tireFlip:
            let r = max(0, Double(reps ?? 0))
            let w = max(0, weight ?? 10)
            return r * w * 0.5

        // Conditioning / cardio
        case .sprint,
             .hillSprint, .resistedSprint, .shuttleRun:
            let t = max(0, durationMin ?? 0)
            return t * 90
        case .run, .cycle, .rower,
             .crossCountrySki, .mountainBike, .paddling, .skating,
             .skiErg, .trailRun, .elliptical:
            let t = max(0, durationMin ?? 0)
            let d = max(0, distanceKm ?? 0)
            return t * 20 + d * 220
        case .swimming,
             .openWaterSwim:
            let t = max(0, durationMin ?? 0)
            let d = max(0, distanceKm ?? 0)
            return t * 24 + d * 260
        case .hikingStairs,
             .baseballSoftball, .skateboarding, .volleyball, .aquaJogging,
             .golf, .pickleball, .ruckMarch, .skiing,
             .walk:
            let t = max(0, durationMin ?? 0)
            return t * 25
        case .battleRopes,
             .burpee, .hiitCircuit, .squash:
            let t = max(0, durationMin ?? 0)
            return t * 70

        case .sledPush,
             .farmersWalk, .frontRackCarry, .overheadCarry, .yokeWalk,
             .assaultBike, .basketball, .grappling, .heavyBag,
             .hockey, .mountainClimber, .rugby, .soccer,
             .ultimateFrisbee, .versaClimber, .bearCrawl, .suitcaseCarry:
            let t = max(0, durationMin ?? 0)
            return t * 60

        case .jumpRope,
             .boxing, .ladderDrill, .sprintDrills:
            let t = max(0, durationMin ?? 0)
            return t * 70
        case .nordicHamstring,
             .atgSplitSquat, .dropLanding, .jeffersonCurl, .kettlebellWindmill,
             .reverseNordic:
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

    /// Deterministic mid-band estimate of what relativeXP will grant —
    /// used for live per-set ticks during an active session. Mirrors
    /// relativeXP's curve without its jitter, and applies the same sets
    /// multiplier logWorkout uses, so the running total tracks reality.
    static func estimatedXP(category: ExerciseCategory, perf: Double, baseline: Double?, sets: Int) -> Double {
        var xp: Double
        if baseline == nil || baseline == 0 || perf == 0 {
            xp = 11.5
        } else {
            let ratio = max(0.01, perf / max(0.0001, baseline!))
            let raw = ratio >= 1.0 ? 12.0 * pow(ratio, 1.25) : 12.0 * pow(ratio, 0.5)
            xp = min(50.0, max(8.5, raw))
        }
        xp *= focusGainMultiplier(category.focus)
        if sets > 1 {
            xp *= min(1.60, 1.0 + 0.15 * Double(sets - 1))
        }
        return min(60.0, xp)
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
            .squat, .frontSquat, .deadlift, .romanianDeadlift, .benchPress, .overheadPress, .powerClean,
            .andersonSquat, .boardPress, .closeGripBenchPress, .declineBenchPress,
            .deficitDeadlift, .inclineBenchPress, .logPress, .pauseSquat,
            .rackPull, .safetyBarSquat, .seatedBarbellPress, .sumoDeadlift,
            .trapBarDeadlift, .cleanAndJerk, .hangClean, .hangSnatch,
            .powerSnatch, .pushJerk, .snatch, .splitJerk,
            .squatClean, .floorPress, .overheadSquat, .pushPress,
            .snatchGripDeadlift
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
        case .squat, .frontSquat, .deadlift, .romanianDeadlift, .benchPress, .overheadPress, .powerClean,
             .andersonSquat, .boardPress, .closeGripBenchPress, .declineBenchPress,
             .deficitDeadlift, .inclineBenchPress, .logPress, .pauseSquat,
             .rackPull, .safetyBarSquat, .seatedBarbellPress, .sumoDeadlift,
             .trapBarDeadlift, .cleanAndJerk, .hangClean, .hangSnatch,
             .powerSnatch, .pushJerk, .snatch, .splitJerk,
             .squatClean, .floorPress, .overheadSquat, .pushPress,
             .snatchGripDeadlift:
            // perf = accurate 1RM estimate using Brzycki formula
            return max(0.0, estimate1RM(category: category, reps: Int(r), weight: w))

        // ——— Other loaded lifts (use simpler weight × reps metric) ———
        case .row, .hipThrust, .bulgarianSplitSquat, .legPress, .latPulldown, .cableRow, .chestFly,
             .lateralRaise, .curl, .tricepsExtension, .legExtension, .legCurl, .calfRaiseStanding,
             .atlasStone, .behindTheNeckPress, .beltSquat, .boxSquat,
             .chestPressMachine, .cleanPull, .gobletSquat, .goodMorning,
             .hackSquat, .jeffersonDeadlift, .landminePress, .pendlayRow,
             .singleArmRow, .snatchPull, .tBarRow, .walkingLunge,
             .zercherSquat, .arnoldPress, .barbellCurl, .cableCrunch,
             .cablePullThrough, .calfRaiseSeated, .gluteKickback, .hammerCurl,
             .hipAbduction, .hipAdduction, .jmPress, .landmineRotation,
             .neckCurl, .pullover, .rearDeltFly, .reverseHyper,
             .shoulderPressMachine, .shrug, .sideBend, .skullcrusher,
             .straightArmPulldown, .wristCurl, .cleanAndPress, .highPull,
             .snatchBalance, .cableWoodchop, .chestSupportedRow, .facePull,
             .pallofPress, .renegadeRow, .singleLegRDL, .thruster,
             .turkishGetUp, .uprightRow:
            // perf = total volume (weight × reps) for accessory movements
            return w * r

        // ——— Bodyweight & skill (reps; optional weight) ———
        case .pushUp, .dip, .pullUp, .pistolSquat, .hangingLegRaise, .abWheel,
             .lateralLunge, .sissySquat, .archerPullUp, .archerPushUp,
             .bicycleCrunch, .bodyweightSquat, .deadBug, .lyingLegRaise,
             .muscleUp, .pikePushUp, .skinTheCat, .vUp,
             .windshieldWiper, .backExtension, .dragonFlag, .invertedRow,
             .jumpSquat, .lunge, .russianTwist, .scapularPullUp,
             .sitUp, .stepUp:
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
        case .plank, .copenhagenPlank, .mcgillBig3,
             .platePinch, .backLever, .frontLever, .gripHold,
             .hollowHold, .humanFlag, .planche, .wallSit,
             .deadHang, .lSit:
            // perf = time × ((BW+added)/BW)^0.3
            let eff = bw + w
            return tMin * pow(eff / bw, 0.30)

        // ——— Explosive / athleticism ———
        case .kettlebellSwing, .medBallSlam,
             .dumbbellSnatch, .sandbagShoulder, .sledgehammerStrikes, .tireFlip:
            // Loaded reps: reps × (weight/BW)^0.65 (if no weight given, treat as BW)
            let load = max(w, 0.0)
            let ratio = (load > 0 ? load / bw : 1.0)
            return r * pow(ratio, 0.65)

        case .boxJump,
             .bounding, .depthJump, .hurdleHop, .lateralBound,
             .pogoHop, .singleLegHop, .splitSquatJump, .tuckJump,
             .plyoPushUp:
            // Until we capture jump height, treat as skill reps
            return r

        case .sprint,
             .hillSprint, .resistedSprint, .shuttleRun:
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
        case .run, .cycle, .rower, .swimming,
             .crossCountrySki, .mountainBike, .openWaterSwim, .skating,
             .skiErg, .trailRun, .elliptical:
            guard dKm > 0 && tHr > 0 else { return 0 }
            let v = dKm / tHr    // km/h
            return v * pow(dKm, 0.50)

        // ——— Conditioning (duration-dominant with optional load) ———
        case .hikingStairs, .battleRopes, .jumpRope, .sledPush,
             .farmersWalk, .frontRackCarry, .overheadCarry, .yokeWalk,
             .climbing, .gymnastics, .baseballSoftball, .boxing,
             .ladderDrill, .skateboarding, .sprintDrills, .volleyball,
             .aquaJogging, .assaultBike, .badminton, .basketball,
             .burpee, .dance, .golf, .grappling,
             .heavyBag, .hiitCircuit, .hockey, .mountainClimber,
             .paddling, .pickleball, .ruckMarch, .rugby,
             .skiing, .soccer, .squash, .surfing,
             .tennis, .ultimateFrisbee, .versaClimber, .walk,
             .bearCrawl, .suitcaseCarry:
            guard tMin > 0 else { return 0 }
            // perf = minutes × ((BW+added)/BW)^0.5
            let eff = bw + w
            return tMin * pow(eff / bw, 0.50)

        // ——— Mobility / prehab (consistency over intensity) ———
        case .hip90_90, .couchStretch, .cars, .thoracicRotation, .externalRotation, .monsterWalks, .tibialisRaise, .hipAirplanes, .yoga,
             .adductorRockback, .ankleDorsiflexion, .bandPullApart, .catCow,
             .deepSquatHold, .foamRolling, .hamstringStretch, .hipFlexorMarch,
             .pilates, .proneYTW, .scapularPushUp, .shoulderDislocates,
             .wallSlides, .worldsGreatestStretch:
            // Track minutes for EMA; XP bonuses are handled elsewhere via streak logic.
            return tMin

        case .nordicHamstring,
             .atgSplitSquat, .dropLanding, .jeffersonCurl, .kettlebellWindmill,
             .reverseNordic:
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

        // Rarer chests may also hold a companion egg
        if Double.random(in: 0...1) < eggDropChance(for: chestType) {
            rewards.append(TreasureReward(type: .egg, amount: 1, description: "Companion Egg", itemInfo: nil))
        }

        return rewards
    }

    // Companion eggs are the deck's chase reward — rarer than items.
    private static func eggDropChance(for chestType: TreasureChestType) -> Double {
        switch chestType {
        case .common: return 0.08
        case .uncommon: return 0.12
        case .rare: return 0.20
        case .epic: return 0.35
        case .mythic: return 0.55
        }
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

        case .egg:
            return (1, "Companion Egg", nil)
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
            let items: [RareTierItem] = [.dice, .puzzlepiece, .balloon]
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
        // Smooth global curve — no per-prestige reset. The old curve cycled
        // 50→792 XP inside every prestige block against flat per-entry income,
        // showering rewards at block starts and going silent for weeks at
        // block ends. This grows ~2.8%/level: 50 early, ~200 mid, ~750 late,
        // ~36k XP total to level 100 (a year-plus of steady training).
        let l = min(level, maxLevel)
        return (50.0 * pow(1.028, Double(l - 1))).rounded()
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
        case .bronze:
            return Color(light: Color(red: 0.62, green: 0.42, blue: 0.24),
                         dark: Color(red: 0.80, green: 0.58, blue: 0.38))
        case .silver:
            return Color(light: Color(red: 0.45, green: 0.48, blue: 0.53),
                         dark: Color(red: 0.72, green: 0.75, blue: 0.80))
        case .gold:
            return RPGTheme.gold
        case .platinum:
            return Color(light: Color(red: 0.00, green: 0.52, blue: 0.58),
                         dark: Color(red: 0.35, green: 0.82, blue: 0.88))
        case .diamond:
            return Stat.endurance.color
        case .master:
            return RPGTheme.arcane
        case .grandmaster:
            return Stat.strength.color
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

    private var tint: Color { prestigeLevel > 0 ? RPGTheme.gold : .gray }

    var body: some View {
        HStack(spacing: 4) {
            if prestigeLevel > 0 {
                RPGSymbolIcon(
                    symbol: .rank,
                    size: 12,
                    presentation: .compact,
                    palette: .monochrome(RPGTheme.gold)
                )
            }
            Text(prestigeLevel > 0 ? "P\(prestigeLevel)" : "None")
                .font(.caption2.weight(.semibold))
                .foregroundColor(prestigeLevel > 0 ? RPGTheme.gold : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(tint.opacity(0.55), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(prestigeLevel > 0 ? "Prestige \(prestigeLevel)" : "No prestige")
    }
}

struct AttributeRankBadge: View {
    let tier: RankTier

    var body: some View {
        RankIcon(tier: tier, size: 13)
            .frame(width: 22, height: 22)
            .background(
                Circle()
                    .strokeBorder(tier.color.opacity(0.55), lineWidth: 1)
            )
            .accessibilityLabel("\(tier.rawValue) rank")
    }
}

extension UserProfile {
    var prestigeLevel: Int {
        // Start with prestige 0, increase every 10 levels after level 10.
        // Clamped so the seal and badges cap at the max total level.
        return level > 10 ? min((level - 1) / 10, StatEngine.maxPrestige) : 0
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
