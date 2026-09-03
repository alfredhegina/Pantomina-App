import Foundation

/// §4.10 snowball: pure. Custom order/batches; IOU repay before park; no silent sweep.
enum Snowball {
    struct IOURepay: Equatable, Sendable {
        var fundId: String
        var amountC: Int
    }

    struct SweepPlan: Equatable, Sendable {
        var iouRepays: [IOURepay]
        var parkToLoanPayoffC: Int
        var loanPayoffFundId: String?
        var totalAllocatedC: Int
    }

    /// Active loans in the lowest batch that still has actives, sorted by `snowballOrder` (nil last).
    static func orderedQueue(loans: [Loan.Snapshot]) -> [Loan.Snapshot] {
        let active = loans.filter { $0.status == .active }
        guard !active.isEmpty else { return [] }
        let batch = active.map { $0.snowballBatch ?? 1 }.min() ?? 1
        return active
            .filter { ($0.snowballBatch ?? 1) == batch }
            .sorted {
                let o0 = $0.snowballOrder ?? Int.max
                let o1 = $1.snowballOrder ?? Int.max
                if o0 != o1 { return o0 < o1 }
                return $0.description < $1.description
            }
    }

    /// Show Batch chrome only when more than one wave is in play (any batch ≠ 1, or 2+ distinct batches).
    static func showsBatchChrome(loans: [Loan.Snapshot]) -> Bool {
        let batches = Set(
            loans
                .filter { $0.status == .active }
                .map { $0.snowballBatch ?? 1 }
        )
        guard !batches.isEmpty else { return false }
        return batches.count > 1 || batches.contains(where: { $0 != 1 })
    }

    static func nextTargetMonthlyC(loans: [Loan.Snapshot]) -> Int? {
        orderedQueue(loans: loans).first?.monthlyC
    }

    static func isReadyToPay(loanPayoffBalanceC: Int, loans: [Loan.Snapshot]) -> Bool {
        guard let target = nextTargetMonthlyC(loans: loans), target > 0 else { return false }
        return loanPayoffBalanceC >= target
    }

    /// `prepay` and nil allow parking another month into the loan-payoff fund; `park_to_maturity` does not.
    static func parkAnotherMonthAmountC(loan: Loan.Snapshot) -> Int? {
        guard loan.status == .active, loan.monthlyC > 0 else { return nil }
        switch loan.strategy {
        case .parkToMaturity: return nil
        case .prepay, .none: return loan.monthlyC
        }
    }

    /// Allocate surplus: oldest open IOUs first (by date, then fund raid order), remainder to loan-payoff.
    static func proposeSweep(
        surplusC: Int,
        funds: [Fund.Snapshot],
        loanPayoffFundId: String?
    ) -> SweepPlan? {
        guard surplusC > 0 else { return nil }

        struct OpenIOU {
            var fundId: String
            var dateISO: String
            var raidOrder: Int
            var outstandingC: Int
        }

        var opens: [OpenIOU] = []
        for fund in funds where fund.iousC > 0 {
            for entry in fund.iouLog where entry.isOpen {
                opens.append(
                    OpenIOU(
                        fundId: fund.id,
                        dateISO: entry.dateISO,
                        raidOrder: fund.raidOrder,
                        outstandingC: entry.outstandingC
                    )
                )
            }
        }
        opens.sort {
            if $0.dateISO != $1.dateISO { return $0.dateISO < $1.dateISO }
            if $0.raidOrder != $1.raidOrder { return $0.raidOrder < $1.raidOrder }
            return $0.fundId < $1.fundId
        }

        var remaining = surplusC
        var perFund: [String: Int] = [:]
        for iou in opens where remaining > 0 {
            let pay = min(remaining, iou.outstandingC)
            guard pay > 0 else { continue }
            perFund[iou.fundId, default: 0] += pay
            remaining -= pay
        }

        var orderedRepays: [IOURepay] = []
        var seen = Set<String>()
        for iou in opens {
            guard !seen.contains(iou.fundId), let amount = perFund[iou.fundId] else { continue }
            seen.insert(iou.fundId)
            orderedRepays.append(IOURepay(fundId: iou.fundId, amountC: amount))
        }

        let park: Int
        let payoffId: String?
        if remaining > 0 {
            guard let id = loanPayoffFundId,
                  funds.contains(where: { $0.id == id && $0.purpose == .loanPayoff })
            else { return nil }
            park = remaining
            payoffId = id
        } else {
            park = 0
            payoffId = loanPayoffFundId
        }

        return SweepPlan(
            iouRepays: orderedRepays,
            parkToLoanPayoffC: park,
            loanPayoffFundId: payoffId,
            totalAllocatedC: surplusC
        )
    }
}
