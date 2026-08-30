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

        try seedDemoRulesIfNeeded(into: context)
        try seedDemoFundingIfNeeded(into: context)
        try seedDemoJarIfNeeded(into: context)
        try context.save()
    }

    /// Boarder units + demo jar rows (additive). Matches CookieJarTests fixture shape.
    @MainActor
    static func seedDemoJarIfNeeded(into context: ModelContext) throws {
        var sources = try context.fetch(FetchDescriptor<JarSourceRecord>())
        let expected = [CookieJar.Expected(amountC: 700_00, cadence: .monthly)]
        let unitLabels = ["404", "406", "408", "305"]
        for label in unitLabels where !sources.contains(where: { $0.label == label }) {
            context.insert(
                JarSourceRecord(id: "jar-unit-\(label)", label: label, kind: .unit, expected: expected)
            )
        }
        if !sources.contains(where: { $0.id == "jar-person-fern" }) {
            context.insert(
                JarSourceRecord(id: "jar-person-fern", label: "Fern", kind: .person, expected: [])
            )
        }
        sources = try context.fetch(FetchDescriptor<JarSourceRecord>())

        let jarTx = try context.fetch(FetchDescriptor<TransactionRecord>()).filter(\.isJarEntry)
        guard jarTx.isEmpty else { return }

        let accounts = try context.fetch(FetchDescriptor<AccountRecord>())
        let categories = try context.fetch(FetchDescriptor<CategoryRecord>())
        guard
            let cash = accounts.first(where: { $0.baseName == "House cash box" && $0.scope == .household }),
            let petty = categories.first(where: { $0.system && $0.item == "Petty Cash" })
                ?? categories.first(where: { !$0.system && $0.flow == .expense })
        else { return }

        let src404 = sources.first { $0.label == "404" }?.id
        let src406 = sources.first { $0.label == "406" }?.id
        let srcFern = sources.first { $0.id == "jar-person-fern" }?.id

        let demo: [(String, Int, CookieJar.Kind, String?, Bool?, String)] = [
            ("2026-08-01", 700_00, .income, src404, nil, "Internet"),
            ("2026-08-02", 700_00, .income, src406, nil, "Internet"),
            ("2026-08-05", 200_00, .spend, nil, nil, "Pocket"),
            ("2026-08-10", 500_00, .borrow, srcFern, false, "Fern No Cash"),
        ]
        for row in demo {
            context.insert(
                TransactionRecord(
                    purchaseDate: row.0,
                    realizedDate: row.0,
                    realizedStatus: .realized,
                    amountC: row.1,
                    accountId: cash.id,
                    categoryId: petty.id,
                    paidBy: .fern,
                    allocation: Allocation(fern: row.1, stark: 0),
                    note: row.5,
                    jarKind: row.2,
                    jarSourceId: row.3,
                    jarReturned: row.4
                )
            )
        }
    }

    /// Demo recurring rules for Forecast/Checklist (additive backfill).
    @MainActor
    static func seedDemoRulesIfNeeded(into context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<RecurringRuleRecord>())
        guard existing.isEmpty else { return }

        let accounts = try context.fetch(FetchDescriptor<AccountRecord>())
        let categories = try context.fetch(FetchDescriptor<CategoryRecord>())
        guard
            let cash = accounts.first(where: { $0.baseName == "House cash box" && $0.scope == .household }),
            let rent = categories.first(where: { $0.group == "Rent" && $0.item == "House" }),
            let internet = categories.first(where: { $0.group == "Utilities" && $0.item == "Internet PLDT" })
        else { return }

        let start = Cycle.cycleFor(isoDate: {
            let f = DateFormatter()
            f.calendar = Calendar(identifier: .gregorian)
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone.current
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: Date())
        }()).anchorISO

        context.insert(
            RecurringRuleRecord(
                title: rent.displayName,
                amountC: 20_000_00,
                accountId: cash.id,
                categoryId: rent.id,
                paidBy: .fern,
                allocation: Allocation(fern: 10_000_00, stark: 10_000_00),
                cadence: .biweekly,
                anchorDay: .both,
                amountBehavior: .exact,
                startCycleISO: start,
                flow: .expense,
                fixedVariable: .fixed
            )
        )
        context.insert(
            RecurringRuleRecord(
                title: internet.displayName,
                amountC: 1_799_00,
                accountId: cash.id,
                categoryId: internet.id,
                paidBy: .fern,
                allocation: Allocation(fern: 1_799_00, stark: 0),
                cadence: .monthly,
                anchorDay: .fifteenth,
                amountBehavior: .exact,
                startCycleISO: start,
                flow: .expense,
                fixedVariable: .fixed
            )
        )
    }

    /// Twin personal PruLife plans (additive). Retires bare single PruLife seed.
    @MainActor
    static func seedDemoFundingIfNeeded(into context: ModelContext) throws {
        let accounts = try context.fetch(FetchDescriptor<AccountRecord>())
        let categories = try context.fetch(FetchDescriptor<CategoryRecord>())
        guard
            let fernCash = accounts.first(where: { $0.baseName == "Cash" && $0.scope == .fern }),
            let starkCash = accounts.first(where: { $0.baseName == "Cash" && $0.scope == .stark }),
            let insurance = categories.first(where: {
                $0.group.localizedCaseInsensitiveContains("Insurance")
                    || ($0.group == "Needs" && $0.item.localizedCaseInsensitiveContains("Pru"))
            }) ?? categories.first(where: { !$0.system && $0.flow == .expense })
        else { return }

        let today: String = {
            let f = DateFormatter()
            f.calendar = Calendar(identifier: .gregorian)
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone.current
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: Date())
        }()
        let first = Cycle.cycleFor(isoDate: today)
        let second = Cycle.nextHalfMonth(after: first)

        var rules = try context.fetch(FetchDescriptor<RecurringRuleRecord>())
        var plans = try context.fetch(FetchDescriptor<FundingPlanRecord>())

        // Retire old single PruLife demo (not person-suffixed).
        for rule in rules where rule.title == "PruLife" {
            for plan in plans where plan.billRecurringRuleId == rule.id {
                context.delete(plan)
            }
            context.delete(rule)
        }
        rules = try context.fetch(FetchDescriptor<RecurringRuleRecord>())
        plans = try context.fetch(FetchDescriptor<FundingPlanRecord>())

        if !rules.contains(where: { $0.title == "PruLife · Fern" }) {
            let fernRule = RecurringRuleRecord(
                title: "PruLife · Fern",
                amountC: 3_000_00,
                accountId: fernCash.id,
                categoryId: insurance.id,
                paidBy: .fern,
                allocation: Allocation(fern: 3_000_00, stark: 0),
                cadence: .biweekly,
                anchorDay: .both,
                amountBehavior: .exact,
                startCycleISO: first.anchorISO,
                flow: .expense,
                fixedVariable: .fixed
            )
            context.insert(fernRule)
            context.insert(
                FundingPlanRecord(
                    billRecurringRuleId: fernRule.id,
                    billTitle: fernRule.title,
                    sourceAccountId: fernCash.id,
                    payoutCycleISO: second.anchorISO,
                    tranches: [
                        Funding.Tranche(cycleISO: first.anchorISO, amountC: 1_500_00, reserved: false),
                        Funding.Tranche(cycleISO: second.anchorISO, amountC: 1_500_00, reserved: false),
                    ]
                )
            )
        }

        if !rules.contains(where: { $0.title == "PruLife · Stark" }) {
            let starkRule = RecurringRuleRecord(
                title: "PruLife · Stark",
                amountC: 3_000_00,
                accountId: starkCash.id,
                categoryId: insurance.id,
                paidBy: .stark,
                allocation: Allocation(fern: 0, stark: 3_000_00),
                cadence: .biweekly,
                anchorDay: .both,
                amountBehavior: .exact,
                startCycleISO: first.anchorISO,
                flow: .expense,
                fixedVariable: .fixed
            )
            context.insert(starkRule)
            context.insert(
                FundingPlanRecord(
                    billRecurringRuleId: starkRule.id,
                    billTitle: starkRule.title,
                    sourceAccountId: starkCash.id,
                    payoutCycleISO: first.anchorISO,
                    tranches: [
                        Funding.Tranche(cycleISO: first.anchorISO, amountC: 3_000_00, reserved: false),
                    ]
                )
            )
        }
    }
}
