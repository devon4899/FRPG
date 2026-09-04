import SwiftUI
import UserNotifications

// MARK: - Training Sessions
//
// The competitor evidence converges on one interaction: checking off a set.
// It fires the rest timer, the PR check, and the reward tick — and none of
// Strong, Hevy, or the clones can make that tap an XP moment. Here it is one.
//
// Architecture: the session is a lightweight DRAFT (persisted to
// UserDefaults on every mutation, so a force-quit mid-workout loses
// nothing). Each exercise logs through the existing engine when completed —
// one WorkoutEntry per exercise, stamped with a shared sessionID — so XP,
// quests, streaks, trials, and recalculation all keep working unchanged.
// Per-set ticks during the session are deterministic ESTIMATES (labelled ≈);
// the summary shows the engine's real numbers.

// MARK: Draft model

struct ActiveSessionDraft: Codable, Equatable {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    /// Wall-clock gaps created by Save & Exit are not training time. Both
    /// fields are optional so drafts written before pause-aware timing was
    /// introduced continue to decode through the synthesized Codable path.
    var pausedAt: Date? = nil
    var accumulatedPausedDuration: TimeInterval? = nil
    var levelAtStart: Int = 1
    /// The display units used by every numeric string in this draft. Optional
    /// so drafts written before this field existed still decode; they are
    /// pinned to the current setting the first time they resume.
    var unitsAtStart: Units? = nil
    var exercises: [DraftExercise] = []
    /// Rest state lives in the draft so Save & Exit and force-quits keep the
    /// countdown — a resumed session picks it back up mid-tick.
    var restEndsAt: Date? = nil
    var restTotalSeconds: Int? = nil
    var restExerciseName: String? = nil

    static let storageKey = "activeSessionDraft.v1"

    static func load() -> ActiveSessionDraft? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        guard var draft = try? JSONDecoder().decode(ActiveSessionDraft.self, from: data) else {
            return nil
        }
        // Heal drafts written by older builds (or interrupted midway through
        // an edit) before the session reaches the UI.
        draft.normalizeSupersets()
        return draft
    }

    func persist() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    /// A draft worth resuming — an empty shell (session opened, nothing
    /// added) doesn't earn a Resume banner.
    static func loadResumable() -> ActiveSessionDraft? {
        guard let draft = load(), !draft.exercises.isEmpty else { return nil }
        return draft
    }

    /// Elapsed training time with every explicitly paused interval removed.
    /// A currently paused draft stays frozen even if it is resumed days later.
    func activeDuration(at date: Date = Date()) -> TimeInterval {
        let wallClockDuration = max(0, date.timeIntervalSince(startedAt))
        let previousPauses = max(0, accumulatedPausedDuration ?? 0)
        let currentPause = pausedAt.map { max(0, date.timeIntervalSince($0)) } ?? 0
        return max(0, wallClockDuration - previousPauses - currentPause)
    }

    mutating func pause(at date: Date = Date()) {
        guard pausedAt == nil else { return }
        pausedAt = date
    }

    mutating func resume(at date: Date = Date()) {
        guard let pausedAt else { return }
        accumulatedPausedDuration = max(0, accumulatedPausedDuration ?? 0)
            + max(0, date.timeIntervalSince(pausedAt))
        self.pausedAt = nil
    }
}

struct DraftExercise: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var category: ExerciseCategory
    var sets: [DraftSet]
    var duration: String = ""   // timed exercises
    var distance: String = ""   // cardio
    var logged: Bool = false
    /// Custom-exercise identity. The name is denormalized so an in-flight
    /// session survives the definition being deleted mid-workout.
    var customExerciseID: UUID? = nil
    var customName: String? = nil
    /// Exercises sharing a group id alternate as a superset: A set → B set
    /// → rest, instead of resting after every set.
    var supersetGroup: Int? = nil

    var isTimed: Bool { category.prefersDuration }
    var doneSets: [DraftSet] { sets.filter { $0.done } }
    var displayName: String { customName ?? category.displayName }

    /// The working set that best represents this exercise in the progression
    /// engine. This deliberately uses the same category metric as XP,
    /// baselines, and rank placement: compound lifts prefer the best valid
    /// 1RM set, accessories prefer volume, and bodyweight work prefers its
    /// effective-load score.
    func representativeWorkingSet(units: Units, bodyweightKg: Double?) -> DraftSet? {
        let candidates = doneSets.filter { !$0.isWarmup }
        guard !candidates.isEmpty else { return nil }

        func score(_ set: DraftSet) -> Double {
            StatEngine.placementMetric(
                category: category,
                reps: Int(set.reps),
                weight: flexibleDouble(set.weight).map { units.toKg($0) },
                durationMin: nil,
                distanceKm: nil,
                bodyweightKg: bodyweightKg
            )
        }

        func enteredWork(_ set: DraftSet) -> Double {
            Double(Int(set.reps) ?? 0) * max(1, flexibleDouble(set.weight) ?? 0)
        }

        return candidates.max { left, right in
            let leftScore = score(left)
            let rightScore = score(right)
            return leftScore == rightScore
                ? enteredWork(left) < enteredWork(right)
                : leftScore < rightScore
        }
    }
}

// MARK: Superset grouping

extension ActiveSessionDraft {
    /// Restores the two invariants every editing path relies on: timed
    /// exercises are never grouped, and a superset always has 2+ members.
    mutating func normalizeSupersets() {
        for index in exercises.indices where exercises[index].isTimed {
            exercises[index].supersetGroup = nil
        }

        let groupedIndices = Dictionary(grouping: exercises.indices.compactMap { index in
            exercises[index].supersetGroup.map { ($0, index) }
        }, by: \.0)

        for members in groupedIndices.values where members.count < 2 {
            for (_, index) in members {
                exercises[index].supersetGroup = nil
            }
        }
    }

    /// Links the exercise at `index` with the next unlogged set-based
    /// exercise, merging groups when either side is already grouped.
    mutating func supersetWithNext(at index: Int) {
        guard exercises.indices.contains(index) else { return }
        normalizeSupersets()
        guard !exercises[index].logged, !exercises[index].isTimed else { return }
        guard let nextIndex = exercises.indices.first(where: {
            $0 > index && !exercises[$0].logged && !exercises[$0].isTimed
        }) else { return }

        let leftGroup = exercises[index].supersetGroup
        let rightGroup = exercises[nextIndex].supersetGroup
        let group = leftGroup
            ?? rightGroup
            ?? (exercises.compactMap(\.supersetGroup).max() ?? 0) + 1

        // Linking members of two existing groups joins the full groups, not
        // just the two cards the user happened to connect.
        if let leftGroup, leftGroup != group {
            for member in exercises.indices where exercises[member].supersetGroup == leftGroup {
                exercises[member].supersetGroup = group
            }
        }
        if let rightGroup, rightGroup != group {
            for member in exercises.indices where exercises[member].supersetGroup == rightGroup {
                exercises[member].supersetGroup = group
            }
        }
        exercises[index].supersetGroup = group
        exercises[nextIndex].supersetGroup = group
        normalizeSupersets()
    }

    /// Removes the exercise at `index` from its group; a group left with a
    /// single member stops being a group.
    mutating func breakSuperset(at index: Int) {
        guard exercises.indices.contains(index),
              exercises[index].supersetGroup != nil else { return }
        exercises[index].supersetGroup = nil
        normalizeSupersets()
    }

    /// Whether checking a set on this exercise should start rest. Solo
    /// exercises rest while they still have work. In a superset, rest begins
    /// once every member participating in the just-completed round has done
    /// that many sets; exhausted members do not join later rounds. This is
    /// independent of tap order and lets A×3 + B×1 flow through one shared
    /// round followed by two solo A rounds.
    func shouldRest(afterSetIn id: UUID) -> Bool {
        guard let exercise = exercises.first(where: { $0.id == id }) else { return false }
        guard let group = exercise.supersetGroup else {
            return exercise.sets.contains { !$0.done }
        }
        let members = exercises.filter { $0.supersetGroup == group && !$0.logged }
        guard members.contains(where: { $0.sets.contains { !$0.done } }),
              members.contains(where: { $0.id == id }) else {
            return false
        }

        let completedRound = exercise.doneSets.count
        // Keep pre-existing callers that ask about a pristine draft useful;
        // the live path always reaches this method after checking a set.
        guard completedRound > 0 else { return members.last?.id == id }

        let roundIsComplete = members.allSatisfy { member in
            guard member.sets.count >= completedRound else { return true }
            return member.doneSets.count >= completedRound
        }
        return roundIsComplete
    }
}

struct DraftSet: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var reps: String = ""
    var weight: String = ""   // in the user's display units
    var done: Bool = false
    var isWarmup: Bool = false
    var rpe: Double? = nil

    private enum CodingKeys: String, CodingKey {
        case id, reps, weight, done, isWarmup, rpe
    }
}

extension DraftSet {
    // Lenient decode so a draft saved before warm-up/RPE existed still
    // resumes instead of silently vanishing.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        reps = try container.decode(String.self, forKey: .reps)
        weight = try container.decode(String.self, forKey: .weight)
        done = try container.decode(Bool.self, forKey: .done)
        isWarmup = (try? container.decodeIfPresent(Bool.self, forKey: .isWarmup)) ?? false
        rpe = (try? container.decodeIfPresent(Double.self, forKey: .rpe)) ?? nil
    }
}

// MARK: Routines
//
// A routine is a reusable session template: exercises with planned per-set
// targets, stored in canonical units (kg/km) like history. Created from a
// finished session in one tap — the workout you just did IS the template.

struct Routine: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var exercises: [RoutineExercise] = []
    var createdAt: Date = Date()
    var lastUsedAt: Date? = nil
}

struct RoutineExercise: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var category: ExerciseCategory
    var plannedSets: [PlannedSet] = []
    var plannedDurationMinutes: Double? = nil
    var plannedDistanceKm: Double? = nil
    /// Custom-exercise identity, name denormalized like the draft's.
    var customExerciseID: UUID? = nil
    var customName: String? = nil

    var displayName: String { customName ?? category.displayName }
}

struct PlannedSet: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var reps: Int? = nil
    var weightKg: Double? = nil
    var isWarmup: Bool = false

    private enum CodingKeys: String, CodingKey {
        case id, reps, weightKg, isWarmup
    }
}

extension PlannedSet {
    // Lenient decode: routines saved before warm-up marking existed keep
    // working.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        reps = try container.decodeIfPresent(Int.self, forKey: .reps)
        weightKg = try container.decodeIfPresent(Double.self, forKey: .weightKg)
        isWarmup = (try? container.decodeIfPresent(Bool.self, forKey: .isWarmup)) ?? false
    }
}

extension AppState {
    /// Entries of the most recent training session, oldest first (or the
    /// single most recent workout when nothing was logged as a session).
    var lastSessionEntries: [WorkoutEntry] {
        if let sid = history.first(where: { $0.sessionID != nil })?.sessionID {
            return history.filter { $0.sessionID == sid }.reversed()
        }
        if let latest = history.first { return [latest] }
        return []
    }

    /// Turns logged entries into routine exercises, carrying real per-set
    /// targets via resolvedSets (legacy summaries expand automatically).
    func routineExercises(from entries: [WorkoutEntry]) -> [RoutineExercise] {
        entries.map { entry in
            var exercise = RoutineExercise(category: entry.category)
            exercise.customExerciseID = entry.customExerciseID
            exercise.customName = entry.customExerciseID != nil ? entry.name : nil
            if entry.category.prefersDuration {
                exercise.plannedDurationMinutes = entry.durationMinutes
                exercise.plannedDistanceKm = entry.distanceKm
            } else {
                exercise.plannedSets = entry.resolvedSets.map {
                    PlannedSet(reps: $0.reps, weightKg: $0.weightKg, isWarmup: $0.isWarmup)
                }
            }
            return exercise
        }
    }

    func saveRoutine(named name: String, from entries: [WorkoutEntry]) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !entries.isEmpty else { return }
        user.routines.insert(Routine(name: trimmed, exercises: routineExercises(from: entries)), at: 0)
        save()
        pushToast(title: "Routine Saved",
                  subtitle: "\(trimmed) is ready on the Train tab",
                  kind: .accent,
                  symbol: .routine)
    }

    func deleteRoutine(_ id: UUID) {
        user.routines.removeAll { $0.id == id }
        save()
    }

    func renameRoutine(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = user.routines.firstIndex(where: { $0.id == id }) else { return }
        user.routines[index].name = trimmed
        save()
    }

    /// A fresh session draft pre-filled from a routine, weights and
    /// distances shown in the user's display units.
    func sessionDraft(from routine: Routine) -> ActiveSessionDraft {
        var draft = ActiveSessionDraft()
        draft.levelAtStart = user.level
        draft.unitsAtStart = user.units
        draft.exercises = routine.exercises.map { exercise in
            var draftExercise = DraftExercise(category: exercise.category, sets: [])
            draftExercise.customExerciseID = exercise.customExerciseID
            draftExercise.customName = exercise.customName
            if exercise.category.prefersDuration {
                draftExercise.duration = exercise.plannedDurationMinutes.map(Self.fieldNumber) ?? ""
                draftExercise.distance = exercise.plannedDistanceKm.map { Self.fieldNumber(user.units.fromKm($0)) } ?? ""
            } else {
                draftExercise.sets = exercise.plannedSets.map { planned in
                    DraftSet(reps: planned.reps.map(String.init) ?? "",
                             weight: planned.weightKg.map { Self.fieldNumber(user.units.fromKg($0)) } ?? "",
                             isWarmup: planned.isWarmup)
                }
                if draftExercise.sets.isEmpty {
                    draftExercise.sets = (0..<3).map { _ in DraftSet() }
                }
            }
            return draftExercise
        }
        if let index = user.routines.firstIndex(where: { $0.id == routine.id }) {
            user.routines[index].lastUsedAt = Date()
            save()
        }
        return draft
    }

    func sessionDraftRepeatingLast() -> ActiveSessionDraft? {
        let entries = lastSessionEntries
        guard !entries.isEmpty else { return nil }
        return sessionDraft(from: Routine(name: "Last session",
                                          exercises: routineExercises(from: entries)))
    }

    /// Formats a prefilled numeric field: no trailing ".0", one decimal max.
    static func fieldNumber(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(rounded))
            : String(format: "%.1f", rounded)
    }

    /// Stores a warm-up-only exercise without passing it through the reward
    /// engine. This preserves the performed sets for history/routines while
    /// guaranteeing that preparation work cannot mint gameplay progress.
    @discardableResult
    func logWarmupOnlyExercise(
        name: String,
        category: ExerciseCategory,
        performedSets: [PerformedSet],
        sessionID: UUID,
        customExerciseID: UUID?
    ) -> WorkoutEntry {
        let warmups = performedSets.map { set in
            var clean = set
            clean.isWarmup = true
            if let reps = clean.reps { clean.reps = min(9999, max(1, reps)) }
            if let weight = clean.weightKg {
                clean.weightKg = weight.isFinite ? min(9999, max(0, weight)) : nil
            }
            return clean
        }
        let entry = WorkoutEntry(
            id: UUID(),
            date: Date(),
            name: name.isEmpty ? category.displayName : name,
            category: category,
            sessionID: sessionID,
            customExerciseID: customExerciseID,
            sets: warmups.count,
            reps: nil,
            weight: nil,
            durationMinutes: nil,
            distanceKm: nil,
            performedSets: warmups,
            statGains: .zero,
            expGained: 0,
            catchUpLevel: nil,
            prevLevel: user.level,
            newLevel: user.level,
            prevBest1RM: nil,
            est1RM: nil,
            totalProgressXP: 0
        )
        history.insert(entry, at: 0)
        save()
        return entry
    }
}

extension ExerciseCategory {
    /// Exercises whose effort is duration/distance, not sets×reps — they get
    /// a single timed row instead of set rows.
    var prefersDuration: Bool {
        switch self {
        case .plank, .copenhagenPlank, .mcgillBig3, .hip90_90, .couchStretch,
             .cars, .thoracicRotation, .externalRotation, .monsterWalks,
             .tibialisRaise, .hipAirplanes, .yoga,
             .sprint, .run, .cycle, .rower, .swimming, .hikingStairs,
             .battleRopes, .sledPush, .jumpRope,
             .farmersWalk, .frontRackCarry, .overheadCarry, .platePinch,
             .yokeWalk, .backLever, .climbing, .frontLever,
             .gripHold, .gymnastics, .hollowHold, .humanFlag,
             .planche, .wallSit, .baseballSoftball, .boxing,
             .hillSprint, .ladderDrill, .resistedSprint, .shuttleRun,
             .skateboarding, .sprintDrills, .volleyball, .aquaJogging,
             .assaultBike, .badminton, .basketball, .burpee,
             .crossCountrySki, .dance, .golf, .grappling,
             .heavyBag, .hiitCircuit, .hockey, .mountainBike,
             .mountainClimber, .openWaterSwim, .paddling, .pickleball,
             .ruckMarch, .rugby, .skating, .skiErg,
             .skiing, .soccer, .squash, .surfing,
             .tennis, .trailRun, .ultimateFrisbee, .versaClimber,
             .walk, .adductorRockback, .ankleDorsiflexion, .bandPullApart,
             .catCow, .deepSquatHold, .foamRolling, .hamstringStretch,
             .hipFlexorMarch, .pilates, .proneYTW, .scapularPushUp,
             .shoulderDislocates, .wallSlides, .worldsGreatestStretch, .bearCrawl,
             .deadHang, .elliptical, .lSit, .suitcaseCarry:
            return true
        default:
            return false
        }
    }

    /// Default rest between sets, tuned per training style.
    var defaultRestSeconds: Int {
        switch focus {
        case .strength: return 150
        case .hypertrophy: return 90
        case .bodyweight: return 90
        case .explosive: return 120
        default: return 60
        }
    }
}

// MARK: - Train tab home

/// The Train tab: begin or resume a session (the primary path), start a
/// routine in one tap, or quick-log a single exercise the old way.
struct TrainHomeView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var activeDraft: ActiveSessionDraft? = nil
    @State private var showQuickLog = false
    @State private var resumableDraft: ActiveSessionDraft? = nil
    @State private var renameTarget: Routine? = nil
    @State private var renameText = ""
    @State private var pendingReplacementDraft: ActiveSessionDraft? = nil
    @State private var routineToDelete: Routine? = nil
    #if DEBUG
    @State private var openedScreenshotSession = false
    #endif

    private var freshDraft: ActiveSessionDraft {
        var draft = ActiveSessionDraft()
        draft.levelAtStart = state.user.level
        draft.unitsAtStart = state.user.units
        return draft
    }

    private var heroSubtitle: String {
        if let species = state.activeCompanionSpecies {
            return "\(state.companionDisplayName(species)) is warmed up and waiting."
        }
        return "Sets, rest, and XP in one flowing session."
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        hero

                        AdaptiveColumns {
                            routinesPanel

                            VStack(spacing: 16) {
                                Button {
                                    showQuickLog = true
                                } label: {
                                    RPGRow(title: "Quick Log",
                                           subtitle: "One exercise, logged in seconds.") {
                                        RPGSymbolIcon(
                                            symbol: .quickLog,
                                            size: 20,
                                            presentation: .compact,
                                            palette: .monochrome(RPGTheme.accent)
                                        )
                                    }
                                    .rpgCard(padding: 14)
                                }
                                .buttonStyle(PressableCardStyle())

                                // The standalone timer stays on the tab so a
                                // running countdown survives navigation.
                                RestTimerCard()
                            }
                        }
                    }
                    .screenColumn(maxWidth: sizeClass == .regular ? AppLayout.wideMaxWidth : AppLayout.contentMaxWidth)
                    .padding(.vertical, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Train")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showQuickLog) {
                LogWorkoutView()
                    .environmentObject(state)
            }
            .fullScreenCover(item: $activeDraft) { draft in
                ActiveWorkoutView(initialDraft: draft) {
                    activeDraft = nil
                    resumableDraft = ActiveSessionDraft.loadResumable()
                }
                .environmentObject(state)
            }
            .onAppear {
                resumableDraft = ActiveSessionDraft.loadResumable()
                #if DEBUG
                if !openedScreenshotSession,
                   ProcessInfo.processInfo.arguments.contains("-rpgfit-open-screenshot-session"),
                   let draft = state.sessionDraftRepeatingLast() {
                    openedScreenshotSession = true
                    // Present on the next run-loop turn, after this tab's
                    // NavigationStack has joined the window hierarchy.
                    DispatchQueue.main.async {
                        activeDraft = draft
                    }
                }
                #endif
            }
            .alert("Rename routine", isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
            )) {
                TextField("Name", text: $renameText)
                Button("Save") {
                    if let target = renameTarget {
                        state.renameRoutine(target.id, to: renameText)
                    }
                    renameTarget = nil
                }
                Button("Cancel", role: .cancel) { renameTarget = nil }
            }
            .confirmationDialog("Delete this routine?", isPresented: Binding(
                get: { routineToDelete != nil },
                set: { if !$0 { routineToDelete = nil } }
            ), titleVisibility: .visible) {
                Button("Delete Routine", role: .destructive) {
                    if let routine = routineToDelete { state.deleteRoutine(routine.id) }
                    routineToDelete = nil
                }
                Button("Keep", role: .cancel) { routineToDelete = nil }
            } message: {
                Text("Your logged sessions are untouched — only the template goes.")
            }
            .confirmationDialog("Replace saved session?", isPresented: Binding(
                get: { pendingReplacementDraft != nil },
                set: { if !$0 { pendingReplacementDraft = nil } }
            ), titleVisibility: .visible) {
                Button("Start New Session", role: .destructive) {
                    guard let replacement = pendingReplacementDraft else { return }
                    ActiveSessionDraft.clear()
                    resumableDraft = nil
                    pendingReplacementDraft = nil
                    activeDraft = replacement
                }
                Button("Keep Saved Session", role: .cancel) {
                    pendingReplacementDraft = nil
                }
            } message: {
                Text("Your session in progress will be discarded. You can resume it instead from the Train tab.")
            }
        }
    }

    // MARK: Hero

    @ViewBuilder
    private var hero: some View {
        if let draft = resumableDraft {
            VStack(spacing: 8) {
                Button {
                    activeDraft = draft
                } label: {
                    HeroPlate(
                        title: "Resume Session",
                        subtitle: "\(draft.exercises.count) exercise\(draft.exercises.count == 1 ? "" : "s") in progress · started \(draft.startedAt.formatted(date: .omitted, time: .shortened))",
                        symbol: .training
                    )
                }
                .buttonStyle(PressableCardStyle())
                .accessibilityLabel("Resume session, \(draft.exercises.count) exercises in progress")

                Button("Start a new session instead") {
                    requestStart(freshDraft)
                }
                .buttonStyle(RPGQuietButtonStyle(tint: .secondary))
            }
        } else {
            Button {
                requestStart(freshDraft)
            } label: {
                HeroPlate(title: "Begin Session", subtitle: heroSubtitle, symbol: .training)
            }
            .buttonStyle(PressableCardStyle())
            .accessibilityLabel("Begin training session")
        }
    }

    // MARK: Routines

    private var routinesPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel("Routines")
                .padding(.bottom, 6)

            let hasLast = !state.lastSessionEntries.isEmpty
            if hasLast {
                Button {
                    if let draft = state.sessionDraftRepeatingLast() {
                        requestStart(draft)
                    }
                } label: {
                    RPGRow(title: "Repeat Last Session", subtitle: lastSessionSummaryLine) {
                        RPGSymbolIcon(symbol: .repeatSession, size: 22,
                                      presentation: .compact,
                                      palette: .monochrome(RPGTheme.gold))
                    }
                }
                .buttonStyle(PressableCardStyle())
            }

            ForEach(Array(state.user.routines.enumerated()), id: \.element.id) { index, routine in
                if hasLast || index > 0 { HairlineRule() }
                HStack(spacing: 4) {
                    Button {
                        requestStart(state.sessionDraft(from: routine))
                    } label: {
                        RPGRow(title: routine.name, subtitle: routineSummaryLine(routine)) {
                            RPGSymbolIcon(
                                symbol: .routine,
                                size: 19,
                                presentation: .compact,
                                palette: .monochrome(RPGTheme.accent)
                            )
                        }
                    }
                    .buttonStyle(PressableCardStyle())
                    .accessibilityHint("Starts a session from this routine.")
                    .contextMenu { routineMenu(routine) }

                    Menu {
                        routineMenu(routine)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.body)
                            .foregroundColor(RPGTheme.accent)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Routine options for \(routine.name)")
                }
            }

            if state.user.routines.isEmpty {
                if hasLast { HairlineRule() }
                Text("Finish a session and save it as a routine to start it here in one tap.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .rpgCard(padding: 14)
    }

    @ViewBuilder
    private func routineMenu(_ routine: Routine) -> some View {
        Button {
            renameTarget = routine
            renameText = routine.name
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        Button(role: .destructive) {
            routineToDelete = routine
        } label: {
            Label("Delete Routine", systemImage: "trash")
        }
    }

    private func requestStart(_ candidate: ActiveSessionDraft) {
        if let saved = resumableDraft, saved.id != candidate.id {
            pendingReplacementDraft = candidate
        } else {
            activeDraft = candidate
        }
    }

    private var lastSessionSummaryLine: String {
        summaryLine(for: state.lastSessionEntries.map {
            $0.customExerciseID != nil ? $0.name : $0.category.displayName
        })
    }

    private func routineSummaryLine(_ routine: Routine) -> String {
        summaryLine(for: routine.exercises.map { $0.displayName })
    }

    private func summaryLine(for names: [String]) -> String {
        guard !names.isEmpty else { return "" }
        let shown = names.prefix(2).joined(separator: " · ")
        let more = names.count - min(2, names.count)
        return more > 0 ? "\(shown) +\(more) more" : shown
    }
}

extension ActiveSessionDraft: Identifiable {}

// MARK: - Active session

struct ActiveWorkoutView: View {
    let initialDraft: ActiveSessionDraft
    let onClose: () -> Void

    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var draft: ActiveSessionDraft = ActiveSessionDraft()
    @State private var estimatedXP: Double = 0
    @State private var lastTick: Double = 0
    @State private var tickToken = UUID()
    @State private var showPicker = false
    @State private var restEndDate: Date? = nil
    @State private var restTotal: Int = 90
    @State private var restExerciseName = "your next set"
    @State private var showEndConfirm = false
    @State private var summary: SessionSummary? = nil
    /// Once the session is finished or discarded, draft mutations (e.g.
    /// endRest clearing rest state) must not re-persist the cleared draft —
    /// that would resurrect a dead session in the Resume banner.
    @State private var sessionEnded = false
    /// The exercise the dock is working through. Follows check-offs and
    /// additions so the bottom action always names the set you meant.
    @State private var focusedExerciseID: UUID? = nil
    @State private var dockNotice: String? = nil

    private struct PlateCalcRequest: Identifiable {
        let id = UUID()
        let weight: Double?
    }
    @State private var plateCalcRequest: PlateCalcRequest? = nil
    /// When set, the next picker selection substitutes this exercise
    /// instead of adding a new one.
    @State private var swapTargetID: UUID? = nil

    private static let restNotificationID = "rpgfit.sessionRest"

    /// Numeric strings in a saved draft always keep the units they were
    /// entered with, even if the profile setting changes before resume.
    private var sessionUnits: Units {
        draft.unitsAtStart ?? initialDraft.unitsAtStart ?? state.user.units
    }

    /// The next set to complete: the focused exercise's first unchecked set,
    /// or the first pending set anywhere in the session.
    private struct PendingTarget {
        let exerciseIndex: Int
        let setIndex: Int
    }

    private var pendingTarget: PendingTarget? {
        var order = Array(draft.exercises.indices)
        if let focused = focusedExerciseID,
           let index = draft.exercises.firstIndex(where: { $0.id == focused }) {
            order.removeAll { $0 == index }
            order.insert(index, at: 0)
        }
        for index in order {
            let exercise = draft.exercises[index]
            guard !exercise.logged, !exercise.isTimed else { continue }
            if let setIndex = exercise.sets.firstIndex(where: { !$0.done }) {
                return PendingTarget(exerciseIndex: index, setIndex: setIndex)
            }
        }
        return nil
    }

    private var hasWork: Bool {
        draft.exercises.contains { exercise in
            exercise.logged
                || !exercise.doneSets.isEmpty
                || (exercise.isTimed && ((flexibleDouble(exercise.duration) ?? 0) > 0 || (flexibleDouble(exercise.distance) ?? 0) > 0))
        }
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        ForEach($draft.exercises) { $exercise in
                            if !exercise.logged {
                                ExerciseSessionCard(
                                    exercise: $exercise,
                                    units: sessionUnits,
                                    isFocused: pendingTarget.map { draft.exercises[$0.exerciseIndex].id == exercise.id } ?? false,
                                    onSetChecked: { setChecked(in: exercise.id) },
                                    onComplete: { logExercise(id: exercise.id) },
                                    onRemove: { removeExercise(id: exercise.id) },
                                    onPlateCalculator: { presentPlateCalculator(for: exercise) },
                                    onSwap: {
                                        swapTargetID = exercise.id
                                        showPicker = true
                                    },
                                    onToggleSuperset: supersetAction(for: exercise.id)
                                )
                            } else {
                                loggedRow(for: exercise)
                            }
                        }

                        Button {
                            showPicker = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.subheadline.weight(.bold))
                                Text(draft.exercises.isEmpty ? "Add your first exercise" : "Add exercise")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(RPGTheme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: RPGTheme.innerRadius, style: .continuous)
                                    .strokeBorder(RPGTheme.frame.opacity(RPGTheme.hairline + 0.2), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                            )
                        }
                        .padding(.top, 2)
                    }
                    .screenColumn()
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .font(.body.weight(.semibold))
                .foregroundColor(RPGTheme.accent)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            dock
        }
        .onAppear {
            draft = initialDraft
            // Close the persisted pause interval before the timer is shown.
            // Fresh and legacy drafts have no pausedAt value, so this is a
            // no-op for them.
            draft.resume()
            // Legacy drafts did not record their display units. Pin them once
            // on first resume so subsequent settings changes are safe.
            if draft.unitsAtStart == nil { draft.unitsAtStart = state.user.units }
            restExerciseName = draft.restExerciseName ?? "your next set"
            // A resumed session picks its rest countdown back up; a stale one
            // (rest elapsed while away) is cleared rather than flashed.
            if let ends = draft.restEndsAt, ends > Date() {
                restEndDate = ends
                restTotal = draft.restTotalSeconds ?? 90
            } else {
                draft.restEndsAt = nil
                draft.restTotalSeconds = nil
                draft.restExerciseName = nil
            }
            draft.persist()
            recomputeEstimate()
        }
        .onChangeCompat(of: draft) { _, _ in
            // Every keystroke and check-off survives a force-quit.
            guard !sessionEnded else { return }
            draft.persist()
        }
        .sheet(isPresented: $showPicker, onDismiss: { swapTargetID = nil }) {
            ExercisePickerSheet(displayUnits: sessionUnits, swapMode: swapTargetID != nil) { selection in
                if let swapID = swapTargetID {
                    swapExercise(id: swapID, to: selection)
                } else {
                    addExercise(selection)
                }
            }
            .environmentObject(state)
        }
        .sheet(item: $plateCalcRequest) { request in
            PlateCalculatorSheet(units: sessionUnits, initialWeight: request.weight)
        }
        .fullScreenCover(item: $summary) { result in
            SessionSummaryView(summary: result) {
                summary = nil
                onClose()
            }
            .environmentObject(state)
        }
        .confirmationDialog("End this session?", isPresented: $showEndConfirm, titleVisibility: .visible) {
            Button("Discard empty session", role: .destructive) {
                sessionEnded = true
                ActiveSessionDraft.clear()
                endRest()
                onClose()
            }
            Button("Keep training", role: .cancel) {}
        } message: {
            Text("Nothing has been logged yet.")
        }
    }

    // MARK: header

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            if draft.exercises.isEmpty {
                Button("Close") { showEndConfirm = true }
                    .buttonStyle(RPGQuietButtonStyle(tint: .secondary))
                    .accessibilityLabel("Close session")
            } else {
                Button("Pause") { saveAndExit() }
                    .buttonStyle(RPGQuietButtonStyle(tint: .secondary))
                    .accessibilityLabel("Save & Exit")
                    .accessibilityHint("Pauses the session. Resume it any time from the Train tab.")
            }

            Spacer(minLength: 4)

            VStack(spacing: 1) {
                Text("Session")
                    .font(RPGTheme.heading(.headline, weight: .bold))
                HStack(spacing: 5) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(sessionTimerText(at: context.date))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                    Text("·")
                        .foregroundColor(.secondary)
                    HStack(spacing: 3) {
                        RPGSymbolIcon(
                            symbol: .xp,
                            size: 10,
                            presentation: .compact,
                            palette: .monochrome(RPGTheme.xp)
                        )
                            .accessibilityHidden(true)
                        Text("≈\(Int(estimatedXP.rounded())) XP")
                            .monospacedDigit()
                            .foregroundColor(RPGTheme.xp)
                            .contentTransition(reduceMotion ? .identity : .numericText())
                        if lastTick > 0.4 {
                            Text("+\(String(format: "%.1f", lastTick))")
                                .font(.caption2.weight(.bold))
                                .monospacedDigit()
                                .foregroundColor(RPGTheme.gold)
                                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                                .id(tickToken)
                        }
                    }
                }
                .font(.caption.weight(.medium))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Session in progress. Approximately \(Int(estimatedXP.rounded())) experience points banked.")

            Spacer(minLength: 4)

            // The header carries Finish unless the dock is showing it as the
            // dominant action (nothing pending, no rest running).
            if restEndDate != nil || pendingTarget != nil || !hasWork {
                Button("Finish") { finishTapped() }
                    .buttonStyle(RPGQuietButtonStyle())
                    .accessibilityLabel("Finish Session")
                    .accessibilityHint("Logs every exercise with completed sets and shows the summary.")
            } else {
                Color.clear.frame(width: 56, height: 44)
            }
        }
        .padding(.horizontal, AppLayout.horizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .frame(maxWidth: AppLayout.contentMaxWidth)
        .frame(maxWidth: .infinity)
    }

    private func finishTapped() {
        if hasWork {
            finishSession()
        } else {
            showEndConfirm = true
        }
    }

    @ViewBuilder
    private func loggedRow(for exercise: DraftExercise) -> some View {
        HStack(spacing: 10) {
            RPGSymbolIcon(symbol: .completionSeal, size: 18,
                          presentation: .compact,
                          palette: .monochrome(RPGTheme.xp))
            Text(exercise.displayName)
                .font(RPGTheme.heading(.subheadline, weight: .semibold))
                .foregroundColor(.secondary)
                .strikethrough()
            Spacer()
            Text(exercise.isTimed ? "logged" : "\(exercise.doneSets.count) set\(exercise.doneSets.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: RPGTheme.innerRadius, style: .continuous)
                .fill(RPGTheme.xp.opacity(0.08))
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: dock

    /// The bottom dock is the session's only fixed control surface: during
    /// rest it is the timer, otherwise it is the next set, and when nothing
    /// is left it is the way out.
    @ViewBuilder
    private var dock: some View {
        DockBar {
            if let restEndDate {
                RestDock(endDate: restEndDate,
                         total: restTotal,
                         nextLine: nextSetLine,
                         onSkip: { endRest() },
                         onExtend: { extendRest(by: 30) })
            } else if let target = pendingTarget {
                setDock(target)
            } else if hasWork {
                VStack(spacing: 8) {
                    Text(dockCompletionCaption)
                        .font(.caption)
                        .foregroundColor(emptyTimedExercises.isEmpty ? .secondary : RPGTheme.warningText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Button("Add exercise") { showPicker = true }
                            .buttonStyle(RPGSecondaryButtonStyle())
                            .frame(maxWidth: 150)
                        Button("Finish Session") { finishSession() }
                            .buttonStyle(RPGPrimaryButtonStyle())
                    }
                }
            } else {
                Button("Add exercise") { showPicker = true }
                    .buttonStyle(RPGPrimaryButtonStyle())
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: restEndDate == nil)
    }

    /// Timed exercises the dock cannot drive and Finish would leave out.
    private var emptyTimedExercises: [DraftExercise] {
        draft.exercises.filter {
            !$0.logged && $0.isTimed
                && (flexibleDouble($0.duration) ?? 0) <= 0
                && (flexibleDouble($0.distance) ?? 0) <= 0
        }
    }

    private var dockCompletionCaption: String {
        let empty = emptyTimedExercises
        guard !empty.isEmpty else { return "Every set is logged." }
        let names = empty.map(\.displayName).joined(separator: ", ")
        return "\(names) has no minutes or distance yet — Finish leaves it out."
    }

    private var nextSetLine: String {
        guard let target = pendingTarget else { return "Nothing left to lift — finish when you are ready." }
        let exercise = draft.exercises[target.exerciseIndex]
        return "Next · \(exercise.displayName) · Set \(target.setIndex + 1)"
    }

    private func setDock(_ target: PendingTarget) -> some View {
        let exercise = draft.exercises[target.exerciseIndex]
        let set = exercise.sets[target.setIndex]
        let weightBinding = Binding<String>(
            get: { draft.exercises[target.exerciseIndex].sets[target.setIndex].weight },
            set: { draft.exercises[target.exerciseIndex].sets[target.setIndex].weight = $0 }
        )
        let repsBinding = Binding<String>(
            get: { draft.exercises[target.exerciseIndex].sets[target.setIndex].reps },
            set: { draft.exercises[target.exerciseIndex].sets[target.setIndex].reps = $0 }
        )
        let title = "\(exercise.displayName) · \(set.isWarmup ? "Warm-up" : "Set \(target.setIndex + 1)")"

        return VStack(spacing: 10) {
            HStack {
                Text(title)
                    .font(RPGTheme.heading(.subheadline, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                if let dockNotice {
                    Text(dockNotice)
                        .font(.caption.weight(.medium))
                        .foregroundColor(RPGTheme.warningText)
                        .transition(.opacity)
                }
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    SetStepper(label: sessionUnits.displayName, text: weightBinding,
                               step: sessionUnits == .kg ? 2.5 : 5, integer: false,
                               accessibilityName: "Weight")
                    SetStepper(label: "reps", text: repsBinding, step: 1, integer: true,
                               accessibilityName: "Repetitions")
                }
            } else {
                HStack(spacing: 10) {
                    SetStepper(label: sessionUnits.displayName, text: weightBinding,
                               step: sessionUnits == .kg ? 2.5 : 5, integer: false,
                               accessibilityName: "Weight")
                    SetStepper(label: "reps", text: repsBinding, step: 1, integer: true,
                               accessibilityName: "Repetitions")
                }
            }

            Button {
                completePendingSet(target)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.headline.weight(.bold))
                    Text("Complete Set")
                }
            }
            .buttonStyle(RPGPrimaryButtonStyle())
            .accessibilityLabel("Log \(set.isWarmup ? "warm-up" : "set \(target.setIndex + 1)") of \(exercise.displayName)")
            .accessibilityValue("\(set.weight.isEmpty ? "no weight" : "\(set.weight) \(sessionUnits.displayName)"), \(set.reps.isEmpty ? "no reps" : "\(set.reps) reps")")
        }
    }

    private func completePendingSet(_ target: PendingTarget) {
        let exercise = draft.exercises[target.exerciseIndex]
        guard Int(exercise.sets[target.setIndex].reps) ?? 0 > 0 else {
            withAnimation { dockNotice = "Enter reps first" }
            UIAccessibility.post(notification: .announcement, argument: "Enter reps first")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation { dockNotice = nil }
            }
            return
        }
        focusedExerciseID = exercise.id
        withAnimation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.6)) {
            draft.exercises[target.exerciseIndex].sets[target.setIndex].done = true
        }
        setChecked(in: exercise.id)
    }

    // MARK: session mechanics

    private func addExercise(_ selection: ExerciseSelection) {
        var sets: [DraftSet] = []
        if !selection.category.prefersDuration {
            // Ghost the last session of this exercise IDENTITY set-by-set —
            // real per-set records prefill individually (60×8, 70×6, 80×4),
            // and legacy summaries expand to identical copies via
            // resolvedSets. Custom and built-in histories never cross-ghost.
            if let last = state.lastEntry(category: selection.category, customID: selection.customExerciseID) {
                sets = last.resolvedSets.map { resolved in
                    DraftSet(reps: resolved.reps.map(String.init) ?? "",
                             weight: resolved.weightKg.map { AppState.fieldNumber(sessionUnits.fromKg($0)) } ?? "",
                             isWarmup: resolved.isWarmup)
                }
            }
            if sets.isEmpty { sets = (0..<3).map { _ in DraftSet() } }
        }
        var exercise = DraftExercise(category: selection.category, sets: sets)
        exercise.customExerciseID = selection.customExerciseID
        exercise.customName = selection.customExerciseID != nil ? selection.displayName : nil
        draft.exercises.append(exercise)
        if pendingTarget == nil || focusedExerciseID == nil {
            focusedExerciseID = exercise.id
        }
        draft.persist()
    }

    /// Substitutes the movement on an unlogged exercise, keeping entered
    /// work when both sides are set-based.
    private func swapExercise(id: UUID, to selection: ExerciseSelection) {
        guard let index = draft.exercises.firstIndex(where: { $0.id == id }),
              !draft.exercises[index].logged else { return }
        let wasTimed = draft.exercises[index].isTimed
        draft.exercises[index].category = selection.category
        draft.exercises[index].customExerciseID = selection.customExerciseID
        draft.exercises[index].customName = selection.customExerciseID != nil ? selection.displayName : nil
        if wasTimed != selection.category.prefersDuration {
            draft.exercises[index].duration = ""
            draft.exercises[index].distance = ""
            draft.exercises[index].sets = selection.category.prefersDuration
                ? []
                : (0..<3).map { _ in DraftSet() }
        }
        draft.normalizeSupersets()
        draft.persist()
        recomputeEstimate()
        Haptics.tap()
    }

    private func removeExercise(id: UUID) {
        draft.exercises.removeAll { $0.id == id && !$0.logged }
        draft.normalizeSupersets()
        if focusedExerciseID == id { focusedExerciseID = nil }
        draft.persist()
        recomputeEstimate()
    }

    private func setChecked(in exerciseID: UUID) {
        guard let exercise = draft.exercises.first(where: { $0.id == exerciseID }) else { return }
        Haptics.setComplete()
        focusedExerciseID = exerciseID
        // In a superset the dock walks the round: A set → B set → rest. Hand
        // the focus to the next unlogged member that still has work.
        if let group = exercise.supersetGroup {
            let members = draft.exercises.filter { $0.supersetGroup == group && !$0.logged }
            if members.count > 1, let index = members.firstIndex(where: { $0.id == exerciseID }) {
                for offset in 1..<members.count {
                    let candidate = members[(index + offset) % members.count]
                    if candidate.sets.contains(where: { !$0.done }) {
                        focusedExerciseID = candidate.id
                        break
                    }
                }
            }
        }
        draft.persist()

        let previous = estimatedXP
        recomputeEstimate()
        let delta = estimatedXP - previous
        if delta > 0.05 {
            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)) {
                lastTick = delta
                tickToken = UUID()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(reduceMotion ? nil : .default) { lastTick = 0 }
            }
        }

        // Auto rest — the tap that ends a set starts the recovery. In a
        // superset, rest waits for the last member of the round.
        if !exercise.isTimed,
           draft.shouldRest(afterSetIn: exerciseID) {
            startRest(seconds: exercise.category.defaultRestSeconds,
                      exerciseName: exercise.displayName)
        }
    }

    /// Deterministic running estimate across all unlogged exercises, plus
    /// the real XP of already-logged ones.
    private func recomputeEstimate() {
        var total: Double = 0
        for exercise in draft.exercises {
            if exercise.logged { continue }
            if exercise.isTimed { continue }
            let allDone = exercise.doneSets
            guard !allDone.isEmpty else { continue }
            // Mirror logExercise: warm-ups don't earn estimated XP.
            let working = allDone.filter { !$0.isWarmup }
            guard !working.isEmpty else { continue }
            let done = working
            guard let representative = exercise.representativeWorkingSet(
                units: sessionUnits,
                bodyweightKg: state.user.bodyweightKg
            ) else { continue }
            let reps = Int(representative.reps) ?? 0
            let weightKg = flexibleDouble(representative.weight).map { sessionUnits.toKg($0) }
            let perf = StatEngine.placementMetric(category: exercise.category,
                                                  reps: reps > 0 ? reps : nil,
                                                  weight: weightKg,
                                                  durationMin: nil, distanceKm: nil,
                                                  bodyweightKg: state.user.bodyweightKg)
            total += StatEngine.estimatedXP(category: exercise.category,
                                            perf: perf,
                                            baseline: state.user.xpBaselines[exercise.category],
                                            sets: done.count)
        }
        let realLogged = state.history
            .filter { $0.sessionID == draft.id }
            .reduce(0.0) { $0 + $1.expGained }
        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)) {
            estimatedXP = total + realLogged
        }
    }

    /// Logs one exercise through the real engine and freezes its card.
    private func logExercise(id: UUID) {
        guard let index = draft.exercises.firstIndex(where: { $0.id == id }) else { return }
        let exercise = draft.exercises[index]

        if exercise.isTimed {
            let duration = flexibleDouble(exercise.duration)
            let distance = flexibleDouble(exercise.distance).map { sessionUnits.toKm($0) }
            guard (duration ?? 0) > 0 || (distance ?? 0) > 0 else { return }
            state.logWorkout(name: exercise.customName ?? "", category: exercise.category, sets: nil, reps: nil,
                             weight: nil, durationMinutes: duration, distanceKm: distance,
                             sessionID: draft.id, customExerciseID: exercise.customExerciseID)
        } else {
            let done = exercise.doneSets
            guard !done.isEmpty else { return }
            // Every performed set is recorded as entered (warm-ups included),
            // but XP, set count, and the summarizing representative come from
            // WORKING sets only — warming up isn't training volume.
            let performed = done.map { draftSet in
                PerformedSet(reps: Int(draftSet.reps),
                             weightKg: flexibleDouble(draftSet.weight).map { sessionUnits.toKg($0) },
                             rpe: draftSet.rpe,
                             isWarmup: draftSet.isWarmup)
            }
            let working = done.filter { !$0.isWarmup }
            if working.isEmpty {
                // Warm-ups remain part of the honest training log, but bypass
                // the reward engine entirely: no XP, quests, Trial might,
                // bond progress, ranks, baselines, or personal records.
                _ = state.logWarmupOnlyExercise(
                    name: exercise.customName ?? "",
                    category: exercise.category,
                    performedSets: performed,
                    sessionID: draft.id,
                    customExerciseID: exercise.customExerciseID
                )
                draft.exercises[index].logged = true
                draft.persist()
                endRest()
                recomputeEstimate()
                return
            }
            let scored = working
            guard let representative = exercise.representativeWorkingSet(
                units: sessionUnits,
                bodyweightKg: state.user.bodyweightKg
            ) else { return }
            let reps = Int(representative.reps)
            let weightKg = flexibleDouble(representative.weight).map { sessionUnits.toKg($0) }
            state.logWorkout(name: exercise.customName ?? "", category: exercise.category, sets: scored.count,
                             reps: reps, weight: weightKg, durationMinutes: nil,
                             distanceKm: nil, sessionID: draft.id,
                             performedSets: performed,
                             customExerciseID: exercise.customExerciseID)
        }

        draft.exercises[index].logged = true
        if focusedExerciseID == id { focusedExerciseID = nil }
        draft.persist()
        endRest()
        recomputeEstimate()
    }

    private func finishSession() {
        // Log anything with work in it that wasn't explicitly completed.
        for exercise in draft.exercises where !exercise.logged {
            if exercise.isTimed {
                if (flexibleDouble(exercise.duration) ?? 0) > 0 || (flexibleDouble(exercise.distance) ?? 0) > 0 {
                    logExercise(id: exercise.id)
                }
            } else if !exercise.doneSets.isEmpty {
                logExercise(id: exercise.id)
            }
        }

        let entries = state.history.filter { $0.sessionID == draft.id }
        guard !entries.isEmpty else {
            showEndConfirm = true
            return
        }

        var gains = StatBlock.zero
        entries.forEach { gains.add($0.statGains) }
        let prCount = entries.filter { entry in
            guard let est = entry.est1RM else { return false }
            return est > (entry.prevBest1RM ?? 0)
        }.count

        let sessionEnd = Date()
        let activeDuration = draft.activeDuration(at: sessionEnd)
        summary = SessionSummary(
            date: draft.startedAt,
            duration: activeDuration,
            exercises: entries.count,
            sets: entries.reduce(0) { $0 + max(1, $1.sets ?? 1) },
            totalXP: entries.reduce(0) { $0 + $1.expGained },
            statGains: gains,
            prCount: prCount,
            levelFrom: draft.levelAtStart,
            levelTo: state.user.level,
            sessionID: draft.id
        )
        sessionEnded = true
        ActiveSessionDraft.clear()
        endRest()
        Haptics.success()

        // Mirror the finished session into Apple Health when enabled.
        let healthSessionStart = sessionEnd.addingTimeInterval(-activeDuration)
        Task { await HealthKitManager.shared.saveSession(start: healthSessionStart, end: sessionEnd) }
    }

    /// The superset menu action for one card: link with the next exercise,
    /// or leave the current group. nil when neither applies.
    private func supersetAction(for id: UUID) -> ExerciseSessionCard.SupersetAction? {
        guard let index = draft.exercises.firstIndex(where: { $0.id == id }) else { return nil }
        if draft.exercises[index].supersetGroup != nil {
            return .init(label: "Remove from Superset") {
                draft.breakSuperset(at: index)
                draft.persist()
            }
        }
        let hasNext = draft.exercises.indices.contains {
            $0 > index && !draft.exercises[$0].logged && !draft.exercises[$0].isTimed
        }
        guard hasNext, !draft.exercises[index].isTimed else { return nil }
        return .init(label: "Superset with Next") {
            draft.supersetWithNext(at: index)
            draft.persist()
            Haptics.tap()
        }
    }

    private func presentPlateCalculator(for exercise: DraftExercise) {
        let pendingWeight = exercise.sets.first(where: { !$0.done })?.weight
            ?? exercise.sets.last?.weight
            ?? ""
        plateCalcRequest = PlateCalcRequest(weight: flexibleDouble(pendingWeight))
    }

    // MARK: pause

    /// The explicit pause: the draft (with its live rest state) stays
    /// persisted for the Train tab's Resume banner, and any scheduled rest
    /// notification keeps ticking so recovery still announces itself.
    private func saveAndExit() {
        draft.restEndsAt = restEndDate
        draft.restTotalSeconds = restEndDate != nil ? restTotal : nil
        draft.pause()
        draft.persist()
        Haptics.tap()
        onClose()
    }

    private func sessionTimerText(at date: Date) -> String {
        let totalSeconds = Int(draft.activeDuration(at: date))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: rest handling

    private func startRest(seconds: Int, exerciseName: String = "your next set") {
        restTotal = seconds
        restExerciseName = exerciseName
        let ends = Date().addingTimeInterval(TimeInterval(seconds))
        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) {
            restEndDate = ends
        }
        draft.restEndsAt = ends
        draft.restTotalSeconds = seconds
        draft.restExerciseName = exerciseName
        scheduleRestNotification(fireIn: TimeInterval(seconds), restLength: seconds)
        RestLiveActivity.start(endDate: ends, totalSeconds: seconds, exerciseName: exerciseName)
    }

    private func extendRest(by seconds: Int) {
        guard let current = restEndDate else { return }
        let ends = max(current, Date()).addingTimeInterval(TimeInterval(seconds))
        restEndDate = ends
        restTotal += seconds
        draft.restEndsAt = ends
        draft.restTotalSeconds = restTotal
        draft.restExerciseName = restExerciseName
        Haptics.tick()
        // Reschedule, or the ding still fires at the ORIGINAL end time.
        scheduleRestNotification(fireIn: ends.timeIntervalSinceNow, restLength: restTotal)
        RestLiveActivity.update(endDate: ends, totalSeconds: restTotal, exerciseName: restExerciseName)
    }

    private func endRest() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { restEndDate = nil }
        draft.restEndsAt = nil
        draft.restTotalSeconds = nil
        draft.restExerciseName = nil
        restExerciseName = "your next set"
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.restNotificationID])
        RestLiveActivity.end()
    }

    private func scheduleRestNotification(fireIn interval: TimeInterval, restLength: Int) {
        guard interval > 0 else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Rest complete"
            content.body = "Next set — your \(restLength)s recovery is done."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            center.removePendingNotificationRequests(withIdentifiers: [Self.restNotificationID])
            center.add(UNNotificationRequest(identifier: Self.restNotificationID, content: content, trigger: trigger))
        }
    }
}

/// A large, one-thumb stepper for the pending set's weight or reps. The
/// number is still a text field elsewhere on the card — this is the fast
/// path, not the only path.
struct SetStepper: View {
    let label: String
    @Binding var text: String
    let step: Double
    let integer: Bool
    /// Spoken name — the visible label is a bare unit ("kg", "reps").
    var accessibilityName: String? = nil

    private func adjust(_ delta: Double) {
        let current = flexibleDouble(text) ?? 0
        let next = max(0, current + delta)
        text = integer ? String(Int(next.rounded())) : AppState.fieldNumber(next)
        Haptics.tick()
    }

    var body: some View {
        HStack(spacing: 0) {
            Button { adjust(-step) } label: {
                Image(systemName: "minus")
                    .font(.headline.weight(.semibold))
                    .frame(width: 44, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundColor(RPGTheme.accent)
            .accessibilityHidden(true)

            VStack(spacing: 0) {
                Text(text.isEmpty ? "—" : text)
                    .font(RPGTheme.display(20, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
                Text(label)
                    .font(RPGTheme.label(10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            Button { adjust(step) } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.semibold))
                    .frame(width: 44, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundColor(RPGTheme.accent)
            .accessibilityHidden(true)
        }
        .background(
            RoundedRectangle(cornerRadius: RPGTheme.innerRadius, style: .continuous)
                .fill(RPGTheme.surfaceInner)
                .overlay(
                    RoundedRectangle(cornerRadius: RPGTheme.innerRadius, style: .continuous)
                        .strokeBorder(RPGTheme.frame.opacity(RPGTheme.hairline), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityName ?? label)
        .accessibilityValue(text.isEmpty ? "Not entered" : "\(text) \(label)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: adjust(step)
            case .decrement: adjust(-step)
            @unknown default: break
            }
        }
    }
}

/// The dock during rest: countdown ring, the set that comes next, and the
/// two things you can do about it.
struct RestDock: View {
    let endDate: Date
    let total: Int
    let nextLine: String
    let onSkip: () -> Void
    let onExtend: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Ring + time on one line, controls beside them — or below them once
        // text grows past the point where they would clip.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 12))
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let remaining = max(0, endDate.timeIntervalSince(context.date))
            VStack(spacing: 8) {
                layout {
                    ZStack {
                        Circle()
                            .stroke(RPGTheme.surfaceInner, lineWidth: 4)
                        Circle()
                            .trim(from: 0, to: CGFloat(remaining / Double(max(1, total))))
                            .stroke(RPGTheme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        RPGSymbolIcon(
                            symbol: .rest,
                            size: 18,
                            presentation: .compact,
                            palette: .monochrome(remaining <= 5 ? RPGTheme.xp : RPGTheme.accent)
                        )
                    }
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Resting")
                            .font(RPGTheme.label(11, weight: .semibold))
                            .tracking(1.0)
                            .foregroundColor(.secondary)
                        Text(String(format: "%d:%02d", Int(remaining) / 60, Int(remaining) % 60))
                            .font(RPGTheme.display(26, weight: .semibold))
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Rest timer")
                    .accessibilityValue("\(Int(remaining)) seconds remaining")

                    if !dynamicTypeSize.isAccessibilitySize { Spacer() }

                    HStack(spacing: 8) {
                        Button("+30s", action: onExtend)
                            .buttonStyle(RPGQuietButtonStyle())
                            .accessibilityLabel("Add 30 seconds to rest timer")

                        Button("Skip", action: onSkip)
                            .buttonStyle(RPGPrimaryButtonStyle())
                            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 120)
                            .accessibilityLabel("Skip rest")
                    }
                }

                Text(nextLine)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChangeCompat(of: remaining <= 0) { _, finished in
                if finished {
                    Haptics.success()
                    onSkip()
                }
            }
        }
    }
}

// MARK: - Session summary

struct SessionSummary: Identifiable {
    let id = UUID()
    let date: Date
    let duration: TimeInterval
    let exercises: Int
    let sets: Int
    let totalXP: Double
    let statGains: StatBlock
    let prCount: Int
    let levelFrom: Int
    let levelTo: Int
    /// Groups this summary's logged entries, so the workout that was just
    /// finished can be saved as a routine in one tap.
    var sessionID: UUID? = nil
}

struct SessionSummaryView: View {
    let summary: SessionSummary
    let onDone: () -> Void
    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animateIn = false
    @State private var showSaveRoutine = false
    @State private var routineName = ""

    var body: some View {
        ZStack {
            RPGTheme.canvas.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer(minLength: 8)

                    if let species = state.activeCompanionSpecies {
                        CompanionSpriteView(species: species, size: 90, accessory: state.accessory(for: species))
                            .scaleEffect(animateIn || reduceMotion ? 1.0 : 0.6)
                            .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.6), value: animateIn)
                    }

                    VStack(spacing: 6) {
                        Text("Session Complete")
                            .font(RPGTheme.heading(32))
                        if summary.levelTo > summary.levelFrom {
                            Text("Level \(summary.levelFrom) → \(summary.levelTo)")
                                .font(.headline)
                                .foregroundColor(RPGTheme.gold)
                        }
                    }

                    HStack(spacing: 4) {
                        RPGSymbolIcon(
                            symbol: .xp,
                            size: 18,
                            presentation: .compact,
                            palette: .monochrome(RPGTheme.xp)
                        )
                            .accessibilityHidden(true)
                        Text("+\(String(format: summary.totalXP < 100 ? "%.1f" : "%.0f", summary.totalXP))")
                            .font(RPGTheme.display(44))
                            .monospacedDigit()
                            .foregroundColor(RPGTheme.xp)
                        Text("XP")
                            .font(.title3.weight(.bold))
                            .foregroundColor(RPGTheme.xp.opacity(0.8))
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                        summaryChip(value: "\(summary.exercises)", label: summary.exercises == 1 ? "exercise" : "exercises")
                        summaryChip(value: "\(summary.sets)", label: summary.sets == 1 ? "set" : "sets")
                        summaryChip(value: timeString(summary.duration), label: "elapsed")
                        if summary.prCount > 0 {
                            summaryChip(value: "\(summary.prCount)", label: summary.prCount == 1 ? "new PR" : "new PRs", tint: RPGTheme.gold)
                        }
                    }
                    .padding(.horizontal, 24)

                    let gains = summary.statGains.statPairs.filter { $0.value > 0.005 }.sorted { $0.value > $1.value }
                    if !gains.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                            ForEach(gains.prefix(3), id: \.stat) { pair in
                                HStack(spacing: 6) {
                                    StatIcon(stat: pair.stat, size: 13)
                                    Text(String(format: "+%.2f", pair.value))
                                        .font(.caption.weight(.bold))
                                        .monospacedDigit()
                                        .foregroundColor(pair.stat.color)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(pair.stat.color.opacity(0.10)))
                            }
                        }
                    }

                    Spacer(minLength: 8)

                    VStack(spacing: 10) {
                        if summary.sessionID != nil {
                            Button("Save as Routine") {
                                routineName = ""
                                showSaveRoutine = true
                            }
                            .buttonStyle(RPGSecondaryButtonStyle())
                        }
                        Button("Continue", action: onDone)
                            .buttonStyle(RPGPrimaryButtonStyle())
                    }
                    .frame(maxWidth: 280)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
        }
        .alert("Save as routine", isPresented: $showSaveRoutine) {
            TextField("Routine name", text: $routineName)
            Button("Save") {
                let entries = Array(state.history
                    .filter { $0.sessionID == summary.sessionID }
                    .reversed())
                state.saveRoutine(named: routineName, from: entries)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Today's exercises and sets become a template on the Train tab.")
        }
        .onAppear { animateIn = true }
        .transaction { transaction in
            if reduceMotion { transaction.animation = nil }
        }
        .accessibilityLabel("Session complete: \(summary.exercises) exercises, \(summary.sets) sets, \(Int(summary.totalXP)) experience points.\(summary.prCount > 0 ? " \(summary.prCount) new personal records." : "")")
    }

    private func timeString(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        return minutes >= 60 ? String(format: "%d:%02d", minutes / 60, minutes % 60) : "\(max(1, minutes))m"
    }

    @ViewBuilder
    private func summaryChip(value: String, label: String, tint: Color = RPGTheme.accent) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(RPGTheme.display(20))
                .monospacedDigit()
                .foregroundColor(tint)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.08))
        )
    }
}

// MARK: - Exercise card during a session

struct ExerciseSessionCard: View {
    @Binding var exercise: DraftExercise
    let units: Units
    /// The exercise the dock is currently working through.
    var isFocused: Bool = false
    let onSetChecked: () -> Void
    let onComplete: () -> Void
    let onRemove: () -> Void
    var onPlateCalculator: (() -> Void)? = nil
    var onSwap: (() -> Void)? = nil
    var onToggleSuperset: SupersetAction? = nil

    struct SupersetAction {
        let label: String
        let perform: () -> Void
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                let focusStat = exercise.category.focus.primaryStat
                ZStack {
                    Circle()
                        .strokeBorder(focusStat.color.opacity(0.45), lineWidth: 1)
                    StatIcon(stat: focusStat, size: 13)
                }
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

                Text(exercise.displayName)
                    .font(RPGTheme.heading(.headline, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if exercise.supersetGroup != nil {
                    PillTag(text: "Superset", tint: RPGTheme.accent)
                        .accessibilityLabel("In a superset — rest starts after the group's last exercise")
                }

                Spacer()

                Menu {
                    if let onPlateCalculator, !exercise.isTimed {
                        Button(action: onPlateCalculator) {
                            RPGSymbolLabel("Plate Calculator", symbol: .plateCalculator)
                        }
                    }
                    if let onSwap {
                        Button(action: onSwap) {
                            RPGSymbolLabel("Swap Exercise", symbol: .exerciseSwap)
                        }
                    }
                    if let onToggleSuperset {
                        Button(action: onToggleSuperset.perform) {
                            RPGSymbolLabel(onToggleSuperset.label, symbol: .superset)
                        }
                    }
                    Button(role: .destructive, action: onRemove) {
                        Label("Remove exercise", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Exercise options")
            }

            if exercise.isTimed {
                HStack(spacing: 12) {
                    sessionField(
                        title: "Minutes",
                        accessibilityLabel: "\(exercise.displayName) duration",
                        accessibilityUnit: "minutes",
                        text: $exercise.duration
                    )
                    sessionField(
                        title: units.distanceDisplayName,
                        accessibilityLabel: "\(exercise.displayName) distance",
                        accessibilityUnit: units == .kg ? "kilometers" : "miles",
                        text: $exercise.distance
                    )
                }
            } else {
                VStack(spacing: 8) {
                    HStack {
                        Text("SET")
                            .frame(width: 44, alignment: .leading)
                        Text("REPS")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("WEIGHT (\(units.displayName.uppercased()))")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Spacer().frame(width: 44)
                    }
                    .font(RPGTheme.label(9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)

                    ForEach(Array($exercise.sets.enumerated()), id: \.element.id) { index, $set in
                        SetRow(
                            index: index + 1,
                            set: $set,
                            exerciseName: exercise.displayName,
                            units: units,
                            onChecked: onSetChecked
                        )
                    }

                    HStack {
                        Button {
                            var newSet = exercise.sets.last ?? DraftSet()
                            newSet.id = UUID()
                            newSet.done = false
                            exercise.sets.append(newSet)
                        } label: {
                            Label("Add set", systemImage: "plus")
                                .font(.caption.weight(.semibold))
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                        }

                        Spacer()

                        if exercise.sets.count > 1 {
                            Button {
                                if let last = exercise.sets.last, !last.done {
                                    exercise.sets.removeLast()
                                }
                            } label: {
                                Label("Remove", systemImage: "minus")
                                    .font(.caption.weight(.semibold))
                                    .frame(minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .disabled(exercise.sets.last?.done ?? true)
                        }
                    }
                    .foregroundColor(RPGTheme.accent)
                }
            }

            let ready = exercise.isTimed
                ? ((flexibleDouble(exercise.duration) ?? 0) > 0 || (flexibleDouble(exercise.distance) ?? 0) > 0)
                : !exercise.doneSets.isEmpty
            // Logging an exercise mid-session banks its real XP and checks
            // for records right away. Quiet until there is something to log,
            // and always secondary — the dock owns the screen's one plate.
            if ready {
                let allDone = exercise.isTimed || exercise.sets.allSatisfy { $0.done }
                Button(action: onComplete) {
                    HStack(spacing: 6) {
                        RPGSymbolIcon(symbol: .quickLog, size: 16,
                                      presentation: .compact,
                                      palette: .monochrome(RPGTheme.accent))
                        Text(exercise.isTimed ? "Log it" : (allDone ? "Log exercise" : "Log \(exercise.doneSets.count) set\(exercise.doneSets.count == 1 ? "" : "s") now"))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(RPGTheme.accent)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        Capsule()
                            .fill(RPGTheme.surface)
                            .overlay(Capsule().strokeBorder(RPGTheme.accent.opacity(allDone ? 0.7 : 0.45), lineWidth: 1))
                    )
                }
                .accessibilityHint("Logs this exercise now and banks its experience points")
            }
        }
        .rpgCard(padding: 16, accent: isFocused ? RPGTheme.accent : nil)
    }

    @ViewBuilder
    private func sessionField(
        title: String,
        accessibilityLabel: String,
        accessibilityUnit: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(RPGTheme.label(9, weight: .semibold))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .font(.body.weight(.medium))
                .monospacedDigit()
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: RPGTheme.innerRadius, style: .continuous)
                        .fill(RPGTheme.surfaceInner)
                        .overlay(
                            RoundedRectangle(cornerRadius: RPGTheme.innerRadius, style: .continuous)
                                .strokeBorder(RPGTheme.frame.opacity(RPGTheme.hairline), lineWidth: 1)
                        )
                )
                .accessibilityLabel(accessibilityLabel)
                .accessibilityValue(accessibilityFieldValue(text.wrappedValue, unit: accessibilityUnit))
        }
    }

    private func accessibilityFieldValue(_ value: String, unit: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Not entered" : "\(trimmed) \(unit)"
    }
}

/// One set row: reps, weight, and the check-off — the tap this entire
/// feature exists for.
struct SetRow: View {
    let index: Int
    @Binding var set: DraftSet
    let exerciseName: String
    let units: Units
    let onChecked: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            // Tap cycles working ↔ warm-up; long-press offers RPE too.
            Button {
                set.isWarmup.toggle()
                Haptics.tap()
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    Text(set.isWarmup ? "W" : "\(index)")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundColor(set.isWarmup ? RPGTheme.gold : (set.done ? RPGTheme.xp : .secondary))
                    if let rpe = set.rpe {
                        Text("@\(AppState.fieldNumber(rpe))")
                            .font(RPGTheme.label(9, weight: .semibold))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 44, alignment: .leading)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel((set.isWarmup
                                ? "Warm-up set. Double tap to make it a working set."
                                : "Set \(index). Double tap to mark as warm-up.")
                                + (set.rpe.map { " RPE \(AppState.fieldNumber($0))." } ?? ""))
            .contextMenu {
                Button {
                    set.isWarmup.toggle()
                } label: {
                    RPGSymbolLabel(
                        set.isWarmup ? "Make Working Set" : "Make Warm-up Set",
                        symbol: set.isWarmup ? .setWorking : .setWarmup
                    )
                }
                Menu("RPE (effort)") {
                    Button("None") { set.rpe = nil }
                    ForEach([6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0], id: \.self) { value in
                        Button("RPE \(AppState.fieldNumber(value))") { set.rpe = value }
                    }
                }
            }

            TextField("8", text: $set.reps)
                .keyboardType(.numberPad)
                .disabled(set.done)
                .modifier(SetFieldStyle(done: set.done))
                .accessibilityLabel("\(exerciseName), set \(index), repetitions")
                .accessibilityValue(set.reps.isEmpty ? "Not entered" : set.reps)

            TextField("—", text: $set.weight)
                .keyboardType(.decimalPad)
                .disabled(set.done)
                .modifier(SetFieldStyle(done: set.done))
                .accessibilityLabel("\(exerciseName), set \(index), weight")
                .accessibilityValue(
                    set.weight.isEmpty
                        ? "Not entered"
                        : "\(set.weight) \(units == .kg ? "kilograms" : "pounds")"
                )

            Button {
                guard !set.done else {
                    set.done = false
                    return
                }
                guard Int(set.reps) ?? 0 > 0 else { return }
                withAnimation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.6)) {
                    set.done = true
                }
                onChecked()
            } label: {
                Image(systemName: set.done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(set.done ? RPGTheme.xp : RPGTheme.frame)
                    .scaleEffect(set.done ? 1.1 : 1.0)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(set.done ? "Set \(index) complete. Double tap to uncheck." : "Complete set \(index)")
        }
    }
}

private struct SetFieldStyle: ViewModifier {
    let done: Bool
    func body(content: Content) -> some View {
        content
            .font(.body.weight(.medium))
            .monospacedDigit()
            .multilineTextAlignment(.center)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(done ? RPGTheme.xp.opacity(0.10) : RPGTheme.surfaceInner)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(done ? RPGTheme.xp.opacity(0.35) : RPGTheme.frame.opacity(0.3), lineWidth: 1)
                    )
            )
            .opacity(done ? 0.75 : 1)
    }
}

// MARK: - Exercise picker

struct ExercisePickerSheet: View {
    var displayUnits: Units? = nil
    /// Titles the sheet honestly when it substitutes rather than adds.
    var swapMode: Bool = false
    let onPick: (ExerciseSelection) -> Void
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var showCreate = false
    @State private var showAllEquipment = false

    private var customMatches: [CustomExercise] {
        state.user.customExercises.filter {
            (showAllEquipment || state.isAvailable($0)) &&
            (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search))
        }
    }

    private var groups: [(focus: FocusGroup, exercises: [ExerciseCategory])] {
        FocusGroup.allCases.compactMap { focus in
            let list = ExerciseCategory.allCases.filter {
                $0.focus == focus &&
                (showAllEquipment || state.isAvailable($0)) &&
                (search.isEmpty || $0.displayName.localizedCaseInsensitiveContains(search))
            }
            return list.isEmpty ? nil : (focus, list)
        }
    }

    /// Exercises the equipment filter is currently hiding.
    private var hiddenByEquipment: Int {
        guard !showAllEquipment else { return 0 }
        let builtIns = ExerciseCategory.allCases.filter { !state.isAvailable($0) }.count
        let customs = state.user.customExercises.filter { !state.isAvailable($0) }.count
        return builtIns + customs
    }

    var body: some View {
        NavigationStack {
            List {
                if !customMatches.isEmpty {
                    Section {
                        ForEach(customMatches) { custom in
                            pickRow(for: ExerciseSelection(custom: custom),
                                    caption: ghostLine(for: ExerciseSelection(custom: custom))
                                        ?? "Counts as \(custom.basedOn.displayName)")
                                .contextMenu {
                                    Button(role: .destructive) {
                                        state.deleteCustomExercise(custom.id)
                                    } label: {
                                        Label("Delete Exercise", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        Text("Your Exercises")
                    }
                }

                ForEach(groups, id: \.focus) { group in
                    Section {
                        ForEach(group.exercises) { category in
                            pickRow(for: ExerciseSelection(category: category),
                                    caption: ghostLine(for: ExerciseSelection(category: category)))
                        }
                    } header: {
                        Text(group.focus.displayName)
                    }
                }

                if hiddenByEquipment > 0 {
                    Section {
                        Button {
                            withAnimation { showAllEquipment = true }
                        } label: {
                            Text("Show \(hiddenByEquipment) hidden by your equipment settings")
                                .font(.footnote.weight(.medium))
                                .foregroundColor(RPGTheme.accent)
                        }
                        .listRowBackground(RPGTheme.surface)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .searchable(text: $search, prompt: "Search exercises")
            .navigationTitle(swapMode ? "Swap Exercise" : "Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showCreate = true
                    } label: {
                        Label("New Exercise", systemImage: "plus")
                    }
                    .accessibilityLabel("Create a custom exercise")
                }
            }
            .sheet(isPresented: $showCreate) {
                CreateExerciseSheet { created in
                    onPick(ExerciseSelection(custom: created))
                    dismiss()
                }
                .environmentObject(state)
            }
        }
    }

    @ViewBuilder
    private func pickRow(for selection: ExerciseSelection, caption: String?) -> some View {
        Button {
            Haptics.tap()
            onPick(selection)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(selection.category.focus.primaryStat.color.opacity(0.45), lineWidth: 1)
                    StatIcon(stat: selection.category.focus.primaryStat, size: 12)
                }
                .frame(width: 26, height: 26)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(selection.displayName)
                        .foregroundColor(.primary)
                    if let caption {
                        Text(caption)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "plus.circle")
                    .foregroundColor(RPGTheme.accent)
                    .accessibilityHidden(true)
            }
        }
        .listRowBackground(RPGTheme.surface)
    }

    private func ghostLine(for selection: ExerciseSelection) -> String? {
        guard let last = state.lastEntry(category: selection.category,
                                         customID: selection.customExerciseID) else { return nil }
        var parts: [String] = []
        if let reps = last.reps {
            let sets = max(1, last.sets ?? 1)
            if let weight = last.weight, weight > 0 {
                let units = displayUnits ?? state.user.units
                parts.append("\(sets)×\(reps) @ \(String(format: "%.1f", units.fromKg(weight))) \(units.displayName)")
            } else {
                parts.append("\(sets)×\(reps)")
            }
        }
        if let duration = last.durationMinutes, duration > 0 { parts.append(String(format: "%.0f min", duration)) }
        guard !parts.isEmpty else { return nil }
        return "Last: " + parts.joined(separator: " · ")
    }
}
