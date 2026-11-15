import WidgetKit
import SwiftUI
import ScheduleCore

struct NowWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NowEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallView(snapshot: entry.snapshot)
        case .systemMedium:
            MediumView(snapshot: entry.snapshot)
        case .systemLarge:
            LargeView(snapshot: entry.snapshot)
        case .accessoryRectangular:
            RectangularView(snapshot: entry.snapshot)
        case .accessoryInline:
            Text("\(entry.snapshot.current.title) · 到 \(endLabel(entry.snapshot))")
        default:
            SmallView(snapshot: entry.snapshot)
        }
    }
}

private func endLabel(_ snapshot: Snapshot) -> String {
    Labels.end(snapshot.current.end, relativeTo: snapshot.date)
}

// MARK: - 共用零件

private struct NowTag: View {
    let title: String

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(Theme.color(for: title)).frame(width: 7, height: 7)
            Text("現在")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.secondary)
        }
    }
}

/// 中、大尺寸左邊（上半部）的「現在」區塊。
private struct CurrentBlock: View {
    let snapshot: Snapshot

    var body: some View {
        let current = snapshot.current
        VStack(alignment: .leading, spacing: 4) {
            NowTag(title: current.title)
            Text(current.title)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Theme.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Text("到 \(endLabel(snapshot)) · 剩")
                    .layoutPriority(1)
                Countdown.text(from: snapshot.date, to: current.end)
                    .monospacedDigit()
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.secondary)
            .lineLimit(1)
            SegmentProgressBar(segment: current)
        }
    }
}

/// 中、大尺寸右邊的「接下來」。
private struct UpcomingBlock: View {
    let snapshot: Snapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("接下來")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.secondary)
            if snapshot.upcoming.isEmpty {
                Text("沒有其他行程")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.secondary)
            }
            ForEach(Array(snapshot.upcoming.prefix(2))) { segment in
                VStack(alignment: .leading, spacing: 1) {
                    Text(Labels.start(segment.start, relativeTo: snapshot.date))
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundStyle(Theme.secondary)
                    HStack(spacing: 5) {
                        Circle().fill(Theme.color(for: segment.title)).frame(width: 6, height: 6)
                        Text(segment.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

private struct TopRow: View {
    let snapshot: Snapshot

    var body: some View {
        HStack(spacing: 14) {
            CurrentBlock(snapshot: snapshot)
                .frame(maxWidth: .infinity, alignment: .leading)
            Rectangle().fill(Theme.divider).frame(width: 1)
            UpcomingBlock(snapshot: snapshot)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - 小

private struct SmallView: View {
    let snapshot: Snapshot

    var body: some View {
        let current = snapshot.current
        VStack(alignment: .leading, spacing: 3) {
            NowTag(title: current.title)
            Text(current.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            Text("到 \(endLabel(snapshot))")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.secondary)
                .lineLimit(1)
            Spacer(minLength: 2)
            SegmentProgressBar(segment: current)
            Spacer(minLength: 2)
            if let next = snapshot.next {
                Text(next.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                    .lineLimit(1)
                HStack(spacing: 3) {
                    Text("還有")
                    Countdown.text(from: snapshot.date, to: next.start).monospacedDigit()
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.secondary)
                .lineLimit(1)
            } else {
                Text("沒有其他行程")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - 中

private struct MediumView: View {
    let snapshot: Snapshot

    var body: some View {
        TopRow(snapshot: snapshot)
    }
}

// MARK: - 大

private struct LargeView: View {
    let snapshot: Snapshot

    /// 今天剩下的時段；如果今天快結束了、剩不到 4 個，就用接下來的補上。
    private var rows: [Segment] {
        var rows = snapshot.remainingToday
        for segment in snapshot.upcoming where rows.count < 4 && !rows.contains(segment) {
            rows.append(segment)
        }
        return Array(rows.prefix(6))
    }

    var body: some View {
        let dayStart = Calendar.current.startOfDay(for: snapshot.date)
        VStack(alignment: .leading, spacing: 10) {
            TopRow(snapshot: snapshot)
                .frame(height: 118)
            Rectangle().fill(Theme.divider).frame(height: 1)
            VStack(spacing: 2) {
                ForEach(rows) { segment in
                    let isCurrent = segment == snapshot.current
                    HStack(spacing: 8) {
                        Text(segment.start < dayStart ? "00:00" : Labels.start(segment.start, relativeTo: snapshot.date))
                            .font(.system(size: 12, weight: .medium).monospacedDigit())
                            .foregroundStyle(Theme.secondary)
                            .frame(width: 72, alignment: .leading)
                        Circle().fill(Theme.color(for: segment.title)).frame(width: 6, height: 6)
                        Text(segment.title)
                            .font(.system(size: 14, weight: isCurrent ? .bold : .regular))
                            .foregroundStyle(segment.isGap && !isCurrent ? Theme.secondary : Theme.primary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(isCurrent ? Theme.divider : Color.clear)
                    )
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - 鎖定畫面

private struct RectangularView: View {
    let snapshot: Snapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(snapshot.current.title)
                .font(.headline)
                .lineLimit(1)
                .widgetAccentable()
            Text("到 \(endLabel(snapshot))")
                .font(.caption)
            Text("下一個：\(snapshot.next?.title ?? "無")")
                .font(.caption)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
