import Foundation

/// 顯示用的文字。
public enum Labels {
    static let weekdayNames = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]
    static let shortWeekdayNames = ["日", "一", "二", "三", "四", "五", "六"]

    public static func weekdayName(_ weekday: Int) -> String {
        weekdayNames[((weekday % 7) + 7) % 7]
    }

    public static func shortWeekdayName(_ weekday: Int) -> String {
        shortWeekdayNames[((weekday % 7) + 7) % 7]
    }

    /// 時鐘時間 "HH:MM"。
    public static func clock(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return TimeOfDay.twoDigits(c.hour ?? 0) + ":" + TimeOfDay.twoDigits(c.minute ?? 0)
    }

    /// 結束時間的寫法：今天 →「15:00」；剛好今天半夜 →「24:00」；明天 →「明天 08:00」。
    public static func end(_ end: Date, relativeTo now: Date, calendar: Calendar = .current) -> String {
        let endDay = calendar.startOfDay(for: end)
        let diff = dayDifference(from: now, to: end, calendar: calendar)
        if end == endDay && diff >= 1 {
            // 剛好在午夜結束：說成前一天的 24:00。
            let previous = calendar.date(byAdding: .day, value: -1, to: endDay) ?? endDay
            return join(dayPrefix(diff - 1, date: previous, calendar: calendar), "24:00")
        }
        return join(dayPrefix(diff, date: end, calendar: calendar), clock(end, calendar: calendar))
    }

    /// 開始時間的寫法：今天 →「15:00」；明天 →「明天 08:00」。
    public static func start(_ start: Date, relativeTo now: Date, calendar: Calendar = .current) -> String {
        let diff = dayDifference(from: now, to: start, calendar: calendar)
        return join(dayPrefix(diff, date: start, calendar: calendar), clock(start, calendar: calendar))
    }

    static func dayDifference(from now: Date, to date: Date, calendar: Calendar) -> Int {
        let a = calendar.startOfDay(for: now)
        let b = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }

    static func dayPrefix(_ diff: Int, date: Date, calendar: Calendar) -> String {
        switch diff {
        case 0: return ""
        case 1: return "明天"
        case 2: return "後天"
        case -1: return "昨天"
        case 3...6: return "週" + shortWeekdayName(calendar.component(.weekday, from: date) - 1)
        default:
            let c = calendar.dateComponents([.month, .day], from: date)
            return "\(c.month ?? 0)/\(c.day ?? 0)"
        }
    }

    static func join(_ prefix: String, _ time: String) -> String {
        prefix.isEmpty ? time : prefix + " " + time
    }
}
