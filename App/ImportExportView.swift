import SwiftUI
import UIKit
import UniformTypeIdentifiers
import ScheduleCore

struct JSONFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct ImportExportView: View {
    @EnvironmentObject private var store: ScheduleStore

    @State private var showExporter = false
    @State private var showImporter = false
    @State private var pasted = ""
    @State private var pending: WeekSchedule?
    @State private var showConfirm = false
    @State private var showResetConfirm = false
    @State private var message: String?
    @State private var showMessage = false
    @FocusState private var pasteFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showExporter = true
                    } label: {
                        Label("匯出成檔案", systemImage: "square.and.arrow.up")
                    }
                    .fileExporter(isPresented: $showExporter,
                                  document: JSONFile(data: Data(ScheduleCodec.encodeText(store.schedule).utf8)),
                                  contentType: .json,
                                  defaultFilename: "schedule") { result in
                        if case .failure(let error) = result { show("匯出失敗：\(error.localizedDescription)") }
                    }

                    Button {
                        UIPasteboard.general.string = ScheduleCodec.encodeText(store.schedule)
                        show("已經複製到剪貼簿。")
                    } label: {
                        Label("複製 JSON 文字", systemImage: "doc.on.doc")
                    }
                } header: {
                    Text("匯出")
                } footer: {
                    Text("匯出和匯入都只針對目前使用中的組合 \(store.activeIndex + 1)。格式和 Scriptable 版本相同。更新 App 之前先匯出一份當備份。")
                }

                Section {
                    Button {
                        showImporter = true
                    } label: {
                        Label("從「檔案」選擇", systemImage: "folder")
                    }
                } header: {
                    Text("從檔案匯入")
                }

                Section {
                    TextEditor(text: $pasted)
                        .font(.footnote.monospaced())
                        .frame(minHeight: 140)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($pasteFocused)
                    Button {
                        pasted = UIPasteboard.general.string ?? ""
                        pasteFocused = false
                    } label: {
                        Label("貼上剪貼簿內容", systemImage: "doc.on.clipboard")
                    }
                    Button {
                        pasteFocused = false
                        importText(pasted)
                    } label: {
                        Label("匯入這段文字", systemImage: "square.and.arrow.down")
                    }
                    .disabled(pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } header: {
                    Text("貼上文字匯入")
                }

                Section {
                    Button("還原成內建的預設時間表", role: .destructive) {
                        showResetConfirm = true
                    }
                }
            }
            .navigationTitle("匯入／匯出")
            .navigationBarTitleDisplayMode(.inline)
            // 多行輸入框沒有「完成」鍵：往下滑清單，或按鍵盤上方的「完成」收起鍵盤。
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { pasteFocused = false }
                }
            }
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: [.json, .plainText, .text, .data]) { result in
                switch result {
                case .success(let url):
                    importFile(url)
                case .failure(let error):
                    show("無法開啟檔案：\(error.localizedDescription)")
                }
            }
            .alert("要取代目前的時間表嗎？", isPresented: $showConfirm, presenting: pending) { schedule in
                Button("取代", role: .destructive) {
                    store.replace(with: schedule)
                    pasted = ""
                    show("匯入完成，共 \(schedule.totalSlotCount) 個時段。")
                }
                Button("取消", role: .cancel) {}
            } message: { schedule in
                Text("匯入的內容有 \(schedule.totalSlotCount) 個時段，組合 \(store.activeIndex + 1) 的時間表會被整份換掉，其他組合不受影響。")
            }
            .alert("要還原成預設時間表嗎？", isPresented: $showResetConfirm) {
                Button("還原", role: .destructive) {
                    store.replace(with: DefaultSchedule.schedule)
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("組合 \(store.activeIndex + 1) 的時間表會被整份換掉，其他組合不受影響。")
            }
            .alert(message ?? "", isPresented: $showMessage) {
                Button("好", role: .cancel) {}
            }
        }
    }

    private func show(_ text: String) {
        message = text
        showMessage = true
    }

    private func importFile(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            importText(String(decoding: data, as: UTF8.self))
        } catch {
            show("讀不到這個檔案：\(error.localizedDescription)")
        }
    }

    private func importText(_ text: String) {
        do {
            pending = try ScheduleCodec.decode(text: text)
            showConfirm = true
        } catch {
            show("匯入失敗：\(error.localizedDescription)")
        }
    }
}
