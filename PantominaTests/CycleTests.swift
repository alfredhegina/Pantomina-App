import Testing
@testable import Pantomina

@Suite("Cycle")
struct CycleTests {
    @Test("dates on or before the 15th snap to the 15th")
    func midMonthFirstHalf() {
        #expect(Cycle.cycleFor(isoDate: "2026-08-01").anchorISO == "2026-08-15")
        #expect(Cycle.cycleFor(isoDate: "2026-08-15").anchorISO == "2026-08-15")
    }

    @Test("dates after the 15th snap to month-end")
    func midMonthSecondHalf() {
        #expect(Cycle.cycleFor(isoDate: "2026-08-16").anchorISO == "2026-08-31")
        #expect(Cycle.cycleFor(isoDate: "2026-06-28").anchorISO == "2026-06-30")
        #expect(Cycle.cycleFor(isoDate: "2026-06-30").anchorISO == "2026-06-30")
    }

    @Test("February non-leap month-end is the 28th")
    func februaryNonLeap() {
        #expect(Cycle.cycleFor(isoDate: "2026-02-20").anchorISO == "2026-02-28")
        #expect(Cycle.cycleFor(isoDate: "2026-02-28").anchorISO == "2026-02-28")
    }

    @Test("February leap month-end is the 29th")
    func februaryLeap() {
        #expect(Cycle.cycleFor(isoDate: "2024-02-20").anchorISO == "2024-02-29")
        #expect(Cycle.cycleFor(isoDate: "2024-02-29").anchorISO == "2024-02-29")
    }

    @Test("first half of February still uses the 15th")
    func februaryFirstHalf() {
        #expect(Cycle.cycleFor(isoDate: "2026-02-10").anchorISO == "2026-02-15")
    }

    @Test("anchors(inYear:) keeps only that calendar year, sorted")
    func anchorsInYear() {
        let all = [
            "2016-01-15", "2016-01-31",
            "2025-12-31",
            "2026-01-15", "2026-08-15", "2026-08-31",
            "2027-01-15",
        ]
        #expect(Cycle.anchors(inYear: 2026, from: all) == [
            "2026-01-15", "2026-08-15", "2026-08-31",
        ])
    }

    @Test("recentAnchors caps by limit around a center, chronological")
    func recentAnchorsCap() {
        var all: [String] = []
        var cursor = Cycle(anchorISO: "2020-01-15")
        for _ in 0..<40 {
            all.append(cursor.anchorISO)
            cursor = Cycle.nextHalfMonth(after: cursor)
        }
        let around = "2021-06-15"
        let capped = Cycle.recentAnchors(from: all, aroundISO: around, limit: 6)
        #expect(capped.count == 6)
        #expect(capped.contains(around) || capped.contains(Cycle.cycleFor(isoDate: around).anchorISO))
        #expect(capped == capped.sorted())
        #expect(capped.last! <= all.last!)
    }
}
