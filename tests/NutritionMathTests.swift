import Foundation

@main
struct NutritionTests {
    static func main() {
        let p = FitnessProfile(formulaSex: .male, age: 32, heightCm: 178, weightKg: 82,
                               activity: .moderate, goal: .maintain, targetWeightKg: nil)
        let baseline = NutritionMath.target(for: p)
        precondition(baseline.bmr == 1778, "BMR formula regression")
        precondition(baseline.maintenanceCalories == 2755, "Maintenance regression")
        precondition(baseline.calories == 2750, "Rounded daily maintenance regression")
        precondition(baseline.proteinG > 0 && baseline.carbsG > 0 && baseline.fatG > 0)

        var cutting = p; cutting.goal = .lose
        var gaining = p; gaining.goal = .gain
        let cut = NutritionMath.target(for: cutting)
        let gain = NutritionMath.target(for: gaining)
        precondition(cut.calories < baseline.calories)
        precondition(gain.calories > baseline.calories)
        precondition(cut.proteinG >= baseline.proteinG)
        print("PASS: adult BMR, maintenance, cut/gain direction, non-negative macros")
    }
}
