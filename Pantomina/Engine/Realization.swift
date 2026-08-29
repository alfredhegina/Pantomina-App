import Foundation

/// Pure §4.3 realization rules. UI never reimplements these.
enum Realization {
    struct Decision: Equatable, Sendable {
        var status: RealizedStatus
        var realizedDate: String?
        var proposedRealizedDate: String?
    }

    struct PendingRow: Equatable, Sendable {
        var id: String
        var amountC: Int
        var proposedRealizedDate: String?
    }

    struct BatchResult: Equatable, Sendable {
        var id: String
        var status: RealizedStatus
        var realizedDate: String?
        var proposedRealizedDate: String?
    }

    struct TBDItem: Equatable, Sendable {
        var id: String
        var amountC: Int
        var status: RealizedStatus
    }

    static func decide(
        purchaseISO: String,
        settlement: SettlementKind,
        statementCutoff: Int?
    ) -> Decision {
        switch settlement {
        case .instant:
            let anchor = Cycle.cycleFor(isoDate: purchaseISO).anchorISO
            return Decision(status: .realized, realizedDate: anchor, proposedRealizedDate: nil)
        case .statement:
            let cutoff = statementCutoff ?? 15
            let proposed = Cycle.nextStatementCycle(isoDate: purchaseISO, cutoff: cutoff).anchorISO
            return Decision(status: .pending, realizedDate: nil, proposedRealizedDate: proposed)
        }
    }

    static func batchRealize(
        rows: [PendingRow],
        selectedIds: Set<String>,
        toAnchorISO: String
    ) -> [BatchResult] {
        rows.filter { selectedIds.contains($0.id) }.map { row in
            BatchResult(
                id: row.id,
                status: .realized,
                realizedDate: toAnchorISO,
                proposedRealizedDate: nil
            )
        }
    }

    /// Convenience overload for array of selected ids.
    static func batchRealize(
        rows: [PendingRow],
        selectedIds: [String],
        toAnchorISO: String
    ) -> [BatchResult] {
        batchRealize(rows: rows, selectedIds: Set(selectedIds), toAnchorISO: toAnchorISO)
    }

    static func tbdSumCentavos(_ items: [TBDItem]) -> Int {
        items.filter { $0.status == .pending }.reduce(0) { $0 + $1.amountC }
    }

    static func pendingForStatement(
        rows: [PendingRow],
        accountMatch: (String) -> Bool,
        proposedAnchorISO: String
    ) -> [PendingRow] {
        rows.filter {
            accountMatch($0.id) && $0.proposedRealizedDate == proposedAnchorISO
        }
    }
}
