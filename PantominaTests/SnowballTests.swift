import Testing
@testable import Pantomina

@Suite("Snowball")
struct SnowballTests {
    private func loan(
        id: String,
        order: Int?,
        batch: Int?,
        monthlyC: Int = 10_000_00,
        strategy: Loan.Strategy? = nil,
        status: Loan.Status = .active
    ) -> Loan.Snapshot {
        Loan.Snapshot(
            id: id,
            lender: "Bank",
            description: id,
            purpose: "Payoff",
            owner: .fern,
            principalC: 100_000_00,
            totalLoanC: 120_000_00,
            termMonths: 12,
            paidMonths: 2,
            monthlyC: monthlyC,
            cutoff: 15,
            startDateISO: "2025-01-15",
            endDateISO: "2026-01-15",
            aprPercent: 12,
            snowballOrder: order,
            snowballBatch: batch,
            strategy: strategy,
            linkedReceivableAccountId: nil,
            journal: [],
            status: status,
            paymentAccountId: "acct-bpi"
        )
    }

    private func fund(
        id: String,
        purpose: Fund.Purpose,
        balanceC: Int,
        iousC: Int,
        log: [Fund.IOUEntry] = [],
        raidOrder: Int
    ) -> Fund.Snapshot {
        Fund.Snapshot(
            id: id,
            name: id,
            purpose: purpose,
            owner: .fern,
            homeAccountId: "acct-bpi",
            targetC: nil,
            balanceC: balanceC,
            iousC: iousC,
            iouLog: log,
            raidOrder: raidOrder
        )
    }

    @Test("queue is current batch only, ordered by snowballOrder; nil batch joins batch 1")
    func orderedQueueCurrentBatch() {
        let loans = [
            loan(id: "b2-a", order: 1, batch: 2),
            loan(id: "b1-b", order: 2, batch: 1),
            loan(id: "b1-a", order: 1, batch: 1),
            loan(id: "done", order: 1, batch: 1, status: .done),
            loan(id: "nil-batch", order: 3, batch: nil),
        ]
        let queue = Snowball.orderedQueue(loans: loans)
        #expect(queue.map(\.id) == ["b1-a", "b1-b", "nil-batch"])
    }

    @Test("nil batch sorts with batch 1; nil order last within batch")
    func nilOrderAndBatchDefaults() {
        let queue = Snowball.orderedQueue(loans: [
            loan(id: "late", order: nil, batch: 1),
            loan(id: "early", order: 1, batch: nil),
        ])
        #expect(queue.map(\.id) == ["early", "late"])
    }

    @Test("sweep pays oldest IOUs across funds before parking remainder")
    func proposeSweepIOUBeforePark() {
        let older = Fund.IOUEntry(
            id: "iou-old",
            dateISO: "2026-07-15",
            amountC: 4_000_00,
            reason: "Bills",
            repaidC: 0,
            attribution: .absorb
        )
        let newer = Fund.IOUEntry(
            id: "iou-new",
            dateISO: "2026-08-15",
            amountC: 3_000_00,
            reason: "Bills",
            repaidC: 0,
            attribution: .absorb
        )
        let emergency = fund(
            id: "fund-emergency",
            purpose: .emergency,
            balanceC: 40_000_00,
            iousC: 4_000_00,
            log: [older],
            raidOrder: 3
        )
        let sinking = fund(
            id: "fund-sinking",
            purpose: .sinking,
            balanceC: 10_000_00,
            iousC: 3_000_00,
            log: [newer],
            raidOrder: 2
        )
        let payoff = fund(
            id: "fund-loan-payoff",
            purpose: .loanPayoff,
            balanceC: 25_000_00,
            iousC: 0,
            raidOrder: 1
        )

        let plan = Snowball.proposeSweep(
            surplusC: 10_000_00,
            funds: [emergency, sinking, payoff],
            loanPayoffFundId: "fund-loan-payoff"
        )
        #expect(plan != nil)
        let p = plan!
        #expect(p.iouRepays == [
            Snowball.IOURepay(fundId: "fund-emergency", amountC: 4_000_00),
            Snowball.IOURepay(fundId: "fund-sinking", amountC: 3_000_00),
        ])
        #expect(p.parkToLoanPayoffC == 3_000_00)
        #expect(p.loanPayoffFundId == "fund-loan-payoff")
        #expect(p.totalAllocatedC == 10_000_00)
    }

    @Test("sweep with no IOUs parks entire surplus into loan-payoff fund")
    func proposeSweepParkOnly() {
        let payoff = fund(
            id: "fund-loan-payoff",
            purpose: .loanPayoff,
            balanceC: 5_000_00,
            iousC: 0,
            raidOrder: 1
        )
        let plan = Snowball.proposeSweep(
            surplusC: 2_500_00,
            funds: [payoff],
            loanPayoffFundId: "fund-loan-payoff"
        )
        #expect(plan?.iouRepays.isEmpty == true)
        #expect(plan?.parkToLoanPayoffC == 2_500_00)
    }

    @Test("sweep returns nil when surplus invalid or no loan-payoff fund for park remainder")
    func proposeSweepGuards() {
        #expect(
            Snowball.proposeSweep(surplusC: 0, funds: [], loanPayoffFundId: "x") == nil
        )
        let emergency = fund(
            id: "fund-emergency",
            purpose: .emergency,
            balanceC: 1,
            iousC: 500_00,
            log: [
                Fund.IOUEntry(
                    id: "iou",
                    dateISO: "2026-07-15",
                    amountC: 500_00,
                    reason: "Bills",
                    repaidC: 0,
                    attribution: .absorb
                )
            ],
            raidOrder: 3
        )
        // All surplus absorbed by IOU — park fund id may be nil.
        let plan = Snowball.proposeSweep(
            surplusC: 500_00,
            funds: [emergency],
            loanPayoffFundId: nil
        )
        #expect(plan?.parkToLoanPayoffC == 0)
        #expect(plan?.iouRepays.first?.amountC == 500_00)
    }

    @Test("ready to pay when loan-payoff covers next monthly in current batch")
    func readyToPay() {
        let loans = [loan(id: "ub", order: 1, batch: 1, monthlyC: 17_469_91)]
        #expect(Snowball.isReadyToPay(loanPayoffBalanceC: 17_469_91, loans: loans))
        #expect(!Snowball.isReadyToPay(loanPayoffBalanceC: 17_469_90, loans: loans))
        #expect(Snowball.nextTargetMonthlyC(loans: loans) == 17_469_91)
    }

    @Test("park another month allowed for prepay (and nil); blocked for park_to_maturity")
    func parkAnotherMonth() {
        let prepay = loan(id: "a", order: 1, batch: 1, monthlyC: 5_000_00, strategy: .prepay)
        let park = loan(id: "b", order: 2, batch: 1, monthlyC: 5_000_00, strategy: .parkToMaturity)
        let unset = loan(id: "c", order: 3, batch: 1, monthlyC: 5_000_00, strategy: nil)
        #expect(Snowball.parkAnotherMonthAmountC(loan: prepay) == 5_000_00)
        #expect(Snowball.parkAnotherMonthAmountC(loan: park) == nil)
        #expect(Snowball.parkAnotherMonthAmountC(loan: unset) == 5_000_00)
    }
}
