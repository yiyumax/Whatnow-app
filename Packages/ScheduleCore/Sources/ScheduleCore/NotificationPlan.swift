import Foundation

/// 一則每週重複的「行程開始」通知。
public struct PlannedNotification: Equatable, Sendable {
    /// 0 = 星期日 … 6 = 星期六。
    public var weekday: Int
    /// 開始時間（分鐘）。
    public var minute: Int
    public var end: Int
    public var title: String
}

public struct NotificationPlan: Equatable, Sendable {
    /// iOS 同時最多只能排 64 個本機通知。
    public static let systemLimit = 64

    public var items: [PlannedNotification]
    /// 因為超過上限而沒排進去的數量。
    public var dropped: Int

    /// 每個行程開始時一則通知（空檔不通知）。
    /// 跨午夜拆成兩段的行程，隔天 00:00 那一段不再通知一次。
    public static func make(for schedule: WeekSchedule, limit: Int = systemLimit) -> NotificationPlan {
        var all: [PlannedNotification] = []
        for w in 0..<7 {
            let previous = schedule.days[(w + 6) % 7]
            for slot in schedule.days[w].sorted(by: { $0.start < $1.start }) where slot.end > slot.start {
                if slot.start == 0, previous.contains(where: { $0.end == 1440 && $0.title == slot.title }) {
                    continue
                }
                all.append(PlannedNotification(weekday: w, minute: slot.start, end: slot.end, title: slot.title))
            }
        }
        let kept = Array(all.prefix(max(0, limit)))
        return NotificationPlan(items: kept, dropped: all.count - kept.count)
    }
}
