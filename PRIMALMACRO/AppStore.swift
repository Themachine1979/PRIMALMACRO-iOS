import Foundation
import Combine

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var data: AppData
    @Published var persistenceError: String?

    init() {
        do {
            let url = try Self.storageURL()
            let existing = try Data(contentsOf: url)
            data = try JSONDecoder().decode(AppData.self, from: existing)
        } catch {
            data = AppData()
        }
    }

    var profile: FitnessProfile? { data.profile }
    var targets: NutritionTarget? { data.profile.flatMap(NutritionMath.target(for:)) }
    var foods: [FoodEntry] { data.foods }
    var weights: [WeightEntry] { data.weights.sorted { $0.date < $1.date } }

    func foods(on date: Date) -> [FoodEntry] {
        data.foods.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date > $1.date }
    }

    func total(on date: Date) -> (calories: Int, protein: Double, carbs: Double, fat: Double) {
        let meals = foods(on: date)
        return (meals.reduce(0) { $0 + $1.calories },
                meals.reduce(0) { $0 + $1.proteinG },
                meals.reduce(0) { $0 + $1.carbsG },
                meals.reduce(0) { $0 + $1.fatG })
    }

    func saveProfile(_ profile: FitnessProfile) {
        data.profile = profile
        if profile.isAdult, let kg = profile.weightKg, data.weights.isEmpty {
            data.weights = [WeightEntry(kg: kg)]
        }
        persist()
    }

    func addFood(_ food: FoodEntry) {
        data.foods.append(food)
        persist()
    }

    func deleteFood(id: UUID) {
        data.foods.removeAll { $0.id == id }
        persist()
    }

    func addWeight(_ kg: Double) {
        guard data.profile?.isAdult == true else { return }
        data.weights.append(WeightEntry(kg: kg))
        data.profile?.weightKg = kg
        persist()
    }

    func clearAllData() {
        data = AppData()
        persist()
    }

    private func persist() {
        do {
            let url = try Self.storageURL()
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
            persistenceError = nil
        } catch {
            persistenceError = "Could not save locally: \(error.localizedDescription)"
        }
    }

    private static func storageURL() throws -> URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("primalmacro-data.json")
    }
}
