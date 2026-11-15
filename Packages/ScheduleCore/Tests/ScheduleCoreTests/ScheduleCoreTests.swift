import XCTest
@testable import ScheduleCore

/// 測試用的一週：2026-11-15（日）到 2026-11-22（日），台北時間。
final class ScheduleCoreTests: XCTestCase {

    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return c
    }()

    func at(_ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    var defaultEngine: ScheduleEngine {
        ScheduleEngine(schedule: DefaultSchedule.schedule, calendar: cal)
    }

    func engine(_ build: (inout WeekSchedule) -> Void) -> ScheduleEngine {
        var s = WeekSchedule()
        build(&s)
        return ScheduleEngine(schedule: s, calendar: cal)
    }

    // MARK: - 基本

    func testWeekdayIndex() {
        XCTAssertEqual(defaultEngine.weekdayIndex(of: at(15, 12)), 0)   // 星期日
        XCTAssertEqual(defaultEngine.weekdayIndex(of: at(16, 12)), 1)   // 星期一
        XCTAssertEqual(defaultEngine.weekdayIndex(of: at(21, 12)), 6)   // 星期六
    }

    func testTimeOfDay() {
        XCTAssertEqual(TimeOfDay.parse("08:00"), 480)
        XCTAssertEqual(TimeOfDay.parse("8:05"), 485)
        XCTAssertEqual(TimeOfDay.parse("24:00"), 1440)
        XCTAssertEqual(TimeOfDay.parse("00:00"), 0)
        XCTAssertNil(TimeOfDay.parse("24:01"))
        XCTAssertNil(TimeOfDay.parse("25:00"))
        XCTAssertNil(TimeOfDay.parse("12:60"))
        XCTAssertNil(TimeOfDay.parse("abc"))
        XCTAssertEqual(TimeOfDay.format(1440), "24:00")
        XCTAssertEqual(TimeOfDay.format(65), "01:05")
    }

    // MARK: - JSON

    func testDecodeDefaultSchedule() throws {
        let s = try ScheduleCodec.decode(text: DefaultSchedule.json)
        XCTAssertEqual(s.days[1].count, 9)
        XCTAssertEqual(s.days[0].count, 3)
        XCTAssertEqual(s.totalSlotCount, 49)
        XCTAssertEqual(s.gap[0], "休息")
        XCTAssertEqual(s.gap[3], "自由時間")
        XCTAssertEqual(s.days[1][0], Slot(start: 480, end: 900, title: "上課"))
    }

    func testEncodeDecodeRoundTrip() throws {
        let original = DefaultSchedule.schedule
        let data = try ScheduleCodec.encode(original)
        XCTAssertEqual(try ScheduleCodec.decode(data), original)

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["version"] as? Int, 1)
        let days = try XCTUnwrap(object["days"] as? [String: [[String]]])
        XCTAssertEqual(days["1"]?.first, ["08:00", "15:00", "上課"])
    }

    func testEncodeKeeps2400() throws {
        var s = WeekSchedule()
        s.days[2] = [Slot(start: 1320, end: 1440, title: "打工")]
        let text = ScheduleCodec.encodeText(s, pretty: false)
        XCTAssertTrue(text.contains("[\"22:00\",\"24:00\",\"打工\"]"))
        XCTAssertEqual(try ScheduleCodec.decode(text: text), s)
    }

    func testImportSplitsOvernightSlot() throws {
        let s = try ScheduleCodec.decode(text: #"{"days":{"1":[["23:00","01:00","夜班"]],"6":[["22:00","02:30","聚會"]]}}"#)
        XCTAssertEqual(s.days[1], [Slot(start: 1380, end: 1440, title: "夜班")])
        XCTAssertEqual(s.days[2], [Slot(start: 0, end: 60, title: "夜班")])
        XCTAssertEqual(s.days[6], [Slot(start: 1320, end: 1440, title: "聚會")])
        XCTAssertEqual(s.days[0], [Slot(start: 0, end: 150, title: "聚會")])   // 星期六跨到星期日
        XCTAssertEqual(s.gap, WeekSchedule.defaultGapNames)                    // 沒給 gap 就用預設
    }

    func testImportEndAtMidnightWrittenAsZero() throws {
        let s = try ScheduleCodec.decode(text: #"{"days":{"3":[["22:00","00:00","讀書"]]}}"#)
        XCTAssertEqual(s.days[3], [Slot(start: 1320, end: 1440, title: "讀書")])
        XCTAssertEqual(s.days[4], [])
    }

    func testImportCurlyQuotes() throws {
        let s = try ScheduleCodec.decode(text: "{“days”:{“1”:[[“08:00”,“09:00”,“上課”]]}}")
        XCTAssertEqual(s.days[1], [Slot(start: 480, end: 540, title: "上課")])
    }

    func testImportErrors() {
        XCTAssertThrowsError(try ScheduleCodec.decode(text: "不是 JSON")) {
            XCTAssertEqual($0 as? ScheduleError, .invalidJSON)
        }
        XCTAssertThrowsError(try ScheduleCodec.decode(text: #"{"version":1}"#)) {
            XCTAssertEqual($0 as? ScheduleError, .missingDays)
        }
        XCTAssertThrowsError(try ScheduleCodec.decode(text: #"{"days":{"1":[["25:00","26:00","x"]]}}"#)) {
            XCTAssertEqual($0 as? ScheduleError, .badTime(day: 1, value: "25:00"))
        }
        XCTAssertThrowsError(try ScheduleCodec.decode(text: #"{"days":{"1":[["08:00","09:00"]]}}"#)) {
            XCTAssertEqual($0 as? ScheduleError, .badEntry(day: 1))
        }
        XCTAssertThrowsError(try ScheduleCodec.decode(text: #"{"days":{"2":[["08:00","08:00","x"]]}}"#)) {
            XCTAssertEqual($0 as? ScheduleError, .zeroLength(day: 2, title: "x"))
        }
        XCTAssertThrowsError(try ScheduleCodec.decode(text: #"{"days":{"1":[["08:00","10:00","A"],["09:00","11:00","B"]]}}"#)) {
            XCTAssertEqual($0 as? ScheduleError, .overlap(day: 1, first: "A", second: "B"))
        }
        // 跨午夜拆出來的那一段撞到隔天的行程，也要擋下。
        XCTAssertThrowsError(try ScheduleCodec.decode(text: #"{"days":{"1":[["23:00","02:00","A"]],"2":[["01:00","03:00","B"]]}}"#)) {
            XCTAssertEqual($0 as? ScheduleError, .overlap(day: 2, first: "A", second: "B"))
        }
    }

    // MARK: - 驗證

    func testValidator() {
        let day = [Slot(start: 480, end: 600, title: "A"), Slot(start: 720, end: 780, title: "B")]
        XCTAssertNil(ScheduleValidator.issue(for: Slot(start: 600, end: 720, title: "C"), in: day))   // 剛好接上不算重疊
        XCTAssertNil(ScheduleValidator.issue(for: Slot(start: 1380, end: 1440, title: "C"), in: day)) // 到 24:00
        XCTAssertEqual(ScheduleValidator.issue(for: Slot(start: 590, end: 700, title: "C"), in: day), .overlaps(day[0]))
        XCTAssertEqual(ScheduleValidator.issue(for: Slot(start: 500, end: 500, title: "C"), in: day), .endNotAfterStart)
        XCTAssertEqual(ScheduleValidator.issue(for: Slot(start: 900, end: 800, title: "C"), in: day), .endNotAfterStart)
        XCTAssertEqual(ScheduleValidator.issue(for: Slot(start: 900, end: 960, title: "  "), in: day), .emptyTitle)
        XCTAssertEqual(ScheduleValidator.issue(for: Slot(start: 900, end: 1500, title: "C"), in: day), .outOfRange)
        // 修改自己那一筆時不跟自己比
        XCTAssertNil(ScheduleValidator.issue(for: Slot(start: 480, end: 660, title: "A"), in: day, ignoring: 0))
        XCTAssertEqual(ScheduleValidator.issue(for: Slot(start: 480, end: 730, title: "A"), in: day, ignoring: 0), .overlaps(day[1]))
    }

    // MARK: - 補空檔

    func testEveryDayIsFullyCovered() {
        let e = defaultEngine
        for day in 15...21 {
            let segs = e.daySegments(forDayContaining: at(day, 12))
            XCTAssertEqual(segs.first?.start, at(day))
            XCTAssertEqual(segs.last?.end, at(day + 1))
            for i in 1..<segs.count {
                XCTAssertEqual(segs[i - 1].end, segs[i].start, "11/\(day) 第 \(i) 段沒有接上")
                XCTAssertLessThan(segs[i].start, segs[i].end)
            }
        }
    }

    func testGapFillOnThursday() {
        // 星期四 10:30–11:00、13:40–14:00 沒排，要補自由時間
        let segs = defaultEngine.daySegments(forDayContaining: at(19, 12))
        let gaps = segs.filter(\.isGap)
        XCTAssertEqual(gaps.map(\.start), [at(19, 0), at(19, 10, 30), at(19, 13, 40), at(19, 23)])
        XCTAssertEqual(gaps.map(\.end), [at(19, 9), at(19, 11), at(19, 14), at(20)])
        XCTAssertTrue(gaps.allSatisfy { $0.title == "自由時間" })
    }

    // MARK: - 目前 / 下一個

    func testCurrentBeforeFirstSlot() {
        let snap = defaultEngine.snapshot(at: at(16, 7))
        XCTAssertEqual(snap.current.title, "自由時間")
        XCTAssertTrue(snap.current.isGap)
        XCTAssertEqual(snap.current.start, at(16))      // 星期日的空檔叫「休息」，名稱不同，不合併
        XCTAssertEqual(snap.current.end, at(16, 8))
        XCTAssertEqual(snap.next?.title, "上課")
        XCTAssertEqual(snap.next?.start, at(16, 8))
    }

    func testCurrentExactlyAtBoundary() {
        let snap = defaultEngine.snapshot(at: at(16, 8))
        XCTAssertEqual(snap.current.title, "上課")
        XCTAssertFalse(snap.current.isGap)
        XCTAssertEqual(snap.current.start, at(16, 8))
        XCTAssertEqual(snap.current.end, at(16, 15))
        XCTAssertEqual(snap.next?.title, "休息")
        XCTAssertEqual(snap.next?.start, at(16, 15))
        XCTAssertEqual(Labels.end(snap.current.end, relativeTo: snap.date, calendar: cal), "15:00")
    }

    func testOneSecondBeforeBoundaryIsStillPrevious() {
        let snap = defaultEngine.snapshot(at: at(16, 15).addingTimeInterval(-1))
        XCTAssertEqual(snap.current.title, "上課")
    }

    func testTodayListAndRemaining() {
        let snap = defaultEngine.snapshot(at: at(16, 21, 30))
        // 星期一：開頭空檔 + 9 個行程 + 結尾空檔
        XCTAssertEqual(snap.today.count, 11)
        XCTAssertEqual(snap.remainingToday.map(\.title), ["回家休息", "線性代數", "休息", "複習作業系統筆記", "自由時間"])
    }

    // MARK: - 跨午夜合併

    func testGapMergesAcrossMidnight() {
        let snap = defaultEngine.snapshot(at: at(16, 23, 45))
        XCTAssertEqual(snap.current.title, "自由時間")
        XCTAssertEqual(snap.current.start, at(16, 23, 30))
        XCTAssertEqual(snap.current.end, at(17, 8))
        XCTAssertEqual(Labels.end(snap.current.end, relativeTo: snap.date, calendar: cal), "明天 08:00")
        XCTAssertEqual(snap.next?.title, "上課")
    }

    func testMergedGapAfterMidnightKeepsOriginalStart() {
        let snap = defaultEngine.snapshot(at: at(17, 0, 30))
        XCTAssertEqual(snap.current.start, at(16, 23, 30))
        XCTAssertEqual(snap.current.end, at(17, 8))
        XCTAssertEqual(Labels.end(snap.current.end, relativeTo: snap.date, calendar: cal), "08:00")
    }

    func testTuesdayNightMergesIntoWednesdayMorning() {
        let snap = defaultEngine.snapshot(at: at(17, 23))
        XCTAssertEqual(snap.current.start, at(17, 22, 30))
        XCTAssertEqual(snap.current.end, at(18, 9))
    }

    func testDifferentGapNamesDoNotMerge() {
        // 星期六晚上「自由時間」→ 星期日「休息」
        let sat = defaultEngine.snapshot(at: at(21, 20))
        XCTAssertEqual(sat.current.title, "自由時間")
        XCTAssertEqual(sat.current.start, at(21, 18))
        XCTAssertEqual(sat.current.end, at(22))
        XCTAssertEqual(Labels.end(sat.current.end, relativeTo: sat.date, calendar: cal), "24:00")
        XCTAssertEqual(sat.next?.title, "休息")
        XCTAssertEqual(sat.next?.end, at(22, 10))

        // 星期日晚上「休息」→ 星期一「自由時間」
        let sun = defaultEngine.snapshot(at: at(15, 22))
        XCTAssertEqual(sun.current.title, "休息")
        XCTAssertEqual(sun.current.start, at(15, 20, 30))
        XCTAssertEqual(sun.current.end, at(16))
        XCTAssertEqual(sun.next?.title, "自由時間")
        XCTAssertEqual(sun.next?.end, at(16, 8))
    }

    func testGapDoesNotMergeWithEventOfSameName() {
        let e = engine { $0.days[1] = [Slot(start: 1380, end: 1440, title: "自由時間")] }
        let snap = e.snapshot(at: at(16, 23, 30))
        XCTAssertFalse(snap.current.isGap)
        XCTAssertEqual(snap.current.end, at(17))
        XCTAssertEqual(snap.next?.isGap, true)
        XCTAssertEqual(snap.next?.start, at(17))
    }

    // MARK: - 24:00 結束

    func testSlotEndingAt2400() {
        let e = engine { $0.days[1] = [Slot(start: 1380, end: 1440, title: "打工")] }
        let day = e.daySegments(forDayContaining: at(16, 12))
        XCTAssertEqual(day.last?.title, "打工")
        XCTAssertEqual(day.last?.end, at(17))

        let snap = e.snapshot(at: at(16, 23, 30))
        XCTAssertEqual(snap.current.end, at(17))
        XCTAssertEqual(Labels.end(snap.current.end, relativeTo: snap.date, calendar: cal), "24:00")
        XCTAssertEqual(snap.next?.title, "自由時間")
        XCTAssertEqual(snap.next?.start, at(17))
    }

    func testSplitOvernightEventIsShownAsOne() {
        let e = engine {
            $0.days[1] = [Slot(start: 1320, end: 1440, title: "打工")]
            $0.days[2] = [Slot(start: 0, end: 120, title: "打工")]
        }
        let before = e.snapshot(at: at(16, 23))
        XCTAssertFalse(before.current.isGap)
        XCTAssertEqual(before.current.start, at(16, 22))
        XCTAssertEqual(before.current.end, at(17, 2))
        XCTAssertEqual(Labels.end(before.current.end, relativeTo: before.date, calendar: cal), "明天 02:00")

        let tl = e.timeline(from: at(16, 21), hours: 24)
        XCTAssertEqual(tl.entries.map(\.date), [at(16, 21), at(16, 22), at(17), at(17, 2)])
        XCTAssertEqual(tl.entries[2].current.title, "打工")
        XCTAssertEqual(tl.entries[2].current.end, at(17, 2))
        XCTAssertEqual(Labels.end(tl.entries[2].current.end, relativeTo: tl.entries[2].date, calendar: cal), "02:00")
    }

    // MARK: - Timeline

    func testTimelineHasEntryAtEveryBoundary() {
        let tl = defaultEngine.timeline(from: at(16, 7), hours: 24)
        let expected = [
            at(16, 7),                                   // 現在
            at(16, 8), at(16, 15), at(16, 15, 30), at(16, 17, 15), at(16, 18),
            at(16, 21), at(16, 22), at(16, 22, 50), at(16, 23), at(16, 23, 30),
            at(17)                                       // 午夜（「明天」的字樣要換）
        ]
        XCTAssertEqual(tl.entries.map(\.date), expected)
        XCTAssertEqual(tl.reloadDate, at(17))

        XCTAssertEqual(tl.entries.map(\.current.title), [
            "自由時間", "上課", "休息", "作業系統雲端課", "晚餐、前往打工", "打工",
            "回家休息", "線性代數", "休息", "複習作業系統筆記", "自由時間", "自由時間"
        ])
        // 邊界上的 entry，目前時段就是從那一刻開始
        for entry in tl.entries.dropFirst().dropLast() {
            XCTAssertEqual(entry.current.start, entry.date)
        }
        // 午夜那一個 entry 仍是同一段合併後的空檔
        XCTAssertEqual(tl.entries.last?.current.start, at(16, 23, 30))
        XCTAssertEqual(tl.entries.last?.current.end, at(17, 8))
    }

    func testDefaultTimelineCoversAtLeast24Hours() throws {
        let now = at(18, 13, 7)
        let e = defaultEngine
        let tl = e.timeline(from: now)
        let dates = tl.entries.map(\.date)

        XCTAssertEqual(dates.first, now)
        XCTAssertEqual(dates, dates.sorted())
        XCTAssertEqual(Set(dates).count, dates.count)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(dates.last), now.addingTimeInterval(24 * 3600))
        XCTAssertEqual(tl.reloadDate, dates.last)

        // 48 小時內每一個時段邊界都要有 entry
        let limit = now.addingTimeInterval(48 * 3600)
        let boundaries = e.segments(fromDayContaining: now, days: 4)
            .map(\.start)
            .filter { $0 > now && $0 <= limit }
        XCTAssertFalse(boundaries.isEmpty)
        for b in boundaries {
            XCTAssertTrue(dates.contains(b), "少了 \(b) 的 entry")
        }
    }

    func testCountdownNeverRunsPastZero() {
        // 每個 entry 的結束時間都在它之後，而且下一個 entry 不會晚於這一段的結束時間，
        // 所以倒數到 0 的那一刻一定換成下一個 entry。
        let tl = defaultEngine.timeline(from: at(20, 6, 40))
        for (i, entry) in tl.entries.enumerated() {
            XCTAssertLessThanOrEqual(entry.current.start, entry.date)
            XCTAssertGreaterThan(entry.current.end, entry.date)
            XCTAssertEqual(entry.next?.start, entry.current.end)
            if i + 1 < tl.entries.count {
                XCTAssertLessThanOrEqual(tl.entries[i + 1].date, entry.current.end)
            }
        }
    }

    // MARK: - 整週空白

    func testBlankWeek() {
        let e = engine { _ in }
        let snap = e.snapshot(at: at(18, 12))
        XCTAssertEqual(snap.current.title, "自由時間")
        XCTAssertTrue(snap.current.isGap)
        XCTAssertEqual(snap.current.start, at(16))     // 星期一 00:00
        XCTAssertEqual(snap.current.end, at(22))       // 到星期日 00:00
        XCTAssertEqual(Labels.end(snap.current.end, relativeTo: snap.date, calendar: cal), "週六 24:00")
        XCTAssertEqual(snap.next?.title, "休息")
        XCTAssertEqual(snap.today.count, 1)

        let tl = e.timeline(from: at(18, 12))
        XCTAssertEqual(tl.entries.map(\.date), [at(18, 12), at(19), at(20)])
        XCTAssertTrue(tl.entries.allSatisfy { $0.current.title == "自由時間" })
        XCTAssertEqual(tl.reloadDate, at(20))
    }

    func testBlankWeekWithIdenticalGapNames() {
        let e = engine { $0.gap = Array(repeating: "沒事", count: 7) }
        let now = at(18, 12)
        let snap = e.snapshot(at: now)
        XCTAssertEqual(snap.current.title, "沒事")
        XCTAssertTrue(snap.upcoming.isEmpty)
        XCTAssertGreaterThan(snap.current.end, now.addingTimeInterval(48 * 3600))

        let tl = e.timeline(from: now)
        XCTAssertEqual(tl.entries.count, 3)
        XCTAssertGreaterThan(tl.reloadDate, now)

        let short = e.timeline(from: now, hours: 6)
        XCTAssertEqual(short.entries.count, 1)
        XCTAssertGreaterThan(short.reloadDate, now)
    }

    func testEmptyGapNameFallsBackToDefault() {
        let e = engine { $0.gap[1] = "  " }
        XCTAssertEqual(e.snapshot(at: at(16, 12)).current.title, "自由時間")
    }

    // MARK: - 文字

    func testLabels() {
        let now = at(16, 10)
        XCTAssertEqual(Labels.end(at(16, 15), relativeTo: now, calendar: cal), "15:00")
        XCTAssertEqual(Labels.end(at(17), relativeTo: now, calendar: cal), "24:00")
        XCTAssertEqual(Labels.end(at(17, 8), relativeTo: now, calendar: cal), "明天 08:00")
        XCTAssertEqual(Labels.end(at(18), relativeTo: now, calendar: cal), "明天 24:00")
        XCTAssertEqual(Labels.end(at(18, 9), relativeTo: now, calendar: cal), "後天 09:00")
        XCTAssertEqual(Labels.end(at(20, 9), relativeTo: now, calendar: cal), "週五 09:00")
        XCTAssertEqual(Labels.start(at(17), relativeTo: now, calendar: cal), "明天 00:00")
        XCTAssertEqual(Labels.start(at(16, 15), relativeTo: now, calendar: cal), "15:00")
    }

    // MARK: - 通知

    func testNotificationPlan() {
        let plan = NotificationPlan.make(for: DefaultSchedule.schedule)
        XCTAssertEqual(plan.items.count, 49)
        XCTAssertEqual(plan.dropped, 0)
        XCTAssertLessThanOrEqual(plan.items.count, NotificationPlan.systemLimit)

        let limited = NotificationPlan.make(for: DefaultSchedule.schedule, limit: 10)
        XCTAssertEqual(limited.items.count, 10)
        XCTAssertEqual(limited.dropped, 39)
    }

    func testNotificationPlanNeverExceeds64() {
        var s = WeekSchedule()
        for w in 0..<7 {
            s.days[w] = (0..<12).map { Slot(start: $0 * 60, end: $0 * 60 + 30, title: "行程\($0)") }
        }
        let plan = NotificationPlan.make(for: s)
        XCTAssertEqual(plan.items.count, 64)
        XCTAssertEqual(plan.dropped, 20)
    }

    func testNotificationSkipsOvernightContinuation() {
        var s = WeekSchedule()
        s.days[1] = [Slot(start: 1320, end: 1440, title: "打工")]
        s.days[2] = [Slot(start: 0, end: 120, title: "打工"), Slot(start: 480, end: 540, title: "上課")]
        let plan = NotificationPlan.make(for: s)
        XCTAssertEqual(plan.items.map(\.title), ["打工", "上課"])
        XCTAssertEqual(plan.items.map(\.weekday), [1, 2])
    }
}
