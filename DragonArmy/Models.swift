import Foundation
import SwiftData

enum DragonStage: String, Codable, CaseIterable {
    case hatchling
    case fledgling
    case guardian

    var title: String {
        switch self {
        case .hatchling: "Hatchling"
        case .fledgling: "Fledgling"
        case .guardian: "Guardian"
        }
    }

    var next: DragonStage? {
        switch self {
        case .hatchling: .fledgling
        case .fledgling: .guardian
        case .guardian: nil
        }
    }

    var requiredXP: Int {
        switch self {
        case .hatchling: 60
        case .fledgling: 180
        case .guardian: 0
        }
    }
}

struct DragonSpecies: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let colorHex: String
    let unlockMinutes: Int
    let description: String

    static let all: [DragonSpecies] = [
        DragonSpecies(id: "ruby", name: "Ruby", emoji: "🐉", colorHex: "E85D4A", unlockMinutes: 0, description: "A brave starter dragon with a warm heart."),
        DragonSpecies(id: "azure", name: "Azure", emoji: "💧", colorHex: "4C9ED9", unlockMinutes: 120, description: "A calm river dragon who protects quiet focus."),
        DragonSpecies(id: "moss", name: "Moss", emoji: "🌿", colorHex: "5D9B67", unlockMinutes: 300, description: "A forest dragon that helps new plants take root."),
        DragonSpecies(id: "sunstone", name: "Sunstone", emoji: "☀️", colorHex: "E5A83B", unlockMinutes: 600, description: "A bright dragon powered by consistent practice."),
        DragonSpecies(id: "moon", name: "Moon", emoji: "🌙", colorHex: "7B6BB4", unlockMinutes: 1200, description: "A patient night dragon for deep work sessions."),
        DragonSpecies(id: "crystal", name: "Crystal", emoji: "💎", colorHex: "57B9B1", unlockMinutes: 2400, description: "A rare dragon earned through a long focus journey.")
    ]
}

struct FocusMedal: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let detail: String

    static let all: [FocusMedal] = [
        FocusMedal(id: "first_focus", title: "First Flight", icon: "🪽", detail: "Complete your first focus session."),
        FocusMedal(id: "focused_hour", title: "One Clear Hour", icon: "⏳", detail: "Reach 60 focused minutes."),
        FocusMedal(id: "three_day_streak", title: "Steady Wings", icon: "🔥", detail: "Focus on three consecutive days."),
        FocusMedal(id: "deep_work", title: "Deep Work", icon: "🌌", detail: "Reach five focused hours."),
        FocusMedal(id: "dragon_friend", title: "Dragon Friend", icon: "🐉", detail: "Unlock a second dragon."),
        FocusMedal(id: "weekly_rhythm", title: "Weekly Rhythm", icon: "🌊", detail: "Complete five sessions in one week.")
    ]
}

@Model
final class Dragon {
    var name: String
    var speciesID: String = "ruby"
    var stageRawValue: String
    var experience: Int
    var colorHex: String
    var createdAt: Date

    init(name: String, speciesID: String = "ruby", stage: DragonStage = .hatchling, experience: Int = 0, colorHex: String = "E85D4A") {
        self.name = name
        self.speciesID = speciesID
        self.stageRawValue = stage.rawValue
        self.experience = experience
        self.colorHex = colorHex
        self.createdAt = .now
    }

    var stage: DragonStage {
        get { DragonStage(rawValue: stageRawValue) ?? .hatchling }
        set { stageRawValue = newValue.rawValue }
    }

    var species: DragonSpecies {
        DragonSpecies.all.first(where: { $0.id == speciesID }) ?? DragonSpecies.all[0]
    }

    var progress: Double {
        guard stage.requiredXP > 0 else { return 1 }
        return min(Double(experience) / Double(stage.requiredXP), 1)
    }

    func addXP(_ amount: Int) {
        experience += amount
        if let next = stage.next, experience >= next.requiredXP {
            stage = next
        }
    }
}

@Model
final class DragonEgg {
    var speciesID: String
    var startedAt: Date
    var durationSeconds: Int
    var focusedSeconds: Int
    var hatched: Bool

    init(speciesID: String, durationSeconds: Int = 60 * 60) {
        self.speciesID = speciesID
        self.startedAt = .now
        self.durationSeconds = durationSeconds
        self.focusedSeconds = 0
        self.hatched = false
    }

    var species: DragonSpecies {
        DragonSpecies.all.first(where: { $0.id == speciesID }) ?? DragonSpecies.all[0]
    }

    var progress: Double {
        guard durationSeconds > 0 else { return 1 }
        return min(Double(focusedSeconds) / Double(durationSeconds), 1)
    }
}

@Model
final class FocusSession {
    var startedAt: Date
    var durationMinutes: Int
    var completed: Bool
    var xpEarned: Int

    init(startedAt: Date = .now, durationMinutes: Int, completed: Bool = true, xpEarned: Int = 0) {
        self.startedAt = startedAt
        self.durationMinutes = durationMinutes
        self.completed = completed
        self.xpEarned = xpEarned
    }
}

@Model
final class KingdomItem {
    var kind: String
    var title: String
    var plantedAt: Date
    var growth: Double

    init(kind: String, title: String, growth: Double = 1) {
        self.kind = kind
        self.title = title
        self.plantedAt = .now
        self.growth = growth
    }
}

