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

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SnapshotRecord.confirmedAt, order: .reverse) private var snapshots: [SnapshotRecord]
    @Query private var people: [PersonRecord]

    @State private var scope: ScopeTab = .fern
    /// Last personal tab — Balance Day is always one person’s check-in.
    @State private var balanceDayPerson: PersonId = .fern
    @State private var showBalanceDay = false

    private var fernName: String { people.first { $0.id == .fern }?.name ?? "Fern" }
    private var starkName: String { people.first { $0.id == .stark }?.name ?? "Stark" }

    private var latestFern: SnapshotRecord? {
        preferredPersonalSnapshot(personId: PersonId.fern.rawValue)
    }

    private var latestStark: SnapshotRecord? {
        preferredPersonalSnapshot(personId: PersonId.stark.rawValue)
    }

    private var displayMetrics: Snapshot.Metrics? {
        switch scope {
        case .fern:
            return latestFern?.metrics
        case .stark:
            return latestStark?.metrics
        case .household:
            guard let lines = householdLines else { return nil }
            return Snapshot.metrics(lines: lines, prior: nil, lens: .household)
        }
    }

    /// Both people need a check-in with real lines before Household can net.
    private var householdLines: [Snapshot.Line]? {
        guard let fern = latestFern, !fern.lines.isEmpty,
              let stark = latestStark, !stark.lines.isEmpty
        else { return nil }
        return fern.lines + stark.lines
    }

    private var canLoadFernDemo: Bool {
        !snapshots.contains { $0.personId == PersonId.fern.rawValue }
    }

    private var footerAsOf: String? {
        switch scope {
        case .fern:
            guard let snap = latestFern else { return nil }
            return "As of \(snap.cycleAnchorISO) · \(fernName)"
        case .stark:
            guard let snap = latestStark else { return nil }
            return "As of \(snap.cycleAnchorISO) · \(starkName)"
        case .household:
            guard householdLines != nil else { return nil }
            return "Household nets Love Tab & fund IOUs"
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
            } footer: {
                Text("Fern and \(starkName) are personal books. Household is shared — not under either person.")
                    .font(PantominaFont.caption)
            }

            if let m = displayMetrics {
                metricsSection(m)
            } else {
                emptySection
            }

            if scope != .household {
                Section {
                    Button {
                        showBalanceDay = true
                    } label: {
                        Label("Check the balances", systemImage: "checklist")
                    }
                    .foregroundStyle(Color.pantomina.sageDeep)
                } footer: {
                    Text("Balance Day for \(balanceDayPerson == .fern ? fernName : starkName). Charts come later.")
                        .font(PantominaFont.caption)
                }
            } else {
                Section {
                    Text("Check the balances from Fern or \(starkName)’s tab — Household only views the netted books.")
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
            BalanceDayView(personId: balanceDayPerson) {
                showBalanceDay = false
            }
        }
    }

    @ViewBuilder
    private var emptySection: some View {
        Section {
            switch scope {
            case .fern:
                Text("No check-in yet for \(fernName).")
                    .foregroundStyle(Color.pantomina.muted)
                if canLoadFernDemo {
                    Button("Load Fern 08/20 demo metrics") {
                        loadDemoMetrics()
                    }
                    .foregroundStyle(Color.pantomina.sageDeep)
                }
            case .stark:
                Text("No check-in yet for \(starkName).")
                    .foregroundStyle(Color.pantomina.muted)
            case .household:
                Text("Household needs both \(fernName) and \(starkName) check-ins with pocket lines — then Love Tab and fund IOUs net out.")
                    .foregroundStyle(Color.pantomina.muted)
            }
        } footer: {
            if scope == .fern, canLoadFernDemo {
                Text("Demo uses the Spec Portfolio-Fern golden (negative NW is fine). Or run Check the balances.")
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

    /// Prefer a check-in with pocket lines; else newest metrics-only (e.g. demo).
    private func preferredPersonalSnapshot(personId: String) -> SnapshotRecord? {
        let mine = snapshots.filter { $0.personId == personId }
        if let withLines = mine.first(where: { !$0.lines.isEmpty }) {
            return withLines
        }
        return mine.first
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
    }
}
