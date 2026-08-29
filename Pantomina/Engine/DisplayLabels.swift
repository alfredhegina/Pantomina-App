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
}
