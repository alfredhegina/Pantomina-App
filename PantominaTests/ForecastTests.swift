import Testing
@testable import Pantomina

@Suite("Forecast")
struct ForecastTests {
    @Test("breathing room when expected in exceeds committed plus typical variable")
    func breathingRoom() {
        let result = Forecast.compute(
            expectedIn: [
                Forecast.Line(id: "sal", title: "Salary", amountC: 50_000_00, reason: .income),
            ],
            committed: [
                Forecast.Line(id: "rent", title: "Rent", amountC: 20_000_00, reason: .fixed),
                Forecast.Line(id: "cc", title: "Card lands", amountC: 5_000_00, reason: .cardLandsHere),
            ],
            typicalVariableC: 10_000_00
        )
        #expect(result.expectedInC == 50_000_00)
        #expect(result.committedC == 25_000_00)
        #expect(result.typicalVariableC == 10_000_00)
        #expect(result.breathingRoomC == 15_000_00)
        #expect(result.verdict == .breathingRoom)
    }

    @Test("over when committed plus variable exceed expected in")
    func over() {
        let result = Forecast.compute(
            expectedIn: [
                Forecast.Line(id: "sal", title: "Salary", amountC: 20_000_00, reason: .income),
            ],
            committed: [
                Forecast.Line(id: "rent", title: "Rent", amountC: 25_000_00, reason: .fixed),
            ],
            typicalVariableC: 5_000_00
        )
        #expect(result.breathingRoomC == -10_000_00)
        #expect(result.verdict == .over)
    }

    @Test("build from projection drafts and pending CC excludes projected from nowhere else")
    func fromInputs() {
        let projected = [
            Projection.DraftRow(
                id: "p1",
                recurringRuleId: "r1",
                title: "Rent · House",
                amountC: 20_000_00,
                accountId: "a",
                categoryId: "c",
                paidBy: .fern,
                allocationFernC: 10_000_00,
                allocationStarkC: 10_000_00,
                status: .projected,
                realizedDate: nil,
                proposedRealizedDate: "2026-09-15",
                amountBehavior: .exact,
                flow: .expense,
                fixedVariable: .fixed
            ),
        ]
        let pendingCC = [
            Forecast.PendingCard(id: "t1", title: "Groceries", amountC: 1_000_00),
        ]
        let income = [
            Forecast.IncomeRow(id: "i1", title: "Salary", amountC: 40_000_00),
        ]
        let built = Forecast.build(
            cycleISO: "2026-09-15",
            incomeRows: income,
            projected: projected,
            pendingCards: pendingCC,
            trancheLines: [],
            typicalVariableC: 8_000_00
        )
        #expect(built.expectedInC == 40_000_00)
        #expect(built.committed.contains { $0.reason == .fixed })
        #expect(built.committed.contains { $0.reason == .cardLandsHere })
        #expect(built.committedC == 21_000_00)
    }

    @Test("Due next is empty when the next cycle has no committed bills")
    func dueNextEmpty() {
        let strip = HomeDueNext.strip(
            todayISO: "2026-09-01",
            upcoming: [
                (anchorISO: "2026-09-30", committed: []),
                (anchorISO: "2026-10-15", committed: []),
            ]
        )
        #expect(strip == nil)
    }

    @Test("Due next uses the following cycle, caps two cards, and keeps the full bill count")
    func dueNextNextCycleTwoCards() {
        let committed = [
            Forecast.Line(id: "rent", title: "Rent · House", amountC: 20_000_00, reason: .fixed),
            Forecast.Line(id: "net", title: "Internet PLDT", amountC: 1_799_00, reason: .fixed),
            Forecast.Line(id: "power", title: "Electricity", amountC: 3_000_00, reason: .estimate),
        ]
        let strip = HomeDueNext.strip(
            todayISO: "2026-09-01",
            upcoming: [
                (anchorISO: "2026-09-30", committed: committed),
            ]
        )
        #expect(strip != nil)
        #expect(strip?.dueISO == "2026-09-30")
        #expect(strip?.billCount == 3)
        #expect(strip?.totalC == 24_799_00)
        #expect(strip?.cards.count == 2)
        #expect(strip?.cards[0].title == "Rent · House")
        #expect(strip?.cards[0].amountC == 20_000_00)
        #expect(strip?.cards[0].daysUntil == 29)
        #expect(strip?.cards[1].title == "Internet PLDT")
    }

    @Test("Due next skips an empty half-month so 15th bills still surface")
    func dueNextSkipsEmptyCycle() {
        let committed = [
            Forecast.Line(id: "rent", title: "Rent · House", amountC: 20_000_00, reason: .fixed),
        ]
        let strip = HomeDueNext.strip(
            todayISO: "2026-09-01",
            upcoming: [
                (anchorISO: "2026-09-30", committed: []),
                (anchorISO: "2026-10-15", committed: committed),
            ]
        )
        #expect(strip?.dueISO == "2026-10-15")
        #expect(strip?.cards.first?.daysUntil == 44)
    }
}
