import Foundation

/// Our Year So Far — pure. UI charts these totals; does not re-sum the ledger.
enum YearSoFar {
    enum Lens: String, Sendable, Equatable {
        /// Person's allocation share (Fern/Stark cents on the row).
        case split
        /// Rows paid by the person; full `amountC`.
        case justMine
    }

    /// Peer scope matches Empire chrome: personal + lens, or household cashflow once.
    enum Scope: Equatable, Sendable {
        case personal(PersonId, Lens)
        case household
    }

    struct CategoryMeta: Equatable, Sendable {
        var id: String
        var label: String
        var flow: FlowType
        var needWant: NeedWant?
    }

    struct Leg: Equatable, Sendable {
        var amountC: Int
        var purchaseDate: String
        var realizedDate: String?
        var realizedStatus: RealizedStatus
        var paidBy: PersonId
        var allocFernC: Int
        var allocStarkC: Int
        var categoryId: String
        var settlementRole: SettlementRole? = nil
        var jarKind: CookieJar.Kind? = nil

        var effectiveDate: String { realizedDate ?? purchaseDate }
    }

    struct MonthBucket: Equatable, Sendable {
        var yearMonth: String
        var incomeC: Int
        var expenseC: Int
    }

    struct CategorySlice: Equatable, Sendable {
        var categoryId: String
        var label: String
        var amountC: Int
    }

    struct Report: Equatable, Sendable {
        var year: Int
        var scope: Scope
        var months: [MonthBucket]
        var incomeTotalC: Int
        var expenseTotalC: Int
        var categoryExpenses: [CategorySlice]
        var needsC: Int
        var wantsC: Int
        /// Attributed `.savings` + `.sinking` flows for the year/scope.
        var savingsC: Int
    }

    /// True when the leg should appear in YTD income/expense totals.
    static func countsTowardYTD(_ leg: Leg) -> Bool {
        guard leg.realizedStatus == .realized else { return false }
        switch leg.settlementRole {
        case .contribution, .receivable, .fundMove:
            return false
        case .loanPayment, nil:
            return true
        }
    }

    /// Income vs expense classification for bars/donut. Jar overrides category flow.
    static func classifiedFlow(leg: Leg, categoryFlow: FlowType?) -> FlowType? {
        if let jar = leg.jarKind {
            switch jar {
            case .income: return .income
            case .spend, .borrow: return .expense
            }
        }
        switch categoryFlow {
        case .income: return .income
        case .expense: return .expense
        case .savings, .sinking: return categoryFlow
        case .transfer, .none:
            return nil
        }
    }

    static func attributedAmountC(leg: Leg, personId: PersonId, lens: Lens) -> Int {
        switch lens {
        case .justMine:
            guard leg.paidBy == personId else { return 0 }
            return leg.amountC
        case .split:
            switch personId {
            case .fern: return leg.allocFernC
            case .stark: return leg.allocStarkC
            }
        }
    }

    static func attributedAmountC(leg: Leg, scope: Scope) -> Int {
        switch scope {
        case .household:
            return leg.amountC
        case .personal(let personId, let lens):
            return attributedAmountC(leg: leg, personId: personId, lens: lens)
        }
    }

    static func report(
        year: Int,
        personId: PersonId,
        lens: Lens,
        legs: [Leg],
        categories: [CategoryMeta]
    ) -> Report {
        report(year: year, scope: .personal(personId, lens), legs: legs, categories: categories)
    }

    static func report(
        year: Int,
        scope: Scope,
        legs: [Leg],
        categories: [CategoryMeta]
    ) -> Report {
        let catById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        let prefix = String(format: "%04d-", year)

        var monthIncome: [String: Int] = [:]
        var monthExpense: [String: Int] = [:]
        var expenseByCat: [String: Int] = [:]
        var needsC = 0
        var wantsC = 0
        var incomeTotal = 0
        var expenseTotal = 0
        var savingsTotal = 0

        for leg in legs {
            guard countsTowardYTD(leg) else { continue }
            guard leg.effectiveDate.hasPrefix(prefix) else { continue }
            let amount = attributedAmountC(leg: leg, scope: scope)
            guard amount != 0 else { continue }
            let flow = classifiedFlow(leg: leg, categoryFlow: catById[leg.categoryId]?.flow)
            guard let flow else { continue }

            let ym = String(leg.effectiveDate.prefix(7))
            switch flow {
            case .income:
                monthIncome[ym, default: 0] += amount
                incomeTotal += amount
            case .expense:
                monthExpense[ym, default: 0] += amount
                expenseTotal += amount
                expenseByCat[leg.categoryId, default: 0] += amount
                switch catById[leg.categoryId]?.needWant {
                case .need: needsC += amount
                case .want: wantsC += amount
                case .none: break
                }
            case .savings, .sinking:
                savingsTotal += amount
            case .transfer:
                break
            }
        }

        let months = Set(monthIncome.keys).union(monthExpense.keys).sorted().map { ym in
            MonthBucket(
                yearMonth: ym,
                incomeC: monthIncome[ym] ?? 0,
                expenseC: monthExpense[ym] ?? 0
            )
        }

        let categoryExpenses = expenseByCat
            .map { id, amount -> CategorySlice in
                CategorySlice(
                    categoryId: id,
                    label: catById[id]?.label ?? id,
                    amountC: amount
                )
            }
            .sorted { $0.amountC > $1.amountC }

        return Report(
            year: year,
            scope: scope,
            months: months,
            incomeTotalC: incomeTotal,
            expenseTotalC: expenseTotal,
            categoryExpenses: categoryExpenses,
            needsC: needsC,
            wantsC: wantsC,
            savingsC: savingsTotal
        )
    }

    /// Mean of up to `window` spend months **before** the latest spend month (“usual”).
    static func usualExpenseC(months: [MonthBucket], window: Int = 3) -> Int? {
        precondition(window > 0)
        let withSpend = months.filter { $0.expenseC > 0 }.sorted { $0.yearMonth < $1.yearMonth }
        guard withSpend.count >= 2 else { return nil }
        let prior = Array(withSpend.dropLast().suffix(window))
        guard !prior.isEmpty else { return nil }
        let sum = prior.reduce(0) { $0 + $1.expenseC }
        return sum / prior.count
    }

    /// Legacy name — same as `usualExpenseC` (prior months only, not including latest).
    static func trailingExpenseAverageC(months: [MonthBucket], window: Int = 3) -> Int? {
        usualExpenseC(months: months, window: window)
    }

    struct ExpenseSpikeInsight: Equatable, Sendable {
        var yearMonth: String
        var expenseC: Int
        var usualC: Int
        /// expenseC / usualC (usual > 0).
        var multiple: Double
    }

    /// Latest spend month vs usual (prior up-to-3). Always when both exist.
    static func monthVsUsualInsight(
        months: [MonthBucket],
        window: Int = 3
    ) -> ExpenseSpikeInsight? {
        guard let usual = usualExpenseC(months: months, window: window), usual > 0 else {
            return nil
        }
        guard let latest = months.filter({ $0.expenseC > 0 }).sorted(by: { $0.yearMonth < $1.yearMonth }).last
        else { return nil }
        let multiple = Double(latest.expenseC) / Double(usual)
        return ExpenseSpikeInsight(
            yearMonth: latest.yearMonth,
            expenseC: latest.expenseC,
            usualC: usual,
            multiple: multiple
        )
    }

    /// Latest spend month vs trailing average; only when ≥ 1.5× usual.
    static func expenseSpikeInsight(
        months: [MonthBucket],
        window: Int = 3,
        threshold: Double = 1.5
    ) -> ExpenseSpikeInsight? {
        guard let insight = monthVsUsualInsight(months: months, window: window),
              insight.multiple >= threshold
        else { return nil }
        return insight
    }

    // MARK: - Demo seed (12-month YTD smoke)

    static let demoNoteMarker = "YTD demo"
    static let demoIdPrefix = "ytd-demo-v2-"

    /// Years the YTD demo (and year wheel) covers — this year plus last year.
    static func demoYears(relativeTo current: Int = Calendar.current.component(.year, from: Date())) -> [Int] {
        [current, current - 1]
    }

    struct DemoRow: Equatable, Sendable {
        var isoDate: String
        var amountC: Int
        var group: String
        var item: String
        var paidBy: PersonId
        var allocFernC: Int
        var allocStarkC: Int
    }

    /// Deterministic 12-month ledger for Quiet ledger smoke (income + spend + one spike month).
    static func demoRows(year: Int) -> [DemoRow] {
        var rows: [DemoRow] = []
        for month in 1...12 {
            let yyyymm = String(format: "%04d-%02d", year, month)
            // Salary — Fern only
            rows.append(
                DemoRow(
                    isoDate: "\(yyyymm)-15",
                    amountC: 50_000_00,
                    group: "Income",
                    item: "Salary",
                    paidBy: .fern,
                    allocFernC: 50_000_00,
                    allocStarkC: 0
                )
            )
            // Rent — shared
            rows.append(
                DemoRow(
                    isoDate: "\(yyyymm)-01",
                    amountC: 20_000_00,
                    group: "Rent",
                    item: "House",
                    paidBy: .fern,
                    allocFernC: 10_000_00,
                    allocStarkC: 10_000_00
                )
            )
            // Internet — shared
            rows.append(
                DemoRow(
                    isoDate: "\(yyyymm)-15",
                    amountC: 1_799_00,
                    group: "Utilities",
                    item: "Internet PLDT",
                    paidBy: .fern,
                    allocFernC: 900_00,
                    allocStarkC: 899_00
                )
            )
            // Electricity — varies
            let power = 2_200_00 + (month * 180_00)
            rows.append(
                DemoRow(
                    isoDate: "\(yyyymm)-20",
                    amountC: power,
                    group: "Utilities",
                    item: "Electricity",
                    paidBy: .fern,
                    allocFernC: power / 2,
                    allocStarkC: power - power / 2
                )
            )
            // Groceries — Fern or Stark alternate
            let grocery = 3_500_00 + (month % 4) * 900_00
            let groceryBy: PersonId = month % 2 == 0 ? .stark : .fern
            rows.append(
                DemoRow(
                    isoDate: "\(yyyymm)-08",
                    amountC: grocery,
                    group: "Groceries",
                    item: "Household",
                    paidBy: groceryBy,
                    allocFernC: groceryBy == .fern ? grocery : grocery / 2,
                    allocStarkC: groceryBy == .stark ? grocery : grocery / 2
                )
            )
            // Spotify — want, Fern
            rows.append(
                DemoRow(
                    isoDate: "\(yyyymm)-05",
                    amountC: 149_00,
                    group: "Subscription",
                    item: "Spotify",
                    paidBy: .fern,
                    allocFernC: 149_00,
                    allocStarkC: 0
                )
            )
            // Parked savings — Fern
            rows.append(
                DemoRow(
                    isoDate: "\(yyyymm)-25",
                    amountC: 5_000_00,
                    group: "Savings",
                    item: "Parked",
                    paidBy: .fern,
                    allocFernC: 5_000_00,
                    allocStarkC: 0
                )
            )
        }
        // October spike — travel (makes “vs usual” pop)
        rows.append(
            DemoRow(
                isoDate: String(format: "%04d-10-12", year),
                amountC: 18_500_00,
                group: "Travels",
                item: "Accommodation",
                paidBy: .fern,
                allocFernC: 9_250_00,
                allocStarkC: 9_250_00
            )
        )
        // Mid-year side hustle
        rows.append(
            DemoRow(
                isoDate: String(format: "%04d-06-28", year),
                amountC: 8_000_00,
                group: "Income",
                item: "Side hustle",
                paidBy: .fern,
                allocFernC: 8_000_00,
                allocStarkC: 0
            )
        )
        return rows
    }
}
