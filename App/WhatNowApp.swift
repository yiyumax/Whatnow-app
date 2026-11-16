import SwiftUI
import WidgetKit

@main
struct WhatNowApp: App {
    @StateObject private var store = ScheduleStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environment(\.locale, Locale(identifier: "zh_Hant_TW"))
                .preferredColorScheme(.dark)
                .tint(Color(hex: 0x4FD1C5))
        }
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("現在", systemImage: "clock.fill") }
            MemoView()
                .tabItem { Label("備忘錄", systemImage: "checklist") }
            EditView()
                .tabItem { Label("編輯", systemImage: "calendar") }
            ImportExportView()
                .tabItem { Label("匯入匯出", systemImage: "arrow.up.arrow.down") }
            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape.fill") }
        }
        // 每次打開 App 順便請系統重排小工具，保險用（前景時不佔用重新整理額度）。
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { WidgetCenter.shared.reloadAllTimelines() }
        }
    }
}
