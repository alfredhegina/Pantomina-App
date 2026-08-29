import Testing
@testable import Pantomina

@Suite("Realization")
struct RealizationTests {
    @Test("instant cash on 06/28 realizes on 06/30")
    func cashInstant() {
        let d = Realization.decide(
            purchaseISO: "2026-06-28",
            settlement: .instant,
            statementCutoff: nil
        )
        #expect(d.status == .realized)
        #expect(d.realizedDate == "2026-06-30")
        #expect(d.proposedRealizedDate == nil)
    }

    @Test("BDO JCB swipe on 07/04 proposes 08/15")
    func bdoJcbPending() {
        let d = Realization.decide(
            purchaseISO: "2026-07-04",
            settlement: .statement,
            statementCutoff: 15
        )
        #expect(d.status == .pending)
        #expect(d.realizedDate == nil)
        #expect(d.proposedRealizedDate == "2026-08-15")
    }

    @Test("statement cutoff 30 proposes next month-end after current cycle")
    func cutoffThirty() {
        let d = Realization.decide(
            purchaseISO: "2026-07-04",
            settlement: .statement,
            statementCutoff: 30
        )
        #expect(d.proposedRealizedDate == "2026-07-31")
    }

    @Test("batch realize sets status and realizedDate; clears proposal")
    func batchRealize() {
        let pending = Realization.PendingRow(
            id: "a",
            amountC: 100_00,
            proposedRealizedDate: "2026-08-15"
        )
        let out = Realization.batchRealize(
            rows: [pending],
            selectedIds: ["a"],
            toAnchorISO: "2026-08-15"
        )
        #expect(out.count == 1)
        #expect(out[0].id == "a")
        #expect(out[0].status == .realized)
        #expect(out[0].realizedDate == "2026-08-15")
        #expect(out[0].proposedRealizedDate == nil)
    }

    @Test("TBD sum is sum of pending amounts")
    func tbdSum() {
        let rows = [
            Realization.TBDItem(id: "1", amountC: 500_00, status: .pending),
            Realization.TBDItem(id: "2", amountC: 250_00, status: .pending),
            Realization.TBDItem(id: "3", amountC: 999_00, status: .realized),
        ]
        #expect(Realization.tbdSumCentavos(rows) == 750_00)
    }
}

@Suite("Cycle.nextStatement")
struct CycleNextStatementTests {
    @Test("next statement after mid-July cycle with cutoff 15 is Aug 15")
    func nextAug15() {
        #expect(
            Cycle.nextStatementCycle(isoDate: "2026-07-04", cutoff: 15).anchorISO
                == "2026-08-15"
        )
    }
}
