import SwiftUI
import SwiftData

/// Read-only pocket drill-down from Empire for one cycle.
struct PocketMiniReportView: View {
    let account: AccountRecord
    let balanceC: Int
    let spokenForC: Int
    let sourceLabel: String
    let cycleAnchorISO: String
    let onDone: () -> Void

    @Query private var transactions: [TransactionRecord]
    @Query private var categories: [CategoryRecord]
    @Environment(\.dismiss) private var dismiss

    private var categoryById: [String: CategoryRecord] {
        Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
    }

    private var legs: [PocketBalance.Leg] {
        transactions
            .filter { $0.accountId == account.id }
            .compactMap { tx -> PocketBalance.Leg? in
                guard let cat = categoryById[tx.categoryId] else { return nil }
                return PocketBalance.Leg(
                    amountC: tx.amountC,
                    flow: cat.flow,
                    realizedStatus: tx.realizedStatus,
                    purchaseDate: tx.purchaseDate,
                    realizedDate: tx.realizedDate,
                    note: tx.note ?? tx.merchant ?? cat.displayName
                )
            }
    }

    private var cycleStatement: (openingC: Int, rows: [PocketBalance.StatementRow]) {
        PocketBalance.statementInCycle(
            kind: account.kind,
            legs: legs,
            cycleAnchorISO: cycleAnchorISO
        )
    }

    var body: some View {
        let statement = cycleStatement
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Balance")
                        Spacer()
                        Text(formatPeso(balanceC))
                            .font(PantominaFont.amount)
                            .monospacedDigit()
                    }
                    Text("As of \(DisplayLabels.displayDate(iso: cycleAnchorISO)) · \(sourceLabel)")
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.muted)
                }
                if spokenForC > 0 {
                    Section {
                        HStack {
                            Text("Spoken for")
                            Spacer()
                            Text(formatPeso(spokenForC))
                                .font(PantominaFont.amount)
                                .monospacedDigit()
                        }
                        HStack {
                            Text("Feels spendable")
                            Spacer()
                            Text(formatPeso(max(0, balanceC - spokenForC)))
                                .font(PantominaFont.amount)
                                .monospacedDigit()
                        }
                    } footer: {
                        Text("Spoken for is War Chest money parked on this pocket — not a second asset.")
                            .font(PantominaFont.caption)
                    }
                }
                Section {
                    HStack {
                        Text("Opening")
                        Spacer()
                        Text(formatPeso(statement.openingC))
                            .font(PantominaFont.amount)
                            .monospacedDigit()
                    }
                    if statement.rows.isEmpty {
                        Text("Nothing counted this cycle yet.")
                            .foregroundStyle(Color.pantomina.muted)
                    } else {
                        ForEach(Array(statement.rows.reversed().enumerated()), id: \.offset) { _, row in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(row.purchaseDate)
                                        .foregroundStyle(Color.pantomina.muted)
                                    Spacer()
                                    Text(formatPeso(row.signedAmountC))
                                        .font(PantominaFont.amount)
                                        .monospacedDigit()
                                }
                                if let note = row.note, !note.isEmpty {
                                    Text(note)
                                        .font(PantominaFont.caption)
                                }
                                Text("After \(formatPeso(row.balanceAfterC))")
                                    .font(PantominaFont.caption)
                                    .foregroundStyle(Color.pantomina.muted)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } header: {
                    Text("This cycle")
                } footer: {
                    Text("Open Receipts for the full list. Edits happen there — not here.")
                        .font(PantominaFont.caption)
                }
            }
            .navigationTitle(account.baseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
