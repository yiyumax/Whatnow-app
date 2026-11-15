import SwiftUI
import ScheduleCore

struct HomeView: View {
    @EnvironmentObject private var store: ScheduleStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var snapshot: Snapshot?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let snapshot {
                    VStack(spacing: 16) {
                        CurrentCard(snapshot: snapshot)
                        NextCard(snapshot: snapshot)
                        TodayList(snapshot: snapshot)
                    }
                    .padding(16)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("現在該做什麼")
            .navigationBarTitleDisplayMode(.inline)
        }
        // 存檔後、或 App 回到前景時，重新開始計時。
        .task(id: "\(store.revision)-\(scenePhase == .active)") {
            await runClock()
        }
    }

    /// 睡到下一個時段邊界（或午夜）再重算；倒數和進度條由系統自己跑，不需要每秒刷新。
    @MainActor
    private func runClock() async {
        while !Task.isCancelled {
            let now = Date()
            let engine = store.engine
            let snap = engine.snapshot(at: now)
            snapshot = snap
            let wake = min(snap.current.end, engine.startOfNextDay(after: now))
            let delay = min(60, max(0.2, wake.timeIntervalSinceNow + 0.05))
            try? await Task.sleep(for: .seconds(delay))
        }
    }
}

private struct CurrentCard: View {
    let snapshot: Snapshot

    var body: some View {
        let current = snapshot.current
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(Theme.color(for: current.title)).frame(width: 10, height: 10)
                Text("現在").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.secondary)
            }
            Text(current.title)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(Theme.primary)
                .lineLimit(3)
                .minimumScaleFactor(0.5)

            if snapshot.upcoming.isEmpty {
                Text("整週都沒有排行程").font(.title3).foregroundStyle(Theme.secondary)
            } else {
                Text("到 \(Labels.end(current.end, relativeTo: snapshot.date))")
                    .font(.title3)
                    .foregroundStyle(Theme.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("剩").font(.title3).foregroundStyle(Theme.secondary)
                    Countdown.text(from: snapshot.date, to: current.end)
                        .font(.system(size: 40, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.primary)
                }
                SegmentProgressBar(segment: current, height: 8)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct NextCard: View {
    let snapshot: Snapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("下一個").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.secondary)
            if let next = snapshot.next {
                HStack(spacing: 8) {
                    Circle().fill(Theme.color(for: next.title)).frame(width: 8, height: 8)
                    Text(next.title)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Theme.primary)
                        .lineLimit(2)
                }
                HStack(spacing: 4) {
                    Text("\(Labels.start(next.start, relativeTo: snapshot.date)) 開始 · 還有")
                    Countdown.text(from: snapshot.date, to: next.start).monospacedDigit()
                }
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)
            } else {
                Text("沒有其他行程").font(.title3).foregroundStyle(Theme.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct TodayList: View {
    let snapshot: Snapshot

    var body: some View {
        let dayStart = Calendar.current.startOfDay(for: snapshot.date)
        let weekday = Calendar.current.component(.weekday, from: snapshot.date) - 1

        VStack(alignment: .leading, spacing: 4) {
            Text("今天 · \(Labels.weekdayName(weekday))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.secondary)
                .padding(.bottom, 6)

            ForEach(snapshot.today) { segment in
                let isCurrent = segment == snapshot.current
                let isPast = segment.end <= snapshot.date
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(segment.start < dayStart ? "00:00" : Labels.clock(segment.start))
                        Text(Labels.end(segment.end, relativeTo: snapshot.date))
                            .foregroundStyle(Theme.secondary)
                    }
                    .font(.footnote.monospacedDigit())
                    .frame(width: 84, alignment: .leading)

                    Circle().fill(Theme.color(for: segment.title)).frame(width: 8, height: 8)

                    Text(segment.title)
                        .font(.body.weight(isCurrent ? .bold : .regular))
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(segment.isGap && !isCurrent ? Theme.secondary : Theme.primary)
                .opacity(isPast ? 0.45 : 1)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isCurrent ? Theme.color(for: segment.title).opacity(0.22) : Color.clear)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
