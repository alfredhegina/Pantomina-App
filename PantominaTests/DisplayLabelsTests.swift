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

    @Test("contribution caption uses the live name and peso amount")
    func contributionSpokenFor() {
        #expect(
            DisplayLabels.contributionSpokenFor(personName: "Stark", amountC: 750_000)
                == "Stark's 7,500 goes against what Stark is spoken for this cycle."
        )
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

    @Test("short date drops the year")
    func displayDateShort() {
        #expect(DisplayLabels.displayDateShort(iso: "2026-10-15") == "Oct 15")
        #expect(DisplayLabels.displayDateShort(iso: "bad") == "bad")
    }

    @Test("ledger meta is event date, scope, and automatic for jar rows")
    func ledgerMeta() {
        #expect(
            DisplayLabels.ledgerMeta(
                eventISO: "2026-09-01",
                scope: .fern,
                fernName: "Fern",
                starkName: "Stark",
                isAutomatic: false
            ) == "Sep 1 · Fern"
        )
        #expect(
            DisplayLabels.ledgerMeta(
                eventISO: "2026-08-10",
                scope: .household,
                fernName: "Fern",
                starkName: "Stark",
                isAutomatic: true
            ) == "Aug 10 · Shared · automatic"
        )
    }

    @Test("fund purpose never shows engine raw values")
    func fundPurposeLabels() {
        #expect(DisplayLabels.fundPurpose(.emergency) == "Emergency")
        #expect(DisplayLabels.fundPurpose(.sinking) == "Sinking")
        #expect(DisplayLabels.fundPurpose(.loanPayoff) == "Loan payoff")
        #expect(DisplayLabels.fundPurpose(.goal) == "Goal")
    }

    @Test("loan strategy display never shows engine jargon")
    func loanStrategyLabels() {
        #expect(DisplayLabels.loanStrategy(.prepay) == "Stash extras")
        #expect(DisplayLabels.loanStrategy(.parkToMaturity) == "On schedule only")
        #expect(DisplayLabels.loanStrategy(nil) == "Stash extras")
        #expect(DisplayLabels.loanStrategyFooter(.prepay).hasPrefix("Stash extras"))
        #expect(DisplayLabels.loanStrategyFooter(.parkToMaturity).hasPrefix("On schedule only"))
    }

    @Test("account kind labels never leak engine raw values")
    func accountKindLabels() {
        #expect(DisplayLabels.accountKind(.cash) == "Cash")
        #expect(DisplayLabels.accountKind(.bank) == "Bank")
        #expect(DisplayLabels.accountKind(.ewallet) == "E-wallet")
        #expect(DisplayLabels.accountKind(.digitalBank) == "Digital bank")
        #expect(DisplayLabels.accountKind(.creditCard) == "Credit card")
        #expect(DisplayLabels.accountKind(.savingsAsset) == "Savings")
        #expect(DisplayLabels.accountKind(.investment) == "Investment")
        #expect(DisplayLabels.accountKind(.govMandated) == "Gov-mandated")
        #expect(!DisplayLabels.accountKind(.creditCard).contains("_"))
    }

    @Test("catalog save errors stay human")
    func catalogIssues() {
        #expect(DisplayLabels.catalogPocketIssue(.duplicate) == "Couldn't save. That name is already used.")
        #expect(DisplayLabels.catalogPocketIssue(.cutoffNeeded) == "Pick a statement day. 15th or month-end.")
        #expect(DisplayLabels.catalogPocketIssue(.shapeLocked) == "This pocket already has entries. You can rename it.")
        #expect(DisplayLabels.catalogCategoryIssue(.duplicate) == "Couldn't save. That name is already used.")
        #expect(DisplayLabels.catalogCategoryIssue(.tagsLocked) == "This category already has entries. You can rename it.")
        #expect(DisplayLabels.catalogCategoryIssue(.needWantNeeded) == "Pick Need or Want.")
        #expect(DisplayLabels.flow(.expense) == "Expense")
        #expect(DisplayLabels.flow(.sinking) == "Sinking")
        #expect(DisplayLabels.needWant(.need) == "Need")
        #expect(DisplayLabels.fixedVariable(.variable) == "Variable")
        #expect(DisplayLabels.statementCutoff(15) == "15th")
        #expect(DisplayLabels.statementCutoff(30) == "Month-end")
    }
}
