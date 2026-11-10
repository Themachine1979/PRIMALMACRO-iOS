import Foundation
import Combine
import CryptoKit

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var data: AppData
    @Published var persistenceError: String?
    @Published var fastingNotificationMessage: String?

    private var currentAccountSubject: String?
    private var accountDataReadable = false

    init() {
        // Never show another member's on-device diary before authentication.
        data = AppData()
    }

    func activateAccount(_ subject: String?) {
        guard subject != currentAccountSubject else { return }
        // Remove reminders belonging to the previous signed-in account.
        if let current = activeFast { FastReminders.cancel(for: current) }
        fastingNotificationMessage = nil
        currentAccountSubject = subject
        accountDataReadable = false
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
            accountDataReadable = true
            persistenceError = nil
            if let fast = activeFast, profile?.isAdult == true, fastingRemindersEnabled {
                Task { await FastReminders.schedule(for: fast) }
            }
        } catch {
            data = AppData()
            accountDataReadable = false
            persistenceError = "Couldn't load your diary securely. No data has been overwritten."
        }
    }

    var profile: FitnessProfile? { data.profile }
    var fastingSessions: [FastSession] { data.fastingSessions ?? [] }
    var activeFast: FastSession? { fastingSessions.last { $0.endedAt == nil } }
    var fastingRemindersEnabled: Bool { data.fastingRemindersEnabled ?? false }

    func startFast(hours: Int) {
        guard accountDataReadable, profile?.isAdult == true,
              activeFast == nil, (12...20).contains(hours) else { return }
        let fast = FastSession(targetHours: hours)
        if data.fastingSessions == nil { data.fastingSessions = [] }
        data.fastingSessions?.append(fast)
        persist()
        if fastingRemindersEnabled { Task { await FastReminders.schedule(for: fast) } }
    }

    func endFast() {
        guard profile?.isAdult == true,
              let index = data.fastingSessions?.lastIndex(where: { $0.endedAt == nil }),
              let fast = data.fastingSessions?[index] else { return }
        data.fastingSessions?[index].endedAt = Date()
        FastReminders.cancel(for: fast)
        persist()
    }

    func setFastingReminders(_ enabled: Bool) {
        guard accountDataReadable, profile?.isAdult == true else { return }
        if !enabled {
            data.fastingRemindersEnabled = false
            if let fast = activeFast { FastReminders.cancel(for: fast) }
            fastingNotificationMessage = nil
            persist()
            return
        }
        Task {
            let allowed = await FastReminders.authorize()
            data.fastingRemindersEnabled = allowed
            fastingNotificationMessage = allowed ? nil :
                "Notifications are disabled in iPhone Settings. You can still use the fasting timer."
            persist()
            if allowed, let fast = activeFast {
                await FastReminders.schedule(for: fast)
            }
        }
    }
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
        if !profile.isAdult, let index = data.fastingSessions?.lastIndex(where: { $0.endedAt == nil }),
           let fast = data.fastingSessions?[index] {
            data.fastingSessions?[index].endedAt = Date()
            FastReminders.cancel(for: fast)
        }
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
        if let fast = activeFast { FastReminders.cancel(for: fast) }
        data = AppData()
        persist()
    }

    func deleteStoredAccountData(for subject: String?) {
        guard let subject else { return }
        if currentAccountSubject == subject, let fast = activeFast {
            FastReminders.cancel(for: fast)
        }
        do {
            let url = try Self.storageURL(for: subject)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            if currentAccountSubject == subject { data = AppData() }
            persistenceError = nil
        } catch {
            persistenceError = "Account deleted, but local records couldn't be erased: \(error.localizedDescription)"
        }
    }

    private func persist() {
        do {
            guard let subject = currentAccountSubject, accountDataReadable else { return }
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
