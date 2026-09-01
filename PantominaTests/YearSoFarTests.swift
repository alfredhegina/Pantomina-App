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
}
