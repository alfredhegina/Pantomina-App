import SwiftUI
import SwiftData

struct ReceiptsView: View {
    @Query(sort: \TransactionRecord.purchaseDate, order: .reverse) private var transactions: [TransactionRecord]
    @Query private var accounts: [AccountRecord]
    @Query private var categories: [CategoryRecord]
    @Query private var people: [PersonRecord]

    @State private var personFilter: PersonId?
    @State private var scopeFilter: Scope?
    @State private var flowFilter: FlowType?
    @State private var statusFilter: RealizedStatus?

    private var fernName: String { people.first { $0.id == .fern }?.name ?? "Fern" }
    private var starkName: String { people.first { $0.id == .stark }?.name ?? "Stark" }

    private var filtersActive: Bool {
        personFilter != nil || scopeFilter != nil || flowFilter != nil || statusFilter != nil
    }

    private var filtered: [TransactionRecord] {
        let rows = transactions.map { tx -> (TransactionRecord, LedgerFilterRow) in
            let account = accounts.first { $0.id == tx.accountId }
            let category = categories.first { $0.id == tx.categoryId }
            let row = LedgerFilterRow(
                id: tx.id,
                paidBy: tx.paidBy,
                scope: account?.scope ?? .household,
                flow: category?.flow ?? .expense,
                status: tx.realizedStatus
            )
            return (tx, row)
        }
        let kept = Set(
            LedgerFilters.apply(
                rows.map(\.1),
                person: personFilter,
                scope: scopeFilter,
                flow: flowFilter,
                status: statusFilter
            ).map(\.id)
        )
        return rows.compactMap { kept.contains($0.0.id) ? $0.0 : nil }
    }

    /// Realized (and projected) rows for the main list — pending live in the TBD drawer.
    private var ledgerRows: [TransactionRecord] {
        if statusFilter == .pending { return filtered }
        return filtered.filter { $0.realizedStatus != .pending }
    }

    private var pendingRows: [TransactionRecord] {
        filtered.filter { $0.realizedStatus == .pending }
    }

    private var tbdSum: Int {
        Realization.tbdSumCentavos(
            pendingRows.map { Realization.TBDItem(id: $0.id, amountC: $0.amountC, status: $0.realizedStatus) }
        )
    }

    private var groupedByRealized: [(key: String, rows: [TransactionRecord])] {
        let groups = Dictionary(grouping: ledgerRows) { tx in
            tx.realizedDate ?? tx.purchaseDate
        }
        return groups.keys.sorted(by: >).map { key in
            (key, groups[key]!.sorted { $0.purchaseDate > $1.purchaseDate })
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                if filtered.isEmpty {
                    empty
                } else {
                    List {
                        if !pendingRows.isEmpty, statusFilter != .pending {
                            Section {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Still in the pile")
                                            .font(PantominaFont.body.weight(.medium))
                                        Text("\(pendingRows.count) waiting · \(formatPeso(tbdSum))")
                                            .font(PantominaFont.caption)
                                            .foregroundStyle(Color.pantomina.muted)
                                    }
                                    Spacer()
                                    NavigationLink {
                                        StatementDayView()
                                    } label: {
                                        Text("Statement day")
                                            .font(PantominaFont.caption.weight(.semibold))
                                            .foregroundStyle(Color.pantomina.sage)
                                    }
                                }
                                ForEach(pendingRows.prefix(5), id: \.id) { tx in
                                    receiptRow(tx, dateISO: tx.proposedRealizedDate ?? tx.purchaseDate)
                                }
                                if pendingRows.count > 5 {
                                    Text("+\(pendingRows.count - 5) more")
                                        .font(PantominaFont.caption)
                                        .foregroundStyle(Color.pantomina.muted)
                                }
                            } header: {
                                Text("TBD")
                            }
                        }

                        if statusFilter == .pending {
                            ForEach(pendingRows, id: \.id) { tx in
                                receiptRow(tx, dateISO: tx.proposedRealizedDate ?? tx.purchaseDate)
                            }
                        } else {
                            ForEach(groupedByRealized, id: \.key) { group in
                                Section(DisplayLabels.displayDate(iso: group.key)) {
                                    ForEach(group.rows, id: \.id) { tx in
                                        receiptRow(tx, dateISO: tx.purchaseDate)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(Color.pantomina.ground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        PetTitle("The Receipts")
                        Text("Ledger")
                            .font(PantominaFont.caption)
                            .foregroundStyle(Color.pantomina.muted)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        StatementDayView()
                    } label: {
                        Image(systemName: "creditcard")
                    }
                    .accessibilityLabel("Statement day")
                }
            }
        }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            FlowLayout(spacing: Spacing.sm) {
                filterChip("All people", selected: personFilter == nil) { personFilter = nil }
                filterChip(fernName, selected: personFilter == .fern) { personFilter = .fern }
                filterChip(starkName, selected: personFilter == .stark) { personFilter = .stark }
                filterChip("Shared", selected: scopeFilter == .household) {
                    scopeFilter = scopeFilter == .household ? nil : .household
                }
                filterChip("Expense", selected: flowFilter == .expense) {
                    flowFilter = flowFilter == .expense ? nil : .expense
                }
                filterChip("Income", selected: flowFilter == .income) {
                    flowFilter = flowFilter == .income ? nil : .income
                }
                filterChip(DisplayLabels.statusFilter(.pending), selected: statusFilter == .pending) {
                    statusFilter = statusFilter == .pending ? nil : .pending
                }
                if filtersActive {
                    filterChip("Clear", selected: false) {
                        personFilter = nil
                        scopeFilter = nil
                        flowFilter = nil
                        statusFilter = nil
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
        }
    }

    private func filterChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(PantominaFont.caption)
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: 44)
                .background(selected ? Color.pantomina.sage : Color.pantomina.hairline)
                .foregroundStyle(selected ? Color.white : Color.pantomina.ink)
                .clipShape(Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }

    private var empty: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            Text(transactions.isEmpty
                 ? "Nothing here yet. Rare quiet moment."
                 : "Nothing matches these filters.")
                .font(PantominaFont.body)
                .foregroundStyle(Color.pantomina.muted)
                .multilineTextAlignment(.center)
            if filtersActive {
                Button("Clear filters") {
                    personFilter = nil
                    scopeFilter = nil
                    flowFilter = nil
                    statusFilter = nil
                }
                .font(PantominaFont.body.weight(.semibold))
                .foregroundStyle(Color.pantomina.sage)
            }
            Spacer()
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
    }

    private func receiptRow(_ tx: TransactionRecord, dateISO: String) -> some View {
        let account = accounts.first { $0.id == tx.accountId }
        let category = categories.first { $0.id == tx.categoryId }
        let label = account?.displayLabel(fernName: fernName, starkName: starkName) ?? "Account"
        let amountColor: Color = {
            switch category?.flow {
            case .income: return Color.pantomina.sageDeep
            case .expense: return Color.pantomina.terraDeep
            default: return Color.pantomina.ink
            }
        }()
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(category?.displayName ?? "Category")
                    .font(PantominaFont.body.weight(.medium))
                Spacer()
                Text(formatPeso(tx.amountC))
                    .font(PantominaFont.body.monospacedDigit())
                    .foregroundStyle(amountColor)
            }
            HStack {
                Text(DisplayLabels.displayDate(iso: dateISO))
                Text("·")
                Text(label)
                Spacer()
                if let status = DisplayLabels.status(tx.realizedStatus) {
                    Chip(label: status, tone: tx.realizedStatus == .pending ? .terra : .neutral)
                }
            }
            .font(PantominaFont.caption)
            .foregroundStyle(Color.pantomina.muted)
        }
        .listRowBackground(Color.pantomina.card)
    }
}
