import Foundation
import UserNotifications

// Local iPhone notifications only; no server scheduler or health tracking.
enum FastReminders {
    private static func identifier(_ suffix: String, for fast: FastSession) -> String {
        "primalfast.\(fast.id.uuidString).\(suffix)"
    }

    static func authorize() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func cancel(for fast: FastSession) {
        let ids = [identifier("two-hours", for: fast), identifier("goal", for: fast)]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
    }

    static func schedule(for fast: FastSession) async {
        guard fast.endedAt == nil else { return }
        cancel(for: fast)
        let center = UNUserNotificationCenter.current()
        let twoHours = fast.goalDate.addingTimeInterval(-7200)
        let reminders: [(String, Date, String, String)] = [
            ("two-hours", twoHours, "PrimalFast: two hours remaining",
             "Your chosen fasting goal is two hours away."),
            ("goal", fast.goalDate, "PrimalFast: fasting goal completed",
             "You've reached your selected fasting time. Your eating window can begin.")
        ]
        for (suffix, delivery, title, body) in reminders {
            let delay = delivery.timeIntervalSinceNow
            guard delay > 1 else { continue }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            let request = UNNotificationRequest(identifier: identifier(suffix, for: fast),
                                                content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}
