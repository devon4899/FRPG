import SwiftUI

// MARK: - Equipment availability
//
// The picker adapts to what the user actually has. Philosophy: only gate
// exercises that are IMPOSSIBLE without the gear — anything with a
// bodyweight or outdoor variant stays available to everyone.

enum EquipmentKind: String, CaseIterable, Codable, Identifiable {
    case barbell
    case dumbbells
    case kettlebell
    case machines
    case pullupBar
    case cardioMachines
    case pool
    case gymExtras

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .barbell: return "Barbell & Plates"
        case .dumbbells: return "Dumbbells"
        case .kettlebell: return "Kettlebell"
        case .machines: return "Machines & Cables"
        case .pullupBar: return "Pull-Up Bar"
        case .cardioMachines: return "Cardio Machines"
        case .pool: return "Pool"
        case .gymExtras: return "Gym Extras (sled, ropes, med ball…)"
        }
    }
}

extension ExerciseCategory {
    /// Any one of these equipment kinds makes the movement available. An
    /// empty list means a bodyweight or outdoor version exists. Keeping the
    /// rule as "any of" matters for movements such as presses and rows: a
    /// lifter with dumbbells should not lose them just because they do not
    /// also own a barbell.
    var requiredEquipmentOptions: [EquipmentKind] {
        switch self {
        case .squat, .frontSquat, .deadlift, .romanianDeadlift:
            return [.barbell, .dumbbells, .kettlebell]
        case .benchPress:
            return [.barbell, .dumbbells]
        case .overheadPress, .row:
            return [.barbell, .dumbbells, .kettlebell, .machines]
        case .powerClean:
            return [.barbell, .kettlebell]
        case .lateralRaise, .curl, .tricepsExtension, .chestFly:
            return [.dumbbells, .machines]
        case .kettlebellSwing:
            return [.kettlebell]
        case .legPress, .latPulldown, .cableRow, .legExtension, .legCurl:
            return [.machines]
        case .pullUp, .hangingLegRaise:
            return [.pullupBar]
        case .rower:
            return [.cardioMachines]
        case .swimming:
            return [.pool]
        case .sledPush, .battleRopes, .medBallSlam, .abWheel, .jumpRope:
            return [.gymExtras]
        case .externalRotation, .monsterWalks:
            return [.machines, .gymExtras]
        // MARK: Expanded catalog
        case .andersonSquat, .barbellCurl, .behindTheNeckPress, .boardPress,
             .boxSquat, .cleanPull, .deficitDeadlift, .goodMorning,
             .hangSnatch, .jeffersonDeadlift, .landminePress, .landmineRotation,
             .pauseSquat, .pendlayRow, .powerSnatch, .rackPull,
             .safetyBarSquat, .skullcrusher, .snatch, .snatchBalance,
             .snatchGripDeadlift, .snatchPull, .trapBarDeadlift, .zercherSquat:
            return [.barbell]
        case .floorPress, .highPull, .overheadSquat, .pullover,
             .pushJerk, .pushPress, .shrug, .splitJerk,
             .sumoDeadlift, .thruster:
            return [.barbell, .dumbbells, .kettlebell]
        case .arnoldPress, .cleanAndPress, .dumbbellSnatch, .gobletSquat,
             .hammerCurl, .renegadeRow, .singleArmRow, .turkishGetUp:
            return [.dumbbells, .kettlebell]
        case .cableCrunch, .chestPressMachine, .hackSquat, .hipAbduction,
             .hipAdduction, .reverseHyper, .shoulderPressMachine, .straightArmPulldown:
            return [.machines]
        case .archerPullUp, .backLever, .deadHang, .frontLever, .muscleUp, .scapularPullUp, .skinTheCat:
            return [.pullupBar]
        case .bandPullApart, .beltSquat, .cablePullThrough, .facePull, .gluteKickback, .pallofPress:
            return [.gymExtras, .machines]
        case .closeGripBenchPress, .declineBenchPress, .inclineBenchPress, .jmPress, .seatedBarbellPress:
            return [.barbell, .dumbbells]
        case .atlasStone, .resistedSprint, .sandbagShoulder, .sledgehammerStrikes, .tireFlip:
            return [.gymExtras]
        case .assaultBike, .elliptical, .skiErg, .versaClimber:
            return [.cardioMachines]
        case .farmersWalk, .frontRackCarry, .overheadCarry:
            return [.barbell, .dumbbells, .gymExtras, .kettlebell]
        case .calfRaiseSeated, .chestSupportedRow, .wristCurl:
            return [.barbell, .dumbbells, .machines]
        case .cleanAndJerk, .hangClean, .squatClean:
            return [.barbell, .kettlebell]
        case .logPress, .yokeWalk:
            return [.barbell, .gymExtras]
        case .platePinch:
            return [.barbell, .dumbbells, .gymExtras]
        case .uprightRow:
            return [.barbell, .dumbbells, .kettlebell, .machines]
        case .gripHold:
            return [.barbell, .dumbbells, .kettlebell, .pullupBar]
        case .tBarRow:
            return [.barbell, .machines]
        case .cableWoodchop:
            return [.dumbbells, .gymExtras, .machines]
        case .sideBend:
            return [.dumbbells, .kettlebell, .machines]
        case .rearDeltFly:
            return [.dumbbells, .machines]
        case .aquaJogging:
            return [.pool]
        default:
            return []
        }
    }

    /// Compatibility shim for older callers and saved tests that only need
    /// to know whether an exercise is equipment-gated at all.
    var requiredEquipment: EquipmentKind? { requiredEquipmentOptions.first }
}

extension AppState {
    /// nil = never configured → everything shows. An empty set is a valid
    /// configuration (bodyweight-only training).
    var configuredEquipment: Set<EquipmentKind>? {
        get {
            user.availableEquipment.map { Set($0.compactMap(EquipmentKind.init(rawValue:))) }
        }
        set {
            user.availableEquipment = newValue.map { $0.map(\.rawValue).sorted() }
        }
    }

    func isAvailable(_ category: ExerciseCategory) -> Bool {
        guard let configured = configuredEquipment else { return true }
        let options = category.requiredEquipmentOptions
        return options.isEmpty || !configured.isDisjoint(with: options)
    }

    /// Custom movements inherit the equipment contract of the category they
    /// are based on, so every logging path applies the same rule.
    func isAvailable(_ custom: CustomExercise) -> Bool {
        isAvailable(custom.basedOn)
    }

    func setEquipment(_ kind: EquipmentKind, available: Bool) {
        // First interaction starts from "has everything" so switching one
        // thing off doesn't silently hide the rest of the catalog.
        var configured = configuredEquipment ?? Set(EquipmentKind.allCases)
        if available { configured.insert(kind) } else { configured.remove(kind) }
        configuredEquipment = configured
        save()
    }
}

/// The Settings card: what do you train with?
struct EquipmentSettingsCard: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("My Equipment")
                .padding(.bottom, 10)

            Text("The exercise picker hides movements that need gear you don't have. Bodyweight and outdoor training always show.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 6)

            ForEach(Array(EquipmentKind.allCases.enumerated()), id: \.element.id) { index, kind in
                if index > 0 { HairlineRule() }
                Toggle(isOn: Binding(
                    get: { state.configuredEquipment?.contains(kind) ?? true },
                    set: { state.setEquipment(kind, available: $0) }
                )) {
                    Text(kind.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                }
                .tint(RPGTheme.xp)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
        }
        .rpgCard(padding: 14)
    }
}
