import Charts
import SwiftUI
import SwiftData

struct YearSoFarView: View {
    /// Peer scope matches Empire — Household is not nested under a person.
    private enum ScopeTab: String, CaseIterable, Identifiable {
        case fern, stark, household
        var id: String { rawValue }
    }

    @Query private var people: [PersonRecord]
    @Query private var categories: [CategoryRecord]
    @Query private var transactions: [TransactionRecord]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scopeTab: ScopeTab = .fern
    @State private var lens: YearSoFar.Lens = .split
    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var chartsRevealed = false
    @State private var seedToast: String?
    @State private var showYearWheel = false
    @State private var wheelDraftYear = Calendar.current.component(.year, from: Date())

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
        for y in YearSoFar.demoYears() { years.insert(y) }
        return years.sorted()
    }

    private var usualExpenseC: Int? {
        YearSoFar.usualExpenseC(months: report.months)
    }

    private var vsUsual: YearSoFar.ExpenseSpikeInsight? {
        YearSoFar.monthVsUsualInsight(months: report.months)
    }

    private var reportIdentity: String {
        "\(year)-\(scopeTab.rawValue)-\(lens.rawValue)-\(report.expenseTotalC)-\(report.incomeTotalC)-\(report.savingsC)"
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

    private var topSlice: (label: String, amountC: Int, percent: Int)? {
        guard let first = donutSlices.first, report.expenseTotalC > 0 else { return nil }
        let pct = Int((Double(first.amountC) / Double(report.expenseTotalC) * 100.0).rounded())
        let short = first.label.split(separator: "·").last.map { $0.trimmingCharacters(in: .whitespaces) }
            ?? first.label
        return (short.lowercased(), first.amountC, pct)
    }

    private var isEmpty: Bool {
        report.months.isEmpty && report.incomeTotalC == 0 && report.expenseTotalC == 0
    }

    private var hasYTDDemoForYear: Bool {
        let prefix = "\(YearSoFar.demoIdPrefix)\(year)-"
        return transactions.contains { $0.id.hasPrefix(prefix) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                scopeTabs
                heroBlock
                if isEmpty {
                    emptyBlock
                    if AppEnvironment.current.isPreprod {
                        demoSeedBlock
                    }
                } else {
                    byMonthBlock
                    if !donutSlices.isEmpty {
                        whereItWentBlock
                    }
                    needsWantsBlock
                    if AppEnvironment.current.isPreprod, !hasYTDDemoForYear {
                        demoSeedBlock
                    }
                }
            }
        }
        .background(Color.pantomina.ground)
        .toolbarBackground(Color.pantomina.ground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                PetTitle("Our Year So Far")
            }
            ToolbarItem(placement: .topBarTrailing) {
                QuietWheelTrigger(
                    label: String(year),
                    accessibilityName: "Year"
                ) {
                    wheelDraftYear = year
                    showYearWheel = true
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let seedToast {
                Text(seedToast)
                    .font(PantominaFont.caption)
                    .foregroundStyle(Color.pantomina.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.pantomina.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.bottom, 24)
            }
        }
        .onAppear {
            for y in YearSoFar.demoYears() {
                try? SeedCatalog.seedDemoYearSoFarIfNeeded(into: modelContext, year: y)
            }
            try? modelContext.save()
            revealCharts()
        }
        .onChange(of: year) { _, newYear in
            chartsRevealed = false
            try? SeedCatalog.seedDemoYearSoFarIfNeeded(into: modelContext, year: newYear)
            revealCharts()
        }
        .sheet(isPresented: $showYearWheel) {
            QuietWheelSheet(
                title: "Year",
                options: yearOptions,
                optionTitle: { String($0) },
                draft: $wheelDraftYear,
                onCancel: { showYearWheel = false },
                onDone: {
                    year = wheelDraftYear
                    showYearWheel = false
                }
            )
        }
    }

    private var demoSeedBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Load 12-month YTD demo") {
                loadYTDDemo()
            }
            .font(PantominaFont.body.weight(.semibold))
            .foregroundStyle(Color.pantomina.quietAccent)
            Text("Preprod smoke data for Quiet ledger charts. Skips if this year already has the demo.")
                .font(PantominaFont.caption)
                .foregroundStyle(Color.pantomina.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }

    private func loadYTDDemo() {
        do {
            let ok = try SeedCatalog.seedDemoYearSoFarIfNeeded(into: modelContext, year: year)
            try modelContext.save()
            seedToast = ok
                ? "12-month demo ready for \(year)."
                : "Couldn’t seed — check categories/accounts."
        } catch {
            seedToast = "Couldn’t save demo."
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            PantominaMotion.run(reduceMotion) { seedToast = nil }
        }
        chartsRevealed = false
        revealCharts()
    }

    // MARK: - Chrome

    private var scopeTabs: some View {
        QuietScopeTabs(
            tabs: [
                (fernName, ScopeTab.fern),
                (starkName, ScopeTab.stark),
                ("Household", ScopeTab.household),
            ],
            selection: $scopeTab
        )
    }

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("Spent this year")
                    .font(PantominaFont.caption.weight(.medium))
                    .foregroundStyle(Color.pantomina.muted)
                Spacer()
                if scopeTab != .household {
                    lensToggle
                }
            }

            Text(formatPeso(report.expenseTotalC))
                .font(heroAmountFont(centavos: report.expenseTotalC))
                .foregroundStyle(Color.pantomina.ink)
                .monospacedDigit()
                .minimumScaleFactor(isMillionPesos(report.expenseTotalC) ? 0.7 : 1)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Earned")
                    .font(PantominaFont.caption)
                    .foregroundStyle(Color.pantomina.muted)
                Text(formatPeso(report.incomeTotalC))
                    .font(earnedAmountFont(centavos: report.incomeTotalC))
                    .foregroundStyle(Color.pantomina.quietAccent)
                    .monospacedDigit()
                    .minimumScaleFactor(isMillionPesos(report.incomeTotalC) ? 0.75 : 1)
                    .lineLimit(1)
            }

            Text(heroFooter)
                .font(PantominaFont.caption)
                .foregroundStyle(Color.pantomina.muted)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.pantomina.rule)
                .frame(height: 1)
        }
    }

    private var lensToggle: some View {
        HStack(spacing: 0) {
            lensChip("Split", .split)
            lensChip("Just mine", .justMine)
        }
        .padding(2)
        .background(Color(hex: "#EFEDE7"))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func lensChip(_ title: String, _ value: YearSoFar.Lens) -> some View {
        let on = lens == value
        return Button {
            lens = value
        } label: {
            Text(title)
                .font(PantominaFont.caption.weight(on ? .semibold : .regular))
                .foregroundStyle(on ? Color.pantomina.ink : Color.pantomina.muted)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    if on {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.pantomina.card)
                            .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var heroFooter: String {
        if scopeTab == .household {
            return "\(fernName) and \(starkName) are personal books. Household is shared — not under either person."
        }
        return "Split is each person’s share. Just mine is what \(activePersonName) paid. Counted by when it became real."
    }

    private var emptyBlock: some View {
        Text("Nothing counted in \(year) yet. Rare quiet year.")
            .font(PantominaFont.body)
            .foregroundStyle(Color.pantomina.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
    }

    // MARK: - By month

    private var byMonthBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("By month")
                    .font(PantominaFont.body.weight(.semibold))
                    .foregroundStyle(Color.pantomina.ink)
                Spacer()
                Text("vs prior 3 months")
                    .font(PantominaFont.caption)
                    .foregroundStyle(Color.pantomina.muted)
            }

            Chart {
                ForEach(report.months, id: \.yearMonth) { m in
                    BarMark(
                        x: .value("Month", monthAbbrev(m.yearMonth)),
                        y: .value("Income", Double(m.incomeC) / 100.0)
                    )
                    .foregroundStyle(Color.pantomina.quietAccent)
                    .position(by: .value("Kind", "Income"))

                    BarMark(
                        x: .value("Month", monthAbbrev(m.yearMonth)),
                        y: .value("Expense", Double(m.expenseC) / 100.0)
                    )
                    .foregroundStyle(Color.pantomina.expenseBar)
                    .position(by: .value("Kind", "Expense"))
                }

                if let usual = usualExpenseC {
                    RuleMark(y: .value("Usual", Double(usual) / 100.0))
                        .lineStyle(StrokeStyle(lineWidth: 1.4, dash: [5, 5]))
                        .foregroundStyle(Color.pantomina.ink.opacity(0.55))
                        .annotation(position: .top, alignment: .leading) {
                            Text("\(formatPesoCompact(usual)) usual")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(Color.pantomina.ink)
                                .padding(.horizontal, 2)
                        }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                        .foregroundStyle(Color.pantomina.hairline)
                    AxisValueLabel {
                        if let pesos = value.as(Double.self) {
                            Text(compactAxisLabel(pesos))
                                .font(.system(size: 10))
                                .foregroundStyle(Color.pantomina.muted)
                        }
                    }
                }
            }
            .frame(height: 168)
            .id("bars-\(reportIdentity)")
            .opacity(chartsRevealed ? 1 : 0)
            .accessibilityLabel("Income and expense by month")

            if let vsUsual {
                Text(vsUsualCopy(vsUsual))
                    .font(PantominaFont.body)
                    .foregroundStyle(Color.pantomina.ink)
                    .fixedSize(horizontal: false, vertical: true)
            } else if usualExpenseC == nil, report.months.contains(where: { $0.expenseC > 0 }) {
                Text("Need a couple of spend months before a usual line shows.")
                    .font(PantominaFont.caption)
                    .foregroundStyle(Color.pantomina.muted)
            }
        }
        .padding(20)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.pantomina.rule)
                .frame(height: 1)
        }
    }

    private func vsUsualCopy(_ insight: YearSoFar.ExpenseSpikeInsight) -> String {
        let name = monthFull(insight.yearMonth)
        let spent = formatPeso(insight.expenseC)
        if insight.multiple >= 2.8 {
            return "\(name) spent \(spent) — nearly three times a usual month."
        }
        if insight.multiple >= 1.9 {
            return "\(name) spent \(spent) — about twice a usual month."
        }
        if insight.multiple >= 1.5 {
            return "\(name) spent \(spent) — well above a usual month."
        }
        if insight.multiple >= 0.85 {
            return "\(name) spent \(spent) — about a usual month."
        }
        if insight.multiple >= 0.5 {
            return "\(name) spent \(spent) — under a usual month."
        }
        return "\(name) spent \(spent) — a quiet month versus usual."
    }

    // MARK: - Where it went

    private var whereItWentBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Where it went")
                    .font(PantominaFont.body.weight(.semibold))
                    .foregroundStyle(Color.pantomina.ink)
                Spacer()
                Text("\(donutSlices.count) categories")
                    .font(PantominaFont.caption)
                    .foregroundStyle(Color.pantomina.muted)
            }

            HStack(alignment: .center, spacing: 18) {
                ZStack {
                    Chart(donutSlices, id: \.id) { slice in
                        SectorMark(
                            angle: .value("Amount", Double(slice.amountC) / 100.0),
                            innerRadius: .ratio(0.78),
                            angularInset: 1.5
                        )
                        .foregroundStyle(Color.pantomina.categorySlice(rank: slice.rank))
                    }
                    .frame(width: 116, height: 116)
                    .id("donut-\(reportIdentity)")

                    if let top = topSlice {
                        VStack(spacing: 2) {
                            Text("\(top.percent)%")
                                .font(PantominaFont.body.weight(.semibold))
                                .foregroundStyle(Color.pantomina.ink)
                                .monospacedDigit()
                            Text(top.label)
                                .font(PantominaFont.caption)
                                .foregroundStyle(Color.pantomina.muted)
                                .lineLimit(1)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(top.percent) percent \(top.label)")
                    }
                }
                .opacity(chartsRevealed ? 1 : 0)

                VStack(spacing: 0) {
                    ForEach(Array(donutSlices.enumerated()), id: \.element.id) { index, slice in
                        HStack(spacing: 9) {
                            Circle()
                                .fill(Color.pantomina.categorySlice(rank: slice.rank))
                                .frame(width: 8, height: 8)
                            Text(shortCategory(slice.label))
                                .font(PantominaFont.body)
                                .foregroundStyle(Color.pantomina.ink)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .layoutPriority(0)
                            Spacer(minLength: 8)
                            Text(formatPesoCompact(slice.amountC))
                                .font(listAmountFont(centavos: slice.amountC))
                                .monospacedDigit()
                                .foregroundStyle(Color.pantomina.ink)
                                .minimumScaleFactor(isMillionPesos(slice.amountC) ? 0.75 : 1)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .layoutPriority(1)
                        }
                        .padding(.vertical, 9)
                        if index < donutSlices.count - 1 {
                            Rectangle()
                                .fill(Color.pantomina.hairline)
                                .frame(height: 1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.pantomina.rule)
                .frame(height: 1)
        }
    }

    // MARK: - Needs & wants

    private var needsWantsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Needs, wants & savings")
                .font(PantominaFont.body.weight(.semibold))
                .foregroundStyle(Color.pantomina.ink)

            HStack(alignment: .top, spacing: 8) {
                compact("Needs", report.needsC)
                compact("Wants", report.wantsC)
                compact("Savings", report.savingsC)
            }
            .id("nws-\(reportIdentity)")

            Text("Needs and wants from category tags. Savings is parked / sinking flow. Untagged spend stays out of Needs and Wants.")
                .font(PantominaFont.caption)
                .foregroundStyle(Color.pantomina.muted)
        }
        .padding(20)
    }

    private func compact(_ title: String, _ amountC: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(PantominaFont.caption)
                .foregroundStyle(Color.pantomina.muted)
            Text(formatPeso(amountC))
                .font(listAmountFont(centavos: amountC))
                .foregroundStyle(Color.pantomina.ink)
                .monospacedDigit()
                .minimumScaleFactor(isMillionPesos(amountC) ? 0.75 : 1)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    /// Whole pesos ≥ 1,000,000 — only then shrink type.
    private func isMillionPesos(_ centavos: Int) -> Bool {
        abs(centavos) / 100 >= 1_000_000
    }

    private func heroAmountFont(centavos: Int) -> Font {
        // Full 40pt through hundreds of thousands; step down only at millions+.
        let pesos = abs(centavos) / 100
        let size: CGFloat
        if pesos >= 100_000_000 { size = 26 }
        else if pesos >= 10_000_000 { size = 30 }
        else if pesos >= 1_000_000 { size = 34 }
        else { size = 40 }
        return .system(size: size, weight: .semibold)
    }

    private func earnedAmountFont(centavos: Int) -> Font {
        let size: CGFloat = isMillionPesos(centavos) ? 15 : 16
        return .system(size: size, weight: .semibold)
    }

    private func listAmountFont(centavos: Int) -> Font {
        let size: CGFloat = isMillionPesos(centavos) ? 14 : 16
        return .system(size: size, weight: .medium)
    }

    private func compactAxisLabel(_ pesos: Double) -> String {
        let abs = Swift.abs(pesos)
        if abs >= 1_000_000 {
            return String(format: "%.1fM", pesos / 1_000_000)
        }
        if abs >= 10_000 {
            return String(format: "%.0fK", pesos / 1_000)
        }
        return String(format: "%.0f", pesos)
    }

    private func revealCharts() {
        guard !reduceMotion else {
            chartsRevealed = true
            return
        }
        withAnimation(PantominaMotion.feedback) { chartsRevealed = true }
    }

    private func monthAbbrev(_ yearMonth: String) -> String {
        let parts = yearMonth.split(separator: "-")
        guard parts.count == 2, let month = Int(parts[1]), (1...12).contains(month) else {
            return yearMonth
        }
        let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return names[month - 1]
    }

    private func monthFull(_ yearMonth: String) -> String {
        let parts = yearMonth.split(separator: "-")
        guard parts.count == 2, let month = Int(parts[1]), (1...12).contains(month) else {
            return yearMonth
        }
        let names = [
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December",
        ]
        return names[month - 1]
    }

    private func shortCategory(_ label: String) -> String {
        if let item = label.split(separator: "·").last {
            return item.trimmingCharacters(in: .whitespaces)
        }
        return label
    }

    /// Whole pesos when cents are zero — quieter list density (1c).
    private func formatPesoCompact(_ amountC: Int) -> String {
        if amountC % 100 == 0 {
            return formatPeso(amountC, fractionDigits: 0)
        }
        return formatPeso(amountC)
    }
}
