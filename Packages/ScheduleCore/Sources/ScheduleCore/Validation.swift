import Foundation

/// 單一時段的問題（編輯畫面用）。
public enum SlotIssue: Equatable, Sendable {
    case emptyTitle
    case outOfRange
    case endNotAfterStart
    case overlaps(Slot)

    public var message: String {
        switch self {
        case .emptyTitle:
            return "請輸入名稱。"
        case .outOfRange:
            return "時間必須在 00:00 到 24:00 之間。"
        case .endNotAfterStart:
            return "結束時間必須晚於開始時間。跨過半夜的行程請拆成兩段：前一天到 24:00，隔天從 00:00 開始。"
        case .overlaps(let other):
            return "和「\(other.title)」(\(TimeOfDay.format(other.start))–\(TimeOfDay.format(other.end))) 重疊了。"
        }
    }
}

public enum ScheduleValidator {
    /// 檢查一個時段能不能放進某一天。`ignoring` 是正在修改的那一筆的索引（不跟自己比）。
    public static func issue(for slot: Slot, in day: [Slot], ignoring index: Int? = nil) -> SlotIssue? {
        if slot.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .emptyTitle }
        if slot.start < 0 || slot.end > 1440 { return .outOfRange }
        if slot.end <= slot.start { return .endNotAfterStart }
        for (i, other) in day.enumerated() where i != index {
            if slot.start < other.end && other.start < slot.end { return .overlaps(other) }
        }
        return nil
    }

    /// 找出一天裡第一組重疊的時段。
    public static func firstOverlap(in day: [Slot]) -> (Slot, Slot)? {
        let sorted = day.sorted { ($0.start, $0.end) < ($1.start, $1.end) }
        guard sorted.count > 1 else { return nil }
        for i in 1..<sorted.count where sorted[i].start < sorted[i - 1].end {
            return (sorted[i - 1], sorted[i])
        }
        return nil
    }
}
