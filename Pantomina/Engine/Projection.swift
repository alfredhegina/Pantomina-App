import Foundation

/// §4.5: projected rows from recurring rules. Pure; UI never reimplements.
enum Projection {
    enum Cadence: String, Sendable {
        case biweekly
        case monthly
    }

    enum AnchorDay: String, Sendable {
        case fifteenth = "15"
        case monthEnd = "30"
        case both
    }

    enum AmountBehavior: String, Sendable {
        case exact
        case estimate
    }

    struct Rule: Equatable, Sendable {
        var id: String
        var amountC: Int
        var accountId: String
        var categoryId: String
        var paidBy: PersonId
        var allocationFernC: Int
        var allocationStarkC: Int
        var cadence: Cadence
        var anchorDay: AnchorDay
        var amountBehavior: AmountBehavior
        var startCycleISO: String
        var endCycleISO: String?
        var paused: Bool
        var title: String
        var flow: FlowType
        var fixedVariable: FixedVariable?
    }

    struct DraftRow: Equatable, Sendable {
        var id: String
        var recurringRuleId: String
        var title: String
        var amountC: Int
        var accountId: String
        var categoryId: String
        var paidBy: PersonId
        var allocationFernC: Int
        var allocationStarkC: Int
        var status: RealizedStatus
        var realizedDate: String?
        var proposedRealizedDate: String?
        var amountBehavior: AmountBehavior
        var flow: FlowType
        var fixedVariable: FixedVariable?
    }

    struct AmountLine: Equatable, Sendable {
        var amountC: Int
        var status: RealizedStatus
    }

    /// Sum of realized amounts only: projected/pending never count as actuals.
    static func actualTotalCentavos(_ lines: [AmountLine]) -> Int {
        lines.filter { $0.status == .realized }.reduce(0) { $0 + $1.amountC }
    }

    static func rows(forCycleISO cycleISO: String, rules: [Rule]) -> [DraftRow] {
        rules.compactMap { rule in
            guard applies(rule, toCycleISO: cycleISO) else { return nil }
            return DraftRow(
                id: "proj-\(rule.id)-\(cycleISO)",
                recurringRuleId: rule.id,
                title: rule.title,
                amountC: rule.amountC,
                accountId: rule.accountId,
                categoryId: rule.categoryId,
                paidBy: rule.paidBy,
                allocationFernC: rule.allocationFernC,
                allocationStarkC: rule.allocationStarkC,
                status: .projected,
                realizedDate: nil,
                proposedRealizedDate: cycleISO,
                amountBehavior: rule.amountBehavior,
                flow: rule.flow,
                fixedVariable: rule.fixedVariable
            )
        }
    }

    static func confirmExact(_ draft: DraftRow, cycleISO: String) -> DraftRow {
        var out = draft
        out.status = .realized
        out.realizedDate = cycleISO
        out.proposedRealizedDate = nil
        return out
    }

    static func confirmEstimate(_ draft: DraftRow, cycleISO: String, amountC: Int) -> DraftRow {
        var out = draft
        out.amountC = amountC
        out.status = .realized
        out.realizedDate = cycleISO
        out.proposedRealizedDate = nil
        return out
    }

    private static func applies(_ rule: Rule, toCycleISO cycleISO: String) -> Bool {
        guard !rule.paused else { return false }
        guard cycleISO >= rule.startCycleISO else { return false }
        if let end = rule.endCycleISO, cycleISO > end { return false }

        let day = Int(cycleISO.split(separator: "-").last ?? "") ?? 0
        let isFifteenth = day == 15
        let isMonthEnd = day != 15

        switch rule.anchorDay {
        case .fifteenth:
            guard isFifteenth else { return false }
        case .monthEnd:
            guard isMonthEnd else { return false }
        case .both:
            break
        }

        switch rule.cadence {
        case .biweekly:
            return true
        case .monthly:
            // Once per calendar month: prefer 15th when both, else the matching anchor.
            if rule.anchorDay == .both {
                return isFifteenth
            }
            return true
        }
    }
}
