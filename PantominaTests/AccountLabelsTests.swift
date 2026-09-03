import Testing
@testable import Pantomina

@Suite("AccountLabels")
struct AccountLabelsTests {
    @Test("household scope uses baseName only")
    func household() {
        let label = AccountLabels.display(baseName: "BDO JCB CC", scope: .household, personName: "Marco")
        #expect(label == "BDO JCB CC")
    }

    @Test("personal scope appends current person name at render time")
    func personal() {
        let label = AccountLabels.display(baseName: "BDO JCB CC", scope: .fern, personName: "Marco")
        #expect(label == "BDO JCB CC · Marco")
    }

    @Test("renaming person changes label without stored suffix")
    func rename() {
        let before = AccountLabels.display(baseName: "Cash", scope: .stark, personName: "Stark")
        let after = AccountLabels.display(baseName: "Cash", scope: .stark, personName: "Alex")
        #expect(before == "Cash · Stark")
        #expect(after == "Cash · Alex")
    }
}

@Suite("SeedCatalog onboarding preview")
struct SeedCatalogOnboardingPreviewTests {
    @Test("starter pocket labels use live names, never stored suffixes")
    func starterAccountLabels() {
        let labels = SeedCatalog.starterAccountPreviewLabels(fernName: "Marco", starkName: "Alex")
        #expect(labels.count == 9)
        #expect(labels == [
            "House cash box",
            "BDO JCB CC",
            "Cash · Marco",
            "BPI Debit · Marco",
            "GCash · Marco",
            "BPI CC · Marco",
            "Cash · Alex",
            "GCash · Alex",
            "Maya · Alex",
        ])
    }

    @Test("seed-on preview is 15 user categories in 10 groups")
    func starterUserCategories() {
        #expect(SeedCatalog.starterUserCategoryCount == 15)
        #expect(SeedCatalog.starterUserCategoryGroups == [
            "Rent",
            "Utilities",
            "Subscription",
            "Groceries",
            "Travels",
            "Income",
            "Savings",
            "Child Support",
            "Siblings",
            "Loan",
        ])
    }

    @Test("seed-off preview names the five system categories Bootstrap still inserts")
    func systemCategories() {
        #expect(SeedCatalog.systemCategoryItems == [
            "Partner Contribution",
            "Partner Receivable",
            "Fund Move",
            "Loan Payment",
            "Petty Cash",
        ])
    }
}
