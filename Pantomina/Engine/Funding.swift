import Foundation

/// §4.9 funding plans: pure. UI never reimplements status or tranche math.
enum Funding {
    enum Status: Equatable, Sendable {
        case funded(done: Int, total: Int)
        case paid
    }

    struct Tranche: Equatable, Sendable, Codable {
        var cycleISO: String
        var amountC: Int
        var reserved: Bool
    }

    struct Plan: Equatable, Sendable {
        var id: String
        var billRecurringRuleId: String
        var billTitle: String
        var sourceAccountId: String
        var payoutCycleISO: String
        var tranches: [Tranche]
        var paid: Bool

        init(
            id: String,
            billRecurringRuleId: String,
            billTitle: String,
            sourceAccountId: String,
            payoutCycleISO: String,
            tranches: [Tranche],
            paid: Bool = false
        ) {
            self.id = id
            self.billRecurringRuleId = billRecurringRuleId
            self.billTitle = billTitle
            self.sourceAccountId = sourceAccountId
            self.payoutCycleISO = payoutCycleISO
            self.tranches = tranches
            self.paid = paid
        }

        /// Earmarked reserve = sum of reserved tranche amounts.
        var reserveC: Int {
            tranches.filter(\.reserved).reduce(0) { $0 + $1.amountC }
        }
    }

    struct ChecklistTranche: Equatable, Sendable {
        var id: String
        var title: String
        var sourceAccountId: String
        var amountC: Int
        var linkedId: String?
        var paymentsRequired: Int
        var paymentsDone: Int
        var done: Bool
    }

    static func status(_ plan: Plan) -> Status {
        if plan.paid { return .paid }
        let total = plan.tranches.count
        let done = plan.tranches.filter(\.reserved).count
        return .funded(done: done, total: total)
    }

    static func excludedBillRuleIds(plans: [Plan]) -> Set<String> {
        Set(plans.map(\.billRecurringRuleId))
    }

    static func forecastLines(cycleISO: String, plans: [Plan]) -> [Forecast.Line] {
        plans.compactMap { plan in
            guard !plan.paid,
                  let tranche = plan.tranches.first(where: { $0.cycleISO == cycleISO })
            else { return nil }
            return Forecast.Line(
                id: "tranche-\(plan.id)-\(cycleISO)",
                title: "\(plan.billTitle) tranche",
                amountC: tranche.amountC,
                reason: .tranche
            )
        }
    }

    static func checklistTranches(cycleISO: String, plans: [Plan]) -> [ChecklistTranche] {
        plans.compactMap { plan in
            guard !plan.paid,
                  let tranche = plan.tranches.first(where: { $0.cycleISO == cycleISO })
            else { return nil }
            let doneCount = plan.tranches.filter(\.reserved).count
            return ChecklistTranche(
                id: "tranche-\(plan.id)-\(cycleISO)",
                title: "Set aside \(plan.billTitle)",
                sourceAccountId: plan.sourceAccountId,
                amountC: tranche.amountC,
                linkedId: plan.id,
                paymentsRequired: plan.tranches.count,
                paymentsDone: doneCount,
                done: tranche.reserved
            )
        }
    }

    /// Mark the tranche for `cycleISO` reserved. Idempotent. Auto-pays when all tranches reserved.
    static func markReserved(planId: String, cycleISO: String, in plans: [Plan]) -> [Plan] {
        plans.map { plan in
            guard plan.id == planId else { return plan }
            var next = plan
            next.tranches = plan.tranches.map { t in
                guard t.cycleISO == cycleISO else { return t }
                var u = t
                u.reserved = true
                return u
            }
            if next.tranches.allSatisfy(\.reserved) {
                next.paid = true
            }
            return next
        }
    }

    static func markPaid(planId: String, in plans: [Plan]) -> [Plan] {
        plans.map { plan in
            guard plan.id == planId else { return plan }
            var next = plan
            next.paid = true
            return next
        }
    }
}
