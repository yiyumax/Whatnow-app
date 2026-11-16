import Foundation
import ScheduleCore

/// 一個「組合」= 一份完整的每週時間表，加上選填的名稱。
struct ScheduleSet: Equatable {
    var name: String
    var schedule: WeekSchedule
}

/// 所有組合存在 sets.json（只有 App 會讀寫）。
/// 使用中的那一組另外寫一份到 schedule.json，小工具只讀那一份，不需要知道有組合這件事。
enum ScheduleSetsFile {
    static let maxSets = 5
    static let fileName = "sets.json"

    struct Contents: Equatable {
        var sets: [ScheduleSet]
        var active: Int
    }

    private static var fileURL: URL? {
        SharedStore.location?.directory.appendingPathComponent(fileName)
    }

    /// 讀不到（第一次使用、或從舊版升級）時回傳 nil。
    static func load() -> Contents? {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawSets = root["sets"] as? [[String: Any]] else {
            return nil
        }
        var sets: [ScheduleSet] = []
        for raw in rawSets.prefix(maxSets) {
            guard let object = raw["schedule"],
                  let scheduleData = try? JSONSerialization.data(withJSONObject: object),
                  let schedule = try? ScheduleCodec.decode(scheduleData) else {
                continue
            }
            sets.append(ScheduleSet(name: raw["name"] as? String ?? "", schedule: schedule))
        }
        guard !sets.isEmpty else { return nil }
        let active = root["active"] as? Int ?? 0
        return Contents(sets: sets, active: min(max(0, active), sets.count - 1))
    }

    static func save(_ contents: Contents) throws {
        guard let url = fileURL else { throw CocoaError(.fileNoSuchFile) }
        var rawSets: [[String: Any]] = []
        for set in contents.sets {
            let scheduleData = try ScheduleCodec.encode(set.schedule, pretty: false)
            let object = try JSONSerialization.jsonObject(with: scheduleData)
            rawSets.append(["name": set.name, "schedule": object])
        }
        let root: [String: Any] = ["version": 1, "active": contents.active, "sets": rawSets]
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }
}
