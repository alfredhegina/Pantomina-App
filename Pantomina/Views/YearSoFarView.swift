import Charts
import SwiftUI
import SwiftData

struct YearSoFarView: View {
    /// Peer Seg matches Empire — Household is not nested under a person.
    private enum ScopeTab: String, CaseIterable, Identifiable {
        case fern, stark, household
        var id: String { rawValue }
    }

    @Query private var people: [PersonRecord]
    @Query private var categories: [CategoryRecord]
    @Query private var transactions: [TransactionRecord]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scopeTab: ScopeTab = .fern
    @State private var lens: YearSoFar.Lens = .split
    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var chartsRevealed = false

    private var fernName: String { people.first { $0.id == .fern }?.name ?? "Fern" }
    private var starkName: String { people.first { $0.id == .stark }?.name ?? "Stark" }

    private var activePersonName: String {
        switch scopeTab {
        case .fern: return fernName
        case .stark: return starkName
        case .household: return "Household"
        }
    }

    private var reportScope: YearSoFar.Scope {
        switch scopeTab {
        case .fern: return .personal(.fern, lens)
        case .stark: return .personal(.stark, lens)
        case .household: return .household
        }
    }

    private var categoryMetas: [YearSoFar.CategoryMeta] {
        categories.map {
            YearSoFar.CategoryMeta(
                id: $0.id,
                label: $0.displayName,
                flow: $0.flow,
                needWant: $0.needWant
            )
        }
    }

    private var legs: [YearSoFar.Leg] {
        transactions.map {
            YearSoFar.Leg(
                amountC: $0.amountC,
                purchaseDate: $0.purchaseDate,
                realizedDate: $0.realizedDate,
                realizedStatus: $0.realizedStatus,
                paidBy: $0.paidBy,
                allocFernC: $0.allocFernC,
                allocStarkC: $0.allocStarkC,
                categoryId: $0.categoryId,
                settlementRole: $0.settlementRole,
                jarKind: $0.jarKind
            )
        }
    }

    private var report: YearSoFar.Report {
        YearSoFar.report(
            year: year,
            scope: reportScope,
            legs: legs,
            categories: categoryMetas
        )
    }

    private var yearOptions: [Int] {
        var years = Set(legs.compactMap { Int($0.effectiveDate.prefix(4)) })
        years.insert(year)
        years.insert(Calendar.current.component(.year, from: Date()))
        return years.sorted(by: >)
    }

    /// Top 5 by amount + rolled Other for the donut.
    private var donutSlices: [(id: String, label: String, amountC: Int, rank: Int)] {
        let all = report.categoryExpenses
        guard !all.isEmpty else { return [] }
        if all.count <= 5 {
            return all.enumerated().map { i, s in
                (s.categoryId, s.label, s.amountC, i)
            }
        }
        let head = Array(all.prefix(5))
        let otherAmount = all.dropFirst(5).reduce(0) { $0 + $1.amountC }
        var rows = head.enumerated().map { i, s in
            (s.categoryId, s.label, s.amountC, i)
        }
        rows.append(("__other__", "Other", otherAmount, 5))
        return rows
    }

    var body: some View {
        List {
            Section {
                Picker("Scope", selection: $scopeTab) {
                    Text(fernName).tag(ScopeTab.fern)
                    Text(starkName).tag(ScopeTab.stark)
                    Text("Household").tag(ScopeTab.household)
                }
                .pickerStyle(.segmented)

                if scopeTab != .household {
                    Picker("Lens", selection: $lens) {
                        Text("Split").tag(YearSoFar.Lens.split)
                        Text("Just mine").tag(YearSoFar.Lens.justMine)
                    }
                    .pickerStyle(.segmented)
                }

                Picker("Year", selection: $year) {
                    ForEach(yearOptions, id: \.self) { y in
                        Text(String(y)).tag(y)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Year")
            } footer: {
                Group {
                    if scopeTab == .household {
                        Text("\(fernName) and \(starkName) are personal books. Household is shared — not under either person.")
                    } else {
                        Text("Split is each person’s share. Just mine is what \(activePersonName) paid.")
                    }
                }
                .font(PantominaFont.caption)
            }

            if report.months.isEmpty && report.incomeTotalC == 0 && report.expenseTotalC == 0 {
                Section {
                    Text(emptyCopy)
                        .foregroundStyle(Color.pantomina.muted)
                }
            } else {
                totalsSection
                monthlyBarsSection
                if !report.categoryExpenses.isEmpty {
                    donutSection
                }
                needsWantsSection
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.pantomina.ground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                PetTitle("Our Year So Far")
            }
        }
        .onAppear { revealCharts() }
        .onChange(of: year) { _, _ in
            chartsRevealed = false
            revealCharts()
        }
    }

    private var emptyCopy: String {
        "Nothing counted in \(year) yet. Rare quiet year."
    }

    private func revealCharts() {
        guard !reduceMotion else {
            chartsRevealed = true
            return
        }
        withAnimation(PantominaMotion.feedback) { chartsRevealed = true }
    }

    private var totalsSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Income")
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.muted)
                    Text(formatPeso(report.incomeTotalC))
                        .font(PantominaFont.body.weight(.semibold))
                        .foregroundStyle(Color.pantomina.sageDeep)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Expense")
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.muted)
                    Text(formatPeso(report.expenseTotalC))
                        .font(PantominaFont.body.weight(.semibold))
                        .foregroundStyle(Color.pantomina.terraDeep)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } footer: {
            Text("Counted by when it became real · \(String(year))")
                .font(PantominaFont.caption)
        }
    }

    private var monthlyBarsSection: some View {
        Section {
            Chart {
                ForEach(report.months, id: \.yearMonth) { m in
                    BarMark(
                        x: .value("Month", shortMonth(m.yearMonth)),
                        y: .value("Income", Double(m.incomeC) / 100.0)
                    )
                    .foregroundStyle(Color.pantomina.sage)
                    .position(by: .value("Kind", "Income"))

                    BarMark(
                        x: .value("Month", shortMonth(m.yearMonth)),
                        y: .value("Expense", Double(m.expenseC) / 100.0)
                    )
                    .foregroundStyle(Color.pantomina.terra)
                    .position(by: .value("Kind", "Expense"))
                }
            }
            .frame(height: 180)
            .opacity(chartsRevealed ? 1 : 0)
            .accessibilityLabel("Income and expense by month")
        } header: {
            Text("By month")
        }
    }

    private var donutSection: some View {
        Section {
            ZStack {
                Chart(donutSlices, id: \.id) { slice in
                    SectorMark(
                        angle: .value("Amount", Double(slice.amountC) / 100.0),
                        innerRadius: .ratio(0.58),
                        angularInset: 1.5
                    )
                    .foregroundStyle(Color.pantomina.categorySlice(rank: slice.rank))
                }
                .frame(height: 200)

                VStack(spacing: 2) {
                    Text(formatPeso(report.expenseTotalC))
                        .font(PantominaFont.body.weight(.semibold))
                        .foregroundStyle(Color.pantomina.ink)
                        .monospacedDigit()
                    Text("Spend")
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.muted)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Spend \(formatPeso(report.expenseTotalC))")
            }
            .opacity(chartsRevealed ? 1 : 0)

            ForEach(Array(donutSlices.enumerated()), id: \.element.id) { _, slice in
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.pantomina.categorySlice(rank: slice.rank))
                        .frame(width: 8, height: 8)
                    Text(slice.label)
                        .foregroundStyle(Color.pantomina.ink)
                    Spacer()
                    Text(formatPeso(slice.amountC))
                        .font(PantominaFont.caption)
                        .monospacedDigit()
                        .foregroundStyle(Color.pantomina.muted)
                }
            }
        } header: {
            Text("Where it went")
        }
    }

    private var needsWantsSection: some View {
        Section {
            HStack {
                compact("Needs", report.needsC)
                compact("Wants", report.wantsC)
            }
        } header: {
            Text("Needs & wants")
        } footer: {
            Text("From category tags. Untagged spend stays out of these two.")
                .font(PantominaFont.caption)
        }
    }

    private func compact(_ title: String, _ amountC: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(PantominaFont.caption)
                .foregroundStyle(Color.pantomina.muted)
            Text(formatPeso(amountC))
                .font(PantominaFont.body.weight(.semibold))
                .foregroundStyle(Color.pantomina.ink)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func shortMonth(_ yearMonth: String) -> String {
        let parts = yearMonth.split(separator: "-")
        guard parts.count == 2, let month = Int(parts[1]) else { return yearMonth }
        return "\(month)"
    }
}
