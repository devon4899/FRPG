import SwiftUI

// MARK: - Custom exercises
//
// A custom exercise is a named movement that BEHAVES like a built-in
// category (stats, XP, duration-vs-sets, quest focus) but keeps its own
// identity in history, ghosting, routines, and charts via
// customExerciseID. Two deliberate boundaries:
//  - The XP baseline pools with the base category (fair: similar movements
//    earn similar XP).
//  - est1RM/PR records are NOT computed for customs — pooling a "Larsen
//    Press" single into the Bench Press record book would corrupt both.

struct CustomExercise: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    /// Engine behavior comes from this category.
    var basedOn: ExerciseCategory
    var createdAt: Date = Date()
}

/// What the exercise picker hands back: a built-in category, or a custom
/// exercise riding on one.
struct ExerciseSelection: Hashable, Identifiable {
    let category: ExerciseCategory
    let customExerciseID: UUID?
    let displayName: String

    var id: String { customExerciseID?.uuidString ?? category.rawValue }

    init(category: ExerciseCategory) {
        self.category = category
        self.customExerciseID = nil
        self.displayName = category.displayName
    }

    init(custom: CustomExercise) {
        self.category = custom.basedOn
        self.customExerciseID = custom.id
        self.displayName = custom.name
    }
}

extension AppState {

    @discardableResult
    func addCustomExercise(named name: String, basedOn category: ExerciseCategory) -> CustomExercise? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let exercise = CustomExercise(name: trimmed, basedOn: category)
        user.customExercises.insert(exercise, at: 0)
        save()
        return exercise
    }

    /// Removes the definition; history entries keep their logged name.
    func deleteCustomExercise(_ id: UUID) {
        user.customExercises.removeAll { $0.id == id }
        save()
    }

    func customExercise(_ id: UUID?) -> CustomExercise? {
        guard let id else { return nil }
        return user.customExercises.first { $0.id == id }
    }

    /// Most recent history entry for one exercise IDENTITY — a built-in
    /// lookup (customID nil) never matches entries logged as a custom, and
    /// vice versa.
    func lastEntry(category: ExerciseCategory, customID: UUID?) -> WorkoutEntry? {
        history.first { $0.category == category && $0.customExerciseID == customID }
    }
}

// MARK: - Create sheet

struct CreateExerciseSheet: View {
    let onCreate: (CustomExercise) -> Void
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var basedOn: ExerciseCategory = .benchPress

    private var availableBaseCategories: [ExerciseCategory] {
        ExerciseCategory.allCases.filter { state.isAvailable($0) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. Larsen Press)", text: $name)
                } header: {
                    Text("Name")
                } footer: {
                    Text("Shown everywhere this exercise appears.")
                }
                .listRowBackground(RPGTheme.surface)

                Section {
                    Picker("Counts as", selection: $basedOn) {
                        ForEach(FocusGroup.allCases) { focus in
                            Section(focus.displayName) {
                                ForEach(availableBaseCategories.filter { $0.focus == focus }) { category in
                                    Text(category.displayName).tag(category)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Behaves like")
                } footer: {
                    Text("Attributes, XP, and quest credit follow the movement it counts as. Records stay separate.")
                }
                .listRowBackground(RPGTheme.surface)
            }
            .listRowSeparatorTint(RPGTheme.frame.opacity(RPGTheme.hairline))
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .tint(RPGTheme.accent)
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        if let created = state.addCustomExercise(named: name, basedOn: basedOn) {
                            onCreate(created)
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if !state.isAvailable(basedOn), let first = availableBaseCategories.first {
                    basedOn = first
                }
            }
        }
    }
}
