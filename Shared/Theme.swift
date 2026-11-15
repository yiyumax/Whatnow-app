import SwiftUI
import ScheduleCore

enum Theme {
    static let background = Color(hex: 0x161618)
    static let primary = Color(hex: 0xF5F5F7)
    static let secondary = Color(hex: 0x8E8E93)
    static let divider = Color(hex: 0x2C2C2E)
    static let card = Color(hex: 0x1F1F22)

    /// 依行程名稱決定顏色（小圓點和進度條）。由上往下，先符合的先用。
    static func color(for title: String) -> Color {
        if title.contains("雲端課") { return Color(hex: 0x5AA2FF) }
        if title.contains("上課") { return Color(hex: 0x8B94FF) }
        if title.contains("打工") || title.contains("上班") { return Color(hex: 0xFF9F45) }
        if title.contains("專題") { return Color(hex: 0xB98BFF) }
        if title == "自由時間" { return Color(hex: 0x4FD1C5) }
        if title.contains("餐") || title.contains("休息") || title.contains("準備") { return Color(hex: 0xD9B46A) }
        return Color(hex: 0x5FD08F)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

/// 倒數計時與進度條。用系統的計時樣式，到 0 就停住，不需要重新整理畫面。
enum Countdown {
    /// 保證下界不大於上界（`Text(timerInterval:)` 的要求）。
    static func range(from start: Date, to end: Date) -> ClosedRange<Date> {
        min(start, end)...max(start, end)
    }

    /// 從 `now` 倒數到 `end`，到 0 停住。
    static func text(from now: Date, to end: Date) -> Text {
        Text(timerInterval: range(from: now, to: end), countsDown: true)
    }
}

/// 會自己前進的進度條。
struct SegmentProgressBar: View {
    let segment: Segment
    var height: CGFloat = 5

    var body: some View {
        ProgressView(timerInterval: Countdown.range(from: segment.start, to: segment.end),
                     countsDown: false,
                     label: { EmptyView() },
                     currentValueLabel: { EmptyView() })
            .progressViewStyle(.linear)
            .tint(Theme.color(for: segment.title))
            .scaleEffect(x: 1, y: height / 4, anchor: .center)
            .frame(height: height)
    }
}
