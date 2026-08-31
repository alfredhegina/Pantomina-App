import SwiftUI
import SwiftData

/// Thin Balance Day — external pockets only. Fern also confirms Shared once.
struct BalanceDayView: View {
    let personId: PersonId
    /// Empire’s selected cycle — Confirm stamps this anchor.
    let cycleISO: String
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [AccountRecord]
    @Query private var loans: [LoanRecord]
    @Query private var funds: [FundRecord]
    @Query private var transactions: [TransactionRecord]
    @Query private var categories: [CategoryRecord]
    @Query private var people: [PersonRecord]
    @Query(sort: \SnapshotRecord.confirmedAt, order: .reverse) private var snapshots: [SnapshotRecord]

    @State private var drafts: [String: DraftLine] = [:]
    @State private var error: String?

    private struct DraftLine {
        var balanceText: String
        var skipped: Bool
    }

    private var fernName: String { people.first { $0.id == .fern }?.name ?? "Fern" }
    private var starkName: String { people.first { $0.id == .stark }?.name ?? "Stark" }

    private var categoryFlow: [String: FlowType] {
        Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.flow) })
    }

    /// Personal externals for this person.
    private var personalExternals: [AccountRecord] {
        accounts
            .filter { !$0.archived && PocketBalance.isExternalKind($0.kind) }
            .filter { account in
                switch account.scope {
                case .fern: return personId == .fern
                case .stark: return personId == .stark
                case .household, .business: return false
                }
            }
            .sorted { $0.baseName.localizedCaseInsensitiveCompare($1.baseName) == .orderedAscending }
    }

    /// Shared externals — Fern (payer) only.
    private var sharedExternals: [AccountRecord] {
        guard personId == .fern else { return [] }
        return accounts
            .filter { !$0.archived && PocketBalance.isExternalKind($0.kind) }
            .filter { $0.scope == .household || $0.scope == .business }
            .sorted { $0.baseName.localizedCaseInsensitiveCompare($1.baseName) == .orderedAscending }
    }

    private var allEditable: [AccountRecord] { personalExternals + sharedExternals }

    /// All pockets that land on this person's Empire book (for snapshot mix).
    private var snapshotAccounts: [AccountRecord] {
        accounts
            .filter { !$0.archived }
            .filter { account in
                switch account.scope {
                case .fern: return personId == .fern
                case .stark: return personId == .stark
                case .household, .business: return personId == .fern
                }
            }
            .sorted { $0.baseName.localizedCaseInsensitiveCompare($1.baseName) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let error {
                    Section {
                        Text(error).foregroundStyle(Color.pantomina.terraDeep)
                    }
                }
                Section {
                    Text("Cycle \(DisplayLabels.displayDate(iso: cycleISO))")
                        .foregroundStyle(Color.pantomina.muted)
                } footer: {
                    Text("Cash and cards come from the ledger as of this cycle. Update what’s still outside — investments and mandated savings.")
                        .font(PantominaFont.caption)
                }

                if personalExternals.isEmpty && sharedExternals.isEmpty {
                    Section {
                        Text("Nothing external to check for \(personId == .fern ? fernName : starkName) right now.")
                            .foregroundStyle(Color.pantomina.muted)
                    } footer: {
                        Text("Ledger pockets already show on Empire. Confirm anyway to refresh the cycle snapshot.")
                            .font(PantominaFont.caption)
                    }
                } else {
                    if !personalExternals.isEmpty {
                        Section {
                            ForEach(personalExternals, id: \.id) { account in
                                accountRow(account)
                            }
                        } header: {
                            Text(personId == .fern ? fernName : starkName)
                        }
                    }
                    if !sharedExternals.isEmpty {
                        Section {
                            ForEach(sharedExternals, id: \.id) { account in
                                accountRow(account)
                            }
                        } header: {
                            Text("Shared")
                        } footer: {
                            Text("Confirmed once here — not again on \(starkName)’s check-in.")
                                .font(PantominaFont.caption)
                        }
                    }
                }
            }
            .navigationTitle("Update investments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDone)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") { confirm() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { seedDraftsIfNeeded() }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private func accountRow(_ account: AccountRecord) -> some View {
        let binding = Binding(
            get: { drafts[account.id] ?? defaultDraft(for: account) },
            set: { drafts[account.id] = $0 }
        )
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(account.displayLabel(fernName: fernName, starkName: starkName))
                .font(PantominaFont.body)
            Toggle("Skipped", isOn: Binding(
                get: { binding.wrappedValue.skipped },
                set: { skipped in
                    var d = binding.wrappedValue
                    d.skipped = skipped
                    drafts[account.id] = d
                }
            ))
            if !binding.wrappedValue.skipped {
                TextField(
                    "Today’s balance",
                    text: Binding(
                        get: { binding.wrappedValue.balanceText },
                        set: { text in
                            var d = binding.wrappedValue
                            d.balanceText = text
                            drafts[account.id] = d
                        }
                    )
                )
                .keyboardType(.decimalPad)
            }
        }
        .padding(.vertical, 4)
    }

    private func defaultDraft(for account: AccountRecord) -> DraftLine {
        // Empty when unknown — never pretend 0.00 is confirmed.
        let text: String
        if let last = account.lastConfirmedBalanceC {
            text = String(format: "%.2f", Double(last) / 100)
        } else {
            text = ""
        }
        return DraftLine(balanceText: text, skipped: false)
    }

    private func seedDraftsIfNeeded() {
        guard drafts.isEmpty else { return }
        for account in allEditable {
            drafts[account.id] = defaultDraft(for: account)
        }
    }

    private func legs(for accountId: String) -> [PocketBalance.Leg] {
        transactions
            .filter { $0.accountId == accountId }
            .compactMap { tx -> PocketBalance.Leg? in
                guard let flow = categoryFlow[tx.categoryId] else { return nil }
                return PocketBalance.Leg(
                    amountC: tx.amountC,
                    flow: flow,
                    realizedStatus: tx.realizedStatus,
                    purchaseDate: tx.purchaseDate,
                    realizedDate: tx.realizedDate,
                    note: tx.note ?? tx.merchant
                )
            }
    }

    private func spokenFor(accountId: String) -> Int {
        funds.filter { $0.homeAccountId == accountId }.map(\.balanceC).reduce(0, +)
    }

    private func loanBalance(for account: AccountRecord) -> Int? {
        guard account.kind == .loan else { return nil }
        let active = loans.filter {
            $0.ownerRaw == personId.rawValue && $0.statusRaw != Loan.Status.done.rawValue
        }
        guard let loan = active.first(where: { $0.paymentAccountId == account.id }) ?? active.first
        else { return 0 }
        return Loan.derivedBalanceC(
            totalLoanC: loan.totalLoanC,
            paidMonths: loan.paidMonths,
            monthlyC: loan.monthlyC
        )
    }

    private func pocketResult(for account: AccountRecord, externalOverride: Int?) -> PocketBalance.Result {
        PocketBalance.compute(
            kind: account.kind,
            legs: legs(for: account.id),
            loanBalanceC: loanBalance(for: account),
            lastConfirmedC: externalOverride ?? account.lastConfirmedBalanceC,
            spokenForC: spokenFor(accountId: account.id),
            receivableBalanceC: account.kind == .receivable ? account.lastConfirmedBalanceC : nil,
            asOfISO: cycleISO,
            lastConfirmedCycleISO: externalOverride != nil ? cycleISO : account.lastConfirmedCycleISO
        )
    }

    private func confirm() {
        error = nil
        var externalBalances: [String: (amountC: Int, skipped: Bool)] = [:]

        for account in allEditable {
            let draft = drafts[account.id] ?? defaultDraft(for: account)
            if draft.skipped {
                externalBalances[account.id] = (account.lastConfirmedBalanceC ?? 0, true)
                continue
            }
            let trimmed = draft.balanceText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                error = "Enter today’s balance on \(account.baseName), or skip it."
                return
            }
            guard let amountC = InputBounds.centavos(fromPesosText: trimmed),
                  amountC >= 0,
                  amountC <= InputBounds.maxAmountC
            else {
                error = "Check the amount on \(account.baseName)."
                return
            }
            externalBalances[account.id] = (amountC, false)
            account.lastConfirmedBalanceC = amountC
            account.lastConfirmedCycleISO = cycleISO
        }

        var lines: [Snapshot.Line] = []
        for account in snapshotAccounts {
            let override: Int?
            let skipped: Bool
            if let ext = externalBalances[account.id] {
                override = ext.amountC
                skipped = ext.skipped
            } else {
                override = account.lastConfirmedBalanceC
                skipped = false
            }

            if skipped {
                lines.append(
                    Snapshot.Line(
                        accountId: account.id,
                        balanceC: account.lastConfirmedBalanceC ?? 0,
                        source: .stale,
                        isLiability: Snapshot.isLiabilityKind(account.kind),
                        countsTowardSavingsAssets: Snapshot.countsTowardSavingsAssets(kind: account.kind),
                        isInternalDebt: account.kind == .receivable
                    )
                )
                continue
            }

            let pocket = pocketResult(for: account, externalOverride: override)
            lines.append(
                Snapshot.line(
                    accountId: account.id,
                    kind: account.kind,
                    pocket: pocket,
                    isInternalDebt: account.kind == .receivable
                )
            )
        }

        let prior = snapshots.first {
            $0.personId == personId.rawValue && !$0.lines.isEmpty
        }?.metrics
        let metrics = Snapshot.metrics(lines: lines, prior: prior, lens: .personal)
        let record = SnapshotRecord(
            cycleAnchorISO: cycleISO,
            personId: personId.rawValue,
            lines: lines,
            metrics: metrics
        )
        modelContext.insert(record)
        try? modelContext.save()
        onDone()
    }
}
