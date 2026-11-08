import Foundation

// General-adult estimates only. They are not a diagnosis, prescription or a
// substitute for personalised advice. Young users and people with complex
// nutritional requirements should not use this calculator.
enum NutritionMath {
    static func target(for profile: FitnessProfile) -> NutritionTarget {
        let weight = max(30, min(400, profile.weightKg))
        let height = max(120, min(240, profile.heightCm))
        let age = max(18, min(100, profile.age))

        let sexAdjustment = profile.formulaSex == .male ? 5.0 : -161.0
        let bmr = (10 * weight) + (6.25 * height) - (5 * Double(age)) + sexAdjustment
        let maintenance = bmr * profile.activity.multiplier
        let adjustment: Double
        switch profile.goal {
        case .lose: adjustment = -400
        case .maintain: adjustment = 0
        case .gain: adjustment = 250
        }
        let calories = Int((max(1_200, maintenance + adjustment) / 25).rounded() * 25)
        let proteinFactor = profile.goal == .maintain ? 1.4 : 1.8
        let protein = Int((weight * proteinFactor).rounded())
        let fat = Int((Double(calories) * 0.28 / 9).rounded())
        let carbs = max(0, Int(((Double(calories) - Double(protein * 4 + fat * 9)) / 4).rounded()))

        return NutritionTarget(calories: calories,
                               proteinG: protein,
                               carbsG: carbs,
                               fatG: fat,
                               bmr: Int(bmr.rounded()),
                               maintenanceCalories: Int(maintenance.rounded()))
    }
}
