import SwiftUI
import SwiftData

struct WarChestView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var funds: [FundRecord]
    @Query private var accounts: [AccountRecord]
    @Query private var categories: [CategoryRecord]
    @Query private var people: [PersonRecord]

    @State private var showRaid = false
    @State private var showAddFund = false
    @State private var topUpFundId: String?
    @State private var repayFundId: String?
    @State private var repayAmountText = ""
    @State private var toast: String?

    var suggestedRaidAmountC: Int? = nil
    var onRaidComplete: (() -> Void)? = nil

    private var fernName: String { people.first { $0.id == .fern }?.name ?? "Fern" }
    private var starkName: String { people.first { $0.id == .stark }?.name ?? "Stark" }

    private var fernPersonalAccounts: [AccountRecord] {
        accounts.filter { !$0.archived && $0.scope == .fern }
    }

    /// Cash / bank / e-wallet / digital bank — fund homes and raid destinations (not CC / loan).
    private var fernAssetPockets: [AccountRecord] {
        fernPersonalAccounts.filter {
            Fund.isSpendPocket(kind: $0.kind, scope: $0.scope)
        }
    }

    private var orderedFunds: [FundRecord] {
        funds.sorted {
            if $0.raidOrder != $1.raidOrder { return $0.raidOrder < $1.raidOrder }
            return $0.name < $1.name
        }
    }

    private var totalOwedC: Int {
        funds.reduce(0) { $0 + $1.iousC }
    }

    private var accountById: [String: AccountRecord] {
        Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
    }

    var body: some View {
        List {
            if totalOwedC > 0 {
                Section {
                    HStack {
                        Text("Household owes the chest")
                            .foregroundStyle(Color.pantomina.muted)
                        Spacer()
                        Text(formatPeso(totalOwedC))
                            .font(PantominaFont.amount)
                            .monospacedDigit()
                            .foregroundStyle(Color.pantomina.terraDeep)
                    }
                } footer: {
                    Text("Visible IOUs — repay when you can. No nagging.")
                        .font(PantominaFont.caption)
                }
            }

            Section("Funds") {
                if orderedFunds.isEmpty {
                    Text("No funds yet. Start one below, or keep the demo seed after relaunch.")
                        .font(PantominaFont.body)
                        .foregroundStyle(Color.pantomina.muted)
                }
                ForEach(orderedFunds, id: \.id) { fund in
                    fundCard(fund)
                }
                Button {
                    showAddFund = true
                } label: {
                    Label("Start a fund", systemImage: "plus.circle")
                        .font(PantominaFont.body.weight(.medium))
                        .foregroundStyle(Color.pantomina.sageDeep)
                }
                .accessibilityLabel("Start a fund")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.pantomina.ground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    PetTitle("The War Chest")
                    Text("Funds")
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.muted)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Borrow") { showRaid = true }
                    .accessibilityLabel("Borrow to cover bills")
            }
        }
        .onAppear {
            if suggestedRaidAmountC != nil {
                showRaid = true
            }
        }
        .task {
            // Seed off the update cycle — save during onAppear contributed to AttributeGraph crashes.
            try? SeedCatalog.seedDemoFundsIfNeeded(into: modelContext)
            try? modelContext.save()
        }
        .sheet(isPresented: $showAddFund) {
            AddFundSheet(
                fernAccounts: fernAssetPockets,
                fernName: fernName,
                onCancel: { showAddFund = false },
                onSave: { name, purpose, homeId, openingC, targetC, dateISO in
                    commitAddFund(
                        name: name,
                        purpose: purpose,
                        homeAccountId: homeId,
                        openingC: openingC,
                        targetC: targetC,
                        dateISO: dateISO
                    )
                    showAddFund = false
                }
            )
        }
        .sheet(isPresented: $showRaid) {
            RaidSheet(
                funds: orderedFunds,
                destinations: fernAssetPockets,
                suggestedAmountC: suggestedRaidAmountC,
                accountLabel: { id in
                    accountById[id]?.displayLabel(fernName: fernName, starkName: starkName) ?? id
                },
                onCancel: { showRaid = false },
                onConfirm: { fundId, amountC, destId, note, dateISO in
                    commitRaid(
                        fundId: fundId,
                        amountC: amountC,
                        destinationId: destId,
                        attribution: .absorb,
                        note: note,
                        dateISO: dateISO
                    )
                    showRaid = false
                    onRaidComplete?()
                }
            )
        }
        .sheet(isPresented: Binding(
            get: { topUpFundId != nil },
            set: { if !$0 { topUpFundId = nil } }
        )) {
            if let id = topUpFundId, let fund = funds.first(where: { $0.id == id }) {
                TopUpSheet(
                    fundName: fund.name,
                    homeAccountId: fund.homeAccountId,
                    fernAccounts: fernPersonalAccounts,
                    fernName: fernName,
                    starkName: starkName,
                    onCancel: { topUpFundId = nil },
                    onSave: { amountC, fromId, dateISO in
                        commitTopUp(
                            fund: fund,
                            amountC: amountC,
                            fromAccountId: fromId,
                            dateISO: dateISO
                        )
                        topUpFundId = nil
                    }
                )
            }
        }
        .sheet(isPresented: Binding(
            get: { repayFundId != nil },
            set: { if !$0 { repayFundId = nil } }
        )) {
            if let id = repayFundId, let fund = funds.first(where: { $0.id == id }) {
                repaySheet(fund)
            }
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

    private func fundCard(_ record: FundRecord) -> some View {
        let snap = record.engineFund
        let owed = Fund.owedBackC(snap)
        let effective = Fund.effectiveBalanceC(snap)
        let homeLabel = accountById[snap.homeAccountId]?
            .displayLabel(fernName: fernName, starkName: starkName) ?? "Account"
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(snap.name)
                .font(PantominaFont.body.weight(.semibold))
            Text(homeLabel)
                .font(PantominaFont.caption)
                .foregroundStyle(Color.pantomina.muted)
            HStack {
                Text("In the bank")
                    .font(PantominaFont.caption)
                    .foregroundStyle(Color.pantomina.muted)
                Spacer()
                Text(formatPeso(snap.balanceC))
                    .font(PantominaFont.amount)
                    .monospacedDigit()
            }
            if owed > 0 {
                HStack {
                    Text("Owed back")
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.terraDeep)
                    Spacer()
                    Text(formatPeso(owed))
                        .font(PantominaFont.caption.monospacedDigit())
                        .foregroundStyle(Color.pantomina.terraDeep)
                }
                Text("Feels like \(formatPeso(effective))")
                    .font(PantominaFont.caption)
                    .foregroundStyle(Color.pantomina.muted)
                if let whole = Fund.wholeAgainAtISO(
                    fund: snap,
                    monthlyRepayC: max(1, owed / 2),
                    fromISO: Self.todayISO()
                ) {
                    Text("Whole again ~ \(DisplayLabels.displayDate(iso: whole))")
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.muted)
                }
            }
            if let target = snap.targetC, target > 0 {
                ProgressView(value: Double(min(snap.balanceC, target)), total: Double(target))
                    .tint(Color.pantomina.sage)
                Text("Target \(formatPeso(target))")
                    .font(PantominaFont.caption)
                    .foregroundStyle(Color.pantomina.muted)
            }
            HStack(spacing: Spacing.md) {
                Button("Top up") { topUpFundId = record.id }
                    .font(PantominaFont.caption.weight(.medium))
                    .foregroundStyle(Color.pantomina.sageDeep)
                if owed > 0 {
                    Button("Repay") {
                        repayAmountText = String(format: "%.2f", Double(owed) / 100)
                        repayFundId = record.id
                    }
                    .font(PantominaFont.caption.weight(.medium))
                    .foregroundStyle(Color.pantomina.sageDeep)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func repaySheet(_ record: FundRecord) -> some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Amount", text: $repayAmountText)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Repay \(record.name)")
                } footer: {
                    Text("Oldest IOU first. Fund balance restores; reverse ledger comes later.")
                        .font(PantominaFont.caption)
                }
            }
            .navigationTitle("Make it whole")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { repayFundId = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Repay") { commitRepay(record) }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Commits

    private func fundMoveCategoryId() -> String? {
        categories.first { $0.system && $0.item == "Fund Move" }?.id
    }

    private func commitAddFund(
        name: String,
        purpose: Fund.Purpose,
        homeAccountId: String,
        openingC: Int,
        targetC: Int?,
        dateISO: String
    ) {
        guard let catId = fundMoveCategoryId() else { return }
        let record = FundRecord(
            name: name,
            purpose: purpose,
            homeAccountId: homeAccountId,
            targetC: targetC,
            balanceC: 0
        )
        modelContext.insert(record)
        if openingC > 0, let updated = Fund.topUp(to: record.engineFund, amountC: openingC) {
            record.apply(updated)
            insertFundMove(
                accountId: homeAccountId,
                amountC: openingC,
                categoryId: catId,
                linkedId: record.id,
                note: "\(name) · opening",
                dateISO: dateISO
            )
        }
        try? modelContext.save()
        flashToast("Added \(name)")
    }

    private func commitTopUp(fund: FundRecord, amountC: Int, fromAccountId: String, dateISO: String) {
        guard let catId = fundMoveCategoryId(),
              let updated = Fund.topUp(to: fund.engineFund, amountC: amountC)
        else { return }
        fund.apply(updated)
        if fromAccountId != fund.homeAccountId {
            insertFundMove(
                accountId: fromAccountId,
                amountC: amountC,
                categoryId: catId,
                linkedId: fund.id,
                note: "\(fund.name) · top-up out",
                dateISO: dateISO
            )
        }
        insertFundMove(
            accountId: fund.homeAccountId,
            amountC: amountC,
            categoryId: catId,
            linkedId: fund.id,
            note: "\(fund.name) · top-up",
            dateISO: dateISO
        )
        try? modelContext.save()
        flashToast("Topped up \(formatPeso(amountC))")
    }

    private func commitRaid(
        fundId: String,
        amountC: Int,
        destinationId: String,
        attribution: Fund.Attribution,
        note: String,
        dateISO: String
    ) {
        let useNote = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Cover bills"
            : note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let record = funds.first(where: { $0.id == fundId }),
              let updated = Fund.applyRaid(
                to: record.engineFund,
                amountC: amountC,
                dateISO: dateISO,
                reason: useNote,
                attribution: attribution
              ),
              let catId = fundMoveCategoryId()
        else { return }

        record.apply(updated)

        let label = "\(record.name) · \(useNote)"
        if destinationId == record.homeAccountId {
            insertFundMove(
                accountId: record.homeAccountId,
                amountC: amountC,
                categoryId: catId,
                linkedId: record.id,
                note: label,
                dateISO: dateISO
            )
        } else {
            insertFundMove(
                accountId: record.homeAccountId,
                amountC: amountC,
                categoryId: catId,
                linkedId: record.id,
                note: "\(label) · out",
                dateISO: dateISO
            )
            insertFundMove(
                accountId: destinationId,
                amountC: amountC,
                categoryId: catId,
                linkedId: record.id,
                note: "\(label) · in",
                dateISO: dateISO
            )
        }

        if attribution == .addToDue,
           let house = accounts.first(where: { $0.scope == .household }) {
            let dueAlloc = AllocationRouting.record(
                intended: Allocation(fern: 0, stark: amountC),
                accountScope: .household,
                paidBy: .fern
            )
            let home = accounts.first { $0.id == record.homeAccountId }
            let decision = Realization.decide(
                purchaseISO: dateISO,
                settlement: home?.settlement ?? .instant,
                statementCutoff: home?.statementCutoff
            )
            modelContext.insert(
                TransactionRecord(
                    purchaseDate: dateISO,
                    realizedDate: decision.realizedDate,
                    realizedStatus: decision.status,
                    amountC: amountC,
                    accountId: house.id,
                    categoryId: catId,
                    paidBy: .fern,
                    allocation: dueAlloc,
                    linkedId: record.id,
                    note: "Raid · add to \(starkName)'s due"
                )
            )
        }

        try? modelContext.save()
        flashToast("Borrowed \(formatPeso(amountC)) from \(record.name)")
    }

    private func insertFundMove(
        accountId: String,
        amountC: Int,
        categoryId: String,
        linkedId: String,
        note: String,
        dateISO: String
    ) {
        let account = accountById[accountId]
        let decision = Realization.decide(
            purchaseISO: dateISO,
            settlement: account?.settlement ?? .instant,
            statementCutoff: account?.statementCutoff
        )
        let alloc = AllocationDefaults.justMine(amountC: amountC, paidBy: .fern)
        modelContext.insert(
            TransactionRecord(
                purchaseDate: dateISO,
                realizedDate: decision.realizedDate,
                realizedStatus: decision.status,
                proposedRealizedDate: decision.proposedRealizedDate,
                amountC: amountC,
                accountId: accountId,
                categoryId: categoryId,
                paidBy: .fern,
                allocation: alloc,
                settlementRole: .fundMove,
                linkedId: linkedId,
                note: note
            )
        )
    }

    private func commitRepay(_ record: FundRecord) {
        guard let amountC = InputBounds.centavos(fromPesosText: repayAmountText), amountC > 0,
              let updated = Fund.repayOldest(in: record.engineFund, amountC: amountC, restoreBalance: true)
        else { return }
        record.apply(updated)
        try? modelContext.save()
        repayFundId = nil
        flashToast("Repaid \(formatPeso(amountC))")
    }

    private func flashToast(_ message: String) {
        Task { @MainActor in
            PantominaMotion.run(reduceMotion) { toast = message }
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            PantominaMotion.run(reduceMotion) { toast = nil }
        }
    }

    private static func todayISO() -> String {
        isoString(from: Date())
    }

    fileprivate static func isoString(from date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

// MARK: - Add fund

private struct AddFundSheet: View {
    let fernAccounts: [AccountRecord]
    let fernName: String
    let onCancel: () -> Void
    let onSave: (String, Fund.Purpose, String, Int, Int?, String) -> Void

    @State private var name = ""
    @State private var purpose: Fund.Purpose = .emergency
    @State private var homeAccountId = ""
    @State private var openingText = ""
    @State private var targetText = ""
    @State private var happenedOn = Date()
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                if let error {
                    Text(error).foregroundStyle(Color.pantomina.terraDeep)
                }
                Section {
                    TextField("Name", text: $name)
                    Picker("Purpose", selection: $purpose) {
                        Text("Emergency").tag(Fund.Purpose.emergency)
                        Text("Sinking").tag(Fund.Purpose.sinking)
                        Text("Loan payoff").tag(Fund.Purpose.loanPayoff)
                        Text("Goal").tag(Fund.Purpose.goal)
                    }
                    Picker("Home account", selection: $homeAccountId) {
                        ForEach(fernAccounts, id: \.id) { acct in
                            Text(acct.displayLabel(fernName: fernName, starkName: "Stark")).tag(acct.id)
                        }
                    }
                    TextField("Opening amount", text: $openingText)
                        .keyboardType(.decimalPad)
                    TextField("Target pesos (optional)", text: $targetText)
                        .keyboardType(.decimalPad)
                    DatePicker(
                        "When it happened",
                        selection: $happenedOn,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                } footer: {
                    Text("Home is cash, bank, e-wallet, or digital bank — not a credit card. Opening posts a Fund Move and fills In the bank. Target is a peso goal (e.g. 80000), not a date. When it happened dates the opening Fund Move when you set an opening amount.")
                        .font(PantominaFont.caption)
                }
            }
            .navigationTitle("Add fund")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { submit() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                if homeAccountId.isEmpty {
                    homeAccountId = fernAccounts.first?.id ?? ""
                }
            }
        }
        .presentationDetents([.large])
    }

    private func submit() {
        error = nil
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            error = "Give the fund a name."
            return
        }
        guard !homeAccountId.isEmpty else {
            error = "Pick a home account."
            return
        }
        let opening: Int
        if openingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            opening = 0
        } else if let c = InputBounds.centavos(fromPesosText: openingText) {
            opening = c
        } else {
            error = "Opening amount looks off."
            return
        }
        var target: Int?
        if !targetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let t = InputBounds.centavos(fromPesosText: targetText) else {
                error = "Target needs pesos (e.g. 80000), not a date."
                return
            }
            target = t
        }
        onSave(trimmed, purpose, homeAccountId, opening, target, WarChestView.isoString(from: happenedOn))
    }
}

// MARK: - Top up

private struct TopUpSheet: View {
    let fundName: String
    let homeAccountId: String
    let fernAccounts: [AccountRecord]
    let fernName: String
    let starkName: String
    let onCancel: () -> Void
    let onSave: (Int, String, String) -> Void

    @State private var amountText = ""
    @State private var fromAccountId = ""
    @State private var happenedOn = Date()
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                if let error {
                    Text(error).foregroundStyle(Color.pantomina.terraDeep)
                }
                Section {
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                    Picker("From", selection: $fromAccountId) {
                        ForEach(fernAccounts, id: \.id) { acct in
                            Text(acct.displayLabel(fernName: fernName, starkName: starkName)).tag(acct.id)
                        }
                    }
                    DatePicker(
                        "When it happened",
                        selection: $happenedOn,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                } header: {
                    Text("Top up \(fundName)")
                } footer: {
                    Text("Adds to In the bank and posts a Fund Move.")
                        .font(PantominaFont.caption)
                }
            }
            .navigationTitle("Top up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { submit() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                if fromAccountId.isEmpty {
                    fromAccountId = homeAccountId
                }
            }
        }
        .presentationDetents([.large])
    }

    private func submit() {
        error = nil
        guard let amountC = InputBounds.centavos(fromPesosText: amountText), amountC > 0 else {
            error = "Enter an amount."
            return
        }
        guard !fromAccountId.isEmpty else {
            error = "Pick where it comes from."
            return
        }
        onSave(amountC, fromAccountId, WarChestView.isoString(from: happenedOn))
    }
}

// MARK: - Raid sheet

private struct RaidSheet: View {
    let funds: [FundRecord]
    let destinations: [AccountRecord]
    let suggestedAmountC: Int?
    let accountLabel: (String) -> String
    let onCancel: () -> Void
    let onConfirm: (String, Int, String, String, String) -> Void

    @State private var selectedFundId = ""
    @State private var destinationId = ""
    @State private var amountText = ""
    @State private var note = "Cover bills"
    @State private var happenedOn = Date()
    @State private var error: String?

    private var candidates: [FundRecord] {
        Fund.raidCandidates(from: funds.map(\.engineFund)).compactMap { snap in
            funds.first { $0.id == snap.id }
        }
    }

    private var selected: FundRecord? {
        funds.first { $0.id == selectedFundId }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let error {
                    Text(error).foregroundStyle(Color.pantomina.terraDeep)
                }
                Section {
                    Picker("Fund", selection: $selectedFundId) {
                        ForEach(candidates, id: \.id) { fund in
                            Text("\(fund.name) · \(formatPeso(fund.balanceC))").tag(fund.id)
                        }
                    }
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                    Picker("Goes to", selection: $destinationId) {
                        ForEach(destinations, id: \.id) { acct in
                            Text(accountLabel(acct.id)).tag(acct.id)
                        }
                    }
                    DatePicker(
                        "When it happened",
                        selection: $happenedOn,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    if selected?.purpose == .emergency {
                        Text("Careful — this is the emergency fund.")
                            .font(PantominaFont.caption)
                            .foregroundStyle(Color.pantomina.terraDeep)
                    }
                } header: {
                    Text("Borrow to cover bills")
                } footer: {
                    Text("Dates the Fund Move and the IOU. Household owes this fund — payer absorbs.")
                        .font(PantominaFont.caption)
                }
                Section {
                    TextField("What for", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                } footer: {
                    Text("Usually settling bills — say so if it’s something else.")
                        .font(PantominaFont.caption)
                }
            }
            .navigationTitle("Borrow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Borrow") { submit() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                if selectedFundId.isEmpty {
                    selectedFundId = candidates.first?.id ?? ""
                }
                if destinationId.isEmpty {
                    let home = selected?.homeAccountId
                    destinationId = destinations.first { $0.id != home }?.id
                        ?? destinations.first?.id
                        ?? ""
                }
                if amountText.isEmpty, let suggestedAmountC, suggestedAmountC > 0 {
                    amountText = String(format: "%.2f", Double(suggestedAmountC) / 100)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func submit() {
        error = nil
        guard let fund = selected else {
            error = "Pick a fund."
            return
        }
        guard let amountC = InputBounds.centavos(fromPesosText: amountText), amountC > 0 else {
            error = "Enter an amount."
            return
        }
        guard amountC <= fund.balanceC else {
            error = "More than the fund holds."
            return
        }
        guard !destinationId.isEmpty else {
            error = "Pick where the money goes."
            return
        }
        onConfirm(
            fund.id,
            amountC,
            destinationId,
            note,
            WarChestView.isoString(from: happenedOn)
        )
    }
}
