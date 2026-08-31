import Testing
@testable import Pantomina

@Suite("Fund")
struct FundTests {
    private func emergency(balanceC: Int = 50_000_00, iousC: Int = 0, log: [Fund.IOUEntry] = []) -> Fund.Snapshot {
        Fund.Snapshot(
            id: "fund-emergency",
            name: "Emergency",
            purpose: .emergency,
            owner: .fern,
            homeAccountId: "acct-bpi",
            targetC: 100_000_00,
            balanceC: balanceC,
            iousC: iousC,
            iouLog: log,
            raidOrder: 3
        )
    }

    private func loanPayoff(balanceC: Int = 20_000_00) -> Fund.Snapshot {
        Fund.Snapshot(
            id: "fund-loan-payoff",
            name: "Loan payoff",
            purpose: .loanPayoff,
            owner: .fern,
            homeAccountId: "acct-bpi",
            targetC: nil,
            balanceC: balanceC,
            iousC: 0,
            iouLog: [],
            raidOrder: 1
        )
    }

    private func sinking(balanceC: Int = 10_000_00) -> Fund.Snapshot {
        Fund.Snapshot(
            id: "fund-sinking",
            name: "Sinking",
            purpose: .sinking,
            owner: .fern,
            homeAccountId: "acct-bpi",
            targetC: 30_000_00,
            balanceC: balanceC,
            iousC: 0,
            iouLog: [],
            raidOrder: 2
        )
    }

    @Test("effective balance is cash left in the envelope (raid already dipped balance)")
    func effectiveBalance() {
        let fund = emergency(balanceC: 43_500_00, iousC: 6_500_00)
        #expect(Fund.effectiveBalanceC(fund) == 43_500_00)
        #expect(Fund.owedBackC(fund) == 6_500_00)
    }

    @Test("raid order is loan_payoff then sinking then emergency")
    func raidOrder() {
        let ordered = Fund.raidCandidates(from: [emergency(), sinking(), loanPayoff()])
        #expect(ordered.map(\.id) == ["fund-loan-payoff", "fund-sinking", "fund-emergency"])
    }

    @Test("raid creates IOU with absorb attribution; dips balance")
    func raidCreatesIOUAbsorb() {
        let before = emergency(balanceC: 50_000_00)
        let result = Fund.applyRaid(
            to: before,
            amountC: 6_500_00,
            dateISO: "2026-09-15",
            reason: "Cover bills",
            attribution: .absorb
        )
        #expect(result != nil)
        let after = result!
        #expect(after.balanceC == 43_500_00)
        #expect(after.iousC == 6_500_00)
        #expect(after.iouLog.count == 1)
        #expect(after.iouLog[0].amountC == 6_500_00)
        #expect(after.iouLog[0].repaidC == 0)
        #expect(after.iouLog[0].attribution == .absorb)
        #expect(Fund.effectiveBalanceC(after) == 43_500_00)
    }

    @Test("raid rejects amount above balance")
    func raidRejectsOverBalance() {
        let fund = emergency(balanceC: 1_000_00)
        #expect(Fund.applyRaid(to: fund, amountC: 2_000_00, dateISO: "2026-09-15", reason: "Short", attribution: .absorb) == nil)
    }

    @Test("raid with addToDue attribution is recorded on the IOU")
    func raidAddToDueAttribution() {
        let after = Fund.applyRaid(
            to: emergency(),
            amountC: 2_000_00,
            dateISO: "2026-09-15",
            reason: "Shortfall",
            attribution: .addToDue
        )!
        #expect(after.iouLog[0].attribution == .addToDue)
    }

    @Test("repay oldest IOU first; partial then complete")
    func repayOldestFirst() {
        var fund = emergency(balanceC: 40_000_00, iousC: 0)
        fund = Fund.applyRaid(to: fund, amountC: 3_000_00, dateISO: "2026-08-15", reason: "First", attribution: .absorb)!
        fund = Fund.applyRaid(to: fund, amountC: 2_000_00, dateISO: "2026-09-15", reason: "Second", attribution: .absorb)!
        #expect(fund.iousC == 5_000_00)

        fund = Fund.repayOldest(in: fund, amountC: 1_000_00, restoreBalance: true)!
        #expect(fund.iouLog[0].repaidC == 1_000_00)
        #expect(fund.iouLog[1].repaidC == 0)
        #expect(fund.iousC == 4_000_00)
        #expect(fund.balanceC == 36_000_00) // 40k − 5k raids + 1k repay

        fund = Fund.repayOldest(in: fund, amountC: 4_000_00, restoreBalance: true)!
        #expect(fund.iousC == 0)
        #expect(fund.balanceC == 40_000_00)
        #expect(fund.iouLog.allSatisfy { $0.repaidC == $0.amountC })
    }

    @Test("whole-again estimate at zero pace is nil; with monthly repay pace returns ISO")
    func wholeAgainAt() {
        let fund = emergency(
            balanceC: 40_000_00,
            iousC: 6_500_00,
            log: [
                Fund.IOUEntry(
                    id: "iou-1",
                    dateISO: "2026-09-15",
                    amountC: 6_500_00,
                    reason: "Bills",
                    repaidC: 0,
                    attribution: .absorb
                )
            ]
        )
        #expect(Fund.wholeAgainAtISO(fund: fund, monthlyRepayC: 0, fromISO: "2026-09-15") == nil)
        let date = Fund.wholeAgainAtISO(fund: fund, monthlyRepayC: 3_250_00, fromISO: "2026-09-15")
        #expect(date == "2026-11-15")
    }

    @Test("topUp increases balance; rejects non-positive")
    func topUp() {
        let before = emergency(balanceC: 10_000_00)
        let after = Fund.topUp(to: before, amountC: 5_000_00)!
        #expect(after.balanceC == 15_000_00)
        #expect(after.iousC == before.iousC)
        #expect(Fund.topUp(to: before, amountC: 0) == nil)
    }

    @Test("spend pocket is Fern cash bank ewallet only")
    func spendPocket() {
        #expect(Fund.isSpendPocket(kind: .cash, scope: .fern))
        #expect(Fund.isSpendPocket(kind: .bank, scope: .fern))
        #expect(Fund.isSpendPocket(kind: .ewallet, scope: .fern))
        #expect(!Fund.isSpendPocket(kind: .creditCard, scope: .fern))
        #expect(!Fund.isSpendPocket(kind: .cash, scope: .household))
    }
}
