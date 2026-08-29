import Foundation

/// How a transaction participates in cycle settlement (§4.1).
enum SettlementRole: String, Codable, Sendable {
    case contribution
    case receivable
    case fundMove = "fund_move"
    case loanPayment = "loan_payment"
}

enum SettlementStatus: String, Codable, Sendable {
    case settled
    case partial
    case overpaid
}

/// §4.2 — store allocations after asymmetric routing for household instruments.
enum AllocationRouting {
    /// Applies contributor-pays asymmetry: when Stark pays a household (or business) item,
    /// only Fern's share is stored (`stark = 0`). Personal scopes pass through unchanged.
    static func record(
        intended: Allocation,
        accountScope: Scope,
        paidBy: PersonId
    ) -> Allocation {
        switch accountScope {
        case .household, .business:
            if paidBy == .stark {
                return Allocation(fern: intended.fern, stark: 0)
            }
            return intended
        case .fern, .stark:
            return intended
        }
    }
}

/// §4.1 — pure cycle settlement and Love Tab math.
enum Settlement {
    struct LedgerRow: Equatable, Sendable {
        var realizedDate: String?
        var realizedStatus: RealizedStatus
        var accountScope: Scope
        var allocationStarkC: Int
        /// Fern's stored share (§4.2). Used for covers/planning, not Love Tab due.
        var allocationFernC: Int = 0
        var amountC: Int
        var settlementRole: SettlementRole?
        var isStatement: Bool = false
        var proposedRealizedDate: String? = nil
    }

    struct Result: Equatable, Sendable {
        var dueC: Int
        var contributedC: Int
        var carriedCreditC: Int
        var remainingC: Int
        var creditOutC: Int
        var tabAfterC: Int
        var status: SettlementStatus
    }

    /// Household covers for a cycle: realized on this anchor, or pending statement proposed here.
    struct HouseholdShares: Equatable, Sendable {
        var fernC: Int
        var starkC: Int
        var pendingCount: Int
    }

    static func compute(
        cycleAnchorISO: String,
        rows: [LedgerRow],
        carriedCreditC: Int,
        tabBeforeC: Int
    ) -> Result {
        let inCycle = rows.filter { row in
            guard row.realizedStatus == .realized,
                  let date = row.realizedDate
            else { return false }
            return Cycle.cycleFor(isoDate: date).anchorISO == cycleAnchorISO
        }

        let dueC = inCycle
            .filter { $0.settlementRole == nil && ($0.accountScope == .household) }
            .reduce(0) { $0 + $1.allocationStarkC }

        let contributedC = inCycle
            .filter { $0.settlementRole == .contribution }
            .reduce(0) { $0 + $1.amountC }

        let applied = contributedC + max(0, carriedCreditC)
        let shortfall = dueC - applied

        if shortfall > 0 {
            return Result(
                dueC: dueC,
                contributedC: contributedC,
                carriedCreditC: carriedCreditC,
                remainingC: shortfall,
                creditOutC: 0,
                tabAfterC: tabBeforeC + shortfall,
                status: .partial
            )
        }

        if shortfall == 0 {
            return Result(
                dueC: dueC,
                contributedC: contributedC,
                carriedCreditC: carriedCreditC,
                remainingC: 0,
                creditOutC: 0,
                tabAfterC: tabBeforeC,
                status: .settled
            )
        }

        // Overpay: net the Love Tab first; surplus past zero becomes next-cycle credit.
        let overpayC = -shortfall
        let tabNet = tabBeforeC - overpayC
        if tabNet >= 0 {
            return Result(
                dueC: dueC,
                contributedC: contributedC,
                carriedCreditC: carriedCreditC,
                remainingC: 0,
                creditOutC: 0,
                tabAfterC: tabNet,
                status: .overpaid
            )
        }
        return Result(
            dueC: dueC,
            contributedC: contributedC,
            carriedCreditC: carriedCreditC,
            remainingC: 0,
            creditOutC: -tabNet,
            tabAfterC: 0,
            status: .overpaid
        )
    }

    /// Fern/Stark shares of household spends landing on this cycle (planning / statement covers).
    /// Does not create reverse Love Tab debt. Includes pending statement rows by `proposedRealizedDate`.
    static func householdShares(cycleAnchorISO: String, rows: [LedgerRow]) -> HouseholdShares {
        let relevant = rows.filter { row in
            guard row.settlementRole == nil, row.accountScope == .household else { return false }
            if row.realizedStatus == .realized, let date = row.realizedDate {
                return Cycle.cycleFor(isoDate: date).anchorISO == cycleAnchorISO
            }
            if row.realizedStatus == .pending, row.isStatement,
               row.proposedRealizedDate == cycleAnchorISO
            {
                return true
            }
            return false
        }
        return HouseholdShares(
            fernC: relevant.reduce(0) { $0 + $1.allocationFernC },
            starkC: relevant.reduce(0) { $0 + $1.allocationStarkC },
            pendingCount: relevant.filter { $0.realizedStatus == .pending }.count
        )
    }

    /// Running Love Tab + credit across ordered cycle anchors.
    struct CycleSnapshot: Equatable, Sendable {
        var anchorISO: String
        var result: Result
    }

    static func cycleAnchors(in rows: [LedgerRow]) -> [String] {
        var set = Set(rows.compactMap { row -> String? in
            guard row.realizedStatus == .realized, let date = row.realizedDate else { return nil }
            return Cycle.cycleFor(isoDate: date).anchorISO
        })
        for row in rows where row.realizedStatus == .pending && row.isStatement {
            if let proposed = row.proposedRealizedDate {
                set.insert(proposed)
            }
        }
        return set.sorted()
    }

    static func history(rows: [LedgerRow], anchors: [String]? = nil) -> [CycleSnapshot] {
        let list = anchors ?? cycleAnchors(in: rows)
        var tab = 0
        var credit = 0
        var out: [CycleSnapshot] = []
        for anchor in list {
            let result = compute(
                cycleAnchorISO: anchor,
                rows: rows,
                carriedCreditC: credit,
                tabBeforeC: tab
            )
            out.append(CycleSnapshot(anchorISO: anchor, result: result))
            tab = result.tabAfterC
            credit = result.creditOutC
        }
        return out
    }

    static func receivableAmount(from result: Result) -> Int {
        result.remainingC
    }
}
