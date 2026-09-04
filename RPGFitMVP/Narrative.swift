import Foundation

// MARK: - Narrative voice
//
// The verification research was blunt: story and character voice retain
// people that stat math never reaches (Ascended, Zombies Run), and it costs
// a solo dev nothing but words. This file is the app's entire "writers'
// room": small authored tables, deterministically picked per quest so the
// same quest keeps the same line (stable via UUID hash, no Date/random —
// which also keeps SwiftUI renders pure).

enum QuestVoice {
    /// A flavor line for a quest card. Stable per quest id.
    static func flavor(for challenge: Challenge) -> String {
        if challenge.isComeback ?? false {
            return "The campfire is lit. The gear is where you left it."
        }
        let variants = lines(for: challenge.targetCategory,
                             isVariety: challenge.unit == .exercises,
                             isWeekly: challenge.type == .weekly)
        let index = abs(challenge.id.uuidString.hashValue) % variants.count
        return variants[index]
    }

    private static func lines(for focus: FocusGroup, isVariety: Bool, isWeekly: Bool) -> [String] {
        if isWeekly {
            switch focus {
            case .strength:
                return ["Seven days. One heavier bar.",
                        "The week remembers every plate you add.",
                        "Mastery is a week of unglamorous sets."]
            case .hypertrophy:
                return ["Build the frame the legend will wear.",
                        "Brick by brick, rep by rep.",
                        "Growth is quiet work. Do it loudly anyway."]
            case .endurance:
                return ["The long road only ends if you stop.",
                        "Outlast the week. Then outlast the next.",
                        "Every mile is a page of the chronicle."]
            case .explosive:
                return ["Strike quickly, all week long.",
                        "Speed is strength that learned to dance.",
                        "Seven days to sharpen the spark."]
            case .mobility:
                return ["Suppleness is armor that never rusts.",
                        "The oak breaks; the willow trains mobility.",
                        "Recover like it's part of the fight — it is."]
            case .bodyweight:
                return ["Your body is the only weapon you always carry.",
                        "Master the self before the iron.",
                        "No barbell. No excuses. No limits."]
            }
        }
        if isVariety {
            switch focus {
            case .strength:
                return ["A warrior knows more than one blade.",
                        "Vary the attack; surprise the plateau.",
                        "Different lifts, same fire."]
            case .hypertrophy:
                return ["Sculpt from every angle.",
                        "The chisel moves; the marble grows.",
                        "New movements wake sleeping muscle."]
            case .endurance:
                return ["Many roads, one traveler.",
                        "Cross-train like the map depends on it.",
                        "The heart doesn't care which road — only that you take it."]
            case .explosive:
                return ["Lightning never strikes the same way twice.",
                        "Mix the explosions. Keep the powder dry.",
                        "Agility is variety at full speed."]
            case .mobility:
                return ["Bend in new directions today.",
                        "Every joint deserves a word in the story.",
                        "Flow through forms like water through stone."]
            case .bodyweight:
                return ["New shapes for an old instrument.",
                        "The calisthenic arts are many. Learn two more.",
                        "Skill stacks on skill."]
            }
        }
        switch focus {
        case .strength:
            return ["The bar is patient. It will wait — briefly.",
                    "Pick up heavy things. Put down doubt.",
                    "Strength is a promise you keep to yourself."]
        case .hypertrophy:
            return ["Volume today, silhouette tomorrow.",
                    "Feed the forge its sets.",
                    "The pump is the poem; the sets are the meter."]
        case .endurance:
            return ["One breath at a time, adventurer.",
                    "The horizon moves for those who keep moving.",
                    "Stamina is courage, sustained."]
        case .explosive:
            return ["Explode like the floor owes you money.",
                    "Fast twitch, faster spirit.",
                    "Jump first. Gravity will negotiate."]
        case .mobility:
            return ["Stretch now — swagger later.",
                    "Tomorrow's lifts are built in today's recovery.",
                    "Even legends touch their toes."]
        case .bodyweight:
            return ["Just you versus yesterday's you.",
                    "Gravity is the oldest training partner.",
                    "Own every inch of the movement."]
        }
    }
}
