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

    private var fernName: String { people.first { $0.id == .fern }?.name ?? "Fern" }
    private var starkName: String { people.first { $0.id == .stark }?.name ?? "Stark" }

    private var categoryFlow: [String: FlowType] {
        Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.flow) })
    }

    private var activeAnchor: String {
        selectedAnchor ?? Cycle.cycleFor(isoDate: Self.todayISO()).anchorISO
    }

    private var cycleAnchors: [String] {
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

    private var fernPockets: [PocketRow] { livePockets(for: .fern) }
    private var starkPockets: [PocketRow] { livePockets(for: .stark) }

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
        List {
            Section {
                Picker("Scope", selection: $scope) {
                    Text(fernName).tag(ScopeTab.fern)
                    Text(starkName).tag(ScopeTab.stark)
                    Text("Household").tag(ScopeTab.household)
                }
                .pickerStyle(.segmented)
                .onChange(of: scope) { _, new in
                    if new == .fern { balanceDayPerson = .fern }
                    if new == .stark { balanceDayPerson = .stark }
                }

                Picker("Cycle", selection: Binding(
                    get: { activeAnchor },
                    set: { selectedAnchor = $0 }
                )) {
                    ForEach(cycleAnchors.reversed(), id: \.self) { anchor in
                        Text(DisplayLabels.displayDate(iso: anchor)).tag(anchor)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Cycle")
            } footer: {
                Text("Fern and \(starkName) are personal books. Household is shared — not under either person. Pockets are as of the cycle you pick.")
                    .font(PantominaFont.caption)
            }

            if let m = displayMetrics {
                metricsSection(m)
                if scope == .fern, canLoadFernDemo {
                    Section {
                        Button("Load Fern 08/20 demo metrics") {
                            loadDemoMetrics()
                        }
                        .foregroundStyle(Color.pantomina.sageDeep)
                    } footer: {
                        Text("Loads Spec golden metrics for Aug 20. Pick that cycle to see them; other cycles stay live from the ledger.")
                            .font(PantominaFont.caption)
                    }
                }
            } else {
                emptySection
            }

            if scope != .household {
                pocketListSection
                balanceDaySection
            } else if displayMetrics == nil {
                Section {
                    Text("Add pockets on Fern or \(starkName) — Household nets both live books.")
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.muted)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.pantomina.ground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                PetTitle("Our Little Empire")
            }
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
            Section {
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
                                    .font(PantominaFont.amount)
                                    .foregroundStyle(Color.pantomina.ink)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            } header: {
                Text("Pockets")
            } footer: {
                Text("Tap a pocket for this cycle’s moves. Edit on Receipts.")
                    .font(PantominaFont.caption)
            }
        }
    }

    @ViewBuilder
    private var balanceDaySection: some View {
        Section {
            Button {
                showBalanceDay = true
            } label: {
                Label(
                    hasExternalsForBalanceDay ? "Update investments" : "Refresh cycle snapshot",
                    systemImage: "checklist"
                )
            }
            .foregroundStyle(Color.pantomina.sageDeep)
        } footer: {
            Text(
                hasExternalsForBalanceDay
                    ? "External balances for \(balanceDayPerson == .fern ? fernName : starkName) as of \(DisplayLabels.displayDate(iso: activeAnchor)). Shared confirm is on Fern."
                    : "No external pockets yet — confirm to store \(DisplayLabels.displayDate(iso: activeAnchor))’s live books."
            )
            .font(PantominaFont.caption)
        }
    }

    @ViewBuilder
    private var emptySection: some View {
        Section {
            switch scope {
            case .fern:
                Text("No pockets on \(fernName)’s book yet.")
                    .foregroundStyle(Color.pantomina.muted)
                if canLoadFernDemo {
                    Button("Load Fern 08/20 demo metrics") {
                        loadDemoMetrics()
                    }
                    .foregroundStyle(Color.pantomina.sageDeep)
                }
            case .stark:
                Text("No pockets on \(starkName)’s book yet.")
                    .foregroundStyle(Color.pantomina.muted)
            case .household:
                Text("Household needs live pockets on both \(fernName) and \(starkName).")
                    .foregroundStyle(Color.pantomina.muted)
            }
        } footer: {
            if scope == .fern, canLoadFernDemo {
                Text("Demo uses the Spec Portfolio-Fern golden (negative NW is fine).")
                    .font(PantominaFont.caption)
            }
        }
    }

    @ViewBuilder
    private func metricsSection(_ m: Snapshot.Metrics) -> some View {
        Section {
            metricRow("Total assets", m.assetsC)
            metricRow("Total liabilities", m.liabilitiesC)
            metricRow("Net worth", m.netWorthC)
        }
        Section {
            metricRow("Net worth change", m.netWorthDeltaC)
            metricRow("Assets change", m.assetsDeltaC)
            metricRow("Liabilities change", m.liabilitiesDeltaC)
            metricRow("Savings assets", m.savingsAssetsC)
        } footer: {
            if let footerAsOf {
                Text(footerAsOf)
                    .font(PantominaFont.caption)
            }
        }
    }

    private func metricRow(_ label: String, _ amountC: Int) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Color.pantomina.ink)
            Spacer()
            Text(formatPeso(amountC))
                .font(PantominaFont.amount)
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
