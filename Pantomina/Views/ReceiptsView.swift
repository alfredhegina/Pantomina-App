import SwiftUI
import SwiftData

struct ReceiptsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \TransactionRecord.purchaseDate, order: .reverse) private var transactions: [TransactionRecord]
    @Query private var accounts: [AccountRecord]
    @Query private var categories: [CategoryRecord]
    @Query private var people: [PersonRecord]
    @Query private var funds: [FundRecord]

    @State private var personFilter: PersonId?
    @State private var scopeFilter: Scope?
    @State private var flowFilter: FlowType?
    @State private var statusFilter: RealizedStatus?
    @State private var showMoreFilters = false
    @State private var editingTx: TransactionRecord?
    @State private var editingContribution: TransactionRecord?
    @State private var contributionEditText = ""
    @State private var contributionEditError: String?
    @State private var pendingDelete: TransactionRecord?
    @State private var toast: String?

    private enum Route: Hashable {
        case statementDay
    }

    private var filtersActive: Bool {
        personFilter != nil || scopeFilter != nil || flowFilter != nil || statusFilter != nil
    }

    private var sheetFiltersActive: Bool {
        flowFilter != nil || statusFilter != nil
    }

    private var sheetFilterCount: Int {
        (flowFilter != nil ? 1 : 0) + (statusFilter != nil ? 1 : 0)
    }

    var body: some View {
        // One snapshot per body pass — never re-enter @Query from nested helpers during the same update.
        let accountById = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
        let categoryById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        let fern = people.first { $0.id == .fern }?.name ?? "Fern"
        let stark = people.first { $0.id == .stark }?.name ?? "Stark"
        let filteredRows = Self.filteredTransactions(
            transactions: transactions,
            accountById: accountById,
            categoryById: categoryById,
            personFilter: personFilter,
            scopeFilter: scopeFilter,
            flowFilter: flowFilter,
            statusFilter: statusFilter
        )
        let pending = filteredRows.filter { $0.realizedStatus == .pending }
        let ledger = statusFilter == .pending
            ? filteredRows
            : filteredRows.filter { $0.realizedStatus != .pending }
        let tbdSum = Realization.tbdSumCentavos(
            pending.map { Realization.TBDItem(id: $0.id, amountC: $0.amountC, status: $0.realizedStatus) }
        )
        let grouped = Self.groupedByRealizedDate(ledger)

        NavigationStack {
            VStack(spacing: 0) {
                filterBar(fernName: fern, starkName: stark)
                if filteredRows.isEmpty {
                    empty
                } else {
                    List {
                        if !pending.isEmpty, statusFilter != .pending {
                            Section {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Still in the pile")
                                            .font(PantominaFont.body.weight(.medium))
                                        Text("\(pending.count) waiting · \(formatPeso(tbdSum))")
                                            .font(PantominaFont.caption)
                                            .foregroundStyle(Color.pantomina.muted)
                                    }
                                    Spacer()
                                    NavigationLink(value: Route.statementDay) {
                                        Text("Statement day")
                                            .font(PantominaFont.caption.weight(.semibold))
                                            .foregroundStyle(Color.pantomina.sage)
                                    }
                                }
                                ForEach(Array(pending.prefix(5)), id: \.id) { tx in
                                    receiptRow(
                                        tx,
                                        dateISO: tx.proposedRealizedDate ?? tx.purchaseDate,
                                        accountById: accountById,
                                        categoryById: categoryById,
                                        fernName: fern,
                                        starkName: stark
                                    )
                                }
                                if pending.count > 5 {
                                    Text("+\(pending.count - 5) more")
                                        .font(PantominaFont.caption)
                                        .foregroundStyle(Color.pantomina.muted)
                                }
                            } header: {
                                Text("TBD")
                            }
                        }

                        if statusFilter == .pending {
                            ForEach(pending, id: \.id) { tx in
                                receiptRow(
                                    tx,
                                    dateISO: tx.proposedRealizedDate ?? tx.purchaseDate,
                                    accountById: accountById,
                                    categoryById: categoryById,
                                    fernName: fern,
                                    starkName: stark
                                )
                            }
                        } else {
                            ForEach(grouped, id: \.key) { group in
                                Section(DisplayLabels.displayDate(iso: group.key)) {
                                    ForEach(group.rows, id: \.id) { tx in
                                        receiptRow(
                                            tx,
                                            dateISO: tx.purchaseDate,
                                            accountById: accountById,
                                            categoryById: categoryById,
                                            fernName: fern,
                                            starkName: stark
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(Color.pantomina.ground)
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
                    NavigationLink(value: Route.statementDay) {
                        Image(systemName: "creditcard")
                    }
                    .accessibilityLabel("Statement day")
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .statementDay:
                    StatementDayView()
                }
            }
            .sheet(isPresented: $showMoreFilters) {
                moreFiltersSheet
            }
            .sheet(item: $editingTx) { tx in
                AddEntryView(presentsAsSheet: true, editingTransaction: tx)
            }
            .sheet(item: $editingContribution) { tx in
                contributionEditSheet(tx, starkName: stark)
            }
            .confirmationDialog(
                deleteDialogTitle,
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                if pendingOpeningFund != nil {
                    Button("Remove fund and all Fund Moves", role: .destructive) {
                        let tx = pendingDelete
                        let fund = pendingOpeningFund
                        pendingDelete = nil
                        Task { @MainActor in
                            if let tx, let fund {
                                deleteOpeningFundMove(tx, fund: fund)
                            }
                        }
                    }
                } else {
                    Button("Remove", role: .destructive) {
                        let tx = pendingDelete
                        pendingDelete = nil
                        Task { @MainActor in
                            if let tx { deleteTransaction(tx) }
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingDelete = nil
                }
            }
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.pantomina.ink)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    /// Opening Fund Move that created a War Chest fund — ledger-only delete leaves In the bank wrong.
    private var pendingOpeningFund: FundRecord? {
        guard let tx = pendingDelete,
              tx.settlementRole == .fundMove,
              let linkedId = tx.linkedId,
              (tx.note ?? "").contains(Fund.openingNoteMarker)
        else { return nil }
        return funds.first { $0.id == linkedId }
    }

    private var deleteDialogTitle: String {
        if let fund = pendingOpeningFund {
            return "This opened \(fund.name). Remove that fund and all its Fund Moves from the War Chest?"
        }
        if pendingDelete?.settlementRole != nil {
            return "This was posted from Bills. Remove it?"
        }
        return "Remove from the pile?"
    }

    private static func filteredTransactions(
        transactions: [TransactionRecord],
        accountById: [String: AccountRecord],
        categoryById: [String: CategoryRecord],
        personFilter: PersonId?,
        scopeFilter: Scope?,
        flowFilter: FlowType?,
        statusFilter: RealizedStatus?
    ) -> [TransactionRecord] {
        let rows = transactions.map { tx -> (TransactionRecord, LedgerFilterRow) in
            let account = accountById[tx.accountId]
            let category = categoryById[tx.categoryId]
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

    private static func groupedByRealizedDate(
        _ rows: [TransactionRecord]
    ) -> [(key: String, rows: [TransactionRecord])] {
        let groups = Dictionary(grouping: rows) { tx in
            tx.realizedDate ?? tx.purchaseDate
        }
        return groups.keys.sorted(by: >).map { key in
            (key, groups[key]!.sorted { $0.purchaseDate > $1.purchaseDate })
        }
    }

    private func filterBar(fernName: String, starkName: String) -> some View {
        FlowLayout(spacing: Spacing.sm) {
            filterChip("All", selected: personFilter == nil && scopeFilter == nil) {
                personFilter = nil
                scopeFilter = nil
            }
            filterChip(fernName, selected: personFilter == .fern) {
                personFilter = personFilter == .fern ? nil : .fern
                if personFilter != nil { scopeFilter = nil }
            }
            filterChip(starkName, selected: personFilter == .stark) {
                personFilter = personFilter == .stark ? nil : .stark
                if personFilter != nil { scopeFilter = nil }
            }
            filterChip("Shared", selected: scopeFilter == .household) {
                scopeFilter = scopeFilter == .household ? nil : .household
                if scopeFilter != nil { personFilter = nil }
            }
            filterChip(
                sheetFilterCount > 0 ? "Filters · \(sheetFilterCount)" : "Filters",
                selected: sheetFiltersActive
            ) {
                showMoreFilters = true
            }
            if filtersActive {
                filterChip("Clear", selected: false) {
                    clearAllFilters()
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    private var moreFiltersSheet: some View {
        NavigationStack {
            List {
                Section("Flow") {
                    sheetToggleRow("Expense", selected: flowFilter == .expense) {
                        flowFilter = flowFilter == .expense ? nil : .expense
                    }
                    sheetToggleRow("Income", selected: flowFilter == .income) {
                        flowFilter = flowFilter == .income ? nil : .income
                    }
                }
                Section("Status") {
                    sheetToggleRow(
                        DisplayLabels.statusFilterShort(.pending),
                        selected: statusFilter == .pending
                    ) {
                        statusFilter = statusFilter == .pending ? nil : .pending
                    }
                    sheetToggleRow(
                        DisplayLabels.statusFilterShort(.projected),
                        selected: statusFilter == .projected
                    ) {
                        statusFilter = statusFilter == .projected ? nil : .projected
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") {
                        flowFilter = nil
                        statusFilter = nil
                    }
                    .disabled(!sheetFiltersActive)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showMoreFilters = false }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func sheetToggleRow(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(Color.pantomina.ink)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.pantomina.sage)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }

    private func clearAllFilters() {
        personFilter = nil
        scopeFilter = nil
        flowFilter = nil
        statusFilter = nil
    }

    private func filterChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(PantominaFont.caption)
                .lineLimit(1)
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
                    clearAllFilters()
                }
                .font(PantominaFont.body.weight(.semibold))
                .foregroundStyle(Color.pantomina.sage)
            }
            Spacer()
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
    }

    private func receiptRow(
        _ tx: TransactionRecord,
        dateISO: String,
        accountById: [String: AccountRecord],
        categoryById: [String: CategoryRecord],
        fernName: String,
        starkName: String
    ) -> some View {
        let account = accountById[tx.accountId]
        let category = categoryById[tx.categoryId]
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
                    Chip(
                        label: status,
                        tone: tx.realizedStatus == .pending ? .terra : .neutral
                    )
                }
            }
            .font(PantominaFont.caption)
            .foregroundStyle(Color.pantomina.muted)
        }
        .opacity(tx.realizedStatus == .projected ? 0.72 : 1)
        .listRowBackground(Color.pantomina.card)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if tx.settlementRole == nil {
                Button {
                    editingTx = tx
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(Color.pantomina.sage)
            } else if tx.settlementRole == .contribution {
                Button {
                    contributionEditText = String(format: "%.2f", Double(tx.amountC) / 100)
                    contributionEditError = nil
                    editingContribution = tx
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(Color.pantomina.sage)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingDelete = tx
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityAction(named: "Delete") {
            pendingDelete = tx
        }
        .modifier(EditAccessibilityModifier(
            kind: {
                if tx.settlementRole == nil { return .full }
                if tx.settlementRole == .contribution { return .contribution }
                return .none
            }()
        ) {
            if tx.settlementRole == nil {
                editingTx = tx
            } else if tx.settlementRole == .contribution {
                contributionEditText = String(format: "%.2f", Double(tx.amountC) / 100)
                contributionEditError = nil
                editingContribution = tx
            }
        })
    }

    private func contributionEditSheet(_ tx: TransactionRecord, starkName: String) -> some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Amount", text: $contributionEditText)
                        .keyboardType(.decimalPad)
                    if let contributionEditError {
                        Text(contributionEditError)
                            .foregroundStyle(Color.pantomina.terraDeep)
                    }
                } header: {
                    Text("Contribution")
                } footer: {
                    Text("Updates \(starkName)'s sent amount for this cycle.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.pantomina.ground)
            .navigationTitle("Edit contribution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { editingContribution = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveContributionEdit(tx) }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func saveContributionEdit(_ tx: TransactionRecord) {
        contributionEditError = nil
        guard let amountC = InputBounds.centavos(fromPesosText: contributionEditText), amountC > 0 else {
            contributionEditError = "Enter an amount."
            return
        }
        tx.amountC = amountC
        tx.allocFernC = 0
        tx.allocStarkC = 0
        tx.updatedAt = .now
        do {
            try modelContext.save()
            Task { @MainActor in
                editingContribution = nil
                PantominaMotion.run(reduceMotion) { toast = "Updated." }
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                PantominaMotion.run(reduceMotion) { toast = nil }
            }
        } catch {
            contributionEditError = "Couldn't save. Try again."
        }
    }

    private func deleteOpeningFundMove(_ tx: TransactionRecord, fund: FundRecord) {
        let linkedId = fund.id
        let linkedMoves = transactions.filter {
            $0.settlementRole == .fundMove && $0.linkedId == linkedId
        }
        for move in linkedMoves {
            modelContext.delete(move)
        }
        if !linkedMoves.contains(where: { $0.id == tx.id }) {
            modelContext.delete(tx)
        }
        modelContext.delete(fund)
        do {
            try modelContext.save()
            Task { @MainActor in
                PantominaMotion.run(reduceMotion) { toast = "Removed fund and moves." }
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                PantominaMotion.run(reduceMotion) { toast = nil }
            }
        } catch {
            Task { @MainActor in
                PantominaMotion.run(reduceMotion) { toast = "Couldn't remove. Try again." }
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                PantominaMotion.run(reduceMotion) { toast = nil }
            }
        }
    }

    private func deleteTransaction(_ tx: TransactionRecord) {
        modelContext.delete(tx)
        do {
            try modelContext.save()
            Task { @MainActor in
                PantominaMotion.run(reduceMotion) { toast = "Removed." }
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                PantominaMotion.run(reduceMotion) { toast = nil }
            }
        } catch {
            Task { @MainActor in
                PantominaMotion.run(reduceMotion) { toast = "Couldn't remove. Try again." }
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                PantominaMotion.run(reduceMotion) { toast = nil }
            }
        }
    }
}

private enum ReceiptEditKind {
    case none, full, contribution
}

private struct EditAccessibilityModifier: ViewModifier {
    let kind: ReceiptEditKind
    let action: () -> Void

    func body(content: Content) -> some View {
        if kind != .none {
            content.accessibilityAction(named: "Edit") { action() }
        } else {
            content
        }
    }
}
