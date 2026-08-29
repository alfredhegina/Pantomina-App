import Foundation
import SwiftData

enum SeedCatalog {
    struct AccountSeed {
        var baseName: String
        var owner: String
        var scope: Scope
        var kind: AccountKind
        var settlement: SettlementKind
        var statementCutoff: Int?
    }

    struct CategorySeed {
        var group: String
        var item: String
        var flow: FlowType
        var needWant: NeedWant?
        var fixedVariable: FixedVariable?
        var system: Bool = false
    }

    static let starterAccounts: [AccountSeed] = [
        .init(baseName: "House cash box", owner: "household", scope: .household, kind: .cash, settlement: .instant),
        .init(baseName: "BDO JCB CC", owner: "household", scope: .household, kind: .creditCard, settlement: .statement, statementCutoff: 15),
        .init(baseName: "Cash", owner: "fern", scope: .fern, kind: .cash, settlement: .instant),
        .init(baseName: "BPI Debit", owner: "fern", scope: .fern, kind: .bank, settlement: .instant),
        .init(baseName: "GCash", owner: "fern", scope: .fern, kind: .ewallet, settlement: .instant),
        .init(baseName: "BPI CC", owner: "fern", scope: .fern, kind: .creditCard, settlement: .statement, statementCutoff: 15),
        .init(baseName: "Cash", owner: "stark", scope: .stark, kind: .cash, settlement: .instant),
        .init(baseName: "GCash", owner: "stark", scope: .stark, kind: .ewallet, settlement: .instant),
        .init(baseName: "Maya", owner: "stark", scope: .stark, kind: .ewallet, settlement: .instant),
    ]

    static let starterCategories: [CategorySeed] = [
        .init(group: "Rent", item: "House", flow: .expense, needWant: .need, fixedVariable: .fixed),
        .init(group: "Utilities", item: "Electricity", flow: .expense, needWant: .need, fixedVariable: .variable),
        .init(group: "Utilities", item: "Internet PLDT", flow: .expense, needWant: .need, fixedVariable: .fixed),
        .init(group: "Utilities", item: "Water", flow: .expense, needWant: .need, fixedVariable: .fixed),
        .init(group: "Utilities", item: "Smart Postpaid", flow: .expense, needWant: .want, fixedVariable: .fixed),
        .init(group: "Subscription", item: "Spotify", flow: .expense, needWant: .want, fixedVariable: .fixed),
        .init(group: "Subscription", item: "iCloud", flow: .expense, needWant: .want, fixedVariable: .fixed),
        .init(group: "Groceries", item: "Household", flow: .expense, needWant: .need, fixedVariable: .variable),
        .init(group: "Travels", item: "Accommodation", flow: .expense, needWant: .want, fixedVariable: .variable),
        .init(group: "Income", item: "Salary", flow: .income, needWant: nil, fixedVariable: .fixed),
        .init(group: "Income", item: "Side hustle", flow: .income, needWant: nil, fixedVariable: .variable),
        .init(group: "Child Support", item: "Birthday", flow: .expense, needWant: .want, fixedVariable: .variable),
        .init(group: "Siblings", item: "Birthday", flow: .expense, needWant: .need, fixedVariable: .variable),
        .init(group: "Loan", item: "BPI Credit to Cash", flow: .expense, needWant: .want, fixedVariable: .fixed),
        // System (hidden from pickers)
        .init(group: "System", item: "Partner Contribution", flow: .transfer, needWant: nil, fixedVariable: nil, system: true),
        .init(group: "System", item: "Partner Receivable", flow: .transfer, needWant: nil, fixedVariable: nil, system: true),
        .init(group: "System", item: "Fund Move", flow: .transfer, needWant: nil, fixedVariable: nil, system: true),
        .init(group: "System", item: "Loan Payment", flow: .expense, needWant: nil, fixedVariable: nil, system: true),
        .init(group: "System", item: "Petty Cash", flow: .expense, needWant: nil, fixedVariable: nil, system: true),
    ]

    /// Oddities to surface once after first seed (never silently fix).
    static let migrationOddityPrompts: [(legacy: String, oddity: CoAOddity)] = [
        ("Loan · BPI Credit to Cash", .loanMarkedWant),
        ("Child Support · Birthday", .childSupportBirthdayWant),
        ("Utilities · Smart Postpaid", .smartPostpaidWant),
    ]

    @MainActor
    static func seedStarterData(into context: ModelContext) throws {
        let existingAccounts = try context.fetch(FetchDescriptor<AccountRecord>())
        if existingAccounts.isEmpty {
            for seed in starterAccounts {
                context.insert(
                    AccountRecord(
                        baseName: seed.baseName,
                        owner: seed.owner,
                        scope: seed.scope,
                        kind: seed.kind,
                        settlement: seed.settlement,
                        statementCutoff: seed.statementCutoff
                    )
                )
            }
        }

        let existingCats = try context.fetch(FetchDescriptor<CategoryRecord>())
        if existingCats.isEmpty {
            for seed in starterCategories {
                context.insert(
                    CategoryRecord(
                        group: seed.group,
                        item: seed.item,
                        flow: seed.flow,
                        needWant: seed.needWant,
                        fixedVariable: seed.fixedVariable,
                        system: seed.system
                    )
                )
            }
        } else if !existingCats.contains(where: { $0.group == "Income" && $0.item == "Side hustle" }) {
            context.insert(
                CategoryRecord(
                    group: "Income",
                    item: "Side hustle",
                    flow: .income,
                    needWant: nil,
                    fixedVariable: .variable,
                    system: false
                )
            )
        }
        try context.save()
    }
}
