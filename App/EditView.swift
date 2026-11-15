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

struct EditView: View {
    @EnvironmentObject private var store: ScheduleStore
    @State private var weekday = Calendar.current.component(.weekday, from: Date()) - 1
    @State private var target: EditTarget?
    @State private var showCopy = false
    @State private var gapText = ""
    @FocusState private var gapFocused: Bool

    private var slots: [Slot] { store.schedule.days[weekday] }

    var body: some View {
        NavigationStack {
            List {
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
                    Text("\(Labels.weekdayName(weekday))的時段")
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
            .onAppear { gapText = store.schedule.gap[weekday] }
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
