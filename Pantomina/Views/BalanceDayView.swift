import SwiftUI
import SwiftData

/// Thin Balance Day: external pockets only. Fern also confirms Shared once.
struct BalanceDayView: View {
    let personId: PersonId
    /// Empire's selected cycle: Confirm stamps this anchor.
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
    @State private var driftQueue: [InterestDrift.Prompt] = []
    @State private var activeDrift: InterestDrift.Prompt?

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

    /// Shared externals: Fern (payer) only.
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
                    Text("Cash and cards come from the ledger as of this cycle. Update what's still outside: investments and mandated savings.")
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
                            Text("Confirmed once here, not again on \(starkName)'s check-in.")
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
            .onAppear {
                try? SeedCatalog.seedDemoExternalsIfNeeded(into: modelContext)
                try? modelContext.save()
                seedDraftsIfNeeded()
            }
            .onChange(of: personalExternals.map(\.id)) { _, _ in
                seedDraftsIfNeeded()
            }
            .onChange(of: sharedExternals.map(\.id)) { _, _ in
                seedDraftsIfNeeded()
            }
            .sheet(item: $activeDrift) { prompt in
                InterestDriftSheet(
                    prompt: prompt,
                    accountLabel: accounts.first { $0.id == prompt.homeAccountId }?
                        .displayLabel(fernName: fernName, starkName: starkName)
                        ?? "This pocket",
                    onBook: { bookInterest(prompt); advanceDriftQueue() },
                    onSkip: { advanceDriftQueue() }
                )
            }
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
                    "Today's balance",
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
        // Empty when unknown: never pretend 0.00 is confirmed.
        let text: String
        if let last = account.lastConfirmedBalanceC {
            text = String(format: "%.2f", Double(last) / 100)
        } else {
            text = ""
        }
        return DraftLine(balanceText: text, skipped: false)
    }

    private func seedDraftsIfNeeded() {
        for account in allEditable where drafts[account.id] == nil {
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
                    note: tx.note ?? tx.merchant,
                    settlementRole: tx.settlementRole
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
        var pendingDrift: [InterestDrift.Prompt] = []

        for account in allEditable {
            let draft = drafts[account.id] ?? defaultDraft(for: account)
            if draft.skipped {
                externalBalances[account.id] = (account.lastConfirmedBalanceC ?? 0, true)
                continue
            }
            let trimmed = draft.balanceText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                error = "Enter today's balance on \(account.baseName), or skip it."
                return
            }
            guard let amountC = InputBounds.centavos(fromPesosText: trimmed),
                  amountC >= 0,
                  amountC <= InputBounds.maxAmountC
            else {
                error = "Check the amount on \(account.baseName)."
                return
            }
            let isFundHome = funds.contains { $0.homeAccountId == account.id }
            if isFundHome, let previous = account.lastConfirmedBalanceC {
                let explained = explainedIncomeC(
                    accountId: account.id,
                    afterCycleISO: account.lastConfirmedCycleISO
                )
                if let prompt = InterestDrift.prompt(
                    homeAccountId: account.id,
                    previousConfirmedBalanceC: previous,
                    currentBalanceC: amountC,
                    explainedIncomeC: explained
                ) {
                    pendingDrift.append(prompt)
                }
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

        if personId == .fern, let love = loveTabLine(asOf: cycleISO) {
            lines.append(love)
        }

        let prior = priorMetrics()
        let metrics = Snapshot.metrics(lines: lines, prior: prior, lens: .personal)
        let record = SnapshotRecord(
            cycleAnchorISO: cycleISO,
            personId: personId.rawValue,
            lines: lines,
            metrics: metrics
        )
        modelContext.insert(record)
        try? modelContext.save()

        if pendingDrift.isEmpty {
            onDone()
        } else {
            driftQueue = pendingDrift
            activeDrift = pendingDrift.first
        }
    }

    private func explainedIncomeC(accountId: String, afterCycleISO: String?) -> Int {
        transactions
            .filter { $0.accountId == accountId && $0.realizedStatus == .realized }
            .filter { tx in
                guard let after = afterCycleISO else { return true }
                let effective = tx.realizedDate ?? tx.purchaseDate
                return effective > after
            }
            .filter { categoryFlow[$0.categoryId] == .income }
            .filter {
                switch $0.settlementRole {
                case .contribution, .receivable, .fundMove: return false
                case .loanPayment, nil: return true
                }
            }
            .reduce(0) { $0 + $1.amountC }
    }

    private func bookInterest(_ prompt: InterestDrift.Prompt) {
        let incomeCat = categories.first { $0.flow == .income && $0.item == "Side hustle" }
            ?? categories.first { $0.flow == .income }
        guard let incomeCat else { return }
        let tx = TransactionRecord(
            purchaseDate: cycleISO,
            realizedDate: cycleISO,
            realizedStatus: .realized,
            amountC: prompt.unexplainedPositiveC,
            accountId: prompt.homeAccountId,
            categoryId: incomeCat.id,
            paidBy: personId,
            allocation: Allocation(
                fern: personId == .fern ? prompt.unexplainedPositiveC : 0,
                stark: personId == .stark ? prompt.unexplainedPositiveC : 0
            ),
            note: "Interest"
        )
        modelContext.insert(tx)
        try? modelContext.save()
    }

    private func advanceDriftQueue() {
        guard !driftQueue.isEmpty else {
            activeDrift = nil
            onDone()
            return
        }
        driftQueue.removeFirst()
        if let next = driftQueue.first {
            activeDrift = next
        } else {
            activeDrift = nil
            onDone()
        }
    }

    private func priorMetrics() -> Snapshot.Metrics? {
        let prev = Cycle.previousHalfMonth(before: Cycle(anchorISO: cycleISO)).anchorISO
        if let snap = snapshots.first(where: {
            $0.personId == personId.rawValue && $0.cycleAnchorISO == prev && !$0.lines.isEmpty
        }) {
            return snap.metrics
        }
        return snapshots
            .filter {
                $0.personId == personId.rawValue
                    && !$0.lines.isEmpty
                    && $0.cycleAnchorISO < cycleISO
            }
            .sorted { $0.cycleAnchorISO > $1.cycleAnchorISO }
            .first?
            .metrics
    }

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
}
