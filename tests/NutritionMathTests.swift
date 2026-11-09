import Foundation

@main
struct NutritionTests {
    static func main() {
        let p = FitnessProfile(formulaSex: .male, age: 32, heightCm: 178, weightKg: 82,
                               activity: .moderate, goal: .maintain, targetWeightKg: nil)
        guard let baseline = NutritionMath.target(for: p) else {
            fatalError("Adult plan should be available")
        }
        precondition(baseline.bmr == 1778, "BMR formula regression")
        precondition(baseline.maintenanceCalories == 2755, "Maintenance regression")
        precondition(baseline.calories == 2750, "Rounded daily maintenance regression")
        precondition(baseline.proteinG > 0 && baseline.carbsG > 0 && baseline.fatG > 0)

        var cutting = p; cutting.goal = .lose
        var gaining = p; gaining.goal = .gain
        guard let cut = NutritionMath.target(for: cutting),
              let gain = NutritionMath.target(for: gaining) else {
            fatalError("Adult plan variation should be available")
        }
        precondition(cut.calories < baseline.calories)
        precondition(gain.calories > baseline.calories)
        precondition(cut.proteinG >= baseline.proteinG)

        let teen = FitnessProfile(formulaSex: nil, age: 13, heightCm: nil,
                                  weightKg: nil, activity: .moderate,
                                  goal: .maintain, targetWeightKg: nil)
        precondition(teen.isTeen)
        precondition(NutritionMath.target(for: teen) == nil,
                     "Under-18 user must not receive adult calorie targets")
        var seventeen = teen
        seventeen.age = 17
        precondition(NutritionMath.target(for: seventeen) == nil,
                     "17-year-old must not receive adult targets")
        var eighteenth = p
        eighteenth.age = 18
        precondition(NutritionMath.target(for: eighteenth) != nil,
                     "18-year-old adult plan should be available")
        print("PASS: adult BMR/maintenance, adult goals, no teen calorie targets")
    }
}
