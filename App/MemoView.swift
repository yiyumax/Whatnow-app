import SwiftUI

struct MemoItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
}

/// 備忘錄：臨時要做的事。存在 memos.json，和時間表放同一個資料夾，更新 App 不會消失。
@MainActor
final class MemoStore: ObservableObject {
    @Published private(set) var items: [MemoItem] = []
    @Published var saveError: String?

    private static var fileURL: URL? {
        SharedStore.location?.directory.appendingPathComponent("memos.json")
    }

    init() {
        if let url = Self.fileURL,
           let data = try? Data(contentsOf: url),
           let saved = try? JSONDecoder().decode([MemoItem].self, from: data) {
            items = saved
        }
    }

    func add(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.append(MemoItem(title: trimmed))
        save()
    }

    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    func remove(atOffsets offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        save()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        save()
    }

    private func save() {
        guard let url = Self.fileURL else {
            saveError = "存檔失敗：找不到儲存位置。"
            return
        }
        do {
            try JSONEncoder().encode(items).write(to: url, options: .atomic)
        } catch {
            saveError = "存檔失敗：\(error.localizedDescription)"
        }
    }
}

struct MemoView: View {
    @StateObject private var memos = MemoStore()
    @State private var draft = ""
    /// 剛被點掉、正在顯示打勾動畫的項目。
    @State private var completing: Set<UUID> = []
    @FocusState private var draftFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(memos.items) { item in
                        let done = completing.contains(item.id)
                        HStack(spacing: 12) {
                            Button {
                                complete(item)
                            } label: {
                                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundStyle(done ? Color.accentColor : Theme.secondary)
                                    .frame(width: 32, height: 32)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("完成「\(item.title)」")

                            Text(item.title)
                                .foregroundStyle(done ? Theme.secondary : Theme.primary)
                                .strikethrough(done)
                        }
                    }
                    .onDelete { memos.remove(atOffsets: $0) }
                    .onMove { memos.move(fromOffsets: $0, toOffset: $1) }

                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 32, height: 32)
                        TextField("新增事項", text: $draft)
                            .focused($draftFocused)
                            .submitLabel(.done)
                            .onSubmit { addDraft() }
                    }
                } footer: {
                    Text(memos.items.isEmpty
                         ? "把臨時要做的事記在這裡。做完點左邊的圓圈，它就會消失。"
                         : "做完點左邊的圓圈就會消失。長按可以拖曳排序。")
                }
            }
            .navigationTitle("備忘錄")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .alert("存檔失敗", isPresented: Binding(
                get: { memos.saveError != nil },
                set: { if !$0 { memos.saveError = nil } })) {
                Button("好", role: .cancel) {}
            } message: {
                Text(memos.saveError ?? "")
            }
        }
    }

    @MainActor
    private func addDraft() {
        let hadText = !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        withAnimation { memos.add(draft) }
        draft = ""
        // 有輸入內容就留在輸入框，方便連續新增；空白按完成就收起鍵盤。
        draftFocused = hadText
    }

    /// 先顯示打勾，停一下再讓它消失，才看得出點到了哪一項。
    @MainActor
    private func complete(_ item: MemoItem) {
        guard !completing.contains(item.id) else { return }
        completing.insert(item.id)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.45))
            withAnimation { memos.remove(item.id) }
            completing.remove(item.id)
        }
    }
}
