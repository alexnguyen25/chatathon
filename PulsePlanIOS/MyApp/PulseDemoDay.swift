import Foundation

/// A fictional day for previewing PulsePlan. These samples and appointments are
/// synthetic, never written to Health or Calendar, and imply no medical cause.
struct PulseDemoDay {
    let now: Date
    let readings: [TodayHeartReading]
    let events: [CalendarEvent]

    init(date: Date = Date()) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        func time(_ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: startOfDay)
                ?? startOfDay.addingTimeInterval(Double(hour * 60 + minute) * 60)
        }

        now = time(11, 55)

        // Minutes after 09:00. The 10:00–10:20 gap intentionally demonstrates
        // intermittent wearable readings rather than continuous monitoring.
        // A deliberately dramatic fictional rise stays elevated through the
        // final half hour. The measurements alone do not establish stress.
        let samples: [(minute: Int, bpm: Double)] = [
            (0, 68), (5, 66), (10, 70), (15, 69), (20, 72), (25, 67),
            (30, 71), (35, 73), (40, 70), (45, 75), (50, 72), (55, 69),
            (60, 74), (80, 71), (85, 75),
            (90, 120), (95, 123), (100, 127), (105, 125), (110, 130),
            (115, 128), (120, 132), (125, 131), (130, 135),
            (135, 133), (140, 135), (145, 138),
            (150, 142), (155, 145), (160, 147), (165, 150), (170, 146),
            (174, 148)
        ]
        readings = samples.enumerated().map { index, sample in
            TodayHeartReading(
                id: UUID(uuid: (0x50, 0x55, 0x4C, 0x53, 0x45, 0x44, 0x45, 0x4D,
                                0x80, 0, 0, 0, 0, 0, 0, UInt8(index))),
                date: time(9 + sample.minute / 60, sample.minute % 60),
                bpm: sample.bpm,
                source: "Demo data · simulated wearable"
            )
        }

        // A fictional, meeting-heavy corporate day: six back-to-back morning
        // meetings, a noon opening, and another packed afternoon.
        events = [
            CalendarEvent(id: "demo-standup", title: "Team stand-up", startDate: time(9), endDate: time(9, 15), isAllDay: false),
            CalendarEvent(id: "demo-planning", title: "Sprint planning", startDate: time(9, 15), endDate: time(10), isAllDay: false),
            CalendarEvent(id: "demo-roadmap", title: "Product roadmap alignment", startDate: time(10), endDate: time(10, 30), isAllDay: false),
            CalendarEvent(id: "demo-review", title: "Design & engineering review", startDate: time(10, 30), endDate: time(11), isAllDay: false),
            CalendarEvent(id: "demo-stakeholders", title: "Stakeholder status review", startDate: time(11), endDate: time(11, 30), isAllDay: false),
            CalendarEvent(id: "demo-launch", title: "Launch readiness check-in", startDate: time(11, 30), endDate: time(12), isAllDay: false),
            CalendarEvent(id: "demo-lunch", title: "Lunch", startDate: time(12, 30), endDate: time(13), isAllDay: false),
            CalendarEvent(id: "demo-customer", title: "Customer escalation review", startDate: time(13), endDate: time(13, 30), isAllDay: false),
            CalendarEvent(id: "demo-cross-functional", title: "Cross-functional project sync", startDate: time(13, 30), endDate: time(14), isAllDay: false),
            CalendarEvent(id: "demo-budget", title: "Budget & resourcing", startDate: time(14), endDate: time(14, 30), isAllDay: false),
            CalendarEvent(id: "demo-vendor", title: "Vendor implementation call", startDate: time(14, 30), endDate: time(15), isAllDay: false),
            CalendarEvent(id: "demo-focus", title: "Focus: finish project brief", startDate: time(15), endDate: time(15, 30), isAllDay: false),
            CalendarEvent(id: "demo-manager", title: "Manager 1:1", startDate: time(15, 30), endDate: time(16), isAllDay: false),
            CalendarEvent(id: "demo-quarterly", title: "Quarterly business review prep", startDate: time(16), endDate: time(16, 45), isAllDay: false),
            CalendarEvent(id: "demo-global", title: "Global team handoff", startDate: time(16, 45), endDate: time(17, 30), isAllDay: false)
        ]
    }
}
