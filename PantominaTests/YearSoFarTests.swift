import Foundation
import Testing
@testable import Pantomina

@Suite("YearSoFar")
struct YearSoFarTests {
    private func cat(
        id: String,
        label: String,
        flow: FlowType,
        needWant: NeedWant? = nil
    ) -> YearSoFar.CategoryMeta {
        YearSoFar.CategoryMeta(id: id, label: label, flow: flow, needWant: needWant)
    }

    private func leg(
        amountC: Int,
        date: String,
        paidBy: PersonId = .fern,
        allocFern: Int? = nil,
        allocStark: Int = 0,
        categoryId: String,
        status: RealizedStatus = .realized,
        role: SettlementRole? = nil,
        jar: CookieJar.Kind? = nil
    ) -> YearSoFar.Leg {
        YearSoFar.Leg(
            amountC: amountC,
            purchaseDate: date,
            realizedDate: date,
            realizedStatus: status,
            paidBy: paidBy,
            allocFernC: allocFern ?? amountC,
            allocStarkC: allocStark,
            categoryId: categoryId,
            settlementRole: role,
            jarKind: jar
        )
    }

    @Test("split lens uses allocation; justMine uses paidBy full amount")
    func lenses() {
        let cats = [cat(id: "rent", label: "House", flow: .expense, needWant: .need)]
        let shared = leg(
            amountC: 10_000_00,
            date: "2026-03-15",
            paidBy: .fern,
            allocFern: 6_000_00,
            allocStark: 4_000_00,
            categoryId: "rent"
        )
        let fernSplit = YearSoFar.report(year: 2026, personId: .fern, lens: .split, legs: [shared], categories: cats)
        #expect(fernSplit.expenseTotalC == 6_000_00)
        #expect(fernSplit.needsC == 6_000_00)

        let starkSplit = YearSoFar.report(year: 2026, personId: .stark, lens: .split, legs: [shared], categories: cats)
        #expect(starkSplit.expenseTotalC == 4_000_00)

        let starkMine = YearSoFar.report(year: 2026, personId: .stark, lens: .justMine, legs: [shared], categories: cats)
        #expect(starkMine.expenseTotalC == 0)

        let fernMine = YearSoFar.report(year: 2026, personId: .fern, lens: .justMine, legs: [shared], categories: cats)
        #expect(fernMine.expenseTotalC == 10_000_00)
    }

    @Test("excludes projected and fund_move theater; jar.kind overrides category")
    func exclusionsAndJar() {
        let cats = [
            cat(id: "salary", label: "Salary", flow: .income),
            cat(id: "misc", label: "Misc", flow: .expense),
        ]
        let legs = [
            leg(amountC: 50_000_00, date: "2026-01-15", categoryId: "salary"),
            leg(amountC: 1_000_00, date: "2026-01-20", categoryId: "misc", status: .projected),
            leg(amountC: 2_000_00, date: "2026-01-21", categoryId: "misc", role: .fundMove),
            leg(amountC: 700_00, date: "2026-02-01", categoryId: "misc", jar: .income),
        ]
        let r = YearSoFar.report(year: 2026, personId: .fern, lens: .justMine, legs: legs, categories: cats)
        #expect(r.incomeTotalC == 50_700_00)
        #expect(r.expenseTotalC == 0)
        #expect(r.months.count == 2)
    }

    @Test("needs vs wants and category donut sort by amount")
    func needsWantsDonut() {
        let cats = [
            cat(id: "rent", label: "House", flow: .expense, needWant: .need),
            cat(id: "spotify", label: "Spotify", flow: .expense, needWant: .want),
            cat(id: "food", label: "Food", flow: .expense, needWant: .need),
        ]
        let legs = [
            leg(amountC: 5_000_00, date: "2026-05-10", categoryId: "rent"),
            leg(amountC: 200_00, date: "2026-05-11", categoryId: "spotify"),
            leg(amountC: 3_000_00, date: "2026-05-12", categoryId: "food"),
            leg(amountC: 9_000_00, date: "2025-12-31", categoryId: "rent"),
        ]
        let r = YearSoFar.report(year: 2026, personId: .fern, lens: .justMine, legs: legs, categories: cats)
        #expect(r.needsC == 8_000_00)
        #expect(r.wantsC == 200_00)
        #expect(r.categoryExpenses.map(\.categoryId) == ["rent", "food", "spotify"])
        #expect(r.months.count == 1)
    }

    @Test("household uses each leg once at full amountC — not Fern-split plus Stark-split")
    func householdCombinedNoDoubleCount() {
        let cats = [cat(id: "rent", label: "House", flow: .expense, needWant: .need)]
        let shared = leg(
            amountC: 10_000_00,
            date: "2026-03-15",
            paidBy: .fern,
            allocFern: 6_000_00,
            allocStark: 4_000_00,
            categoryId: "rent"
        )
        let household = YearSoFar.report(
            year: 2026,
            scope: .household,
            legs: [shared],
            categories: cats
        )
        #expect(household.expenseTotalC == 10_000_00)
        #expect(household.needsC == 10_000_00)
        #expect(household.scope == .household)

        let fernPlusStark =
            YearSoFar.report(year: 2026, personId: .fern, lens: .split, legs: [shared], categories: cats)
                .expenseTotalC
            + YearSoFar.report(year: 2026, personId: .stark, lens: .split, legs: [shared], categories: cats)
                .expenseTotalC
        #expect(fernPlusStark == 10_000_00)
        #expect(household.expenseTotalC == fernPlusStark)
    }

    @Test("usualExpenseC averages prior months — excludes the latest")
    func trailingAverage() {
        let months = [
            YearSoFar.MonthBucket(yearMonth: "2026-08", incomeC: 0, expenseC: 1_000_00),
            YearSoFar.MonthBucket(yearMonth: "2026-09", incomeC: 0, expenseC: 2_000_00),
            YearSoFar.MonthBucket(yearMonth: "2026-10", incomeC: 0, expenseC: 9_000_00),
        ]
        #expect(YearSoFar.usualExpenseC(months: months) == 1_500_00)
        #expect(YearSoFar.trailingExpenseAverageC(months: months) == 1_500_00)

        let sparse = [
            YearSoFar.MonthBucket(yearMonth: "2026-01", incomeC: 500_00, expenseC: 0),
            YearSoFar.MonthBucket(yearMonth: "2026-03", incomeC: 0, expenseC: 3_000_00),
        ]
        #expect(YearSoFar.usualExpenseC(months: sparse) == nil)
        #expect(YearSoFar.usualExpenseC(months: []) == nil)
    }

    @Test("monthVsUsualInsight always compares latest to prior usual; spike at 1.5×")
    func expenseSpike() {
        let months = [
            YearSoFar.MonthBucket(yearMonth: "2026-08", incomeC: 0, expenseC: 1_000_00),
            YearSoFar.MonthBucket(yearMonth: "2026-09", incomeC: 0, expenseC: 2_000_00),
            YearSoFar.MonthBucket(yearMonth: "2026-10", incomeC: 0, expenseC: 9_000_00),
        ]
        let vs = YearSoFar.monthVsUsualInsight(months: months)
        #expect(vs?.yearMonth == "2026-10")
        #expect(vs?.expenseC == 9_000_00)
        #expect(vs?.usualC == 1_500_00)
        #expect(vs?.multiple ?? 0 > 5.0)

        let spike = YearSoFar.expenseSpikeInsight(months: months)
        #expect(spike?.yearMonth == "2026-10")
    }

    @Test("savings flow sums into savingsC; not expense")
    func savingsBucket() {
        let cats = [
            cat(id: "park", label: "Savings · Parked", flow: .savings),
            cat(id: "rent", label: "House", flow: .expense, needWant: .need),
        ]
        let legs = [
            leg(amountC: 5_000_00, date: "2026-04-10", categoryId: "park"),
            leg(amountC: 2_000_00, date: "2026-04-11", categoryId: "rent"),
        ]
        let r = YearSoFar.report(year: 2026, personId: .fern, lens: .justMine, legs: legs, categories: cats)
        #expect(r.savingsC == 5_000_00)
        #expect(r.expenseTotalC == 2_000_00)
        #expect(r.needsC == 2_000_00)
    }

    @Test("demoRows cover all 12 months with realized-style dates")
    func demoRowsTwelveMonths() {
        let rows = YearSoFar.demoRows(year: 2026)
        let months = Set(rows.map { String($0.isoDate.prefix(7)) })
        #expect(months.count == 12)
        for m in 1...12 {
            #expect(months.contains(String(format: "2026-%02d", m)))
        }
        #expect(rows.contains { $0.group == "Income" && $0.item == "Salary" })
        #expect(rows.contains { $0.group == "Rent" })
        // October spike travel row
        #expect(rows.contains { $0.isoDate.hasPrefix("2026-10") && $0.group == "Travels" })
    }

    @Test("demo years for the year wheel are current and prior")
    func demoYearsCurrentAndPrior() {
        #expect(YearSoFar.demoYears(relativeTo: 2026) == [2026, 2025])
        let rows = YearSoFar.demoRows(year: 2025)
        #expect(rows.allSatisfy { $0.isoDate.hasPrefix("2025-") })
        #expect(Set(rows.map { String($0.isoDate.prefix(7)) }).count == 12)
    }
}
