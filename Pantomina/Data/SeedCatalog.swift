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
        .init(group: "Savings", item: "Parked", flow: .savings, needWant: nil, fixedVariable: .variable),
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
        if !(try context.fetch(FetchDescriptor<CategoryRecord>()))
            .contains(where: { $0.group == "Savings" && $0.item == "Parked" }) {
            context.insert(
                CategoryRecord(
                    group: "Savings",
                    item: "Parked",
                    flow: .savings,
                    needWant: nil,
                    fixedVariable: .variable,
                    system: false
                )
            )
        }

        try seedDemoRulesIfNeeded(into: context)
        try seedDemoFundingIfNeeded(into: context)
        try seedDemoJarIfNeeded(into: context)
        try seedDemoLoansIfNeeded(into: context)
        try seedDemoFundsIfNeeded(into: context)
        try seedDemoExternalsIfNeeded(into: context)
        for y in YearSoFar.demoYears() {
            try seedDemoYearSoFarIfNeeded(into: context, year: y)
        }
        try context.save()
    }

    /// Spec-named external pockets for Balance Day (prefilled tier). Additive.
    @MainActor
    static func seedDemoExternalsIfNeeded(into context: ModelContext) throws {
        struct ExternalSeed {
            var id: String
            var baseName: String
            var owner: String
            var scope: Scope
            var kind: AccountKind
            var lastConfirmedBalanceC: Int
        }

        let seeds: [ExternalSeed] = [
            .init(
                id: "acct-ext-prulife",
                baseName: "PruLife",
                owner: "fern",
                scope: .fern,
                kind: .savingsAsset,
                lastConfirmedBalanceC: 185_000_00
            ),
            .init(
                id: "acct-ext-philstocks",
                baseName: "Philstocks",
                owner: "fern",
                scope: .fern,
                kind: .investment,
                lastConfirmedBalanceC: 42_500_00
            ),
            .init(
                id: "acct-ext-gotrade",
                baseName: "GoTrade",
                owner: "fern",
                scope: .fern,
                kind: .investment,
                lastConfirmedBalanceC: 18_250_00
            ),
            .init(
                id: "acct-ext-coinsph",
                baseName: "CoinsPH",
                owner: "fern",
                scope: .fern,
                kind: .investment,
                lastConfirmedBalanceC: 6_800_00
            ),
            .init(
                id: "acct-ext-pagibig",
                baseName: "Pag-IBIG MP2",
                owner: "fern",
                scope: .fern,
                kind: .govMandated,
                lastConfirmedBalanceC: 95_000_00
            ),
            .init(
                id: "acct-ext-stark-maya-invest",
                baseName: "Maya Invest",
                owner: "stark",
                scope: .stark,
                kind: .investment,
                lastConfirmedBalanceC: 12_000_00
            ),
        ]

        let existing = try context.fetch(FetchDescriptor<AccountRecord>())
        let byId = Set(existing.map(\.id))
        let byNameScope = Set(existing.map { "\($0.baseName)|\($0.scopeRaw)" })

        for seed in seeds {
            if byId.contains(seed.id) { continue }
            if byNameScope.contains("\(seed.baseName)|\(seed.scope.rawValue)") { continue }
            context.insert(
                AccountRecord(
                    id: seed.id,
                    baseName: seed.baseName,
                    owner: seed.owner,
                    scope: seed.scope,
                    kind: seed.kind,
                    settlement: .instant,
                    lastConfirmedBalanceC: seed.lastConfirmedBalanceC,
                    lastConfirmedCycleISO: nil
                )
            )
        }
    }

    /// Twelve months of realized legs for Our Year So Far Quiet ledger smoke. Additive; idempotent per year.
    /// Returns `true` when this year already had the demo or rows were inserted.
    @MainActor
    @discardableResult
    static func seedDemoYearSoFarIfNeeded(into context: ModelContext, year: Int? = nil) throws -> Bool {
        let year = year ?? Calendar.current.component(.year, from: Date())
        let prefix = "\(YearSoFar.demoIdPrefix)\(year)-"
        let existing = try context.fetch(FetchDescriptor<TransactionRecord>())
        if existing.contains(where: { $0.id.hasPrefix(prefix) }) { return true }

        let accounts = try context.fetch(FetchDescriptor<AccountRecord>())
        guard
            let cash = accounts.first(where: { $0.baseName == "House cash box" && $0.scope == .household })
                ?? accounts.first(where: { $0.scope == .fern && $0.kind == .cash })
                ?? accounts.first
        else { return false }

        let categories = try context.fetch(FetchDescriptor<CategoryRecord>())
        if !categories.contains(where: { $0.group == "Savings" && $0.item == "Parked" }) {
            context.insert(
                CategoryRecord(
                    group: "Savings",
                    item: "Parked",
                    flow: .savings,
                    needWant: nil,
                    fixedVariable: .variable,
                    system: false
                )
            )
        }
        let cats = try context.fetch(FetchDescriptor<CategoryRecord>())

        func categoryId(group: String, item: String) -> String? {
            cats.first { $0.group == group && $0.item == item }?.id
        }

        var inserted = 0
        for (index, row) in YearSoFar.demoRows(year: year).enumerated() {
            guard let catId = categoryId(group: row.group, item: row.item) else { continue }
            context.insert(
                TransactionRecord(
                    id: "\(prefix)\(index)",
                    purchaseDate: row.isoDate,
                    realizedDate: row.isoDate,
                    realizedStatus: .realized,
                    amountC: row.amountC,
                    accountId: cash.id,
                    categoryId: catId,
                    paidBy: row.paidBy,
                    allocation: Allocation(fern: row.allocFernC, stark: row.allocStarkC),
                    note: YearSoFar.demoNoteMarker
                )
            )
            inserted += 1
        }
        return inserted > 0
    }

    /// Demo War Chest funds (Fern personal). Additive.
    @MainActor
    static func seedDemoFundsIfNeeded(into context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<FundRecord>())
        guard !existing.contains(where: { $0.id == "fund-emergency" }) else { return }

        let accounts = try context.fetch(FetchDescriptor<AccountRecord>())
        let homeId = accounts.first { $0.baseName == "BPI Debit" && $0.scope == .fern }?.id
            ?? accounts.first { $0.scope == .fern }?.id
            ?? accounts.first?.id
        guard let homeId else { return }

        context.insert(
            FundRecord(
                id: "fund-loan-payoff",
                name: "Loan payoff",
                purpose: .loanPayoff,
                homeAccountId: homeId,
                targetC: nil,
                balanceC: 25_000_00
            )
        )
        context.insert(
            FundRecord(
                id: "fund-sinking",
                name: "Sinking · car",
                purpose: .sinking,
                homeAccountId: homeId,
                targetC: 80_000_00,
                balanceC: 18_000_00
            )
        )
        context.insert(
            FundRecord(
                id: "fund-emergency",
                name: "Emergency",
                purpose: .emergency,
                homeAccountId: homeId,
                targetC: 100_000_00,
                balanceC: 50_000_00
            )
        )
    }

    /// UB Personal accept fixture + second snowball demo loan (additive).
    @MainActor
    static func seedDemoLoansIfNeeded(into context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<LoanRecord>())
        let accounts = try context.fetch(FetchDescriptor<AccountRecord>())
        let paymentId = accounts.first { $0.baseName == "BPI Debit" && $0.scope == .fern }?.id
            ?? accounts.first { $0.scope == .fern }?.id
            ?? accounts.first?.id
        guard let paymentId else { return }

        if !existing.contains(where: { $0.id == "loan-ub-personal" }) {
            context.insert(
                LoanRecord(
                    id: "loan-ub-personal",
                    lender: "UnionBank",
                    description: "UB Personal Loan",
                    purpose: "Debt consolidation",
                    owner: .fern,
                    principalC: 850_000_00,
                    totalLoanC: 104_819_460,
                    termMonths: 60,
                    paidMonths: 24,
                    monthlyC: 17_469_91,
                    cutoff: 15,
                    startDateISO: "2024-08-15",
                    endDateISO: "2029-08-15",
                    aprPercent: 18.5,
                    snowballOrder: 1,
                    snowballBatch: 1,
                    strategy: .prepay,
                    journal: [
                        Loan.JournalEntry(dateISO: "2024-08-01", note: "Took the loan to clear high-APR cards.")
                    ],
                    status: .active,
                    paymentAccountId: paymentId
                )
            )
        }

        if !existing.contains(where: { $0.id == "loan-bpi-remnant" }) {
            context.insert(
                LoanRecord(
                    id: "loan-bpi-remnant",
                    lender: "BPI",
                    description: "BPI CC remnant",
                    purpose: "Clear the card",
                    owner: .fern,
                    principalC: 40_000_00,
                    totalLoanC: 40_000_00,
                    termMonths: 8,
                    paidMonths: 2,
                    monthlyC: 5_000_00,
                    cutoff: 30,
                    startDateISO: "2026-01-30",
                    endDateISO: "2026-09-30",
                    aprPercent: 0,
                    snowballOrder: 2,
                    snowballBatch: 1,
                    strategy: .prepay,
                    journal: [],
                    status: .active,
                    paymentAccountId: paymentId
                )
            )
        }
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
