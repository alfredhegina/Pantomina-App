import Foundation

struct LedgerFilterRow: Equatable, Sendable {
    var id: String
    var paidBy: PersonId
    var scope: Scope
    var flow: FlowType
    var status: RealizedStatus
}

enum LedgerFilters {
    static func apply(
        _ rows: [LedgerFilterRow],
        person: PersonId?,
        scope: Scope?,
        flow: FlowType?,
        status: RealizedStatus?
    ) -> [LedgerFilterRow] {
        rows.filter { row in
            if let person, row.paidBy != person { return false }
            if let scope, row.scope != scope { return false }
            if let flow, row.flow != flow { return false }
            if let status, row.status != status { return false }
            return true
        }
    }
}
