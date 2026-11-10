import Foundation

enum FormulaSex: String, CaseIterable, Codable, Identifiable {
    case male = "Male"
    case female = "Female"
    var id: String { rawValue }
}

enum ActivityLevel: String, CaseIterable, Codable, Identifiable {
    case sedentary = "Mostly sitting"
    case light = "Lightly active"
    case moderate = "Moderately active"
    case veryActive = "Very active"
    case athlete = "Athlete / intense training"

    var id: String { rawValue }
    var multiplier: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .veryActive: 1.725
        case .athlete: 1.9
        }
    }
}

enum FitnessGoal: String, CaseIterable, Codable, Identifiable {
    case lose = "Lose body fat"
    case maintain = "Maintain weight"
    case gain = "Build muscle"
    var id: String { rawValue }
    var subtitle: String {
        switch self {
        case .lose: "Controlled deficit • preserve muscle"
        case .maintain: "Fuel performance • stay consistent"
        case .gain: "Small surplus • support strength"
        }
    }
}

struct FitnessProfile: Codable {
    // Users 13–17 only need their age to use the food diary.
    // Optional body measurements preserve privacy and prevent placeholder
    // measurements from accidentally driving adult calorie calculations.
    var formulaSex: FormulaSex?
    var age: Int
    var heightCm: Double?
    var weightKg: Double?
    var activity: ActivityLevel
    var goal: FitnessGoal
    var targetWeightKg: Double?

    var isTeen: Bool { (13..<18).contains(age) }
    var isAdult: Bool { age >= 18 }
}

struct NutritionTarget {
    var calories: Int
    var proteinG: Int
    var carbsG: Int
    var fatG: Int
    var bmr: Int
    var maintenanceCalories: Int
}

enum Meal: String, CaseIterable, Codable, Identifiable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snacks = "Snacks"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .dinner: "moon.stars.fill"
        case .snacks: "carrot.fill"
        }
    }
}

struct FoodEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var meal: Meal
    var name: String
    var serving: String
    var calories: Int
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var fiberG: Double
    var source: String
}

struct WeightEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var kg: Double
}

struct FastSession: Identifiable, Codable {
    var id = UUID()
    var startedAt = Date()
    var targetHours: Int
    var endedAt: Date? = nil

    var goalDate: Date { startedAt.addingTimeInterval(TimeInterval(targetHours) * 3600) }
    var duration: TimeInterval { max(0, (endedAt ?? Date()).timeIntervalSince(startedAt)) }
    var completedGoal: Bool { endedAt.map { $0 >= goalDate } ?? false }
}

struct AppData: Codable {
    var profile: FitnessProfile?
    var foods: [FoodEntry] = []
    var weights: [WeightEntry] = []
    // Optional fields preserve decoding of diaries saved by older app versions.
    var fastingSessions: [FastSession]? = nil
    var fastingRemindersEnabled: Bool? = nil
}

enum ScanMode: String, CaseIterable, Identifiable {
    case food = "Food"
    case menu = "Menu"
    case packaging = "Packaging"
    var id: String { rawValue }
    var explanation: String {
        switch self {
        case .food: "Estimate a meal from a photo. Portions are approximations."
        case .menu: "Read menu items and choose the dish you plan to eat."
        case .packaging: "Read a nutrition label and its stated serving size."
        }
    }
}

struct FoodEstimate: Identifiable, Codable {
    var id = UUID()
    var name: String
    var serving: String
    var calories: Int
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var fiberG: Double
    var confidence: String
    var notes: String

    enum CodingKeys: String, CodingKey {
        case name, serving, calories, proteinG, carbsG, fatG, fiberG, confidence, notes
    }
}

struct FoodScanResponse: Decodable {
    var foods: [FoodEstimate]
    var disclaimer: String
}
