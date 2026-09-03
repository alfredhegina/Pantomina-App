import Foundation

/// §4.13 Cookie Jar: pure. UI never reimplements running balance or who's-paid.
enum CookieJar {
    enum Kind: String, Equatable, Hashable, Sendable, Codable {
        case income
        case spend
        case borrow
    }

    enum SourceKind: String, Equatable, Sendable, Codable {
        case unit
        case person
    }

    enum Cadence: String, Equatable, Sendable, Codable {
        case monthly
        case biweekly
    }

    struct Expected: Equatable, Sendable, Codable {
        var amountC: Int
        var cadence: Cadence
    }

    struct Source: Equatable, Sendable {
        var id: String
        var label: String
        var kind: SourceKind
        var expected: [Expected]
    }

    struct Entry: Equatable, Sendable {
        var id: String
        var dateISO: String
        var amountC: Int
        var kind: Kind
        var sourceId: String?
        var returned: Bool?
        var note: String?
    }

    struct StatementRow: Equatable, Sendable {
        var entry: Entry
        var balanceAfterC: Int
        /// Unreturned borrows show parenthesized in the tracker.
        var parenthesized: Bool
    }

    struct PaidChip: Equatable, Sendable {
        var sourceId: String
        var label: String
        var paid: Bool
    }

    /// Signed delta toward jar cash: income +, spend −, unreturned borrow −, returned borrow 0 (nets out).
    static func delta(for entry: Entry) -> Int {
        switch entry.kind {
        case .income:
            return entry.amountC
        case .spend:
            return -entry.amountC
        case .borrow:
            if entry.returned == true { return 0 }
            return -entry.amountC
        }
    }

    static func statement(entries: [Entry], sourceId: String? = nil) -> [StatementRow] {
        let sorted = entries.sorted { lhs, rhs in
            if lhs.dateISO != rhs.dateISO { return lhs.dateISO < rhs.dateISO }
            return lhs.id < rhs.id
        }
        var balance = 0
        var rows: [StatementRow] = []
        for entry in sorted {
            balance += delta(for: entry)
            if let sourceId, entry.sourceId != sourceId { continue }
            let paren = entry.kind == .borrow && entry.returned != true
            rows.append(StatementRow(entry: entry, balanceAfterC: balance, parenthesized: paren))
        }
        return rows
    }

    static func balance(entries: [Entry]) -> Int {
        entries.reduce(0) { $0 + delta(for: $1) }
    }

    static func unreturnedBorrows(entries: [Entry]) -> [Entry] {
        entries.filter { $0.kind == .borrow && $0.returned != true }
            .sorted { $0.dateISO < $1.dateISO }
    }

    static func markReturned(entryId: String, in entries: [Entry]) -> [Entry] {
        entries.map { entry in
            guard entry.id == entryId, entry.kind == .borrow else { return entry }
            var next = entry
            next.returned = true
            return next
        }
    }

    /// Who's-paid for sources with expected amounts. Monthly = any income in the calendar month of the cycle; biweekly = income in that cycle.
    static func whosPaid(cycleISO: String, sources: [Source], entries: [Entry]) -> [PaidChip] {
        let cycle = Cycle(anchorISO: cycleISO)
        return sources.map { source in
            let expected = source.expected.first
            let need = expected?.amountC ?? 0
            let cadence = expected?.cadence ?? .biweekly
            let paidIn: Int
            switch cadence {
            case .biweekly:
                paidIn = incomeTotal(sourceId: source.id, entries: entries) { date in
                    Cycle.cycleFor(isoDate: date).anchorISO == cycle.anchorISO
                }
            case .monthly:
                let monthPrefix = String(cycleISO.prefix(7)) // yyyy-MM
                paidIn = incomeTotal(sourceId: source.id, entries: entries) { date in
                    date.hasPrefix(monthPrefix)
                }
            }
            return PaidChip(
                sourceId: source.id,
                label: source.label,
                paid: need == 0 ? true : paidIn >= need
            )
        }
    }

    private static func incomeTotal(
        sourceId: String,
        entries: [Entry],
        dateMatches: (String) -> Bool
    ) -> Int {
        entries
            .filter {
                $0.kind == .income
                    && $0.sourceId == sourceId
                    && dateMatches($0.dateISO)
            }
            .reduce(0) { $0 + $1.amountC }
    }
}
