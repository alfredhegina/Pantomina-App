import Testing
@testable import Pantomina

@Suite("LedgerCatalog")
struct LedgerCatalogTests {
    @Test("clamps pocket names and rejects blanks")
    func pocketNameClamp() {
        let long = String(repeating: "a", count: 50)
        let existing: [LedgerCatalog.ExistingPocket] = []
        let ok = LedgerCatalog.validatePocket(
            .init(baseName: "  BPI Debit  ", scope: .fern, kind: .bank, statementCutoff: nil, existingId: nil, lockedShape: nil),
            existing: existing
        )
        #expect(ok.value?.baseName == "BPI Debit")

        let blank = LedgerCatalog.validatePocket(
            .init(baseName: "   ", scope: .household, kind: .cash, statementCutoff: nil, existingId: nil, lockedShape: nil),
            existing: existing
        )
        #expect(blank.error == .emptyName)

        let clipped = LedgerCatalog.validatePocket(
            .init(baseName: long, scope: .fern, kind: .cash, statementCutoff: nil, existingId: nil, lockedShape: nil),
            existing: existing
        )
        #expect(clipped.value?.baseName.count == InputBounds.maxDisplayNameLength)
    }

    @Test("Cash can exist on Fern and Stark; same scope is a duplicate")
    func pocketUniqueness() {
        let existing = [
            LedgerCatalog.ExistingPocket(id: "1", baseName: "Cash", scope: .fern),
        ]
        let stark = LedgerCatalog.validatePocket(
            .init(baseName: "cash", scope: .stark, kind: .cash, statementCutoff: nil, existingId: nil, lockedShape: nil),
            existing: existing
        )
        #expect(stark.value?.scope == .stark)

        let fernAgain = LedgerCatalog.validatePocket(
            .init(baseName: "Cash", scope: .fern, kind: .cash, statementCutoff: nil, existingId: nil, lockedShape: nil),
            existing: existing
        )
        #expect(fernAgain.error == .duplicate)

        let renameSelf = LedgerCatalog.validatePocket(
            .init(baseName: "Cash", scope: .fern, kind: .cash, statementCutoff: nil, existingId: "1", lockedShape: nil),
            existing: existing
        )
        #expect(renameSelf.value?.baseName == "Cash")
    }

    @Test("credit cards need a 15 or 30 cutoff; other kinds are instant")
    func settlementFromKind() {
        let existing: [LedgerCatalog.ExistingPocket] = []
        let ccMissing = LedgerCatalog.validatePocket(
            .init(baseName: "BPI CC", scope: .fern, kind: .creditCard, statementCutoff: nil, existingId: nil, lockedShape: nil),
            existing: existing
        )
        #expect(ccMissing.error == .cutoffNeeded)

        let cc = LedgerCatalog.validatePocket(
            .init(baseName: "BPI CC", scope: .fern, kind: .creditCard, statementCutoff: 15, existingId: nil, lockedShape: nil),
            existing: existing
        )
        #expect(cc.value?.settlement == .statement)
        #expect(cc.value?.statementCutoff == 15)
        #expect(cc.value?.owner == PersonId.fern.rawValue)

        let cash = LedgerCatalog.validatePocket(
            .init(baseName: "Cash", scope: .household, kind: .cash, statementCutoff: 15, existingId: nil, lockedShape: nil),
            existing: existing
        )
        #expect(cash.value?.settlement == .instant)
        #expect(cash.value?.statementCutoff == nil)
        #expect(cash.value?.owner == "household")
    }

    @Test("business scope is not offered")
    func noBusiness() {
        let result = LedgerCatalog.validatePocket(
            .init(baseName: "Ops", scope: .business, kind: .bank, statementCutoff: nil, existingId: nil, lockedShape: nil),
            existing: []
        )
        #expect(result.error == .businessNotAllowed)
        #expect(!LedgerCatalog.userScopes.contains(.business))
    }

    @Test("in-use pocket cannot change scope, kind, or cutoff")
    func pocketShapeLock() {
        let locked = LedgerCatalog.PocketShape(scope: .fern, kind: .bank, statementCutoff: nil)
        let changeKind = LedgerCatalog.validatePocket(
            .init(baseName: "BPI Debit", scope: .fern, kind: .ewallet, statementCutoff: nil, existingId: "1", lockedShape: locked),
            existing: [LedgerCatalog.ExistingPocket(id: "1", baseName: "BPI Debit", scope: .fern)]
        )
        #expect(changeKind.error == .shapeLocked)

        let rename = LedgerCatalog.validatePocket(
            .init(baseName: "BPI Savings", scope: .fern, kind: .bank, statementCutoff: nil, existingId: "1", lockedShape: locked),
            existing: [LedgerCatalog.ExistingPocket(id: "1", baseName: "BPI Debit", scope: .fern)]
        )
        #expect(rename.value?.baseName == "BPI Savings")
        #expect(rename.value?.kind == .bank)
    }

    @Test("pocket in-use follows ledger legs, rules, fund homes, loans, and funding")
    func pocketInUse() {
        #expect(LedgerCatalog.pocketInUse(id: "a", transactionAccountIds: ["a"], ruleAccountIds: []))
        #expect(LedgerCatalog.pocketInUse(id: "a", transactionAccountIds: [], ruleAccountIds: ["a"]))
        #expect(LedgerCatalog.pocketInUse(
            id: "a",
            transactionAccountIds: [],
            ruleAccountIds: [],
            fundHomeAccountIds: ["a"]
        ))
        #expect(LedgerCatalog.pocketInUse(
            id: "a",
            transactionAccountIds: [],
            ruleAccountIds: [],
            loanPaymentAccountIds: ["a"]
        ))
        #expect(LedgerCatalog.pocketInUse(
            id: "a",
            transactionAccountIds: [],
            ruleAccountIds: [],
            fundingSourceAccountIds: ["a"]
        ))
        #expect(!LedgerCatalog.pocketInUse(
            id: "a",
            transactionAccountIds: ["b"],
            ruleAccountIds: ["c"],
            fundHomeAccountIds: ["d"],
            loanPaymentAccountIds: ["e"],
            fundingSourceAccountIds: ["f"]
        ))
    }

    @Test("user kinds exclude loan and receivable")
    func userKinds() {
        #expect(!LedgerCatalog.userKinds.contains(.loan))
        #expect(!LedgerCatalog.userKinds.contains(.receivable))
        #expect(LedgerCatalog.userKinds.contains(.cash))
        #expect(LedgerCatalog.userKinds.contains(.investment))
        #expect(LedgerCatalog.userKinds.contains(.govMandated))

        let loan = LedgerCatalog.validatePocket(
            .init(baseName: "UB Personal", scope: .fern, kind: .loan, statementCutoff: nil, existingId: nil, lockedShape: nil),
            existing: []
        )
        #expect(loan.error == .kindNotAllowed)

        let receivable = LedgerCatalog.validatePocket(
            .init(baseName: "Love Tab", scope: .fern, kind: .receivable, statementCutoff: nil, existingId: nil, lockedShape: nil),
            existing: []
        )
        #expect(receivable.error == .kindNotAllowed)
    }

    @Test("expense needs need/want and fixed/variable; income does not")
    func categoryTags() {
        let existing: [LedgerCatalog.ExistingCategory] = []
        let expenseBare = LedgerCatalog.validateCategory(
            .init(group: "Rent", item: "House", flow: .expense, needWant: nil, fixedVariable: .fixed, existingId: nil, lockedTags: nil, system: false),
            existing: existing
        )
        #expect(expenseBare.error == .needWantNeeded)

        let expenseNoRhythm = LedgerCatalog.validateCategory(
            .init(group: "Rent", item: "House", flow: .expense, needWant: .need, fixedVariable: nil, existingId: nil, lockedTags: nil, system: false),
            existing: existing
        )
        #expect(expenseNoRhythm.error == .fixedVariableNeeded)

        let expense = LedgerCatalog.validateCategory(
            .init(group: " Rent ", item: " House ", flow: .expense, needWant: .need, fixedVariable: .fixed, existingId: nil, lockedTags: nil, system: false),
            existing: existing
        )
        #expect(expense.value?.group == "Rent")
        #expect(expense.value?.item == "House")
        #expect(expense.value?.needWant == .need)

        let income = LedgerCatalog.validateCategory(
            .init(group: "Income", item: "Salary", flow: .income, needWant: .want, fixedVariable: .fixed, existingId: nil, lockedTags: nil, system: false),
            existing: existing
        )
        #expect(income.value?.needWant == nil)
        #expect(income.value?.fixedVariable == nil)
        #expect(income.value?.flow == .income)
    }

    @Test("category uniqueness is case-insensitive; self-edit is allowed")
    func categoryUniqueness() {
        let existing = [
            LedgerCatalog.ExistingCategory(id: "1", group: "Rent", item: "House", system: false),
        ]
        let dup = LedgerCatalog.validateCategory(
            .init(group: "rent", item: "house", flow: .expense, needWant: .need, fixedVariable: .fixed, existingId: nil, lockedTags: nil, system: false),
            existing: existing
        )
        #expect(dup.error == .duplicate)

        let selfEdit = LedgerCatalog.validateCategory(
            .init(group: "Rent", item: "House", flow: .expense, needWant: .need, fixedVariable: .fixed, existingId: "1", lockedTags: nil, system: false),
            existing: existing
        )
        #expect(selfEdit.value?.group == "Rent")
    }

    @Test("users cannot create system or transfer categories")
    func noSystemOrTransfer() {
        #expect(!LedgerCatalog.userFlows.contains(.transfer))
        let system = LedgerCatalog.validateCategory(
            .init(group: "System", item: "Fund Move", flow: .transfer, needWant: nil, fixedVariable: nil, existingId: nil, lockedTags: nil, system: true),
            existing: []
        )
        #expect(system.error == .systemNotAllowed)

        let transfer = LedgerCatalog.validateCategory(
            .init(group: "Move", item: "Shift", flow: .transfer, needWant: nil, fixedVariable: nil, existingId: nil, lockedTags: nil, system: false),
            existing: []
        )
        #expect(transfer.error == .transferNotAllowed)
    }

    @Test("in-use category can rename but not change flow or tags")
    func categoryTagLock() {
        let locked = LedgerCatalog.CategoryTags(flow: .expense, needWant: .need, fixedVariable: .fixed)
        let changeFlow = LedgerCatalog.validateCategory(
            .init(group: "Rent", item: "House", flow: .income, needWant: nil, fixedVariable: nil, existingId: "1", lockedTags: locked, system: false),
            existing: [LedgerCatalog.ExistingCategory(id: "1", group: "Rent", item: "House", system: false)]
        )
        #expect(changeFlow.error == .tagsLocked)

        let rename = LedgerCatalog.validateCategory(
            .init(group: "Housing", item: "Rent", flow: .expense, needWant: .need, fixedVariable: .fixed, existingId: "1", lockedTags: locked, system: false),
            existing: [LedgerCatalog.ExistingCategory(id: "1", group: "Rent", item: "House", system: false)]
        )
        #expect(rename.value?.group == "Housing")
        #expect(rename.value?.item == "Rent")
        #expect(rename.value?.flow == .expense)
    }

    @Test("category in-use follows ledger legs and recurring rules")
    func categoryInUse() {
        #expect(LedgerCatalog.categoryInUse(id: "c", transactionCategoryIds: ["c"], ruleCategoryIds: []))
        #expect(LedgerCatalog.categoryInUse(id: "c", transactionCategoryIds: [], ruleCategoryIds: ["c"]))
        #expect(!LedgerCatalog.categoryInUse(id: "c", transactionCategoryIds: ["x"], ruleCategoryIds: []))
    }

    @Test("blank group or item is rejected")
    func categoryBlanks() {
        let existing: [LedgerCatalog.ExistingCategory] = []
        #expect(
            LedgerCatalog.validateCategory(
                .init(group: "  ", item: "House", flow: .expense, needWant: .need, fixedVariable: .fixed, existingId: nil, lockedTags: nil, system: false),
                existing: existing
            ).error == .emptyGroup
        )
        #expect(
            LedgerCatalog.validateCategory(
                .init(group: "Rent", item: " ", flow: .expense, needWant: .need, fixedVariable: .fixed, existingId: nil, lockedTags: nil, system: false),
                existing: existing
            ).error == .emptyItem
        )
    }
}

private extension Result {
    var value: Success? {
        if case .success(let value) = self { return value }
        return nil
    }

    var error: Failure? {
        if case .failure(let error) = self { return error }
        return nil
    }
}
