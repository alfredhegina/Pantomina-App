import SwiftUI
import SwiftData

struct WarChestView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var funds: [FundRecord]
    @Query private var loans: [LoanRecord]
    @Query private var accounts: [AccountRecord]
    @Query private var categories: [CategoryRecord]
    @Query private var people: [PersonRecord]

    @State private var showRaid = false
    @State private var showSweep = false
    @State private var showAddFund = false
    @State private var topUpFundId: String?
    @State private var repayFundId: String?
    @State private var editLoanId: String?
    @State private var parkLoanId: String?
    @State private var repayAmountText = ""
    @State private var toast: String?

    var suggestedRaidAmountC: Int? = nil
    var suggestedSurplusC: Int? = nil
    var onRaidComplete: (() -> Void)? = nil
    var onSweepComplete: (() -> Void)? = nil

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

    private var loanPayoffFund: FundRecord? {
        funds.first { $0.purposeRaw == Fund.Purpose.loanPayoff.rawValue }
    }

    private var snowballQueue: [Loan.Snapshot] {
        Snowball.orderedQueue(loans: loans.map(\.engineLoan))
    }

    private var totalOwedC: Int {
        funds.reduce(0) { $0 + $1.iousC }
    }

    private var accountById: [String: AccountRecord] {
        Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
    }

    private var readyToPay: Bool {
        guard let payoff = loanPayoffFund else { return false }
        return Snowball.isReadyToPay(loanPayoffBalanceC: payoff.balanceC, loans: loans.map(\.engineLoan))
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

            Section {
                if snowballQueue.isEmpty {
                    Text("No active loans in the current batch. Baggage holds the register.")
                        .font(PantominaFont.body)
                        .foregroundStyle(Color.pantomina.muted)
                } else {
                    if readyToPay, let top = snowballQueue.first {
                        Text("Loan payoff covers the next payment · \(top.description)")
                            .font(PantominaFont.caption.weight(.medium))
                            .foregroundStyle(Color.pantomina.sageDeep)
                        Text("When it’s due: Bills → Checklist → Count it.")
                            .font(PantominaFont.caption)
                            .foregroundStyle(Color.pantomina.muted)
                    }
                    ForEach(snowballQueue, id: \.id) { snap in
                        snowballRow(snap)
                    }
                }
                Button {
                    showSweep = true
                } label: {
                    Text("Sweep leftover")
                        .font(PantominaFont.body.weight(.medium))
                        .foregroundStyle(Color.pantomina.sageDeep)
                }
                .accessibilityLabel("Sweep leftover toward IOUs then loan payoff")
            } header: {
                Text("Snowball")
            } footer: {
                Text("Order is yours — not auto smallest-first. Sweep leftover pays the chest back before parking more.")
                    .font(PantominaFont.caption)
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
                    Text("Funds · snowball")
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
            if suggestedSurplusC != nil {
                showSweep = true
            }
        }
        .task {
            try? SeedCatalog.seedDemoFundsIfNeeded(into: modelContext)
            try? SeedCatalog.seedDemoLoansIfNeeded(into: modelContext)
            try? modelContext.save()
        }
        .sheet(isPresented: $showAddFund) {
            AddFundSheet(
                fernAccounts: fernAssetPockets,
                fernName: fernName,
                starkName: starkName,
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
        .sheet(isPresented: $showSweep) {
            SweepSheet(
                suggestedAmountC: suggestedSurplusC,
                fernAccounts: fernAssetPockets,
                fernName: fernName,
                starkName: starkName,
                funds: funds.map(\.engineFund),
                loanPayoffFundId: loanPayoffFund?.id,
                defaultFromAccountId: loanPayoffFund?.homeAccountId,
                onCancel: { showSweep = false },
                onConfirm: { amountC, fromId, dateISO in
                    commitSweep(surplusC: amountC, fromAccountId: fromId, dateISO: dateISO)
                    showSweep = false
                    onSweepComplete?()
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
                    fernAccounts: fernAssetPockets,
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
        .sheet(isPresented: Binding(
            get: { editLoanId != nil },
            set: { if !$0 { editLoanId = nil } }
        )) {
            if let id = editLoanId, let loan = loans.first(where: { $0.id == id }) {
                EditSnowballSheet(
                    loan: loan,
                    onCancel: { editLoanId = nil },
                    onSave: { order, batch, strategy in
                        loan.applySnowball(order: order, batch: batch, strategy: strategy)
                        try? modelContext.save()
                        editLoanId = nil
                        flashToast("Payoff order updated")
                    }
                )
            }
        }
        .sheet(isPresented: Binding(
            get: { parkLoanId != nil },
            set: { if !$0 { parkLoanId = nil } }
        )) {
            if let id = parkLoanId,
               let loan = loans.first(where: { $0.id == id }),
               let payoff = loanPayoffFund,
               let amountC = Snowball.parkAnotherMonthAmountC(loan: loan.engineLoan) {
                ParkMonthSheet(
                    loanName: loan.loanDescription,
                    amountC: amountC,
                    homeAccountId: payoff.homeAccountId,
                    fundName: payoff.name,
                    fernAccounts: fernAssetPockets,
                    fernName: fernName,
                    starkName: starkName,
                    onCancel: { parkLoanId = nil },
                    onConfirm: { fromId, dateISO in
                        commitParkAnotherMonth(
                            amountC: amountC,
                            payoff: payoff,
                            fromAccountId: fromId,
                            loanName: loan.loanDescription,
                            dateISO: dateISO
                        )
                        parkLoanId = nil
                    }
                )
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

    private func snowballRow(_ snap: Loan.Snapshot) -> some View {
        let record = loans.first { $0.id == snap.id }
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(snap.description)
                    .font(PantominaFont.body.weight(.semibold))
                Spacer()
                Text(formatPeso(Loan.derivedBalanceC(
                    totalLoanC: snap.totalLoanC,
                    paidMonths: snap.paidMonths,
                    monthlyC: snap.monthlyC
                )))
                .font(PantominaFont.amount)
                .monospacedDigit()
            }
            Text(snowballMetaLabel(snap))
                .font(PantominaFont.caption)
                .foregroundStyle(Color.pantomina.muted)
            HStack(spacing: Spacing.md) {
                Button("Edit queue") { editLoanId = snap.id }
                    .font(PantominaFont.caption.weight(.medium))
                    .foregroundStyle(Color.pantomina.sageDeep)
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Edit payoff order")
                if let parkC = Snowball.parkAnotherMonthAmountC(loan: snap),
                   loanPayoffFund != nil {
                    Button("Park another month") { parkLoanId = snap.id }
                        .font(PantominaFont.caption.weight(.medium))
                        .foregroundStyle(Color.pantomina.sageDeep)
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Park another month \(formatPeso(parkC))")
                }
            }
            if record == nil {
                EmptyView()
            }
        }
        .padding(.vertical, 4)
    }

    private func snowballMetaLabel(_ snap: Loan.Snapshot) -> String {
        let order = snap.snowballOrder.map(String.init) ?? "—"
        let batch = snap.snowballBatch.map(String.init) ?? "1"
        return "Pay next · #\(order) · Batch \(batch) · \(Self.strategyPlainLabel(snap.strategy)) · \(formatPeso(snap.monthlyC))/mo"
    }

    private static func strategyPlainLabel(_ strategy: Loan.Strategy?) -> String {
        switch strategy {
        case .parkToMaturity: return "Park to maturity"
        case .prepay, .none: return "Prepay"
        }
    }

    private func fundCard(_ record: FundRecord) -> some View {
        let snap = record.engineFund
        let owed = Fund.owedBackC(snap)
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
                fundTargetBar(balanceC: snap.balanceC, owedC: owed, targetC: target)
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

    private func fundTargetBar(balanceC: Int, owedC: Int, targetC: Int) -> some View {
        let total = Double(max(targetC, 1))
        let cash = Double(min(max(balanceC, 0), targetC)) / total
        let owedFrac = Double(min(max(owedC, 0), targetC)) / total
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.pantomina.ink.opacity(0.08))
                Capsule()
                    .fill(Color.pantomina.sage.opacity(0.85))
                    .frame(width: max(4, geo.size.width * cash))
                if owedC > 0 {
                    Capsule()
                        .fill(Color.pantomina.terraDeep.opacity(0.55))
                        .frame(width: max(3, geo.size.width * min(owedFrac, 1)))
                        .offset(x: max(0, geo.size.width * cash - geo.size.width * min(owedFrac, cash)))
                }
            }
        }
        .frame(height: 8)
        .accessibilityLabel("Target progress with owed sliver")
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
        guard let catId = fundMoveCategoryId() else {
            flashToast("Couldn't post — Fund Move category missing.")
            return
        }
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
                note: "\(name) \(Fund.openingNoteMarker)",
                dateISO: dateISO
            )
        }
        try? modelContext.save()
        flashToast("Added \(name)")
    }

    private func commitTopUp(fund: FundRecord, amountC: Int, fromAccountId: String, dateISO: String) {
        guard let catId = fundMoveCategoryId(),
              let updated = Fund.topUp(to: fund.engineFund, amountC: amountC)
        else {
            flashToast("Couldn't top up — try again.")
            return
        }
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
        else {
            flashToast("Couldn't borrow — try again.")
            return
        }

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
        else {
            flashToast("Couldn't repay — try again.")
            return
        }
        record.apply(updated)
        try? modelContext.save()
        repayFundId = nil
        flashToast("Repaid \(formatPeso(amountC))")
    }

    private func commitSweep(surplusC: Int, fromAccountId: String, dateISO: String) {
        guard let catId = fundMoveCategoryId(),
              let plan = Snowball.proposeSweep(
                surplusC: surplusC,
                funds: funds.map(\.engineFund),
                loanPayoffFundId: loanPayoffFund?.id
              )
        else {
            flashToast("Couldn't sweep — check amount and loan-payoff fund.")
            return
        }

        for repay in plan.iouRepays {
            guard let fund = funds.first(where: { $0.id == repay.fundId }),
                  let updated = Fund.repayOldest(in: fund.engineFund, amountC: repay.amountC, restoreBalance: true)
            else {
                flashToast("Couldn't repay an IOU — try again.")
                return
            }
            fund.apply(updated)
            insertFundMove(
                accountId: fromAccountId,
                amountC: repay.amountC,
                categoryId: catId,
                linkedId: fund.id,
                note: "Sweep · repay \(fund.name)",
                dateISO: dateISO
            )
            if fromAccountId != fund.homeAccountId {
                insertFundMove(
                    accountId: fund.homeAccountId,
                    amountC: repay.amountC,
                    categoryId: catId,
                    linkedId: fund.id,
                    note: "Sweep · into \(fund.name)",
                    dateISO: dateISO
                )
            }
        }

        if plan.parkToLoanPayoffC > 0,
           let payoffId = plan.loanPayoffFundId,
           let payoff = funds.first(where: { $0.id == payoffId }),
           let updated = Fund.topUp(to: payoff.engineFund, amountC: plan.parkToLoanPayoffC) {
            payoff.apply(updated)
            if fromAccountId != payoff.homeAccountId {
                insertFundMove(
                    accountId: fromAccountId,
                    amountC: plan.parkToLoanPayoffC,
                    categoryId: catId,
                    linkedId: payoff.id,
                    note: "Sweep · park loan payoff",
                    dateISO: dateISO
                )
            }
            insertFundMove(
                accountId: payoff.homeAccountId,
                amountC: plan.parkToLoanPayoffC,
                categoryId: catId,
                linkedId: payoff.id,
                note: "Sweep · into \(payoff.name)",
                dateISO: dateISO
            )
        }

        try? modelContext.save()
        flashToast("Swept \(formatPeso(plan.totalAllocatedC))")
    }

    private func commitParkAnotherMonth(
        amountC: Int,
        payoff: FundRecord,
        fromAccountId: String,
        loanName: String,
        dateISO: String
    ) {
        guard let catId = fundMoveCategoryId(),
              let updated = Fund.topUp(to: payoff.engineFund, amountC: amountC)
        else {
            flashToast("Couldn't park — try again.")
            return
        }
        payoff.apply(updated)
        if fromAccountId != payoff.homeAccountId {
            insertFundMove(
                accountId: fromAccountId,
                amountC: amountC,
                categoryId: catId,
                linkedId: payoff.id,
                note: "Park another month · \(loanName)",
                dateISO: dateISO
            )
        }
        insertFundMove(
            accountId: payoff.homeAccountId,
            amountC: amountC,
            categoryId: catId,
            linkedId: payoff.id,
            note: "Park into \(payoff.name) · \(loanName)",
            dateISO: dateISO
        )
        try? modelContext.save()
        flashToast("Parked \(formatPeso(amountC))")
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
    let starkName: String
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
                            Text(acct.displayLabel(fernName: fernName, starkName: starkName)).tag(acct.id)
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

// MARK: - Sweep leftover

private struct SweepSheet: View {
    let suggestedAmountC: Int?
    let fernAccounts: [AccountRecord]
    let fernName: String
    let starkName: String
    let funds: [Fund.Snapshot]
    let loanPayoffFundId: String?
    var defaultFromAccountId: String? = nil
    let onCancel: () -> Void
    let onConfirm: (Int, String, String) -> Void

    @State private var amountText = ""
    @State private var fromAccountId = ""
    @State private var happenedOn = Date()
    @State private var error: String?

    private var preview: Snowball.SweepPlan? {
        guard let amountC = InputBounds.centavos(fromPesosText: amountText), amountC > 0 else { return nil }
        return Snowball.proposeSweep(
            surplusC: amountC,
            funds: funds,
            loanPayoffFundId: loanPayoffFundId
        )
    }

    var body: some View {
        NavigationStack {
            Form {
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
                    if let preview {
                        ForEach(preview.iouRepays, id: \.fundId) { repay in
                            let name = funds.first { $0.id == repay.fundId }?.name ?? "Fund"
                            Text("Repay \(name) \(formatPeso(repay.amountC))")
                                .font(PantominaFont.caption)
                                .foregroundStyle(Color.pantomina.terraDeep)
                        }
                        if preview.parkToLoanPayoffC > 0 {
                            Text("Park loan payoff \(formatPeso(preview.parkToLoanPayoffC))")
                                .font(PantominaFont.caption)
                                .foregroundStyle(Color.pantomina.sageDeep)
                        }
                    }
                    if let error {
                        Text(error)
                            .font(PantominaFont.caption)
                            .foregroundStyle(Color.pantomina.terraDeep)
                    }
                } header: {
                    Text("Sweep leftover")
                } footer: {
                    Text("Pay back the chest first, then park the rest. Nothing moves until you confirm.")
                        .font(PantominaFont.caption)
                }
            }
            .navigationTitle("Sweep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") { save() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                if fromAccountId.isEmpty {
                    if let preferred = defaultFromAccountId,
                       fernAccounts.contains(where: { $0.id == preferred }) {
                        fromAccountId = preferred
                    } else {
                        fromAccountId = fernAccounts.first?.id ?? ""
                    }
                }
                if amountText.isEmpty, let suggested = suggestedAmountC, suggested > 0 {
                    amountText = String(format: "%.2f", Double(suggested) / 100)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func save() {
        guard let amountC = InputBounds.centavos(fromPesosText: amountText), amountC > 0 else {
            error = "Enter an amount."
            return
        }
        guard !fromAccountId.isEmpty else {
            error = "Pick an account."
            return
        }
        guard preview != nil else {
            error = "Need a loan-payoff fund for any leftover after IOUs."
            return
        }
        onConfirm(amountC, fromAccountId, WarChestView.isoString(from: happenedOn))
    }
}

// MARK: - Park another month

private struct ParkMonthSheet: View {
    let loanName: String
    let amountC: Int
    let homeAccountId: String
    let fundName: String
    let fernAccounts: [AccountRecord]
    let fernName: String
    let starkName: String
    let onCancel: () -> Void
    let onConfirm: (String, String) -> Void

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
                    LabeledContent("Amount") {
                        Text(formatPeso(amountC))
                            .font(PantominaFont.body.monospacedDigit())
                    }
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
                    Text(loanName)
                } footer: {
                    Text("Into \(fundName). Same pocket as home → one Fund Move; different pocket → two legs. Nothing moves until you confirm.")
                        .font(PantominaFont.caption)
                }
            }
            .navigationTitle("Park another month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") { submit() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                if fromAccountId.isEmpty {
                    if fernAccounts.contains(where: { $0.id == homeAccountId }) {
                        fromAccountId = homeAccountId
                    } else {
                        fromAccountId = fernAccounts.first?.id ?? ""
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func submit() {
        error = nil
        guard !fromAccountId.isEmpty else {
            error = "Pick where it comes from."
            return
        }
        onConfirm(fromAccountId, WarChestView.isoString(from: happenedOn))
    }
}

// MARK: - Edit snowball queue row

private struct EditSnowballSheet: View {
    let loan: LoanRecord
    let onCancel: () -> Void
    let onSave: (Int?, Int?, Loan.Strategy?) -> Void

    @State private var orderText = ""
    @State private var batchText = ""
    @State private var strategy: Loan.Strategy = .prepay

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(loan.loanDescription)
                        .foregroundStyle(Color.pantomina.muted)
                }

                Section {
                    TextField("Number", text: $orderText)
                        .keyboardType(.numberPad)
                } header: {
                    Text("Pay next (order)")
                } footer: {
                    Text("1 = first in this batch. Custom — not smallest balance first.")
                        .font(PantominaFont.caption)
                }

                Section {
                    TextField("Number", text: $batchText)
                        .keyboardType(.numberPad)
                } header: {
                    Text("Batch")
                } footer: {
                    Text("Finish every loan in batch 1 before batch 2 starts.")
                        .font(PantominaFont.caption)
                }

                Section {
                    Picker("Strategy", selection: $strategy) {
                        Text("Prepay").tag(Loan.Strategy.prepay)
                        Text("Park to maturity").tag(Loan.Strategy.parkToMaturity)
                    }
                } footer: {
                    Text(strategyFooter)
                        .font(PantominaFont.caption)
                }
            }
            .navigationTitle("Edit payoff order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let order = Int(orderText.trimmingCharacters(in: .whitespaces))
                        let batch = Int(batchText.trimmingCharacters(in: .whitespaces))
                        onSave(order, batch, strategy)
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                orderText = loan.snowballOrder.map(String.init) ?? ""
                batchText = loan.snowballBatch.map(String.init) ?? "1"
                strategy = loan.engineLoan.strategy ?? .prepay
            }
        }
        .presentationDetents([.large])
    }

    private var strategyFooter: String {
        switch strategy {
        case .parkToMaturity:
            return "Park to maturity — schedule only; no extra park into Loan payoff."
        case .prepay:
            return "Prepay — OK to park another month into Loan payoff."
        }
    }
}
