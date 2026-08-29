import Foundation

enum CoAOddity: String, Equatable, Sendable {
    case loanMarkedWant
    case childSupportBirthdayWant
    case smartPostpaidWant
}

struct CoAMigrationResult: Equatable, Sendable {
    var group: String
    var item: String
    var flow: FlowType
    var needWant: NeedWant?
    var fixedVariable: FixedVariable?
    var scopeHint: Scope?
    var oddity: CoAOddity?
}

enum CoAMigration {
    /// Maps a legacy spreadsheet-style `Group · Item` (or `Group|Item`) string.
    static func map(legacy: String) -> CoAMigrationResult? {
        let normalized = legacy
            .replacingOccurrences(of: "|", with: " · ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        var parts = normalized.components(separatedBy: " · ").map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count < 2 {
            parts = normalized.components(separatedBy: "·").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        guard parts.count >= 2 else { return nil }

        let rawGroup = fixTypo(parts[0])
        let rawItem = fixTypo(parts[1...].joined(separator: " · "))

        var group = rawGroup
        var item = rawItem
        var scopeHint: Scope?
        var flow: FlowType = .expense
        var needWant: NeedWant? = .need
        var fixedVariable: FixedVariable? = .variable
        var oddity: CoAOddity?

        if rawGroup == "Salary" {
            flow = .income
            needWant = nil
            fixedVariable = .fixed
            group = "Income"
            item = "Salary"
            if rawItem == "Larr" || rawItem == "Fern" {
                scopeHint = .fern
            } else if rawItem == "Len" || rawItem == "Stark" {
                scopeHint = .stark
            } else {
                item = rawItem
            }
        }

        if group == "Loan" {
            needWant = .want
            oddity = .loanMarkedWant
        }

        if group == "Child Support" && item == "Birthday" {
            needWant = .want
            oddity = .childSupportBirthdayWant
        }

        if group == "Siblings" && item == "Birthday" {
            needWant = .need
            oddity = nil
        }

        if group == "Utilities" && item == "Smart Postpaid" {
            needWant = .want
            oddity = .smartPostpaidWant
            fixedVariable = .fixed
        }

        if group == "Subscription" || group == "Utilities" || group == "Rent" {
            if oddity != .smartPostpaidWant {
                fixedVariable = .fixed
            }
        }

        if group == "Subscription" {
            // typo path already fixed group name
            fixedVariable = .fixed
        }

        return CoAMigrationResult(
            group: group,
            item: item,
            flow: flow,
            needWant: needWant,
            fixedVariable: fixedVariable,
            scopeHint: scopeHint,
            oddity: oddity
        )
    }

    private static func fixTypo(_ s: String) -> String {
        switch s {
        case "Subcription": return "Subscription"
        case "Accomodation": return "Accommodation"
        default: return s
        }
    }
}
