import Foundation
import SwiftUI
import WidgetKit
import ScheduleCore

@MainActor
final class ScheduleStore: ObservableObject {
    /// 使用中組合的時間表（「現在」頁、小工具、通知都用這一份）。
    @Published private(set) var schedule: WeekSchedule
    /// 所有組合，1 到 5 個。
    @Published private(set) var sets: [ScheduleSet]
    /// 使用中（也是正在編輯）的組合。
    @Published private(set) var activeIndex: Int
    /// 每次存檔加 1，畫面用它來知道要重新計算。
    @Published private(set) var revision = 0
    @Published private(set) var notificationsEnabled: Bool
    /// 因為超過 64 個上限而沒排進去的通知數量。
    @Published private(set) var droppedNotifications = 0
    @Published var saveError: String?

    private static let notificationsKey = "notificationsEnabled"

    init() {
        let hadScheduleFile = SharedStore.hasSavedFile
        let contents: ScheduleSetsFile.Contents
        let needsWrite: Bool
        if let saved = ScheduleSetsFile.load() {
            contents = saved
            needsWrite = !hadScheduleFile
        } else {
            // 第一次開啟，或從沒有組合的舊版升級：原本的時間表變成組合 1。
            contents = .init(sets: [ScheduleSet(name: "", schedule: SharedStore.load())], active: 0)
            needsWrite = true
        }
        sets = contents.sets
        activeIndex = contents.active
        schedule = contents.sets[contents.active].schedule
        notificationsEnabled = UserDefaults.standard.bool(forKey: Self.notificationsKey)
        if needsWrite {
            // 把資料寫進共用位置，App 和小工具才會讀到同一份。
            try? ScheduleSetsFile.save(contents)
            try? SharedStore.save(schedule)
            WidgetCenter.shared.reloadAllTimelines()
        }
        if notificationsEnabled {
            droppedNotifications = NotificationPlan.make(for: schedule).dropped
        }
    }

    var engine: ScheduleEngine { ScheduleEngine(schedule: schedule) }

    /// 修改時間表並存檔。
    func update(_ change: (inout WeekSchedule) -> Void) {
        var copy = schedule
        change(&copy)
        replace(with: copy)
    }

    func replace(with newSchedule: WeekSchedule) {
        var copy = newSchedule
        copy.sortDays()
        guard copy != schedule else { return }
        sets[activeIndex].schedule = copy
        activeScheduleChanged()
    }

    // MARK: - 組合

    var canAddSet: Bool { sets.count < ScheduleSetsFile.maxSets }

    /// 切換使用中的組合。
    func selectSet(_ index: Int) {
        guard sets.indices.contains(index), index != activeIndex else { return }
        activeIndex = index
        activeScheduleChanged()
    }

    /// 新增一個空白組合並切過去。
    func addSet() {
        guard canAddSet else { return }
        sets.append(ScheduleSet(name: "", schedule: WeekSchedule()))
        activeIndex = sets.count - 1
        activeScheduleChanged()
    }

    /// 把某個組合複製成新的組合並切過去。
    func duplicateSet(_ index: Int) {
        guard canAddSet, sets.indices.contains(index) else { return }
        sets.append(ScheduleSet(name: "", schedule: sets[index].schedule))
        activeIndex = sets.count - 1
        activeScheduleChanged()
    }

    func renameSet(_ index: Int, to name: String) {
        guard sets.indices.contains(index) else { return }
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
        guard trimmed != sets[index].name else { return }
        sets[index].name = trimmed
        saveSetsFile()
    }

    /// 刪除組合；後面的組合編號會往前遞補。至少要留一組。
    func deleteSet(_ index: Int) {
        guard sets.count > 1, sets.indices.contains(index) else { return }
        sets.remove(at: index)
        if index < activeIndex {
            activeIndex -= 1
        } else if activeIndex >= sets.count {
            activeIndex = sets.count - 1
        }
        activeScheduleChanged()
    }

    /// 使用中的時間表內容可能變了：存檔、通知小工具、重排通知。
    private func activeScheduleChanged() {
        let changed = schedule != sets[activeIndex].schedule
        schedule = sets[activeIndex].schedule
        revision += 1
        saveSetsFile()
        guard changed else { return }
        do {
            try SharedStore.save(schedule)
        } catch {
            saveError = "存檔失敗：\(error.localizedDescription)"
        }
        // 存檔後立刻請系統重排小工具的 timeline。
        WidgetCenter.shared.reloadAllTimelines()
        if notificationsEnabled {
            Task { await rescheduleNotifications() }
        }
    }

    private func saveSetsFile() {
        do {
            try ScheduleSetsFile.save(.init(sets: sets, active: activeIndex))
        } catch {
            saveError = "存檔失敗：\(error.localizedDescription)"
        }
    }

    // MARK: - 通知

    /// 回傳 false 代表使用者沒有允許通知。
    func setNotifications(enabled: Bool) async -> Bool {
        if enabled {
            guard await NotificationScheduler.requestAuthorization() else {
                notificationsEnabled = false
                UserDefaults.standard.set(false, forKey: Self.notificationsKey)
                return false
            }
            notificationsEnabled = true
            UserDefaults.standard.set(true, forKey: Self.notificationsKey)
            await rescheduleNotifications()
        } else {
            notificationsEnabled = false
            UserDefaults.standard.set(false, forKey: Self.notificationsKey)
            droppedNotifications = 0
            NotificationScheduler.cancelAll()
        }
        return true
    }

    private func rescheduleNotifications() async {
        droppedNotifications = await NotificationScheduler.reschedule(for: schedule)
    }
}
