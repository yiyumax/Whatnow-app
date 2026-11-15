import Foundation
import SwiftUI
import WidgetKit
import ScheduleCore

@MainActor
final class ScheduleStore: ObservableObject {
    @Published private(set) var schedule: WeekSchedule
    /// 每次存檔加 1，畫面用它來知道要重新計算。
    @Published private(set) var revision = 0
    @Published private(set) var notificationsEnabled: Bool
    /// 因為超過 64 個上限而沒排進去的通知數量。
    @Published private(set) var droppedNotifications = 0
    @Published var saveError: String?

    private static let notificationsKey = "notificationsEnabled"

    init() {
        schedule = SharedStore.load()
        notificationsEnabled = UserDefaults.standard.bool(forKey: Self.notificationsKey)
        if !SharedStore.hasSavedFile {
            // 第一次開啟：把預設資料寫進共用位置，App 和小工具才會讀到同一份。
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
        schedule = copy
        revision += 1
        do {
            try SharedStore.save(copy)
        } catch {
            saveError = "存檔失敗：\(error.localizedDescription)"
        }
        // 存檔後立刻請系統重排小工具的 timeline。
        WidgetCenter.shared.reloadAllTimelines()
        if notificationsEnabled {
            Task { await rescheduleNotifications() }
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
