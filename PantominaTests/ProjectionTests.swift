import Testing
@testable import Pantomina

@Suite("Projection")
struct ProjectionTests {
    private let rentRule = Projection.Rule(
        id: "rule-rent",
        amountC: 20_000_00,
        accountId: "acct-cash",
        categoryId: "cat-rent",
        paidBy: .fern,
        allocationFernC: 10_000_00,
        allocationStarkC: 10_000_00,
        cadence: .biweekly,
        anchorDay: .both,
        amountBehavior: .exact,
        startCycleISO: "2026-08-15",
        endCycleISO: nil,
        paused: false,
        title: "Rent · House",
        flow: .expense,
        fixedVariable: .fixed
    )

    @Test("projects exact rule onto matching cycle anchor")
    func projectsOntoCycle() {
        let rows = Projection.rows(forCycleISO: "2026-09-15", rules: [rentRule])
        #expect(rows.count == 1)
        #expect(rows[0].amountC == 20_000_00)
        #expect(rows[0].status == .projected)
        #expect(rows[0].proposedRealizedDate == "2026-09-15")
        #expect(rows[0].recurringRuleId == "rule-rent")
    }

    @Test("paused and out-of-range rules produce nothing")
    func pausedSkipped() {
        var paused = rentRule
        paused.paused = true
        #expect(Projection.rows(forCycleISO: "2026-09-15", rules: [paused]).isEmpty)

        var future = rentRule
        future.startCycleISO = "2026-10-15"
        #expect(Projection.rows(forCycleISO: "2026-09-15", rules: [future]).isEmpty)
    }

    @Test("actualTotal excludes projected amounts")
    func actualsExcludeProjected() {
        let lines = [
            Projection.AmountLine(amountC: 100_00, status: .realized),
            Projection.AmountLine(amountC: 200_00, status: .projected),
            Projection.AmountLine(amountC: 50_00, status: .pending),
        ]
        #expect(Projection.actualTotalCentavos(lines) == 100_00)
    }

    @Test("confirmExact realizes on cycle anchor")
    func confirmExact() {
        let draft = Projection.rows(forCycleISO: "2026-09-15", rules: [rentRule])[0]
        let confirmed = Projection.confirmExact(draft, cycleISO: "2026-09-15")
        #expect(confirmed.status == .realized)
        #expect(confirmed.realizedDate == "2026-09-15")
        #expect(confirmed.proposedRealizedDate == nil)
        #expect(confirmed.amountC == 20_000_00)
    }

    @Test("confirmEstimate uses override amount")
    func confirmEstimate() {
        var estimate = rentRule
        estimate.amountBehavior = .estimate
        let draft = Projection.rows(forCycleISO: "2026-09-15", rules: [estimate])[0]
        let confirmed = Projection.confirmEstimate(draft, cycleISO: "2026-09-15", amountC: 18_500_00)
        #expect(confirmed.status == .realized)
        #expect(confirmed.amountC == 18_500_00)
        #expect(confirmed.realizedDate == "2026-09-15")
    }
}
