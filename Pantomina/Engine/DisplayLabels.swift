import Foundation

/// Human-facing labels for engine enums. Never show `.rawValue` in the UI.
enum DisplayLabels {
    /// Chip on a receipt row. Realized entries omit a chip (`nil`).
    static func status(_ status: RealizedStatus) -> String? {
        switch status {
        case .realized: return nil
        case .pending: return "Not counted yet"
        case .projected: return "Projected"
        }
    }

    static func statusFilter(_ status: RealizedStatus) -> String {
        switch status {
        case .realized: return "Counted"
        case .pending: return "Not counted yet"
        case .projected: return "Projected"
        }
    }

    /// Compact filter-sheet labels (row chips still use `status`).
    static func statusFilterShort(_ status: RealizedStatus) -> String {
        switch status {
        case .realized: return "Counted"
        case .pending: return "Pending"
        case .projected: return "Projected"
        }
    }

    static func scope(_ scope: Scope, fernName: String, starkName: String) -> String {
        switch scope {
        case .household: return "Shared"
        case .fern: return fernName
        case .stark: return starkName
        case .business: return "Business"
        }
    }

    static func accountKindHint(settlement: SettlementKind, scope: Scope, fernName: String, starkName: String) -> String {
        let who = self.scope(scope, fernName: fernName, starkName: starkName)
        if settlement == .statement {
            return "\(who) · Statement"
        }
        return who
    }

    static func displayDate(iso: String) -> String {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(secondsFromGMT: 0)
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: iso) else { return iso }

        let out = DateFormatter()
        out.calendar = Calendar(identifier: .gregorian)
        out.locale = Locale(identifier: "en_US")
        out.timeZone = TimeZone(secondsFromGMT: 0)
        out.dateFormat = "MMM d, yyyy"
        return out.string(from: date)
    }

    /// Ledger row dates: year lives on the group header, not every row.
    static func displayDateShort(iso: String) -> String {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(secondsFromGMT: 0)
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: iso) else { return iso }

        let out = DateFormatter()
        out.calendar = Calendar(identifier: .gregorian)
        out.locale = Locale(identifier: "en_US")
        out.timeZone = TimeZone(secondsFromGMT: 0)
        out.dateFormat = "MMM d"
        return out.string(from: date)
    }

    /// Quiet ledger caption: `Sep 1 · Fern` or `Aug 10 · Shared · automatic`.
    static func ledgerMeta(
        eventISO: String,
        scope: Scope,
        fernName: String,
        starkName: String,
        isAutomatic: Bool
    ) -> String {
        var parts = [
            displayDateShort(iso: eventISO),
            self.scope(scope, fernName: fernName, starkName: starkName),
        ]
        if isAutomatic {
            parts.append("automatic")
        }
        return parts.joined(separator: " · ")
    }

    static func settlementHint(isStatement: Bool, anchorISO: String) -> String {
        let when = displayDate(iso: anchorISO)
        if isStatement {
            return "Waiting on statement · counts on \(when)"
        }
        return "Counts on \(when)"
    }

    static func settlementStatus(_ status: SettlementStatus) -> String {
        switch status {
        case .settled: return "Settled"
        case .partial: return "Partial"
        case .overpaid: return "Overpaid"
        }
    }

    static func forecastReason(_ reason: Forecast.Reason) -> String {
        switch reason {
        case .income: return "Income"
        case .fixed: return "Fixed"
        case .estimate: return "Estimate"
        case .cardLandsHere: return "Card lands here"
        case .tranche: return "Tranche"
        }
    }

    static func forecastVerdict(_ verdict: Forecast.Verdict, roomC: Int) -> String {
        switch verdict {
        case .breathingRoom:
            return "\(formatPeso(roomC)) breathing room"
        case .over:
            return "Over by \(formatPeso(abs(roomC)))"
        case .tight:
            return "Right on the line"
        }
    }

    static func fundingStatus(_ status: Funding.Status) -> String {
        switch status {
        case .funded(let done, let total):
            return "Funded \(done)/\(total)"
        case .paid:
            return "Paid"
        }
    }

    static func fundPurpose(_ purpose: Fund.Purpose) -> String {
        switch purpose {
        case .emergency: return "Emergency"
        case .sinking: return "Sinking"
        case .loanPayoff: return "Loan payoff"
        case .goal: return "Goal"
        }
    }

    /// Snowball strategy: plain names; engine still stores `prepay` / `park_to_maturity`.
    static func loanStrategy(_ strategy: Loan.Strategy?) -> String {
        switch strategy {
        case .parkToMaturity: return "On schedule only"
        case .prepay, .none: return "Stash extras"
        }
    }

    static func loanStrategyFooter(_ strategy: Loan.Strategy) -> String {
        switch strategy {
        case .parkToMaturity:
            return "On schedule only. Checklist payments only; no extra stash into Loan payoff."
        case .prepay:
            return "Stash extras. OK to put another month into Loan payoff."
        }
    }

    static func accountKind(_ kind: AccountKind) -> String {
        switch kind {
        case .cash: return "Cash"
        case .ewallet: return "E-wallet"
        case .bank: return "Bank"
        case .digitalBank: return "Digital bank"
        case .creditCard: return "Credit card"
        case .savingsAsset: return "Savings"
        case .investment: return "Investment"
        case .govMandated: return "Gov-mandated"
        case .receivable: return "Receivable"
        case .loan: return "Loan"
        }
    }

    static func flow(_ flow: FlowType) -> String {
        switch flow {
        case .income: return "Income"
        case .expense: return "Expense"
        case .transfer: return "Transfer"
        case .savings: return "Savings"
        case .sinking: return "Sinking"
        }
    }

    static func needWant(_ value: NeedWant) -> String {
        switch value {
        case .need: return "Need"
        case .want: return "Want"
        }
    }

    static func fixedVariable(_ value: FixedVariable) -> String {
        switch value {
        case .fixed: return "Fixed"
        case .variable: return "Variable"
        }
    }

    static func statementCutoff(_ day: Int) -> String {
        day == 15 ? "15th" : "Month-end"
    }

    static func catalogPocketIssue(_ issue: LedgerCatalog.PocketIssue) -> String {
        switch issue {
        case .emptyName: return "Couldn't save. Enter a name."
        case .duplicate: return "Couldn't save. That name is already used."
        case .shapeLocked: return "This pocket already has entries. You can rename it."
        case .cutoffNeeded: return "Pick a statement day. 15th or month-end."
        case .businessNotAllowed: return "Business pockets aren't available."
        case .kindNotAllowed: return "That kind of pocket isn't available here."
        }
    }

    static func catalogCategoryIssue(_ issue: LedgerCatalog.CategoryIssue) -> String {
        switch issue {
        case .emptyGroup: return "Couldn't save. Enter a group."
        case .emptyItem: return "Couldn't save. Enter an item."
        case .duplicate: return "Couldn't save. That name is already used."
        case .tagsLocked: return "This category already has entries. You can rename it."
        case .needWantNeeded: return "Pick Need or Want."
        case .fixedVariableNeeded: return "Pick Fixed or Variable."
        case .transferNotAllowed: return "That kind of category isn't available here."
        case .systemNotAllowed: return "System categories stay locked."
        }
    }
}
