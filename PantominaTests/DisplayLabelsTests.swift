import Testing
@testable import Pantomina

@Suite("DisplayLabels")
struct DisplayLabelsTests {
    @Test("status labels never leak engine raw values")
    func statusLabels() {
        #expect(DisplayLabels.status(.realized) == nil)
        #expect(DisplayLabels.status(.pending) == "Not counted yet")
        #expect(DisplayLabels.status(.projected) == "Projected")
        #expect(DisplayLabels.statusFilter(.pending) == "Not counted yet")
    }

    @Test("scope labels use Shared and person names")
    func scopeLabels() {
        #expect(DisplayLabels.scope(.household, fernName: "Fern", starkName: "Stark") == "Shared")
        #expect(DisplayLabels.scope(.fern, fernName: "Fern", starkName: "Stark") == "Fern")
        #expect(DisplayLabels.scope(.stark, fernName: "Fern", starkName: "Stark") == "Stark")
        #expect(DisplayLabels.scope(.business, fernName: "Fern", starkName: "Stark") == "Business")
    }

    @Test("formats ISO dates for display")
    func displayDate() {
        #expect(DisplayLabels.displayDate(iso: "2026-08-15") == "Aug 15, 2026")
        #expect(DisplayLabels.displayDate(iso: "bad") == "bad")
    }

    @Test("settlement hint avoids engine vocabulary")
    func settlementHint() {
        #expect(DisplayLabels.settlementHint(isStatement: true, anchorISO: "2026-08-15")
            == "Waiting on statement · counts on Aug 15, 2026")
        #expect(DisplayLabels.settlementHint(isStatement: false, anchorISO: "2026-06-30")
            == "Counts on Jun 30, 2026")
    }

    @Test("account hints keep Shared visible on statement cards")
    func accountKindHint() {
        #expect(
            DisplayLabels.accountKindHint(
                settlement: .statement,
                scope: .household,
                fernName: "Fern",
                starkName: "Stark"
            ) == "Shared · Statement"
        )
        #expect(
            DisplayLabels.accountKindHint(
                settlement: .statement,
                scope: .fern,
                fernName: "Fern",
                starkName: "Stark"
            ) == "Fern · Statement"
        )
        #expect(
            DisplayLabels.accountKindHint(
                settlement: .instant,
                scope: .household,
                fernName: "Fern",
                starkName: "Stark"
            ) == "Shared"
        )
    }
}
