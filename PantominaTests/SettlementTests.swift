import Testing
@testable import Pantomina

@Suite("AllocationRouting")
struct AllocationRoutingTests {
    @Test("Fern pays household fifty-fifty keeps both shares")
    func fernPaysShared() {
        let intended = AllocationDefaults.fiftyFifty(amountC: 10_000_00)
        let recorded = AllocationRouting.record(
            intended: intended,
            accountScope: .household,
            paidBy: .fern
        )
        #expect(recorded.fern == 5_000_00)
        #expect(recorded.stark == 5_000_00)
    }

    @Test("Stark pays household shared item zeros stark allocation")
    func starkPaysShared() {
        let intended = AllocationDefaults.fiftyFifty(amountC: 10_000_00)
        let recorded = AllocationRouting.record(
            intended: intended,
            accountScope: .household,
            paidBy: .stark
        )
        #expect(recorded.fern == 5_000_00)
        #expect(recorded.stark == 0)
    }

    @Test("Stark pays household custom keeps fern share only")
    func starkPaysCustom() {
        let intended = Allocation(fern: 3_000_00, stark: 7_000_00)
        let recorded = AllocationRouting.record(
            intended: intended,
            accountScope: .household,
            paidBy: .stark
        )
        #expect(recorded.fern == 3_000_00)
        #expect(recorded.stark == 0)
    }

    @Test("personal scope is unchanged by routing")
    func personalUnchanged() {
        let intended = Allocation(fern: 0, stark: 4_000_00)
        let recorded = AllocationRouting.record(
            intended: intended,
            accountScope: .stark,
            paidBy: .stark
        )
        #expect(recorded == intended)
    }
}

@Suite("Settlement")
struct SettlementTests {
    @Test("Aug 15 golden: due 12813.34, contrib 5000, remaining 7813.34")
    func aug15Golden() {
        let rows: [Settlement.LedgerRow] = [
            .init(
                realizedDate: "2026-08-15",
                realizedStatus: .realized,
                accountScope: .household,
                allocationStarkC: 8_000_00,
                amountC: 16_000_00,
                settlementRole: nil
            ),
            .init(
                realizedDate: "2026-08-15",
                realizedStatus: .realized,
                accountScope: .household,
                allocationStarkC: 4_813_34,
                amountC: 9_626_68,
                settlementRole: nil
            ),
            .init(
                realizedDate: "2026-08-15",
                realizedStatus: .realized,
                accountScope: .household,
                allocationStarkC: 0,
                amountC: 5_000_00,
                settlementRole: .contribution
            ),
        ]
        // Contribution is amountC 5000; due is sum of stark allocs on household spend only.
        let result = Settlement.compute(
            cycleAnchorISO: "2026-08-15",
            rows: rows,
            carriedCreditC: 0,
            tabBeforeC: 16_988_447
        )
        #expect(result.dueC == 1_281_334)
        #expect(result.contributedC == 500_000)
        #expect(result.remainingC == 781_334)
        #expect(result.status == .partial)
        #expect(result.creditOutC == 0)
        #expect(result.tabAfterC == 17_769_781)
    }

    @Test("Stark-paid shared item does not add to due")
    func starkPaidNoDue() {
        let rows: [Settlement.LedgerRow] = [
            .init(
                realizedDate: "2026-08-15",
                realizedStatus: .realized,
                accountScope: .household,
                allocationStarkC: 0,
                amountC: 10_000_00,
                settlementRole: nil
            ),
        ]
        let result = Settlement.compute(
            cycleAnchorISO: "2026-08-15",
            rows: rows,
            carriedCreditC: 0,
            tabBeforeC: 0
        )
        #expect(result.dueC == 0)
        #expect(result.remainingC == 0)
        #expect(result.status == .settled)
    }

    @Test("overpay nets tab, floors at 0, carries credit")
    func overpayNetsTab() {
        let rows: [Settlement.LedgerRow] = [
            .init(
                realizedDate: "2026-06-30",
                realizedStatus: .realized,
                accountScope: .household,
                allocationStarkC: 10_000_00,
                amountC: 20_000_00,
                settlementRole: nil
            ),
            .init(
                realizedDate: "2026-06-30",
                realizedStatus: .realized,
                accountScope: .household,
                allocationStarkC: 0,
                amountC: 12_000_00,
                settlementRole: .contribution
            ),
        ]
        let result = Settlement.compute(
            cycleAnchorISO: "2026-06-30",
            rows: rows,
            carriedCreditC: 0,
            tabBeforeC: 500_00
        )
        #expect(result.dueC == 10_000_00)
        #expect(result.contributedC == 12_000_00)
        #expect(result.remainingC == 0)
        #expect(result.status == .overpaid)
        #expect(result.tabAfterC == 0)
        #expect(result.creditOutC == 1_500_00)
    }

    @Test("carried credit reduces remaining")
    func carriedCredit() {
        let rows: [Settlement.LedgerRow] = [
            .init(
                realizedDate: "2026-07-15",
                realizedStatus: .realized,
                accountScope: .household,
                allocationStarkC: 10_000_00,
                amountC: 20_000_00,
                settlementRole: nil
            ),
            .init(
                realizedDate: "2026-07-15",
                realizedStatus: .realized,
                accountScope: .household,
                allocationStarkC: 0,
                amountC: 8_000_00,
                settlementRole: .contribution
            ),
        ]
        let result = Settlement.compute(
            cycleAnchorISO: "2026-07-15",
            rows: rows,
            carriedCreditC: 2_000_00,
            tabBeforeC: 1_000_00
        )
        #expect(result.remainingC == 0)
        #expect(result.status == .settled)
        #expect(result.tabAfterC == 1_000_00)
        #expect(result.creditOutC == 0)
    }

    @Test("pending rows do not count toward due")
    func pendingExcluded() {
        let rows: [Settlement.LedgerRow] = [
            .init(
                realizedDate: nil,
                realizedStatus: .pending,
                accountScope: .household,
                allocationStarkC: 9_999_00,
                amountC: 19_998_00,
                settlementRole: nil
            ),
        ]
        let result = Settlement.compute(
            cycleAnchorISO: "2026-08-15",
            rows: rows,
            carriedCreditC: 0,
            tabBeforeC: 0
        )
        #expect(result.dueC == 0)
    }
}

@Suite("Settlement.householdShares")
struct HouseholdSharesTests {
    @Test("Fern pays household cash 50/50: both shares count for selected cycle")
    func fernPaysCash() {
        let rows: [Settlement.LedgerRow] = [
            .init(
                realizedDate: "2026-08-31",
                realizedStatus: .realized,
                accountScope: .household,
                allocationStarkC: 500_00,
                allocationFernC: 500_00,
                amountC: 1_000_00,
                settlementRole: nil,
                isStatement: false,
                proposedRealizedDate: nil
            ),
        ]
        let shares = Settlement.householdShares(cycleAnchorISO: "2026-08-31", rows: rows)
        #expect(shares.fernC == 500_00)
        #expect(shares.starkC == 500_00)
        #expect(shares.pendingCount == 0)
    }

    @Test("Stark pays household cash 50/50: Fern share only, settle due stays 0")
    func starkPaysCash() {
        let intended = AllocationDefaults.fiftyFifty(amountC: 1_000_00)
        let recorded = AllocationRouting.record(
            intended: intended,
            accountScope: .household,
            paidBy: .stark
        )
        let rows: [Settlement.LedgerRow] = [
            .init(
                realizedDate: "2026-08-31",
                realizedStatus: .realized,
                accountScope: .household,
                allocationStarkC: recorded.stark,
                allocationFernC: recorded.fern,
                amountC: 1_000_00,
                settlementRole: nil,
                isStatement: false,
                proposedRealizedDate: nil
            ),
        ]
        let shares = Settlement.householdShares(cycleAnchorISO: "2026-08-31", rows: rows)
        #expect(shares.fernC == 500_00)
        #expect(shares.starkC == 0)
        let settle = Settlement.compute(
            cycleAnchorISO: "2026-08-31",
            rows: rows,
            carriedCreditC: 0,
            tabBeforeC: 0
        )
        #expect(settle.dueC == 0)
    }

    @Test("Stark pays pending CC: Fern share lands on proposed statement cycle")
    func starkPaysPendingCC() {
        let rows: [Settlement.LedgerRow] = [
            .init(
                realizedDate: nil,
                realizedStatus: .pending,
                accountScope: .household,
                allocationStarkC: 0,
                allocationFernC: 500_00,
                amountC: 1_000_00,
                settlementRole: nil,
                isStatement: true,
                proposedRealizedDate: "2026-09-15"
            ),
        ]
        let shares = Settlement.householdShares(cycleAnchorISO: "2026-09-15", rows: rows)
        #expect(shares.fernC == 500_00)
        #expect(shares.starkC == 0)
        #expect(shares.pendingCount == 1)
        let other = Settlement.householdShares(cycleAnchorISO: "2026-08-31", rows: rows)
        #expect(other.fernC == 0)
        #expect(other.pendingCount == 0)
    }

    @Test("personal scope excluded from household shares")
    func personalExcluded() {
        let rows: [Settlement.LedgerRow] = [
            .init(
                realizedDate: "2026-08-31",
                realizedStatus: .realized,
                accountScope: .fern,
                allocationStarkC: 250_00,
                allocationFernC: 250_00,
                amountC: 500_00,
                settlementRole: nil,
                isStatement: false,
                proposedRealizedDate: nil
            ),
        ]
        let shares = Settlement.householdShares(cycleAnchorISO: "2026-08-31", rows: rows)
        #expect(shares.fernC == 0)
        #expect(shares.starkC == 0)
    }
}
