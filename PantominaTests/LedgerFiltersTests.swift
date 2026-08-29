import Testing
@testable import Pantomina

@Suite("LedgerFilters")
struct LedgerFiltersTests {
    private let rows: [LedgerFilterRow] = [
        .init(id: "1", paidBy: .fern, scope: .household, flow: .expense, status: .realized),
        .init(id: "2", paidBy: .stark, scope: .stark, flow: .expense, status: .pending),
        .init(id: "3", paidBy: .fern, scope: .fern, flow: .income, status: .realized),
        .init(id: "4", paidBy: .fern, scope: .household, flow: .expense, status: .projected),
    ]

    @Test("person filter keeps paidBy")
    func person() {
        let out = LedgerFilters.apply(rows, person: .stark, scope: nil, flow: nil, status: nil)
        #expect(out.map(\.id) == ["2"])
    }

    @Test("scope filter matches account scope")
    func scope() {
        let out = LedgerFilters.apply(rows, person: nil, scope: .household, flow: nil, status: nil)
        #expect(out.map(\.id) == ["1", "4"])
    }

    @Test("combined filters")
    func combined() {
        let out = LedgerFilters.apply(rows, person: .fern, scope: .household, flow: .expense, status: .realized)
        #expect(out.map(\.id) == ["1"])
    }
}
