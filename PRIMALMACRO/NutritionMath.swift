import Foundation

// Adult estimates only. Users aged 13–17 get diary-only nutrition tracking,
// never the adult BMR calculator or weight-loss calorie targets.
enum NutritionMath {
    static func target(for profile: FitnessProfile) -> NutritionTarget? {
        guard profile.isAdult,
              let weightValue = profile.weightKg,
              let heightValue = profile.heightCm,
              let formulaSex = profile.formulaSex else { return nil }
        let weight = max(30, min(400, weightValue))
        let height = max(120, min(240, heightValue))
        let age = max(18, min(100, profile.age))

        let sexAdjustment = formulaSex == .male ? 5.0 : -161.0
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
