import SwiftUI
import SwiftData

struct StatementDayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var accounts: [AccountRecord]
    @Query private var categories: [CategoryRecord]
    @Query private var transactions: [TransactionRecord]
    @Query private var people: [PersonRecord]

    @State private var selectedAccountId: String?
    @State private var selectedAnchor: String?
    @State private var selectedIds: Set<String> = []
    @State private var toast: String?

    private var fernName: String { people.first { $0.id == .fern }?.name ?? "Fern" }
    private var starkName: String { people.first { $0.id == .stark }?.name ?? "Stark" }

    private var statementAccounts: [AccountRecord] {
        accounts.filter { !$0.archived && $0.settlement == .statement }
            .sorted { $0.baseName < $1.baseName }
    }

    private var pendingForAccount: [TransactionRecord] {
        guard let accountId = selectedAccountId else { return [] }
        return transactions.filter {
            $0.accountId == accountId && $0.realizedStatus == .pending
        }
        .sorted { ($0.proposedRealizedDate ?? "") < ($1.proposedRealizedDate ?? "") }
    }

    private var proposedAnchors: [String] {
        Array(Set(pendingForAccount.compactMap(\.proposedRealizedDate))).sorted()
    }

    private var rowsForAnchor: [TransactionRecord] {
        guard let selectedAnchor else { return [] }
        return pendingForAccount.filter { $0.proposedRealizedDate == selectedAnchor }
    }

    var body: some View {
        Form {
            Section {
                if statementAccounts.isEmpty {
                    Text("No statement cards yet.")
                        .foregroundStyle(Color.pantomina.muted)
                } else {
                    Picker("Card", selection: $selectedAccountId) {
                        Text("Choose").tag(String?.none)
                        ForEach(statementAccounts, id: \.id) { account in
                            Text(account.displayLabel(fernName: fernName, starkName: starkName))
                                .tag(Optional(account.id))
                        }
                    }
                }
            } footer: {
                Text("Tick swipes on this statement. They become counted on the chosen cycle; the rest stay in the pile.")
            }

            if selectedAccountId != nil {
                Section("Cycle") {
                    if proposedAnchors.isEmpty {
                        Text("Nothing waiting on a statement for this card.")
                            .foregroundStyle(Color.pantomina.muted)
                    } else {
                        Picker("Counts on", selection: $selectedAnchor) {
                            Text("Choose").tag(String?.none)
                            ForEach(proposedAnchors, id: \.self) { anchor in
                                Text(DisplayLabels.displayDate(iso: anchor)).tag(Optional(anchor))
                            }
                        }
                    }
                }

                if selectedAnchor != nil {
                    Section {
                        ForEach(rowsForAnchor, id: \.id) { tx in
                            let category = categories.first { $0.id == tx.categoryId }
                            Toggle(isOn: Binding(
                                get: { selectedIds.contains(tx.id) },
                                set: { on in
                                    if on { selectedIds.insert(tx.id) } else { selectedIds.remove(tx.id) }
                                }
                            )) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category?.displayName ?? "Category")
                                    Text("\(DisplayLabels.displayDate(iso: tx.purchaseDate)) · \(formatPeso(tx.amountC))")
                                        .font(PantominaFont.caption)
                                        .foregroundStyle(Color.pantomina.muted)
                                }
                            }
                        }
                    } header: {
                        Text("On this statement")
                    }

                    Section {
                        Button("Mark selected as counted") {
                            applyBatch()
                        }
                        .disabled(selectedIds.isEmpty || selectedAnchor == nil)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.pantomina.ground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    PetTitle("Statement day")
                    Text("Count the card")
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.muted)
                }
            }
        }
        .task {
            if selectedAccountId == nil {
                selectedAccountId = statementAccounts.first?.id
            }
            if selectedAnchor == nil {
                selectedAnchor = proposedAnchors.first
            }
        }
        .onChange(of: selectedAccountId) { _, _ in
            selectedAnchor = proposedAnchors.first
            selectedIds = []
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .padding()
                    .background(Color.pantomina.ink)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(.bottom, 24)
            }
        }
    }

    private func applyBatch() {
        guard let anchor = selectedAnchor else { return }
        let pending = rowsForAnchor.map {
            Realization.PendingRow(id: $0.id, amountC: $0.amountC, proposedRealizedDate: $0.proposedRealizedDate)
        }
        let results = Realization.batchRealize(
            rows: pending,
            selectedIds: selectedIds,
            toAnchorISO: anchor
        )
        let byId = Dictionary(uniqueKeysWithValues: transactions.map { ($0.id, $0) })
        for result in results {
            guard let tx = byId[result.id] else { continue }
            tx.realizedStatus = result.status
            tx.realizedDate = result.realizedDate
            tx.proposedRealizedDate = result.proposedRealizedDate
        }
        try? modelContext.save()
        selectedIds = []
        PantominaMotion.run(reduceMotion) { toast = "Counted. Updates everywhere." }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            PantominaMotion.run(reduceMotion) { toast = nil }
            if pendingForAccount.isEmpty { dismiss() }
        }
    }
}
