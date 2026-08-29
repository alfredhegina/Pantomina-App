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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                if filtered.isEmpty {
                    empty
                } else {
                    List(filtered, id: \.id) { tx in
                        receiptRow(tx)
                    }
                    .listStyle(.plain)
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
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                filterChip("All people", selected: personFilter == nil) { personFilter = nil }
                filterChip(fernName, selected: personFilter == .fern) { personFilter = .fern }
                filterChip(starkName, selected: personFilter == .stark) { personFilter = .stark }
                filterChip("Household", selected: scopeFilter == .household) {
                    scopeFilter = scopeFilter == .household ? nil : .household
                }
                filterChip("Expense", selected: flowFilter == .expense) {
                    flowFilter = flowFilter == .expense ? nil : .expense
                }
                filterChip("Income", selected: flowFilter == .income) {
                    flowFilter = flowFilter == .income ? nil : .income
                }
                filterChip("Pending", selected: statusFilter == .pending) {
                    statusFilter = statusFilter == .pending ? nil : .pending
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
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(selected ? Color.pantomina.sage : Color.pantomina.hairline)
                .foregroundStyle(selected ? Color.white : Color.pantomina.ink)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var empty: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            Text("Nothing here yet. Rare quiet moment.")
                .font(PantominaFont.body)
                .foregroundStyle(Color.pantomina.muted)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func receiptRow(_ tx: TransactionRecord) -> some View {
        let account = accounts.first { $0.id == tx.accountId }
        let category = categories.first { $0.id == tx.categoryId }
        let label = account?.displayLabel(fernName: fernName, starkName: starkName) ?? "Account"
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(category?.displayName ?? "Category")
                    .font(PantominaFont.body.weight(.medium))
                Spacer()
                Text(formatPeso(tx.amountC))
                    .font(PantominaFont.body.monospacedDigit())
            }
            HStack {
                Text(tx.purchaseDate)
                Text("·")
                Text(label)
                Spacer()
                Chip(label: tx.realizedStatus.rawValue, tone: tx.realizedStatus == .pending ? .terra : .neutral)
            }
            .font(PantominaFont.caption)
            .foregroundStyle(Color.pantomina.muted)
        }
        .listRowBackground(Color.pantomina.card)
    }
}
