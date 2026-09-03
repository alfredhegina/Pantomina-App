import Foundation

/// Pocket truth for Empire dashboard: pure. Ledger-known kinds from legs; externals from last confirm.
enum PocketBalance {
    enum Source: String, Sendable, Equatable {
        case ledger
        case confirmed
        case unknown
    }

    struct Leg: Equatable, Sendable {
        var amountC: Int
        var flow: FlowType
        var realizedStatus: RealizedStatus
        var purchaseDate: String
        var realizedDate: String? = nil
        var note: String?
        /// Settlement theater on a pocket (contribution / receivable / fund_move): not cash truth.
        var settlementRole: SettlementRole? = nil

        /// Prefer realized date when present (statement-landed), else when it happened.
        var effectiveDate: String { realizedDate ?? purchaseDate }

        /// Loan payments move real pesos; contribution / receivable / fund_move do not for pocket NW.
        var countsTowardPocket: Bool {
            switch settlementRole {
            case .contribution, .receivable, .fundMove:
                return false
            case .loanPayment, nil:
                return true
            }
        }
    }

    struct Result: Equatable, Sendable {
        var balanceC: Int
        var source: Source
        var spokenForC: Int

        var feelsSpendableC: Int { max(0, balanceC - spokenForC) }
    }

    struct StatementRow: Equatable, Sendable {
        var purchaseDate: String
        var note: String?
        var signedAmountC: Int
        var balanceAfterC: Int
    }

    /// Half-month cycle window: (previous anchor, selected anchor].
    static func cycleWindow(endingAtAnchorISO endISO: String) -> (fromExclusive: String, toInclusive: String) {
        let end = Cycle(anchorISO: endISO)
        let prev = Cycle.previousHalfMonth(before: end)
        return (prev.anchorISO, end.anchorISO)
    }

    static func isExternalKind(_ kind: AccountKind) -> Bool {
        switch kind {
        case .investment, .savingsAsset, .govMandated:
            return true
        default:
            return false
        }
    }

    static func isLiabilityKind(_ kind: AccountKind) -> Bool {
        Snapshot.isLiabilityKind(kind)
    }

    /// Legs with effective date ≤ `asOfISO` (inclusive). Nil asOf = all dates.
    static func legsAsOf(_ legs: [Leg], asOfISO: String?) -> [Leg] {
        guard let asOfISO else { return legs }
        return legs.filter { $0.effectiveDate <= asOfISO }
    }

    /// Legs strictly after `fromExclusive` and ≤ `toInclusive`.
    static func legsInWindow(_ legs: [Leg], fromExclusive: String, toInclusive: String) -> [Leg] {
        legs.filter { $0.effectiveDate > fromExclusive && $0.effectiveDate <= toInclusive }
    }

    static func compute(
        kind: AccountKind,
        legs: [Leg],
        loanBalanceC: Int?,
        lastConfirmedC: Int?,
        spokenForC: Int,
        receivableBalanceC: Int? = nil,
        asOfISO: String? = nil,
        lastConfirmedCycleISO: String? = nil
    ) -> Result {
        let spoken = max(0, spokenForC)
        let scoped = legsAsOf(legs, asOfISO: asOfISO)

        if kind == .loan {
            let bal = loanBalanceC ?? 0
            return Result(balanceC: bal, source: .ledger, spokenForC: spoken)
        }

        if kind == .receivable, let tab = receivableBalanceC {
            return Result(balanceC: max(0, tab), source: .ledger, spokenForC: spoken)
        }

        if isExternalKind(kind) {
            if let last = lastConfirmedC {
                if let asOf = asOfISO, let confirmedCycle = lastConfirmedCycleISO, confirmedCycle > asOf {
                    return Result(balanceC: 0, source: .unknown, spokenForC: spoken)
                }
                return Result(balanceC: last, source: .confirmed, spokenForC: spoken)
            }
            return Result(balanceC: 0, source: .unknown, spokenForC: spoken)
        }

        let bal = ledgerSum(kind: kind, legs: scoped)
        return Result(balanceC: bal, source: .ledger, spokenForC: spoken)
    }

    /// Full running statement (oldest first). Optional asOf cuts later legs.
    static func statement(kind: AccountKind, legs: [Leg], asOfISO: String? = nil) -> [StatementRow] {
        statementRows(kind: kind, legs: legsAsOf(legs, asOfISO: asOfISO), openingBalanceC: 0)
    }

    /// Cycle-window statement with opening balance from legs before the window.
    static func statementInCycle(
        kind: AccountKind,
        legs: [Leg],
        cycleAnchorISO: String
    ) -> (openingC: Int, rows: [StatementRow]) {
        let window = cycleWindow(endingAtAnchorISO: cycleAnchorISO)
        let openingLegs = legsAsOf(legs, asOfISO: window.fromExclusive)
        let openingC = ledgerSum(kind: kind, legs: openingLegs)
        let windowLegs = legsInWindow(
            legs,
            fromExclusive: window.fromExclusive,
            toInclusive: window.toInclusive
        )
        let rows = statementRows(kind: kind, legs: windowLegs, openingBalanceC: openingC)
        return (openingC, rows)
    }

    private static func statementRows(
        kind: AccountKind,
        legs: [Leg],
        openingBalanceC: Int
    ) -> [StatementRow] {
        let realized = legs
            .filter { $0.realizedStatus == .realized && $0.countsTowardPocket }
            .sorted {
                if $0.effectiveDate != $1.effectiveDate { return $0.effectiveDate < $1.effectiveDate }
                return $0.purchaseDate < $1.purchaseDate
            }
        var running = openingBalanceC
        var rows: [StatementRow] = []
        let liability = isLiabilityKind(kind)
        for leg in realized {
            let signed = signedDelta(amountC: leg.amountC, flow: leg.flow, isLiability: liability)
            running += signed
            rows.append(
                StatementRow(
                    purchaseDate: leg.effectiveDate,
                    note: leg.note,
                    signedAmountC: signed,
                    balanceAfterC: running
                )
            )
        }
        return rows
    }

    static func ledgerSum(kind: AccountKind, legs: [Leg]) -> Int {
        let liability = isLiabilityKind(kind)
        return legs
            .filter { $0.realizedStatus == .realized && $0.countsTowardPocket }
            .reduce(0) { $0 + signedDelta(amountC: $1.amountC, flow: $1.flow, isLiability: liability) }
    }

    /// Positive amountC always; sign from flow + asset vs liability.
    static func signedDelta(amountC: Int, flow: FlowType, isLiability: Bool) -> Int {
        let abs = abs(amountC)
        if isLiability {
            switch flow {
            case .expense, .sinking:
                return abs
            case .income, .savings, .transfer:
                return -abs
            }
        } else {
            switch flow {
            case .income, .savings, .sinking, .transfer:
                return abs
            case .expense:
                return -abs
            }
        }
    }
}
