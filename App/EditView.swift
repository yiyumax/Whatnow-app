import SwiftUI
import ScheduleCore

/// 時間選擇器用 Date，資料用「分鐘數」，在這裡互轉。
enum ClockTime {
    private static let base: Date = Calendar.current.startOfDay(for: Date(timeIntervalSinceReferenceDate: 86400 * 10))

    static func date(_ minutes: Int) -> Date {
        let m = max(0, min(1439, minutes))
        return Calendar.current.date(byAdding: .minute, value: m, to: base) ?? base
    }

    static func minutes(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}

struct EditTarget: Identifiable {
    let id = UUID()
    /// nil = 新增。
    let index: Int?
    let slot: Slot
}

/// 組合切換列：外觀比照下面的星期切換列。數字 = 已有的組合，「+」= 新增（最多 5 組）。
private struct SetBar: View {
    @EnvironmentObject private var store: ScheduleStore
    /// 切換或新增之前呼叫，讓編輯頁先把還沒存的文字存進目前的組合。
    let onWillSwitch: () -> Void
    let onRename: (Int) -> Void
    let onDelete: (Int) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(store.sets.enumerated()), id: \.offset) { index, set in
                let selected = index == store.activeIndex
                Button {
                    guard !selected else { return }
                    onWillSwitch()
                    store.selectSet(index)
                } label: {
                    Text("\(index + 1)")
                        .font(.footnote.weight(selected ? .semibold : .regular))
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(selected ? Color(.systemGray2) : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(set.name.isEmpty ? "組合 \(index + 1)" : "組合 \(index + 1)，\(set.name)")
                .accessibilityAddTraits(selected ? .isSelected : [])
                .contextMenu {
                    Button {
                        onRename(index)
                    } label: {
                        Label("重新命名", systemImage: "pencil")
                    }
                    if store.canAddSet {
                        Button {
                            onWillSwitch()
                            store.duplicateSet(index)
                        } label: {
                            Label("複製成新組合", systemImage: "plus.square.on.square")
                        }
                    }
                    if store.sets.count > 1 {
                        Button(role: .destructive) {
                            onDelete(index)
                        } label: {
                            Label("刪除", systemImage: "trash")
                        }
                    }
                }
            }

            if store.canAddSet {
                Button {
                    onWillSwitch()
                    store.addSet()
                } label: {
                    Image(systemName: "plus")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("新增組合")
            }
        }
        .padding(2)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

struct EditView: View {
    @EnvironmentObject private var store: ScheduleStore
    @State private var weekday = Calendar.current.component(.weekday, from: Date()) - 1
    @State private var target: EditTarget?
    @State private var showCopy = false
    @State private var gapText = ""
    @FocusState private var gapFocused: Bool
    @State private var showRename = false
    @State private var renameIndex = 0
    @State private var renameText = ""
    @State private var showDelete = false
    @State private var deleteIndex = 0

    private var slots: [Slot] { store.schedule.days[weekday] }

    private var setLabel: String {
        let name = store.sets[store.activeIndex].name
        return name.isEmpty ? "組合 \(store.activeIndex + 1)" : "組合 \(store.activeIndex + 1)「\(name)」"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    SetBar(onWillSwitch: { commitGap(for: weekday) },
                           onRename: { index in
                               renameText = store.sets[index].name
                               renameIndex = index
                               showRename = true
                           },
                           onDelete: { index in
                               deleteIndex = index
                               showDelete = true
                           })
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                } footer: {
                    Text("切到哪個組合，「現在」頁和小工具就用哪一組。長按數字可以命名、複製或刪除。")
                }

                Section {
                    Picker("星期", selection: $weekday) {
                        ForEach(0..<7, id: \.self) { w in
                            Text(Labels.shortWeekdayName(w)).tag(w)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    if slots.isEmpty {
                        Text("這天還沒有排行程").foregroundStyle(.secondary)
                    }
                    ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                        Button {
                            target = EditTarget(index: index, slot: slot)
                        } label: {
                            HStack(spacing: 10) {
                                Circle().fill(Theme.color(for: slot.title)).frame(width: 8, height: 8)
                                Text("\(TimeOfDay.format(slot.start))–\(TimeOfDay.format(slot.end))")
                                    .font(.callout.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                Text(slot.title).foregroundStyle(.primary)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .onDelete { offsets in
                        store.update { $0.days[weekday].remove(atOffsets: offsets) }
                    }

                    Button {
                        target = EditTarget(index: nil, slot: newSlotTemplate())
                    } label: {
                        Label("新增時段", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("\(setLabel) · \(Labels.weekdayName(weekday))的時段")
                } footer: {
                    Text("點一下修改，往左滑刪除。")
                }

                Section {
                    TextField(WeekSchedule.defaultGapNames[weekday], text: $gapText)
                        .focused($gapFocused)
                        .submitLabel(.done)
                        .onSubmit { commitGap(for: weekday) }
                } header: {
                    Text("空檔名稱")
                } footer: {
                    Text("沒排到的時間會顯示這個名稱。")
                }

                Section {
                    Button {
                        commitGap(for: weekday)
                        showCopy = true
                    } label: {
                        Label("把這天複製到其他天…", systemImage: "doc.on.doc")
                    }
                    .disabled(slots.isEmpty)
                }
            }
            .navigationTitle("編輯時間表")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $target) { target in
                SlotEditorView(weekday: weekday, index: target.index, slot: target.slot)
            }
            .sheet(isPresented: $showCopy) {
                CopyDayView(source: weekday)
            }
            .alert("組合名稱", isPresented: $showRename) {
                TextField("例如：上課週、寒假", text: $renameText)
                Button("儲存") { store.renameSet(renameIndex, to: renameText) }
                Button("取消", role: .cancel) {}
            } message: {
                Text("選填。留白就只顯示編號。")
            }
            .alert("要刪除組合 \(deleteIndex + 1) 嗎？", isPresented: $showDelete) {
                Button("刪除", role: .destructive) {
                    gapFocused = false
                    store.deleteSet(deleteIndex)
                    gapText = store.schedule.gap[weekday]
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("這個組合的整份時間表會被刪掉，無法復原。後面的組合編號會往前遞補。")
            }
            .onAppear { gapText = store.schedule.gap[weekday] }
            .onChange(of: store.activeIndex) { _, _ in
                gapFocused = false
                gapText = store.schedule.gap[weekday]
            }
            .onChange(of: weekday) { old, new in
                commitGap(for: old)
                gapText = store.schedule.gap[new]
            }
            .onChange(of: gapFocused) { _, focused in
                if !focused { commitGap(for: weekday) }
            }
            .onChange(of: store.revision) { _, _ in
                if !gapFocused { gapText = store.schedule.gap[weekday] }
            }
        }
    }

    private func commitGap(for day: Int) {
        let trimmed = gapText.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.isEmpty ? WeekSchedule.defaultGapNames[day] : trimmed
        guard value != store.schedule.gap[day] else { return }
        store.update { $0.gap[day] = value }
    }

    /// 新時段預設接在最後一個時段後面，長度 1 小時。
    private func newSlotTemplate() -> Slot {
        let start = min(slots.last?.end ?? 480, 1380)
        return Slot(start: start, end: min(start + 60, 1440), title: "")
    }
}

// MARK: - 新增 / 修改一個時段

struct SlotEditorView: View {
    @EnvironmentObject private var store: ScheduleStore
    @Environment(\.dismiss) private var dismiss

    let weekday: Int
    let index: Int?

    @State private var title: String
    @State private var start: Date
    @State private var end: Date
    @State private var endsAtMidnight: Bool
    @State private var attempted = false

    init(weekday: Int, index: Int?, slot: Slot) {
        self.weekday = weekday
        self.index = index
        _title = State(initialValue: slot.title)
        _start = State(initialValue: ClockTime.date(slot.start))
        _end = State(initialValue: ClockTime.date(slot.end >= 1440 ? 1380 : slot.end))
        _endsAtMidnight = State(initialValue: slot.end >= 1440)
    }

    private var draft: Slot {
        Slot(start: ClockTime.minutes(start),
             end: endsAtMidnight ? 1440 : ClockTime.minutes(end),
             title: title.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var issue: SlotIssue? {
        ScheduleValidator.issue(for: draft, in: store.schedule.days[weekday], ignoring: index)
    }

    /// 還沒按「儲存」之前，不為了空白名稱跳警告。
    private var visibleIssue: SlotIssue? {
        guard let issue else { return nil }
        if issue == .emptyTitle && !attempted { return nil }
        return issue
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("名稱") {
                    TextField("例如：上課", text: $title)
                }
                Section("時間") {
                    DatePicker("開始", selection: $start, displayedComponents: .hourAndMinute)
                    if !endsAtMidnight {
                        DatePicker("結束", selection: $end, displayedComponents: .hourAndMinute)
                    }
                    Toggle("結束在 24:00（半夜）", isOn: $endsAtMidnight)
                }
                if let visibleIssue {
                    Section {
                        Label(visibleIssue.message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                if let index {
                    Section {
                        Button("刪除這個時段", role: .destructive) {
                            store.update { schedule in
                                if schedule.days[weekday].indices.contains(index) {
                                    schedule.days[weekday].remove(at: index)
                                }
                            }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(index == nil ? "新增時段" : "修改時段")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") { save() }
                }
            }
        }
    }

    private func save() {
        attempted = true
        guard issue == nil else { return }   // 有重疊或時間不對就擋下，訊息顯示在表單裡
        let slot = draft
        store.update { schedule in
            if let index, schedule.days[weekday].indices.contains(index) {
                schedule.days[weekday][index] = slot
            } else {
                schedule.days[weekday].append(slot)
            }
        }
        dismiss()
    }
}

// MARK: - 複製到其他天

struct CopyDayView: View {
    @EnvironmentObject private var store: ScheduleStore
    @Environment(\.dismiss) private var dismiss

    let source: Int
    @State private var targets: Set<Int> = []
    @State private var copyGapName = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(0..<7, id: \.self) { w in
                        if w != source {
                            Button {
                                if targets.contains(w) { targets.remove(w) } else { targets.insert(w) }
                            } label: {
                                HStack {
                                    Text(Labels.weekdayName(w)).foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(store.schedule.days[w].count) 個時段")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    Image(systemName: targets.contains(w) ? "checkmark.circle.fill" : "circle")
                                }
                            }
                        }
                    }
                } header: {
                    Text("把\(Labels.weekdayName(source))的行程複製到")
                } footer: {
                    Text("所選日子原有的行程會被取代。")
                }
                Section {
                    Toggle("空檔名稱也一起複製", isOn: $copyGapName)
                }
            }
            .navigationTitle("複製行程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("複製") {
                        store.update { schedule in
                            for w in targets {
                                schedule.days[w] = schedule.days[source]
                                if copyGapName { schedule.gap[w] = schedule.gap[source] }
                            }
                        }
                        dismiss()
                    }
                    .disabled(targets.isEmpty)
                }
            }
        }
    }
}
