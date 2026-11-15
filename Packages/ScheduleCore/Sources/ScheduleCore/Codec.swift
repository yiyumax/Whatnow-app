import Foundation

public enum ScheduleError: Error, Equatable, LocalizedError {
    case invalidJSON
    case missingDays
    case badEntry(day: Int)
    case badTime(day: Int, value: String)
    case emptyTitle(day: Int)
    case zeroLength(day: Int, title: String)
    case overlap(day: Int, first: String, second: String)

    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "這不是合法的 JSON，請確認內容完整（從 { 到 }）。"
        case .missingDays:
            return "找不到 \"days\" 欄位，格式不符。"
        case .badEntry(let day):
            return "\(Labels.weekdayName(day))有一筆資料格式不對，每筆應該是 [\"開始\",\"結束\",\"名稱\"]。"
        case .badTime(let day, let value):
            return "\(Labels.weekdayName(day))的時間「\(value)」看不懂，請用 HH:MM（例如 08:00、24:00）。"
        case .emptyTitle(let day):
            return "\(Labels.weekdayName(day))有一個時段沒有名稱。"
        case .zeroLength(let day, let title):
            return "\(Labels.weekdayName(day))的「\(title)」開始和結束時間相同。"
        case .overlap(let day, let first, let second):
            return "\(Labels.weekdayName(day))的「\(first)」和「\(second)」時間重疊。"
        }
    }
}

/// 讀寫與 Scriptable 版本相容的 JSON：
/// {"version":1,"gap":{"0":"休息",…},"days":{"1":[["08:00","15:00","上課"],…],…}}
public enum ScheduleCodec {
    public static func decode(text: String) throws -> WeekSchedule {
        // 從備忘錄等地方貼上時，引號常被換成彎引號。
        let normalized = text
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
        return try decode(Data(normalized.utf8))
    }

    public static func decode(_ data: Data) throws -> WeekSchedule {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ScheduleError.invalidJSON
        }
        guard let root = object as? [String: Any] else { throw ScheduleError.invalidJSON }
        guard let daysObject = root["days"] as? [String: Any] else { throw ScheduleError.missingDays }

        var schedule = WeekSchedule()

        if let gapObject = root["gap"] as? [String: Any] {
            for w in 0..<7 {
                if let name = gapObject[String(w)] as? String {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { schedule.gap[w] = trimmed }
                }
            }
        }

        for w in 0..<7 {
            guard let raw = daysObject[String(w)] else { continue }
            guard let list = raw as? [Any] else { throw ScheduleError.badEntry(day: w) }
            for item in list {
                guard let fields = item as? [Any], fields.count >= 3,
                      let startText = fields[0] as? String,
                      let endText = fields[1] as? String,
                      let rawTitle = fields[2] as? String else {
                    throw ScheduleError.badEntry(day: w)
                }
                guard let start = TimeOfDay.parse(startText) else {
                    throw ScheduleError.badTime(day: w, value: startText)
                }
                guard let end = TimeOfDay.parse(endText) else {
                    throw ScheduleError.badTime(day: w, value: endText)
                }
                let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if title.isEmpty { throw ScheduleError.emptyTitle(day: w) }
                if start == end { throw ScheduleError.zeroLength(day: w, title: title) }
                if start >= 1440 { throw ScheduleError.badTime(day: w, value: startText) }

                if end > start {
                    schedule.days[w].append(Slot(start: start, end: end, title: title))
                } else {
                    // 跨過半夜：拆成「今天到 24:00」和「隔天從 00:00」兩段。
                    schedule.days[w].append(Slot(start: start, end: 1440, title: title))
                    if end > 0 {
                        schedule.days[(w + 1) % 7].append(Slot(start: 0, end: end, title: title))
                    }
                }
            }
        }

        schedule.sortDays()
        for w in 0..<7 {
            if let (a, b) = ScheduleValidator.firstOverlap(in: schedule.days[w]) {
                throw ScheduleError.overlap(day: w, first: a.title, second: b.title)
            }
        }
        return schedule
    }

    public static func encode(_ schedule: WeekSchedule, pretty: Bool = true) throws -> Data {
        var gap: [String: String] = [:]
        var days: [String: [[String]]] = [:]
        for w in 0..<7 {
            gap[String(w)] = schedule.gapName(w)
            days[String(w)] = schedule.days[w]
                .sorted { ($0.start, $0.end) < ($1.start, $1.end) }
                .map { [TimeOfDay.format($0.start), TimeOfDay.format($0.end), $0.title] }
        }
        let root: [String: Any] = ["version": 1, "gap": gap, "days": days]
        var options: JSONSerialization.WritingOptions = [.sortedKeys, .withoutEscapingSlashes]
        if pretty { options.insert(.prettyPrinted) }
        return try JSONSerialization.data(withJSONObject: root, options: options)
    }

    public static func encodeText(_ schedule: WeekSchedule, pretty: Bool = true) -> String {
        guard let data = try? encode(schedule, pretty: pretty) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
}
