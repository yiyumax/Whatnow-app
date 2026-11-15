import Foundation
import UserNotifications
import ScheduleCore

/// 行程開始時的本機通知。每個行程一則「每週重複」的通知，總數不超過 iOS 的 64 個上限。
enum NotificationScheduler {
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// 清掉舊的再全部重排。回傳因為超過上限而沒排進去的數量。
    static func reschedule(for schedule: WeekSchedule) async -> Int {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let plan = NotificationPlan.make(for: schedule)
        for item in plan.items {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = "\(TimeOfDay.format(item.minute)) – \(TimeOfDay.format(item.end))"
            content.sound = .default

            var components = DateComponents()
            components.weekday = item.weekday + 1      // DateComponents：1 = 星期日
            components.hour = item.minute / 60
            components.minute = item.minute % 60

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "slot-\(item.weekday)-\(item.minute)",
                                                content: content,
                                                trigger: trigger)
            try? await center.add(request)
        }
        return plan.dropped
    }
}
