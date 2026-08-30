import Testing
@testable import Pantomina

@Suite("CookieJar")
struct CookieJarTests {
    /// Petty Cash Tracker–style fixture (centavos).
    private func fixtureEntries() -> [CookieJar.Entry] {
        [
            .init(id: "1", dateISO: "2026-08-01", amountC: 700_00, kind: .income, sourceId: "404", returned: nil, note: "Internet"),
            .init(id: "2", dateISO: "2026-08-02", amountC: 700_00, kind: .income, sourceId: "406", returned: nil, note: "Internet"),
            .init(id: "3", dateISO: "2026-08-05", amountC: 200_00, kind: .spend, sourceId: nil, returned: nil, note: "Pocket"),
            .init(id: "4", dateISO: "2026-08-10", amountC: 500_00, kind: .borrow, sourceId: "fern", returned: false, note: "Fern No Cash"),
        ]
    }

    private func unitSources() -> [CookieJar.Source] {
        ["404", "406", "408", "305"].map {
            CookieJar.Source(
                id: $0,
                label: $0,
                kind: .unit,
                expected: [CookieJar.Expected(amountC: 700_00, cadence: .monthly)]
            )
        }
    }

    @Test("statement running balance; unreturned borrow parenthesized and dips balance")
    func runningBalanceFixture() {
        let rows = CookieJar.statement(entries: fixtureEntries())
        #expect(rows.map(\.balanceAfterC) == [700_00, 1_400_00, 1_200_00, 700_00])
        #expect(rows[3].parenthesized)
        #expect(CookieJar.balance(entries: fixtureEntries()) == 700_00)
    }

    @Test("returned borrow nets out of balance")
    func returnedBorrowNetsOut() {
        var entries = fixtureEntries()
        entries = CookieJar.markReturned(entryId: "4", in: entries)
        let rows = CookieJar.statement(entries: entries)
        #expect(rows.last?.balanceAfterC == 1_200_00)
        #expect(rows.last?.parenthesized == false)
        #expect(CookieJar.unreturnedBorrows(entries: entries).isEmpty)
    }

    @Test("unreturned borrows surface as IOUs")
    func iouList() {
        let ious = CookieJar.unreturnedBorrows(entries: fixtureEntries())
        #expect(ious.count == 1)
        #expect(ious[0].id == "4")
        #expect(ious[0].amountC == 500_00)
    }

    @Test("who's paid strip per cycle for unit expected")
    func whosPaidStrip() {
        let entries = fixtureEntries()
        let strip = CookieJar.whosPaid(
            cycleISO: "2026-08-15",
            sources: unitSources(),
            entries: entries
        )
        #expect(strip.map(\.sourceId) == ["404", "406", "408", "305"])
        #expect(strip[0].paid)
        #expect(strip[1].paid)
        #expect(!strip[2].paid)
        #expect(!strip[3].paid)
    }

    @Test("filter statement by source")
    func filterBySource() {
        let rows = CookieJar.statement(entries: fixtureEntries(), sourceId: "404")
        #expect(rows.count == 1)
        #expect(rows[0].entry.sourceId == "404")
        #expect(rows[0].balanceAfterC == 700_00)
    }
}
