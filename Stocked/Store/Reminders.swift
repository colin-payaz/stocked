import Foundation
import UserNotifications

/// Local notifications the day before (or the morning of) an item's best-before date.
enum Reminders {
    private static let prefix = "best-before-"

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private struct Reminder {
        let id: String
        let body: String
        let fireDate: Date
    }

    static func sync(_ items: [Item]) {
        let calendar = Calendar.current
        let now = Date.now
        var reminders: [Reminder] = []

        for item in items where item.inStock {
            guard let bestBefore = item.bestBefore, let uuid = item.uuid else { continue }
            let day = calendar.startOfDay(for: bestBefore)
            guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: day),
                  let eve = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: dayBefore),
                  let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day)
            else { continue }

            if eve > now {
                reminders.append(Reminder(id: prefix + uuid.uuidString, body: "\(item.displayName) is best before tomorrow.", fireDate: eve))
            } else if morning > now {
                reminders.append(Reminder(id: prefix + uuid.uuidString, body: "\(item.displayName) is best before today.", fireDate: morning))
            }
        }
        // iOS keeps at most 64 pending notifications per app.
        let upcoming = Array(reminders.sorted { $0.fireDate < $1.fireDate }.prefix(60))

        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let old = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: old)
            for reminder in upcoming {
                let content = UNMutableNotificationContent()
                content.title = "Use Soon"
                content.body = reminder.body
                content.sound = .default
                let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
                center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
            }
        }
    }
}
