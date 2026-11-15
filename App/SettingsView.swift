import SwiftUI
import ScheduleCore

struct SettingsView: View {
    @EnvironmentObject private var store: ScheduleStore
    @State private var showDenied = false

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("行程開始時通知", isOn: Binding(
                        get: { store.notificationsEnabled },
                        set: { enabled in
                            Task {
                                let allowed = await store.setNotifications(enabled: enabled)
                                if !allowed { showDenied = true }
                            }
                        }))
                } header: {
                    Text("通知")
                } footer: {
                    if store.droppedNotifications > 0 {
                        Text("iOS 最多只能排 64 個通知，有 \(store.droppedNotifications) 個行程（一週裡最後面的）沒有排進去。")
                    } else {
                        Text("每個行程開始時提醒一次，每週重複。空檔不會通知。")
                    }
                }

                Section {
                    if let location = SharedStore.location, let groupID = location.groupID {
                        Label("正常", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        LabeledContent("群組", value: groupID)
                    } else {
                        Label("失敗：小工具讀不到 App 的資料", systemImage: "xmark.octagon.fill")
                            .foregroundStyle(.red)
                    }
                    LabeledContent("Bundle ID", value: Bundle.main.bundleIdentifier ?? "?")
                } header: {
                    Text("和小工具共用資料")
                } footer: {
                    if SharedStore.location?.isShared == true {
                        Text("App 和小工具讀的是同一份時間表。")
                    } else {
                        Text("這次簽名沒有拿到 App Group，小工具只會顯示內建的預設行程。請在 SideStore 重新安裝一次；如果還是失敗，把這一頁截圖回報。")
                    }
                }

                Section("關於") {
                    LabeledContent("版本", value: version)
                    LabeledContent("時段總數", value: "\(store.schedule.totalSlotCount)")
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .alert("沒有通知權限", isPresented: $showDenied) {
                Button("好", role: .cancel) {}
            } message: {
                Text("請到「設定 → 通知 → 現在該做什麼」打開允許通知，再回來開啟這個選項。")
            }
            .alert("存檔失敗", isPresented: Binding(
                get: { store.saveError != nil },
                set: { if !$0 { store.saveError = nil } })) {
                Button("好", role: .cancel) {}
            } message: {
                Text(store.saveError ?? "")
            }
        }
    }
}
