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

    private var statementAccounts: [AccountRecord] {
        accounts.filter { !$0.archived && $0.settlement == .statement }
            .sorted { $0.baseName < $1.baseName }
    }

    private var selectedAccount: AccountRecord? {
        statementAccounts.first { $0.id == selectedAccountId }
    }

    private var pendingForAccount: [TransactionRecord] {
        guard let accountId = selectedAccountId else { return [] }
        return transactions.filter {
            $0.accountId == accountId && $0.realizedStatus == .pending
        }
        .sorted {
            let lhs = $0.purchaseDate
            let rhs = $1.purchaseDate
            if lhs != rhs { return lhs < rhs }
            return ($0.proposedRealizedDate ?? "") < ($1.proposedRealizedDate ?? "")
        }
    }

    private var countsOnOptions: [String] {
        let cutoff = selectedAccount?.statementCutoff ?? 15
        let around = pendingForAccount.compactMap(\.proposedRealizedDate).sorted().first
            ?? pendingForAccount.map(\.purchaseDate).sorted().first
            ?? Self.todayISO()
        let candidates = Cycle.statementAnchorCandidates(
            aroundISO: around,
            cutoff: cutoff,
            before: 2,
            after: 2
        )
        let extras = pendingForAccount.compactMap(\.proposedRealizedDate)
        return Array(Set(candidates + extras)).sorted()
    }

    private var categoryNameById: [String: String] {
        Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.displayName) })
    }

    var body: some View {
        let fern = people.first { $0.id == .fern }?.name ?? "Fern"
        let stark = people.first { $0.id == .stark }?.name ?? "Stark"
        let names = categoryNameById
        Form {
            cardSection(fernName: fern, starkName: stark)
            if selectedAccountId != nil {
                cycleSection
                if !pendingForAccount.isEmpty, selectedAnchor != nil {
                    pendingSection(categoryNames: names)
                    markSection
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
            ensureSelectedAnchor()
        }
        .onChange(of: selectedAccountId) { _, _ in
            selectedIds = []
            ensureSelectedAnchor()
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

    @ViewBuilder
    private func cardSection(fernName: String, starkName: String) -> some View {
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
            Text("Tick what’s on this statement. The rest stay in the pile.")
        }
    }

    @ViewBuilder
    private var cycleSection: some View {
        Section("Cycle") {
            if pendingForAccount.isEmpty {
                Text("Nothing waiting on a statement for this card.")
                    .foregroundStyle(Color.pantomina.muted)
            } else {
                Picker("Counts on", selection: $selectedAnchor) {
                    Text("Choose").tag(String?.none)
                    ForEach(countsOnOptions, id: \.self) { anchor in
                        Text(DisplayLabels.displayDate(iso: anchor)).tag(Optional(anchor))
                    }
                }
                .accessibilityLabel("Counts on")
            }
        }
    }

    @ViewBuilder
    private func pendingSection(categoryNames: [String: String]) -> some View {
        let waiting = pendingForAccount.count
        let when = selectedAnchor.map { DisplayLabels.displayDate(iso: $0) } ?? "this statement"
        Section {
            ForEach(pendingForAccount, id: \.id) { tx in
                pendingRow(tx: tx, categoryName: categoryNames[tx.categoryId] ?? "Category")
            }
        } header: {
            Text("Still in the pile")
        } footer: {
            Text("\(waiting) waiting · tick what’s on the \(when) statement")
        }
    }

    private var markSection: some View {
        Section {
            Button("Mark selected as counted") {
                applyBatch()
            }
            .disabled(selectedIds.isEmpty || selectedAnchor == nil)
        }
    }

    private func pendingRow(tx: TransactionRecord, categoryName: String) -> some View {
        let guessed = tx.proposedRealizedDate
        let showGuess = guessed != nil && guessed != selectedAnchor
        return Toggle(isOn: Binding(
            get: { selectedIds.contains(tx.id) },
            set: { on in
                if on { selectedIds.insert(tx.id) } else { selectedIds.remove(tx.id) }
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(categoryName)
                Text("\(DisplayLabels.displayDate(iso: tx.purchaseDate)) · \(formatPeso(tx.amountC))")
                    .font(PantominaFont.caption)
                    .foregroundStyle(Color.pantomina.muted)
                if showGuess, let guessed {
                    Text("Guessed · \(DisplayLabels.displayDate(iso: guessed))")
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.muted)
                }
            }
        }
    }

    private func ensureSelectedAnchor() {
        let options = countsOnOptions
        guard !options.isEmpty else {
            selectedAnchor = nil
            return
        }
        if let selectedAnchor, options.contains(selectedAnchor) { return }
        let earliestProposal = pendingForAccount.compactMap(\.proposedRealizedDate).sorted().first
        if let earliestProposal, options.contains(earliestProposal) {
            selectedAnchor = earliestProposal
        } else {
            selectedAnchor = options.first
        }
    }

    private func applyBatch() {
        guard let anchor = selectedAnchor else { return }
        let pending = pendingForAccount.map {
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

    private static func todayISO() -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
