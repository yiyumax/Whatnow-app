import Foundation

/// 一天之中的一個時段。時間用「從 00:00 起算的分鐘數」表示，範圍 0...1440（1440 = 24:00）。
public struct Slot: Equatable, Hashable, Sendable {
    public var start: Int
    public var end: Int
    public var title: String

    public init(start: Int, end: Int, title: String) {
        self.start = start
        self.end = end
        self.title = title
    }
}

/// 每週時間表。索引 0 = 星期日，1 = 星期一 … 6 = 星期六（與 Scriptable 版本相同）。
public struct WeekSchedule: Equatable, Sendable {
    public static let defaultGapNames = ["休息", "自由時間", "自由時間", "自由時間", "自由時間", "自由時間", "自由時間"]

    /// 每天的空檔名稱，固定 7 個。
    public var gap: [String]
    /// 每天的時段，固定 7 天。
    public var days: [[Slot]]

    public init(gap: [String] = WeekSchedule.defaultGapNames,
                days: [[Slot]] = Array(repeating: [], count: 7)) {
        var g = Array(gap.prefix(7))
        while g.count < 7 { g.append(WeekSchedule.defaultGapNames[g.count]) }
        var d = Array(days.prefix(7))
        while d.count < 7 { d.append([]) }
        self.gap = g
        self.days = d
    }

    /// 該天的空檔名稱；空白時退回預設值。
    public func gapName(_ weekday: Int) -> String {
        let name = gap[weekday].trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? WeekSchedule.defaultGapNames[weekday] : name
    }

    /// 把每天的時段依開始時間排序。
    public mutating func sortDays() {
        for i in days.indices {
            days[i].sort { ($0.start, $0.end) < ($1.start, $1.end) }
        }
    }

    public var totalSlotCount: Int { days.reduce(0) { $0 + $1.count } }
}

/// "HH:MM" 字串與分鐘數互轉。
public enum TimeOfDay {
    /// 解析 "8:00"、"08:00"、"24:00"。不合法回傳 nil。
    public static func parse(_ text: String) -> Int? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "：", with: ":")
        let parts = cleaned.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        guard (0...24).contains(h), (0...59).contains(m) else { return nil }
        if h == 24 && m != 0 { return nil }
        return h * 60 + m
    }

    public static func format(_ minutes: Int) -> String {
        let m = max(0, min(1440, minutes))
        return twoDigits(m / 60) + ":" + twoDigits(m % 60)
    }

    static func twoDigits(_ n: Int) -> String {
        n < 10 ? "0\(n)" : "\(n)"
    }
}
