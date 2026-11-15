import Foundation
import ScheduleCore

/// App 和小工具共用的資料位置。
///
/// SideStore / AltStore 用免費 Apple ID 重簽時，會把 App Group 改名成
/// `group.com.whatnow.app.<TEAMID>`，所以不能把群組 ID 寫死。
/// 這裡在執行時找出「這次簽名實際拿到的群組」：
///   1. 自己的 embedded.mobileprovision 裡列出的群組（最可靠，簽名真正授權的）
///   2. Info.plist 的 ALTAppGroups（AltStore 系列寫入的）
///   3. 編譯時的群組 ID（用 Xcode 正式簽名或模擬器時）
/// App 和小工具各自讀自己的描述檔，會得到同一個群組。
enum SharedStore {
    static let baseGroupID = "group.com.whatnow.app"
    static let fileName = "schedule.json"

    struct Location {
        let directory: URL
        /// nil 代表沒有拿到共用容器（只存在 App 自己的資料夾，小工具讀不到）。
        let groupID: String?
        var isShared: Bool { groupID != nil }
        var fileURL: URL { directory.appendingPathComponent(SharedStore.fileName) }
    }

    static let isExtension = Bundle.main.bundleURL.pathExtension == "appex"

    static let location: Location? = resolveLocation()

    // MARK: - 讀寫

    static func load() -> WeekSchedule {
        guard let location = location,
              let data = try? Data(contentsOf: location.fileURL),
              let schedule = try? ScheduleCodec.decode(data) else {
            return DefaultSchedule.schedule
        }
        return schedule
    }

    static var hasSavedFile: Bool {
        guard let location = location else { return false }
        return FileManager.default.fileExists(atPath: location.fileURL.path)
    }

    static func save(_ schedule: WeekSchedule) throws {
        guard let location = location else { throw CocoaError(.fileNoSuchFile) }
        let data = try ScheduleCodec.encode(schedule)
        try data.write(to: location.fileURL, options: .atomic)
    }

    // MARK: - 找出群組

    static func candidateGroupIDs() -> [String] {
        var bundles = [Bundle.main]
        if isExtension {
            // Widget.appex 位在 App.app/PlugIns/ 裡，往上兩層就是主 App。
            let appURL = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
            if let appBundle = Bundle(url: appURL) { bundles.append(appBundle) }
        }

        var result: [String] = []
        func add(_ ids: [String]) {
            let preferred = ids.filter { $0.hasPrefix(baseGroupID) }.sorted()
            let others = ids.filter { !$0.hasPrefix(baseGroupID) }.sorted()
            for id in preferred + others where !result.contains(id) { result.append(id) }
        }

        for bundle in bundles { add(profileGroupIDs(in: bundle)) }
        for bundle in bundles { add(bundle.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] ?? []) }
        add([baseGroupID])
        return result
    }

    /// 從 embedded.mobileprovision 讀出這次簽名授權的 App Group。
    static func profileGroupIDs(in bundle: Bundle) -> [String] {
        let url = bundle.bundleURL.appendingPathComponent("embedded.mobileprovision")
        guard let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex) else {
            return []
        }
        let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
        guard let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let groups = entitlements["com.apple.security.application-groups"] as? [String] else {
            return []
        }
        return groups
    }

    private static func resolveLocation() -> Location? {
        let fm = FileManager.default
        for id in candidateGroupIDs() {
            if let url = fm.containerURL(forSecurityApplicationGroupIdentifier: id) {
                return Location(directory: url, groupID: id)
            }
        }
        // 沒有共用容器：小工具只能顯示內建預設；App 退回自己的資料夾，至少資料不會丟。
        if isExtension { return nil }
        guard let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        try? fm.createDirectory(at: support, withIntermediateDirectories: true)
        return Location(directory: support, groupID: nil)
    }
}
