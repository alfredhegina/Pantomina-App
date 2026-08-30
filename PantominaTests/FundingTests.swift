import Testing
@testable import Pantomina

@Suite("Funding")
struct FundingTests {
    private func pruLifePlan() -> Funding.Plan {
        Funding.Plan(
            id: "fp-prulife",
            billRecurringRuleId: "rule-prulife",
            billTitle: "PruLife",
            sourceAccountId: "cash",
            payoutCycleISO: "2026-09-30",
            tranches: [
                Funding.Tranche(cycleISO: "2026-09-15", amountC: 5_000_00, reserved: false),
                Funding.Tranche(cycleISO: "2026-09-30", amountC: 5_000_00, reserved: false),
            ]
        )
    }

    @Test("status starts funded 0/2 then 1/2; last reserve auto-pays")
    func pruLifeWalkthrough() {
        var plan = pruLifePlan()
        #expect(Funding.status(plan) == .funded(done: 0, total: 2))

        plan = Funding.markReserved(planId: plan.id, cycleISO: "2026-09-15", in: [plan])[0]
        #expect(Funding.status(plan) == .funded(done: 1, total: 2))
        #expect(!plan.paid)

        plan = Funding.markReserved(planId: plan.id, cycleISO: "2026-09-30", in: [plan])[0]
        #expect(Funding.status(plan) == .paid)
        #expect(plan.paid)
        #expect(plan.reserveC == 10_000_00)
    }

    @Test("forecast charges tranche to its own cycle not full payout")
    func forecastChargesTranchePerCycle() {
        let plan = pruLifePlan()
        let mid = Funding.forecastLines(cycleISO: "2026-09-15", plans: [plan])
        #expect(mid.count == 1)
        #expect(mid[0].amountC == 5_000_00)
        #expect(mid[0].reason == .tranche)

        let payout = Funding.forecastLines(cycleISO: "2026-09-30", plans: [plan])
        #expect(payout.count == 1)
        #expect(payout[0].amountC == 5_000_00)

        let other = Funding.forecastLines(cycleISO: "2026-08-15", plans: [plan])
        #expect(other.isEmpty)
    }

    @Test("exclude funded bill rule ids from projection committed")
    func excludeRuleIds() {
        let plan = pruLifePlan()
        #expect(Funding.excludedBillRuleIds(plans: [plan]) == ["rule-prulife"])
    }

    @Test("checklist set-aside tasks; no payout row; paid plan hidden")
    func checklistTranches() {
        var plan = pruLifePlan()
        let mid = Funding.checklistTranches(cycleISO: "2026-09-15", plans: [plan])
        #expect(mid.count == 1)
        #expect(mid[0].title == "Set aside PruLife")
        #expect(mid[0].paymentsRequired == 2)
        #expect(mid[0].paymentsDone == 0)
        #expect(mid[0].amountC == 5_000_00)

        plan = Funding.markReserved(planId: plan.id, cycleISO: "2026-09-15", in: [plan])[0]
        let after = Funding.checklistTranches(cycleISO: "2026-09-15", plans: [plan])
        #expect(after[0].paymentsDone == 1)
        #expect(after[0].done)

        let payoutCycle = Funding.checklistTranches(cycleISO: "2026-09-30", plans: [plan])
        #expect(payoutCycle.count == 1)
        #expect(!payoutCycle[0].id.hasPrefix("payout-"))

        plan = Funding.markReserved(planId: plan.id, cycleISO: "2026-09-30", in: [plan])[0]
        #expect(Funding.checklistTranches(cycleISO: "2026-09-30", plans: [plan]).isEmpty)
    }
}
