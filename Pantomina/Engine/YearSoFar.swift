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
        case .transfer, .savings, .sinking, .none:
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
            case .transfer, .savings, .sinking:
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
            wantsC: wantsC
        )
    }
}
