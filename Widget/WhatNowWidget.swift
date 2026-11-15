import WidgetKit
import SwiftUI
import ScheduleCore

struct NowEntry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot
}

struct NowProvider: TimelineProvider {
    func placeholder(in context: Context) -> NowEntry {
        let now = Date()
        return NowEntry(date: now, snapshot: ScheduleEngine(schedule: DefaultSchedule.schedule).snapshot(at: now))
    }

    func getSnapshot(in context: Context, completion: @escaping (NowEntry) -> Void) {
        let now = Date()
        let engine = ScheduleEngine(schedule: SharedStore.load())
        completion(NowEntry(date: now, snapshot: engine.snapshot(at: now)))
    }

    /// 一次排好未來 48 小時：現在一個 entry，之後每個時段邊界（和每個午夜）各一個。
    /// 換時段由系統照 timeline 準時切換，不必等背景重新整理。
    func getTimeline(in context: Context, completion: @escaping (Timeline<NowEntry>) -> Void) {
        let engine = ScheduleEngine(schedule: SharedStore.load())
        let timeline = engine.timeline(from: Date(), hours: 48)
        let entries = timeline.entries.map { NowEntry(date: $0.date, snapshot: $0) }
        // 最後一個 entry 開始之後再請系統重新載入，接著排下一個 48 小時。
        completion(Timeline(entries: entries, policy: .after(timeline.reloadDate)))
    }
}

struct NowWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NowWidget", provider: NowProvider()) { entry in
            NowWidgetView(entry: entry)
                .containerBackground(for: .widget) { Theme.background }
        }
        .configurationDisplayName("現在該做什麼")
        .description("顯示現在的行程、剩餘時間和接下來的行程。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct WhatNowWidgetBundle: WidgetBundle {
    var body: some Widget {
        NowWidget()
    }
}
