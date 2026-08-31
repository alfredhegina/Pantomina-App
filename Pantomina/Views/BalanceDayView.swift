import SwiftUI
import SwiftData

struct BalanceDayView: View {
    let personId: PersonId
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [AccountRecord]
    @Query private var loans: [LoanRecord]
    @Query private var people: [PersonRecord]
    @Query(sort: \SnapshotRecord.confirmedAt, order: .reverse) private var snapshots: [SnapshotRecord]

    @State private var drafts: [String: DraftLine] = [:]
    @State private var error: String?

    private struct DraftLine {
        var balanceText: String
        var skipped: Bool
        var tier: Snapshot.Tier
        var isLiability: Bool
        var countsTowardSavings: Bool
        var isInternalDebt: Bool
    }

    private var fernName: String { people.first { $0.id == .fern }?.name ?? "Fern" }
    private var starkName: String { people.first { $0.id == .stark }?.name ?? "Stark" }

    private var cycleISO: String {
        Cycle.cycleFor(isoDate: Self.todayISO()).anchorISO
    }

    private var relevantAccounts: [AccountRecord] {
        accounts
            .filter { !$0.archived }
            .filter { account in
                switch account.scope {
                case .fern: return personId == .fern
                case .stark: return personId == .stark
                case .household, .business: return true
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
                    Text("Cycle \(cycleISO)")
                        .foregroundStyle(Color.pantomina.muted)
                } footer: {
                    Text("Confirm what you can. Skip anything you’re not checking today.")
                        .font(PantominaFont.caption)
                }

                ForEach(relevantAccounts, id: \.id) { account in
                    accountRow(account)
                }
            }
            .navigationTitle("Check the balances")
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
        Section {
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
                    binding.wrappedValue.isLiability ? "Balance owed" : "Balance",
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
                .disabled(binding.wrappedValue.tier == .derived && account.kind == .loan)
            }
        } header: {
            Text(account.displayLabel(fernName: fernName, starkName: starkName))
        } footer: {
            Text(tierFooter(binding.wrappedValue.tier, kind: account.kind))
                .font(PantominaFont.caption)
        }
    }

    private func tierFooter(_ tier: Snapshot.Tier, kind: AccountKind) -> String {
        switch tier {
        case .derived:
            return kind == .loan ? "Loan balance is derived — confirm as shown." : "Confirm the pocket balance."
        case .prefilled:
            return "Prefilled from last check-in — overwrite what moved."
        case .stale:
            return "Skipped"
        }
    }

    private func defaultDraft(for account: AccountRecord) -> DraftLine {
        let tier = Snapshot.defaultTier(kind: account.kind)
        let isLiability = Snapshot.isLiabilityKind(account.kind)
        let savings = Snapshot.countsTowardSavingsAssets(kind: account.kind)
        let internalDebt = account.kind == .receivable
        var balanceC = account.lastConfirmedBalanceC ?? 0
        if account.kind == .loan {
            let active = loans.filter {
                $0.ownerRaw == personId.rawValue && $0.statusRaw != Loan.Status.done.rawValue
            }
            if let loan = active.first(where: { $0.paymentAccountId == account.id }) ?? active.first {
                balanceC = Loan.derivedBalanceC(
                    totalLoanC: loan.totalLoanC,
                    paidMonths: loan.paidMonths,
                    monthlyC: loan.monthlyC
                )
            }
        }
        let text: String
        if balanceC == 0 {
            text = "0.00"
        } else {
            text = String(format: "%.2f", Double(balanceC) / 100)
        }
        return DraftLine(
            balanceText: text,
            skipped: false,
            tier: tier,
            isLiability: isLiability,
            countsTowardSavings: savings,
            isInternalDebt: internalDebt
        )
    }

    private func seedDraftsIfNeeded() {
        guard drafts.isEmpty else { return }
        for account in relevantAccounts {
            drafts[account.id] = defaultDraft(for: account)
        }
    }

    private func confirm() {
        error = nil
        var lines: [Snapshot.Line] = []
        for account in relevantAccounts {
            let draft = drafts[account.id] ?? defaultDraft(for: account)
            if draft.skipped {
                lines.append(
                    Snapshot.Line(
                        accountId: account.id,
                        balanceC: account.lastConfirmedBalanceC ?? 0,
                        source: .stale,
                        isLiability: draft.isLiability,
                        countsTowardSavingsAssets: draft.countsTowardSavings,
                        isInternalDebt: draft.isInternalDebt
                    )
                )
                continue
            }
            let trimmed = draft.balanceText.trimmingCharacters(in: .whitespacesAndNewlines)
            let amountC: Int
            if trimmed.isEmpty || trimmed == "0" || trimmed == "0.00" {
                amountC = 0
            } else if let parsed = InputBounds.centavos(fromPesosText: trimmed) {
                amountC = parsed
            } else {
                error = "Check the amount on \(account.baseName)."
                return
            }
            if amountC < 0 || amountC > InputBounds.maxAmountC {
                error = "Check the amount on \(account.baseName)."
                return
            }
            let source: Snapshot.LineSource = draft.tier == .derived ? .derived : .confirmed
            lines.append(
                Snapshot.Line(
                    accountId: account.id,
                    balanceC: amountC,
                    source: source,
                    isLiability: draft.isLiability,
                    countsTowardSavingsAssets: draft.countsTowardSavings,
                    isInternalDebt: draft.isInternalDebt
                )
            )
            account.lastConfirmedBalanceC = amountC
            account.lastConfirmedCycleISO = cycleISO
        }

        // Prefer a prior check-in with pocket lines — skip metrics-only demos so deltas stay honest.
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

    private static func todayISO() -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
