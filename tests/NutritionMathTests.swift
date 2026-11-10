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
        // Regression: older diary files have no fasting fields and must still decode.
        let legacy = AppData(profile: p, foods: [], weights: [])
        let legacyJSON = try! JSONEncoder().encode(legacy)
        let migrated = try! JSONDecoder().decode(AppData.self, from: legacyJSON)
        precondition(migrated.fastingSessions == nil, "Old diary must decode without fasting data")
        let start = Date(timeIntervalSince1970: 1000)
        let complete = FastSession(startedAt: start, targetHours: 16,
                                   endedAt: start.addingTimeInterval(16 * 3600))
        precondition(complete.completedGoal, "16-hour goal completion regression")
        precondition(complete.duration == 16 * 3600, "Completed fasting duration regression")
        let early = FastSession(startedAt: start, targetHours: 16,
                                endedAt: start.addingTimeInterval(15 * 3600))
        precondition(!early.completedGoal, "Early stop must not count as completed")
        precondition(!teen.isAdult && eighteenth.isAdult, "Fasting age gate regression")
        print("PASS: nutrition, teen safety, fasting goal and legacy diary decoding")
    }
}
