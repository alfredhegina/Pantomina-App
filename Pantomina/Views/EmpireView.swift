import SwiftUI
import SwiftData

struct EmpireView: View {
    /// Peer lenses — not nested under a person (Operate / Phase 6 lock).
    private enum ScopeTab: String, CaseIterable, Identifiable {
        case fern
        case stark
        case household
        var id: String { rawValue }
    }

    private struct PocketRow: Identifiable {
        var id: String { account.id }
        var account: AccountRecord
        var pocket: PocketBalance.Result
        var line: Snapshot.Line
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SnapshotRecord.confirmedAt, order: .reverse) private var snapshots: [SnapshotRecord]
    @Query private var people: [PersonRecord]
    @Query private var accounts: [AccountRecord]
    @Query private var loans: [LoanRecord]
    @Query private var funds: [FundRecord]
    @Query private var transactions: [TransactionRecord]
    @Query private var categories: [CategoryRecord]

    @State private var scope: ScopeTab = .fern
    @State private var balanceDayPerson: PersonId = .fern
    @State private var showBalanceDay = false
    @State private var miniReport: PocketRow?
    @State private var selectedAnchor: String?
    @State private var showMetricDetails = false
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())

    private var fernName: String { people.first { $0.id == .fern }?.name ?? "Fern" }
    private var starkName: String { people.first { $0.id == .stark }?.name ?? "Stark" }

    private var categoryFlow: [String: FlowType] {
        Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.flow) })
    }

    private var activeAnchor: String {
        selectedAnchor ?? Cycle.cycleFor(isoDate: Self.todayISO()).anchorISO
    }

    /// Unbounded candidate set (storage truth). Menus never show this raw.
    private var allCycleAnchors: [String] {
        var set = Set<String>()
        let today = Cycle.cycleFor(isoDate: Self.todayISO())
        set.insert(today.anchorISO)
        var cursor = today
        for _ in 0..<8 {
            cursor = Cycle.previousHalfMonth(before: cursor)
            set.insert(cursor.anchorISO)
        }
        cursor = today
        for _ in 0..<2 {
            cursor = Cycle.nextHalfMonth(after: cursor)
            set.insert(cursor.anchorISO)
        }
        for tx in transactions {
            set.insert(Cycle.cycleFor(isoDate: tx.purchaseDate).anchorISO)
            if let realized = tx.realizedDate {
                set.insert(Cycle.cycleFor(isoDate: realized).anchorISO)
            }
        }
        for snap in snapshots {
            set.insert(snap.cycleAnchorISO)
        }
        return set.sorted()
    }

    private var yearOptions: [Int] {
        var years = Set(allCycleAnchors.compactMap { Int($0.prefix(4)) })
        years.insert(selectedYear)
        years.insert(Calendar.current.component(.year, from: Date()))
        return years.sorted(by: >)
    }

    /// Cycle Menu: anchors in the selected year only (≤ ~24).
    private var cycleAnchors: [String] {
        var inYear = Cycle.anchors(inYear: selectedYear, from: allCycleAnchors)
        if inYear.isEmpty {
            inYear = Cycle.recentAnchors(from: allCycleAnchors, aroundISO: activeAnchor, limit: 24)
        }
        if !inYear.contains(activeAnchor),
           activeAnchor.hasPrefix(String(format: "%04d-", selectedYear)) {
            inYear.append(activeAnchor)
            inYear.sort()
        }
        return inYear
    }

    private var fernPockets: [PocketRow] { livePockets(for: .fern) }
    private var starkPockets: [PocketRow] { livePockets(for: .stark) }

    private var chartSnapInputs: [EmpireCharts.SnapInput] {
        snapshots.map { snap in
            EmpireCharts.SnapInput(
                cycleAnchorISO: snap.cycleAnchorISO,
                personId: snap.personId,
                confirmedAt: snap.confirmedAt,
                lines: snap.lines,
                metrics: snap.metrics
            )
        }
    }

    private var chartSeries: [EmpireCharts.Point] {
        let inputs = chartSnapInputs
        let full: [EmpireCharts.Point]
        switch scope {
        case .fern:
            let base = EmpireCharts.personalSeries(snapshots: inputs, personId: PersonId.fern.rawValue)
            let live = displayMetrics.map {
                EmpireCharts.Point(cycleAnchorISO: activeAnchor, metrics: $0)
            }
            full = EmpireCharts.withLiveTip(series: base, live: live, activeAnchor: activeAnchor)
        case .stark:
            let base = EmpireCharts.personalSeries(snapshots: inputs, personId: PersonId.stark.rawValue)
            let live = displayMetrics.map {
                EmpireCharts.Point(cycleAnchorISO: activeAnchor, metrics: $0)
            }
            full = EmpireCharts.withLiveTip(series: base, live: live, activeAnchor: activeAnchor)
        case .household:
            let fern = inputs.filter { $0.personId == PersonId.fern.rawValue }
            let stark = inputs.filter { $0.personId == PersonId.stark.rawValue }
            let base = EmpireCharts.householdSeries(fern: fern, stark: stark)
            let live = displayMetrics.map {
                EmpireCharts.Point(cycleAnchorISO: activeAnchor, metrics: $0)
            }
            full = EmpireCharts.withLiveTip(series: base, live: live, activeAnchor: activeAnchor)
        }
        return EmpireCharts.points(inYear: selectedYear, series: full)
    }

    private var displayMetrics: Snapshot.Metrics? {
        switch scope {
        case .fern:
            let lines = fernMetricLines
            let demoSnap = metricsOnlySnapshot(personId: PersonId.fern.rawValue)
            guard !lines.isEmpty || demoSnap != nil else { return nil }
            // Spec smoke: metrics-only Portfolio-Fern demo wins on its cycle even when pockets exist.
            if let snap = demoSnap, snap.cycleAnchorISO == activeAnchor {
                return snap.metrics
            }
            return Snapshot.metrics(
                lines: lines,
                prior: priorMetrics(personId: PersonId.fern.rawValue),
                lens: .personal
            )
        case .stark:
            let lines = starkPockets.map(\.line)
            guard !lines.isEmpty else { return nil }
            return Snapshot.metrics(
                lines: lines,
                prior: priorMetrics(personId: PersonId.stark.rawValue),
                lens: .personal
            )
        case .household:
            let lines = fernMetricLines + starkPockets.map(\.line)
            guard !lines.isEmpty else { return nil }
            return Snapshot.metrics(lines: lines, prior: nil, lens: .household)
        }
    }

    /// Fern pockets plus Love Tab receivable (Settlement) for NW / household netting.
    private var fernMetricLines: [Snapshot.Line] {
        var lines = fernPockets.map(\.line)
        if let love = loveTabLine(asOf: activeAnchor) {
            lines.append(love)
        }
        return lines
    }

    private var canLoadFernDemo: Bool {
        !snapshots.contains { $0.personId == PersonId.fern.rawValue }
    }

    private var hasExternalsForBalanceDay: Bool {
        let person = balanceDayPerson
        return accounts.contains { account in
            guard !account.archived, PocketBalance.isExternalKind(account.kind) else { return false }
            switch account.scope {
            case .fern: return person == .fern
            case .stark: return person == .stark
            case .household, .business: return person == .fern
            }
        }
    }

    private var footerAsOf: String? {
        let date = DisplayLabels.displayDate(iso: activeAnchor)
        switch scope {
        case .fern:
            if let demo = metricsOnlySnapshot(personId: PersonId.fern.rawValue),
               demo.cycleAnchorISO == activeAnchor {
                return "As of \(date) · Spec demo (Portfolio-Fern)"
            }
            if snapshotForCycle(personId: PersonId.fern.rawValue, cycleISO: activeAnchor) != nil {
                return "As of \(date) · check-in"
            }
            return fernPockets.isEmpty ? nil : "As of \(date) · from the ledger"
        case .stark:
            if snapshotForCycle(personId: PersonId.stark.rawValue, cycleISO: activeAnchor) != nil {
                return "As of \(date) · check-in"
            }
            return starkPockets.isEmpty ? nil : "As of \(date) · from the ledger"
        case .household:
            guard displayMetrics != nil else { return nil }
            return "As of \(date) · Household nets Love Tab & fund IOUs"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                QuietScopeTabs(
                    tabs: [
                        (fernName, ScopeTab.fern),
                        (starkName, ScopeTab.stark),
                        ("Household", ScopeTab.household),
                    ],
                    selection: $scope
                )
                .onChange(of: scope) { _, new in
                    if new == .fern { balanceDayPerson = .fern }
                    if new == .stark { balanceDayPerson = .stark }
                }

                if let m = displayMetrics {
                    heroSection(m)
                    EmpireChartsSection(series: chartSeries, style: .assetsLiabilities)
                    if scope == .fern, canLoadFernDemo {
                        Button("Load Fern 08/20 demo metrics") {
                            loadDemoMetrics()
                        }
                        .font(PantominaFont.body.weight(.semibold))
                        .foregroundStyle(Color.pantomina.quietAccent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                    }
                } else {
                    emptySection
                }

                if scope != .household {
                    pocketListSection
                    balanceDaySection
                } else if displayMetrics == nil {
                    Text("Add pockets on Fern or \(starkName) — Household nets both live books.")
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.muted)
                        .padding(20)
                }
            }
        }
        .background(Color.pantomina.ground)
        .toolbarBackground(Color.pantomina.ground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                PetTitle("Our Little Empire")
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Menu {
                        ForEach(yearOptions, id: \.self) { y in
                            Button(String(y)) {
                                selectedYear = y
                                let inYear = Cycle.anchors(inYear: y, from: allCycleAnchors)
                                if !activeAnchor.hasPrefix(String(format: "%04d-", y)) {
                                    selectedAnchor = inYear.last
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(String(selectedYear))
                                .font(PantominaFont.body.weight(.medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(Color.pantomina.quietAccent)
                    }
                    .accessibilityLabel("Year")

                    Menu {
                        ForEach(cycleAnchors.reversed(), id: \.self) { anchor in
                            Button(DisplayLabels.displayDate(iso: anchor)) {
                                selectedAnchor = anchor
                                if let y = Int(anchor.prefix(4)) { selectedYear = y }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(DisplayLabels.displayDateShort(iso: activeAnchor))
                                .font(PantominaFont.body.weight(.medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(Color.pantomina.quietAccent)
                    }
                    .accessibilityLabel("Cycle")
                }
            }
        }
        .onAppear {
            if let y = Int(activeAnchor.prefix(4)) { selectedYear = y }
            try? SeedCatalog.seedDemoExternalsIfNeeded(into: modelContext)
            try? modelContext.save()
        }
        .sheet(isPresented: $showBalanceDay) {
            BalanceDayView(personId: balanceDayPerson, cycleISO: activeAnchor) {
                showBalanceDay = false
            }
        }
        .sheet(item: $miniReport) { row in
            PocketMiniReportView(
                account: row.account,
                balanceC: row.pocket.balanceC,
                spokenForC: row.pocket.spokenForC,
                sourceLabel: sourceCaption(row.pocket.source),
                cycleAnchorISO: activeAnchor,
                onDone: { miniReport = nil }
            )
        }
    }

    @ViewBuilder
    private var pocketListSection: some View {
        let rows = scope == .fern ? fernPockets : starkPockets
        let visible = rows.filter { $0.line.source != .stale || $0.pocket.source == .unknown }
        if !visible.isEmpty {
            VStack(spacing: 0) {
                HStack {
                    Text("Pockets")
                        .font(PantominaFont.body.weight(.semibold))
                        .foregroundStyle(Color.pantomina.ink)
                    Spacer()
                    Text("\(visible.count)")
                        .font(PantominaFont.body)
                        .foregroundStyle(Color.pantomina.muted)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.pantomina.rule).frame(height: 1)
                }

                ForEach(visible) { row in
                    Button {
                        miniReport = row
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.account.displayLabel(fernName: fernName, starkName: starkName))
                                    .foregroundStyle(Color.pantomina.ink)
                                Text(sourceCaption(row.pocket.source))
                                    .font(PantominaFont.caption)
                                    .foregroundStyle(Color.pantomina.muted)
                            }
                            Spacer()
                            if row.pocket.source == .unknown {
                                Text("—")
                                    .foregroundStyle(Color.pantomina.muted)
                            } else {
                                Text(formatPeso(row.pocket.balanceC))
                                    .font(PantominaFont.body.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(Color.pantomina.ink)
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.pantomina.muted)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color(hex: "#EDEAE3")).frame(height: 1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var balanceDaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                showBalanceDay = true
            } label: {
                Text(hasExternalsForBalanceDay ? "Update investments" : "Refresh cycle snapshot")
                    .font(PantominaFont.body.weight(.semibold))
                    .foregroundStyle(Color.pantomina.quietAccent)
            }
            Text(
                hasExternalsForBalanceDay
                    ? "External balances for \(balanceDayPerson == .fern ? fernName : starkName) as of \(DisplayLabels.displayDate(iso: activeAnchor)). Shared confirm is on Fern."
                    : "No external pockets yet — confirm to store \(DisplayLabels.displayDate(iso: activeAnchor))’s live books."
            )
            .font(PantominaFont.caption)
            .foregroundStyle(Color.pantomina.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }

    @ViewBuilder
    private var emptySection: some View {
        let name: String = {
            switch scope {
            case .fern: return fernName
            case .stark: return starkName
            case .household: return "Household"
            }
        }()
        QuietEmptyBlock(
            systemImage: "building.columns",
            title: scope == .household
                ? "Household needs live pockets on both \(fernName) and \(starkName)."
                : "Nothing on \(name)’s book yet.",
            message: scope == .household
                ? "Rare quiet moment. Confirm a cycle snapshot on each book."
                : "Rare quiet moment. Confirm a cycle snapshot and net worth starts tracking from there.",
            actionTitle: scope == .household ? nil : (hasExternalsForBalanceDay ? "Update investments" : "Refresh cycle snapshot"),
            filled: true,
            action: scope == .household ? nil : { showBalanceDay = true }
        )
        .padding(.top, 48)
        .padding(.bottom, 24)
        if scope == .fern, canLoadFernDemo {
            Button("Load Fern 08/20 demo metrics") {
                loadDemoMetrics()
            }
            .font(PantominaFont.body.weight(.semibold))
            .foregroundStyle(Color.pantomina.quietAccent)
            .padding(.bottom, 24)
        }
    }

    /// Above-fold: NW amount + full-width hero chart, compact assets/liabilities, optional deltas.
    @ViewBuilder
    private func heroSection(_ m: Snapshot.Metrics) -> some View {
        let gained = m.netWorthDeltaC > 0
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Net worth")
                        .font(PantominaFont.caption.weight(.medium))
                        .foregroundStyle(Color.pantomina.muted)
                    if gained {
                        EmpireGainHeart()
                    }
                }
                Text(formatPeso(m.netWorthC))
                    .font(PantominaFont.heroAmount(centavos: m.netWorthC))
                    .foregroundStyle(Color.pantomina.ink)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                if let footerAsOf {
                    Text(footerAsOf)
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.muted)
                } else if gained {
                    Text("Up \(formatPeso(m.netWorthDeltaC)) this check-in")
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.quietAccent)
                } else if m.netWorthDeltaC < 0 {
                    Text("Change \(formatPeso(m.netWorthDeltaC))")
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.muted)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 16)

            EmpireChartsSection(
                series: chartSeries,
                style: .hero,
                celebrateGain: gained
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.pantomina.rule).frame(height: 1)
            }

            HStack(spacing: 0) {
                compactStat(title: "Assets", amountC: m.assetsC)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                compactStat(title: "Liabilities", amountC: m.liabilitiesC)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Color(hex: "#EDEAE3")).frame(width: 1)
                    }
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.pantomina.rule).frame(height: 1)
            }

            DisclosureGroup(isExpanded: $showMetricDetails) {
                metricRow("Net worth change", m.netWorthDeltaC)
                metricRow("Assets change", m.assetsDeltaC)
                metricRow("Liabilities change", m.liabilitiesDeltaC)
                metricRow("Savings assets", m.savingsAssetsC)
            } label: {
                Text("Changes & savings")
                    .font(PantominaFont.body)
                    .foregroundStyle(Color.pantomina.ink)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.pantomina.rule).frame(height: 1)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func compactStat(title: String, amountC: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(PantominaFont.caption)
                .foregroundStyle(Color.pantomina.muted)
            Text(formatPeso(amountC))
                .font(PantominaFont.body.weight(.semibold))
                .foregroundStyle(Color.pantomina.ink)
                .monospacedDigit()
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricRow(_ label: String, _ amountC: Int) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Color.pantomina.ink)
            Spacer()
            Text(formatPeso(amountC))
                .font(PantominaFont.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(Color.pantomina.ink)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private func sourceCaption(_ source: PocketBalance.Source) -> String {
        switch source {
        case .ledger: return "From the ledger"
        case .confirmed: return "Last check-in"
        case .unknown: return "Needs a check-in"
        }
    }

    private func livePockets(for person: PersonId) -> [PocketRow] {
        accounts
            .filter { !$0.archived }
            .filter { account in
                switch account.scope {
                case .fern: return person == .fern
                case .stark: return person == .stark
                case .household, .business: return person == .fern
                }
            }
            .sorted { $0.baseName.localizedCaseInsensitiveCompare($1.baseName) == .orderedAscending }
            .map { account in
                let pocket = pocketResult(for: account, person: person)
                let line = Snapshot.line(
                    accountId: account.id,
                    kind: account.kind,
                    pocket: pocket,
                    isInternalDebt: account.kind == .receivable
                )
                return PocketRow(account: account, pocket: pocket, line: line)
            }
    }

    private func pocketResult(for account: AccountRecord, person: PersonId) -> PocketBalance.Result {
        let legs = transactions
            .filter { $0.accountId == account.id }
            .compactMap { tx -> PocketBalance.Leg? in
                guard let flow = categoryFlow[tx.categoryId] else { return nil }
                return PocketBalance.Leg(
                    amountC: tx.amountC,
                    flow: flow,
                    realizedStatus: tx.realizedStatus,
                    purchaseDate: tx.purchaseDate,
                    realizedDate: tx.realizedDate,
                    note: tx.note ?? tx.merchant,
                    settlementRole: tx.settlementRole
                )
            }
        let spoken = funds.filter { $0.homeAccountId == account.id }.map(\.balanceC).reduce(0, +)
        let loanBal: Int?
        if account.kind == .loan {
            let active = loans.filter {
                $0.ownerRaw == person.rawValue && $0.statusRaw != Loan.Status.done.rawValue
            }
            if let loan = active.first(where: { $0.paymentAccountId == account.id }) ?? active.first {
                loanBal = Loan.derivedBalanceC(
                    totalLoanC: loan.totalLoanC,
                    paidMonths: loan.paidMonths,
                    monthlyC: loan.monthlyC
                )
            } else {
                loanBal = 0
            }
        } else {
            loanBal = nil
        }
        return PocketBalance.compute(
            kind: account.kind,
            legs: legs,
            loanBalanceC: loanBal,
            lastConfirmedC: account.lastConfirmedBalanceC,
            spokenForC: spoken,
            receivableBalanceC: account.kind == .receivable ? account.lastConfirmedBalanceC : nil,
            asOfISO: activeAnchor,
            lastConfirmedCycleISO: account.lastConfirmedCycleISO
        )
    }

    private func snapshotForCycle(personId: String, cycleISO: String) -> SnapshotRecord? {
        snapshots.first {
            $0.personId == personId && $0.cycleAnchorISO == cycleISO && !$0.lines.isEmpty
        }
    }

    private func priorMetrics(personId: String) -> Snapshot.Metrics? {
        let prev = Cycle.previousHalfMonth(before: Cycle(anchorISO: activeAnchor)).anchorISO
        if let snap = snapshotForCycle(personId: personId, cycleISO: prev) {
            return snap.metrics
        }
        return snapshots
            .filter {
                $0.personId == personId
                    && !$0.lines.isEmpty
                    && $0.cycleAnchorISO < activeAnchor
            }
            .sorted { $0.cycleAnchorISO > $1.cycleAnchorISO }
            .first?
            .metrics
    }

    /// Love Tab running balance as of cycle — asset + internal debt for household netting.
    private func loveTabLine(asOf cycleISO: String) -> Snapshot.Line? {
        let rows: [Settlement.LedgerRow] = transactions.map { tx in
            let account = accounts.first { $0.id == tx.accountId }
            return Settlement.LedgerRow(
                realizedDate: tx.realizedDate,
                realizedStatus: tx.realizedStatus,
                accountScope: account?.scope ?? .household,
                allocationStarkC: tx.allocStarkC,
                allocationFernC: tx.allocFernC,
                amountC: tx.amountC,
                settlementRole: tx.settlementRole,
                isStatement: account?.settlement == .statement,
                proposedRealizedDate: tx.proposedRealizedDate
            )
        }
        let anchors = Settlement.cycleAnchors(in: rows).filter { $0 <= cycleISO }
        guard let snap = Settlement.history(rows: rows, anchors: anchors).last,
              snap.result.tabAfterC > 0
        else { return nil }
        return Snapshot.Line(
            accountId: "love-tab",
            balanceC: snap.result.tabAfterC,
            source: .derived,
            isLiability: false,
            countsTowardSavingsAssets: false,
            isInternalDebt: true
        )
    }

    /// Metrics-only demo (no pocket lines) for Spec smoke.
    private func metricsOnlySnapshot(personId: String) -> SnapshotRecord? {
        snapshots.first { $0.personId == personId && $0.lines.isEmpty }
    }

    private func loadDemoMetrics() {
        guard canLoadFernDemo else { return }
        let record = SnapshotRecord(
            cycleAnchorISO: PortfolioFern0820.cycleAnchorISO,
            personId: PortfolioFern0820.personId,
            lines: [],
            metrics: PortfolioFern0820.metrics
        )
        modelContext.insert(record)
        try? modelContext.save()
        scope = .fern
        balanceDayPerson = .fern
        selectedAnchor = PortfolioFern0820.cycleAnchorISO
        if let y = Int(PortfolioFern0820.cycleAnchorISO.prefix(4)) {
            selectedYear = y
        }
    }

    private static func todayISO() -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
