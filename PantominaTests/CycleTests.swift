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
}
