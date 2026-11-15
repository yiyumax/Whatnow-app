import Foundation

/// 時間軸上的一段（已換算成實際日期時間）。空檔也是一段。
public struct Segment: Equatable, Sendable, Identifiable {
    public var start: Date
    public var end: Date
    public var title: String
    public var isGap: Bool

    public var id: Date { start }

    public init(start: Date, end: Date, title: String, isGap: Bool) {
        self.start = start
        self.end = end
        self.title = title
        self.isGap = isGap
    }
}

/// 某個時間點要顯示的全部內容。
public struct Snapshot: Equatable, Sendable {
    /// 這份內容從什麼時候開始有效。
    public var date: Date
    /// 現在的時段。
    public var current: Segment
    /// 接下來的時段（依時間排序，最多 8 個）。
    public var upcoming: [Segment]
    /// 和「今天」有交集的所有時段（跨午夜合併後的結果）。
    public var today: [Segment]

    public var next: Segment? { upcoming.first }

    /// 今天還沒結束的時段（含現在這一段）。
    public var remainingToday: [Segment] { today.filter { $0.end > date } }
}

public struct ScheduleTimeline: Equatable, Sendable {
    public var entries: [Snapshot]
    /// 建議的重新載入時間（最後一個 entry 開始的時候）。
    public var reloadDate: Date
}

public struct ScheduleEngine: Sendable {
    public let schedule: WeekSchedule
    public let calendar: Calendar

    /// 往回看幾天、往後看幾天來建立時間軸。
    static let lookBehindDays = 7
    static let lookAheadDays = 9

    public init(schedule: WeekSchedule, calendar: Calendar = .current) {
        self.schedule = schedule
        self.calendar = calendar
    }

    // MARK: - 日期工具

    /// 0 = 星期日 … 6 = 星期六。
    public func weekdayIndex(of date: Date) -> Int {
        calendar.component(.weekday, from: date) - 1
    }

    public func startOfNextDay(after date: Date) -> Date {
        let dayStart = calendar.startOfDay(for: date)
        if let next = calendar.date(byAdding: .day, value: 1, to: dayStart) {
            return calendar.startOfDay(for: next)
        }
        return dayStart.addingTimeInterval(86400)
    }

    func date(minutes: Int, onDayStarting dayStart: Date) -> Date {
        if minutes <= 0 { return dayStart }
        if minutes >= 1440 { return startOfNextDay(after: dayStart) }
        if let d = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: dayStart) {
            return d
        }
        return dayStart.addingTimeInterval(Double(minutes) * 60)
    }

    // MARK: - 補空檔

    /// 一天的完整時段（從 00:00 到 24:00，沒排到的地方補上空檔），尚未做跨午夜合併。
    public func daySegments(forDayContaining date: Date) -> [Segment] {
        let dayStart = calendar.startOfDay(for: date)
        let weekday = weekdayIndex(of: dayStart)
        let gapTitle = schedule.gapName(weekday)
        let slots = schedule.days[weekday]
            .filter { $0.end > $0.start }
            .sorted { ($0.start, $0.end) < ($1.start, $1.end) }

        var result: [Segment] = []
        func add(_ from: Int, _ to: Int, _ title: String, _ isGap: Bool) {
            let s = self.date(minutes: from, onDayStarting: dayStart)
            let e = self.date(minutes: to, onDayStarting: dayStart)
            guard e > s else { return }
            result.append(Segment(start: s, end: e, title: title, isGap: isGap))
        }

        var cursor = 0
        for slot in slots {
            let from = max(slot.start, cursor)   // 防呆：資料若有重疊，後面的讓位
            let to = min(slot.end, 1440)
            guard to > from else { continue }
            if from > cursor { add(cursor, from, gapTitle, true) }
            add(from, to, slot.title, false)
            cursor = to
        }
        if cursor < 1440 { add(cursor, 1440, gapTitle, true) }
        return result
    }

    // MARK: - 跨午夜合併

    /// 從某一天開始、連續幾天的時段。
    /// 在午夜交界處，前後兩段名稱相同且種類相同（都是空檔，或都是行程）就合併成一段。
    public func segments(fromDayContaining date: Date, days: Int) -> [Segment] {
        var result: [Segment] = []
        var dayStart = calendar.startOfDay(for: date)
        for _ in 0..<max(0, days) {
            for seg in daySegments(forDayContaining: dayStart) {
                if let last = result.last,
                   seg.start == dayStart,
                   last.end == seg.start,
                   last.title == seg.title,
                   last.isGap == seg.isGap {
                    result[result.count - 1].end = seg.end
                } else {
                    result.append(seg)
                }
            }
            dayStart = startOfNextDay(after: dayStart)
        }
        return result
    }

    func window(around now: Date) -> [Segment] {
        let today = calendar.startOfDay(for: now)
        let first = calendar.date(byAdding: .day, value: -Self.lookBehindDays, to: today) ?? today
        return segments(fromDayContaining: first, days: Self.lookBehindDays + Self.lookAheadDays)
    }

    // MARK: - 目前 / 下一個

    public func snapshot(at now: Date) -> Snapshot {
        snapshot(at: now, in: window(around: now))
    }

    func snapshot(at date: Date, in segments: [Segment]) -> Snapshot {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = startOfNextDay(after: date)
        let today = segments.filter { $0.end > dayStart && $0.start < dayEnd }

        if let index = segments.firstIndex(where: { $0.start <= date && date < $0.end }) {
            return Snapshot(date: date,
                            current: segments[index],
                            upcoming: Array(segments[(index + 1)...].prefix(8)),
                            today: today)
        }
        // 理論上不會發生（時間軸涵蓋前後好幾天）；保底給一段到今天結束的空檔。
        let fallback = Segment(start: dayStart, end: dayEnd,
                               title: schedule.gapName(weekdayIndex(of: date)), isGap: true)
        return Snapshot(date: date, current: fallback,
                        upcoming: Array(segments.filter { $0.start >= dayEnd }.prefix(8)),
                        today: today.isEmpty ? [fallback] : today)
    }

    // MARK: - Timeline

    /// 產生從 `now` 起、未來 `hours` 小時內的所有 entry：
    /// 第一個在 `now`，之後每個時段邊界一個，每個午夜也一個（「今天」和「明天」的字樣要換）。
    public func timeline(from now: Date, hours: Int = 48, maxEntries: Int = 90) -> ScheduleTimeline {
        let segments = window(around: now)
        let limit = now.addingTimeInterval(Double(max(1, hours)) * 3600)

        var dates: Set<Date> = [now]
        for seg in segments where seg.start > now && seg.start <= limit {
            dates.insert(seg.start)
        }
        var midnight = startOfNextDay(after: now)
        while midnight <= limit {
            dates.insert(midnight)
            midnight = startOfNextDay(after: midnight)
        }

        let ordered = dates.sorted().prefix(max(1, maxEntries))
        let entries = ordered.map { snapshot(at: $0, in: segments) }

        let reload: Date
        if entries.count > 1, let last = entries.last {
            reload = last.date
        } else {
            reload = min(entries[0].current.end, now.addingTimeInterval(12 * 3600))
        }
        return ScheduleTimeline(entries: entries, reloadDate: reload)
    }
}
