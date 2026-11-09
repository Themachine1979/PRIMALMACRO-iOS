import Foundation
import Combine
import CryptoKit

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var data: AppData
    @Published var persistenceError: String?

    private var currentAccountSubject: String?

    init() {
        // Never show another member's on-device diary before authentication.
        data = AppData()
    }

    func activateAccount(_ subject: String?) {
        guard subject != currentAccountSubject else { return }
        currentAccountSubject = subject
        guard let subject else {
            data = AppData()
            return
        }
        do {
            let destination = try Self.storageURL(for: subject)
            if FileManager.default.fileExists(atPath: destination.path) {
                data = try JSONDecoder().decode(AppData.self, from: Data(contentsOf: destination))
            } else if subject == UserDefaults.standard.string(forKey: "primalmacro.apple.user.id") {
                // One-time migration of pre-email-release data for existing Apple
                // members only. Never migrate someone's diary into an email account.
                let oldURL = try Self.legacyStorageURL()
                if FileManager.default.fileExists(atPath: oldURL.path) {
                    let existing = try Data(contentsOf: oldURL)
                    let migrated = try JSONDecoder().decode(AppData.self, from: existing)
                    try existing.write(to: destination, options: [.atomic, .completeFileProtectionUnlessOpen])
                    try FileManager.default.removeItem(at: oldURL)
                    data = migrated
                } else {
                    data = AppData()
                }
            } else {
                data = AppData()
            }
            persistenceError = nil
        } catch {
            data = AppData()
            persistenceError = "Couldn't load your diary securely. No data has been overwritten."
        }
    }

    var profile: FitnessProfile? { data.profile }
    var targets: NutritionTarget? { data.profile.map(NutritionMath.target(for:)) }
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
        if data.weights.isEmpty {
            data.weights = [WeightEntry(kg: profile.weightKg)]
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
        data.weights.append(WeightEntry(kg: kg))
        if data.profile != nil { data.profile?.weightKg = kg }
        persist()
    }

    func clearAllData() {
        data = AppData()
        persist()
    }

    private func persist() {
        do {
            guard let subject = currentAccountSubject else { return }
            let url = try Self.storageURL(for: subject)
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
            persistenceError = nil
        } catch {
            persistenceError = "Could not save locally: \(error.localizedDescription)"
        }
    }

    private static func storageFolder() throws -> URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private static func legacyStorageURL() throws -> URL {
        try storageFolder().appendingPathComponent("primalmacro-data.json")
    }

    private static func storageURL(for subject: String) throws -> URL {
        let digest = SHA256.hash(data: Data(subject.utf8))
            .map { String(format: "%02x", $0) }.joined()
        return try storageFolder().appendingPathComponent("diary-" + digest + ".json")
    }
}
