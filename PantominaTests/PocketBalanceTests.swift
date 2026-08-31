import Testing
@testable import Pantomina

@Suite("PocketBalance")
struct PocketBalanceTests {
    private func leg(
        amountC: Int,
        flow: FlowType,
        status: RealizedStatus = .realized,
        date: String = "2026-08-01",
        note: String? = nil
    ) -> PocketBalance.Leg {
        PocketBalance.Leg(
            amountC: amountC,
            flow: flow,
            realizedStatus: status,
            purchaseDate: date,
            note: note
        )
    }

    @Test("cash asset sums income minus expense; skips projected")
    func cashTrail() {
        let legs = [
            leg(amountC: 10_000_00, flow: .income),
            leg(amountC: 3_000_00, flow: .expense),
            leg(amountC: 500_00, flow: .expense, status: .projected),
        ]
        let r = PocketBalance.compute(
            kind: .cash,
            legs: legs,
            loanBalanceC: nil,
            lastConfirmedC: nil,
            spokenForC: 0
        )
        #expect(r.balanceC == 7_000_00)
        #expect(r.source == .ledger)
        #expect(r.spokenForC == 0)
    }

    @Test("credit card liability: expenses increase owed")
    func creditCard() {
        let legs = [
            leg(amountC: 2_000_00, flow: .expense),
            leg(amountC: 500_00, flow: .expense),
        ]
        let r = PocketBalance.compute(
            kind: .creditCard,
            legs: legs,
            loanBalanceC: nil,
            lastConfirmedC: nil,
            spokenForC: 0
        )
        #expect(r.balanceC == 2_500_00)
        #expect(r.source == .ledger)
    }

    @Test("loan uses derived balance not legs")
    func loanDerived() {
        let r = PocketBalance.compute(
            kind: .loan,
            legs: [leg(amountC: 99_000_00, flow: .expense)],
            loanBalanceC: 628_916_76,
            lastConfirmedC: nil,
            spokenForC: 0
        )
        #expect(r.balanceC == 628_916_76)
        #expect(r.source == .ledger)
    }

    @Test("investment uses lastConfirmed; unknown without it")
    func externalConfirmed() {
        let unknown = PocketBalance.compute(
            kind: .investment,
            legs: [],
            loanBalanceC: nil,
            lastConfirmedC: nil,
            spokenForC: 0
        )
        #expect(unknown.source == .unknown)
        #expect(unknown.balanceC == 0)

        let known = PocketBalance.compute(
            kind: .investment,
            legs: [],
            loanBalanceC: nil,
            lastConfirmedC: 19_686_23,
            spokenForC: 0
        )
        #expect(known.balanceC == 19_686_23)
        #expect(known.source == .confirmed)
    }

    @Test("spoken-for does not change balanceC")
    func spokenForSeparate() {
        let r = PocketBalance.compute(
            kind: .bank,
            legs: [leg(amountC: 50_000_00, flow: .income)],
            loanBalanceC: nil,
            lastConfirmedC: nil,
            spokenForC: 10_000_00
        )
        #expect(r.balanceC == 50_000_00)
        #expect(r.spokenForC == 10_000_00)
        #expect(r.feelsSpendableC == 40_000_00)
    }

    @Test("isExternalKind matches Balance Day thin list")
    func externalKinds() {
        #expect(PocketBalance.isExternalKind(.investment))
        #expect(PocketBalance.isExternalKind(.savingsAsset))
        #expect(PocketBalance.isExternalKind(.govMandated))
        #expect(!PocketBalance.isExternalKind(.cash))
        #expect(!PocketBalance.isExternalKind(.bank))
    }

    @Test("statement builds running balance after each leg")
    func statement() {
        let legs = [
            leg(amountC: 1_000_00, flow: .income, date: "2026-08-01", note: "Pay"),
            leg(amountC: 200_00, flow: .expense, date: "2026-08-02", note: "Coffee"),
        ]
        let rows = PocketBalance.statement(kind: .cash, legs: legs)
        #expect(rows.count == 2)
        #expect(rows[0].balanceAfterC == 1_000_00)
        #expect(rows[1].balanceAfterC == 800_00)
        #expect(rows[1].note == "Coffee")
    }

    @Test("receivable override prefers Love Tab amount")
    func receivableOverride() {
        let r = PocketBalance.compute(
            kind: .receivable,
            legs: [leg(amountC: 1_00, flow: .income)],
            loanBalanceC: nil,
            lastConfirmedC: nil,
            spokenForC: 0,
            receivableBalanceC: 177_697_81
        )
        #expect(r.balanceC == 177_697_81)
        #expect(r.source == .ledger)
    }

    @Test("Snapshot.line maps pocket sources")
    func snapshotLineMapping() {
        let derived = Snapshot.line(
            accountId: "cash",
            kind: .cash,
            pocket: PocketBalance.Result(balanceC: 100, source: .ledger, spokenForC: 0)
        )
        #expect(derived.source == .derived)
        #expect(!derived.isLiability)

        let confirmed = Snapshot.line(
            accountId: "mp2",
            kind: .savingsAsset,
            pocket: PocketBalance.Result(balanceC: 50, source: .confirmed, spokenForC: 0)
        )
        #expect(confirmed.source == .confirmed)
        #expect(confirmed.countsTowardSavingsAssets)

        let unknown = Snapshot.line(
            accountId: "stocks",
            kind: .investment,
            pocket: PocketBalance.Result(balanceC: 0, source: .unknown, spokenForC: 0)
        )
        #expect(unknown.source == .stale)
    }

    @Test("asOf excludes legs after cycle end")
    func asOfCutsLaterLegs() {
        let legs = [
            leg(amountC: 10_000_00, flow: .income, date: "2026-08-10"),
            leg(amountC: 2_000_00, flow: .expense, date: "2026-08-20"),
            leg(amountC: 1_000_00, flow: .expense, date: "2026-09-05"),
        ]
        let mid = PocketBalance.compute(
            kind: .cash,
            legs: legs,
            loanBalanceC: nil,
            lastConfirmedC: nil,
            spokenForC: 0,
            asOfISO: "2026-08-31"
        )
        #expect(mid.balanceC == 8_000_00)

        let early = PocketBalance.compute(
            kind: .cash,
            legs: legs,
            loanBalanceC: nil,
            lastConfirmedC: nil,
            spokenForC: 0,
            asOfISO: "2026-08-15"
        )
        #expect(early.balanceC == 10_000_00)
    }

    @Test("effectiveDate prefers realizedDate")
    func effectiveDatePrefersRealized() {
        let legs = [
            PocketBalance.Leg(
                amountC: 500_00,
                flow: .expense,
                realizedStatus: .realized,
                purchaseDate: "2026-07-20",
                realizedDate: "2026-08-15",
                note: nil
            )
        ]
        let before = PocketBalance.compute(
            kind: .creditCard,
            legs: legs,
            loanBalanceC: nil,
            lastConfirmedC: nil,
            spokenForC: 0,
            asOfISO: "2026-07-31"
        )
        #expect(before.balanceC == 0)

        let after = PocketBalance.compute(
            kind: .creditCard,
            legs: legs,
            loanBalanceC: nil,
            lastConfirmedC: nil,
            spokenForC: 0,
            asOfISO: "2026-08-15"
        )
        #expect(after.balanceC == 500_00)
    }

    @Test("cycle window statement includes opening balance")
    func cycleWindowStatement() {
        let legs = [
            leg(amountC: 5_000_00, flow: .income, date: "2026-08-01"),
            leg(amountC: 1_000_00, flow: .expense, date: "2026-08-20"),
            leg(amountC: 500_00, flow: .expense, date: "2026-09-10"),
        ]
        // Aug 31 cycle window is (Aug 15, Aug 31]
        let result = PocketBalance.statementInCycle(
            kind: .cash,
            legs: legs,
            cycleAnchorISO: "2026-08-31"
        )
        #expect(result.openingC == 5_000_00)
        #expect(result.rows.count == 1)
        #expect(result.rows[0].signedAmountC == -1_000_00)
        #expect(result.rows[0].balanceAfterC == 4_000_00)
    }

    @Test("external confirmed after asOf is unknown")
    func externalFutureConfirmHidden() {
        let r = PocketBalance.compute(
            kind: .investment,
            legs: [],
            loanBalanceC: nil,
            lastConfirmedC: 19_686_23,
            spokenForC: 0,
            asOfISO: "2026-07-31",
            lastConfirmedCycleISO: "2026-08-31"
        )
        #expect(r.source == .unknown)
    }
}
