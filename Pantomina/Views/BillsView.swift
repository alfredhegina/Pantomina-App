import SwiftUI
import SwiftData

struct BillsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var transactions: [TransactionRecord]
    @Query private var accounts: [AccountRecord]
    @Query private var categories: [CategoryRecord]
    @Query private var people: [PersonRecord]
    @Query private var recurringRules: [RecurringRuleRecord]
    @Query private var fundingPlans: [FundingPlanRecord]
    @Query private var loans: [LoanRecord]

    @State private var pane = 0
    @State private var selectedAnchor: String?
    @State private var showLogContribution = false
    @State private var contributionText = ""
    @State private var contributionError: String?
    @State private var toast: String?
    @State private var countIt: CountItDraft?
    @State private var showCountAccountPicker = false
    @State private var countItError: String?
    @State private var statementRoute: String?
    @State private var showForecastRaid = false
    @State private var showForecastSweep = false
    @AppStorage("checklistDoneIds") private var checklistDoneRaw = ""

    private var checklistDoneIds: Set<String> {
        Set(checklistDoneRaw.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }
    private var accountById: [String: AccountRecord] {
        Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
    }

    private var ledgerRows: [Settlement.LedgerRow] {
        transactions.map { tx in
            let account = accountById[tx.accountId]
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
    }

    private var history: [Settlement.CycleSnapshot] {
        Settlement.history(rows: ledgerRows)
    }

    private var anchors: [String] {
        var set = Set(Settlement.cycleAnchors(in: ledgerRows))
        let today = Self.todayISO()
        let current = Cycle.cycleFor(isoDate: today)
        set.insert(current.anchorISO)
        set.insert(Cycle.nextHalfMonth(after: current).anchorISO)
        for plan in fundingEnginePlans {
            for tranche in plan.tranches {
                set.insert(tranche.cycleISO)
            }
            set.insert(plan.payoutCycleISO)
        }
        return set.sorted()
    }

    private var activeAnchor: String {
        selectedAnchor ?? anchors.last ?? Cycle.cycleFor(isoDate: Self.todayISO()).anchorISO
    }

    private var currentSnapshot: Settlement.CycleSnapshot? {
        history.first { $0.anchorISO == activeAnchor }
            ?? Settlement.CycleSnapshot(
                anchorISO: activeAnchor,
                result: Settlement.compute(
                    cycleAnchorISO: activeAnchor,
                    rows: ledgerRows,
                    carriedCreditC: carriedCredit(before: activeAnchor),
                    tabBeforeC: tabBefore(before: activeAnchor)
                )
            )
    }

    private var cycleShares: Settlement.HouseholdShares {
        Settlement.householdShares(cycleAnchorISO: activeAnchor, rows: ledgerRows)
    }

    private var projectionRules: [Projection.Rule] {
        recurringRules.map(\.engineRule)
    }

    private var fundingEnginePlans: [Funding.Plan] {
        fundingPlans.map(\.enginePlan)
    }

    private var forecastResult: Forecast.Result {
        let excluded = Funding.excludedBillRuleIds(plans: fundingEnginePlans)
        let projected = Projection.rows(forCycleISO: activeAnchor, rules: projectionRules)
            .filter { !excluded.contains($0.recurringRuleId) }
        let income = transactions.compactMap { tx -> Forecast.IncomeRow? in
            guard tx.realizedStatus == .realized,
                  let cat = categories.first(where: { $0.id == tx.categoryId }),
                  cat.flow == .income,
                  tx.realizedDate.map({ Cycle.cycleFor(isoDate: $0).anchorISO }) == activeAnchor
            else { return nil }
            return Forecast.IncomeRow(id: tx.id, title: cat.displayName, amountC: tx.amountC)
        }
        let pendingCards = transactions.compactMap { tx -> Forecast.PendingCard? in
            guard tx.realizedStatus == .pending,
                  tx.proposedRealizedDate == activeAnchor,
                  let cat = categories.first(where: { $0.id == tx.categoryId })
            else { return nil }
            return Forecast.PendingCard(id: tx.id, title: cat.displayName, amountC: tx.amountC)
        }
        let trancheLines = Funding.forecastLines(cycleISO: activeAnchor, plans: fundingEnginePlans)
        return Forecast.build(
            cycleISO: activeAnchor,
            incomeRows: income,
            projected: projected,
            pendingCards: pendingCards,
            trancheLines: trancheLines,
            typicalVariableC: 8_000_00
        )
    }

    private var checklistTasks: [Checklist.Task] {
        let statementPending = Set(
            transactions.compactMap { tx -> String? in
                guard tx.realizedStatus == .pending else { return nil }
                let account = accountById[tx.accountId]
                guard account?.settlement == .statement else { return nil }
                return tx.accountId
            }
        )
        let excluded = Funding.excludedBillRuleIds(plans: fundingEnginePlans)
        let rules = projectionRules.filter { !excluded.contains($0.id) }
        let trancheTasks = Funding.checklistTranches(cycleISO: activeAnchor, plans: fundingEnginePlans)
            .map {
                Checklist.TrancheTask(
                    id: $0.id,
                    title: $0.title,
                    sourceAccountId: $0.sourceAccountId,
                    amountC: $0.amountC,
                    linkedId: $0.linkedId,
                    paymentsRequired: $0.paymentsRequired,
                    paymentsDone: $0.paymentsDone,
                    done: $0.done
                )
            }
        return Checklist.tasks(
            cycleISO: activeAnchor,
            todayISO: Self.todayISO(),
            rules: rules,
            statementAccountsWithPending: Array(statementPending).sorted(),
            trancheTasks: trancheTasks,
            loanSnapshots: loans.map(\.engineLoan),
            doneIds: checklistDoneIds
        )
    }

    var body: some View {
        let snap = currentSnapshot
        let fern = people.first { $0.id == .fern }?.name ?? "Fern"
        let stark = people.first { $0.id == .stark }?.name ?? "Stark"
        let forecast = forecastResult
        let tasks = checklistTasks
        let summary = Checklist.summary(tasks: tasks)
        NavigationStack {
            VStack(spacing: 0) {
                Seg(
                    options: ["Split", "Forecast", "Checklist", "Love Tab"],
                    selection: $pane
                )
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)

                switch pane {
                case 1:
                    BillsForecastPane(
                        cycleISO: activeAnchor,
                        forecast: forecast,
                        onPickCycle: { AnyView(cycleMenu) },
                        onCoverShortfall: {
                            showForecastRaid = true
                        },
                        onParkLeftover: {
                            showForecastSweep = true
                        }
                    )
                case 2:
                    BillsChecklistPane(
                        cycleISO: activeAnchor,
                        tasks: tasks,
                        summary: summary,
                        accountLabels: Dictionary(uniqueKeysWithValues: accounts.map {
                            ($0.id, $0.displayLabel(fernName: fern, starkName: stark))
                        }),
                        pendingTaskId: countIt?.task.id,
                        onPickCycle: { AnyView(cycleMenu) },
                        onToggle: handleChecklistToggle,
                        onOpenStatement: { statementRoute = $0 }
                    )
                case 3:
                    loveTabPane(fernName: fern, starkName: stark)
                default:
                    splitPane(snap: snap, fernName: fern, starkName: stark)
                }
            }
            .background(Color.pantomina.ground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        PetTitle("Whose Turn Is It")
                        Text("Bills due · \(DisplayLabels.displayDate(iso: activeAnchor))")
                            .font(PantominaFont.caption)
                            .foregroundStyle(Color.pantomina.muted)
                    }
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { statementRoute != nil },
                set: { if !$0 { statementRoute = nil } }
            )) {
                StatementDayView()
            }
            .sheet(item: $countIt) { item in
                countItSheet(
                    draft: Binding(
                        get: { countIt ?? item },
                        set: { countIt = $0 }
                    ),
                    fernName: fern,
                    starkName: stark
                )
            }
            .sheet(isPresented: $showLogContribution) {
                contributionSheet(starkName: stark)
            }
            .sheet(isPresented: $showForecastRaid) {
                NavigationStack {
                    WarChestView(
                        suggestedRaidAmountC: forecast.verdict == .over
                            ? abs(forecast.breathingRoomC)
                            : nil,
                        onRaidComplete: { showForecastRaid = false }
                    )
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showForecastRaid = false }
                        }
                    }
                }
            }
            .sheet(isPresented: $showForecastSweep) {
                NavigationStack {
                    WarChestView(
                        suggestedSurplusC: forecast.verdict == .breathingRoom
                            ? forecast.breathingRoomC
                            : nil,
                        onSweepComplete: { showForecastSweep = false }
                    )
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showForecastSweep = false }
                        }
                    }
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
            .onAppear {
                if selectedAnchor == nil {
                    selectedAnchor = anchors.last
                }
                try? SeedCatalog.seedDemoRulesIfNeeded(into: modelContext)
                try? SeedCatalog.seedDemoFundingIfNeeded(into: modelContext)
                try? SeedCatalog.seedDemoLoansIfNeeded(into: modelContext)
                try? modelContext.save()
            }
        }
    }

    private var cycleMenu: some View {
        Group {
            if !anchors.isEmpty {
                Picker("Cycle", selection: Binding(
                    get: { activeAnchor },
                    set: { selectedAnchor = $0 }
                )) {
                    ForEach(anchors.reversed(), id: \.self) { anchor in
                        Text(DisplayLabels.displayDate(iso: anchor)).tag(anchor)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Cycle")
            }
        }
    }

    private func handleChecklistToggle(_ task: Checklist.Task) {
        guard !task.done else { return }
        if task.kind == .ccStatement {
            statementRoute = task.sourceAccountId
            return
        }
        openCountIt(for: task)
    }

    private func openCountIt(for task: Checklist.Task) {
        countItError = nil
        if task.kind == .loanPayment {
            guard let loanId = task.linkedId,
                  let loan = loans.first(where: { $0.id == loanId })
            else { return }
            let accountId = "" // User picks Paid from; do not preselect loan.paymentAccountId
            countIt = CountItDraft(
                task: task,
                amountText: String(format: "%.2f", Double(task.amountC) / 100),
                selectedAccountId: accountId,
                paidBy: .fern,
                splitMode: 0,
                fundingPlanId: nil,
                ruleId: nil,
                loanId: loanId,
                billTitle: loan.loanDescription,
                amountEditable: false
            )
            return
        }
        if task.kind == .fundTranche {
            guard let planId = task.linkedId,
                  let record = fundingPlans.first(where: { $0.id == planId })
            else { return }
            let plan = record.enginePlan
            guard let tranche = plan.tranches.first(where: { $0.cycleISO == activeAnchor }),
                  !tranche.reserved,
                  let rule = recurringRules.first(where: { $0.id == plan.billRecurringRuleId })
            else { return }
            let accountId = resolvedAccountId(preferred: task.sourceAccountId, ruleAccountId: rule.accountId)
            let paidBy = PersonId(rawValue: rule.paidByRaw) ?? .fern
            let account = accountById[accountId]
            let splitMode = (account?.scope == .household && rule.allocStarkC > 0 && rule.allocFernC > 0) ? 1 : 0
            countIt = CountItDraft(
                task: task,
                amountText: String(format: "%.2f", Double(tranche.amountC) / 100),
                selectedAccountId: accountId,
                paidBy: paidBy,
                splitMode: splitMode,
                fundingPlanId: planId,
                ruleId: rule.id,
                loanId: nil,
                billTitle: plan.billTitle,
                amountEditable: false
            )
            return
        }
        guard let ruleId = task.linkedId,
              let rule = recurringRules.first(where: { $0.id == ruleId })
        else { return }
        let accountId = resolvedAccountId(preferred: task.sourceAccountId, ruleAccountId: rule.accountId)
        let paidBy = PersonId(rawValue: rule.paidByRaw) ?? .fern
        let account = accountById[accountId]
        let splitMode = (account?.scope == .household && rule.allocStarkC > 0 && rule.allocFernC > 0) ? 1 : 0
        countIt = CountItDraft(
            task: task,
            amountText: String(format: "%.2f", Double(task.amountC) / 100),
            selectedAccountId: accountId,
            paidBy: paidBy,
            splitMode: splitMode,
            fundingPlanId: nil,
            ruleId: rule.id,
            loanId: nil,
            billTitle: rule.title,
            amountEditable: task.amountBehavior == .estimate
        )
    }

    /// Prefer the Checklist task’s source account, then the rule default, if still in CoA.
    private func resolvedAccountId(preferred: String, ruleAccountId: String) -> String {
        if accountById[preferred] != nil { return preferred }
        if accountById[ruleAccountId] != nil { return ruleAccountId }
        return preferred.isEmpty ? ruleAccountId : preferred
    }

    private func countItSheet(
        draft: Binding<CountItDraft>,
        fernName: String,
        starkName: String
    ) -> some View {
        NavigationStack {
            Form {
                Section {
                    if draft.wrappedValue.amountEditable {
                        TextField("Amount", text: Binding(
                            get: { draft.wrappedValue.amountText },
                            set: { newValue in
                                var next = draft.wrappedValue
                                next.amountText = newValue
                                draft.wrappedValue = next
                            }
                        ))
                        .keyboardType(.decimalPad)
                    } else if let cents = InputBounds.centavos(fromPesosText: draft.wrappedValue.amountText) {
                        Text(formatPeso(cents))
                            .font(PantominaFont.body.monospacedDigit())
                    }
                } header: {
                    Text(draft.wrappedValue.billTitle)
                }
                Section {
                    Button {
                        showCountAccountPicker = true
                    } label: {
                        HStack {
                            Text("Paid from")
                                .foregroundStyle(Color.pantomina.ink)
                            Spacer()
                            Text(paidFromLabel(
                                for: draft.wrappedValue.selectedAccountId,
                                fernName: fernName,
                                starkName: starkName
                            ))
                            .foregroundStyle(Color.pantomina.muted)
                            Text("Change")
                                .font(PantominaFont.caption)
                                .foregroundStyle(Color.pantomina.sage)
                        }
                    }
                    if isHouseholdAccount(draft.wrappedValue.selectedAccountId) {
                        Picker("Split", selection: Binding(
                            get: { draft.wrappedValue.splitMode },
                            set: { newValue in
                                var next = draft.wrappedValue
                                next.splitMode = newValue
                                draft.wrappedValue = next
                            }
                        )) {
                            Text("Just mine").tag(0)
                            Text("50·50").tag(1)
                        }
                        .pickerStyle(.segmented)
                        Picker("Paid by", selection: Binding(
                            get: { draft.wrappedValue.paidBy },
                            set: { newValue in
                                var next = draft.wrappedValue
                                next.paidBy = newValue
                                draft.wrappedValue = next
                            }
                        )) {
                            Text(fernName).tag(PersonId.fern)
                            Text(starkName).tag(PersonId.stark)
                        }
                        .pickerStyle(.segmented)
                    }
                } footer: {
                    Text("Counts on \(DisplayLabels.displayDate(iso: activeAnchor)). Change account only if this payday differs.")
                }
                if let countItError {
                    Text(countItError)
                        .foregroundStyle(Color.pantomina.terraDeep)
                }
            }
            .navigationTitle("Count it")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        countIt = nil
                        countItError = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Count") { submitCountIt() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showCountAccountPicker) {
                SearchablePickList(
                    title: "Change account",
                    items: accounts.filter { !$0.archived }.map {
                        SearchablePickItem(
                            id: $0.id,
                            title: $0.displayLabel(fernName: fernName, starkName: starkName),
                            subtitle: DisplayLabels.accountKindHint(
                                settlement: $0.settlement,
                                scope: $0.scope,
                                fernName: fernName,
                                starkName: starkName
                            )
                        )
                    },
                    selection: Binding(
                        get: {
                            let id = draft.wrappedValue.selectedAccountId
                            return id.isEmpty ? nil : id
                        },
                        set: { newId in
                            guard let newId else { return }
                            var next = draft.wrappedValue
                            next.selectedAccountId = newId
                            if let account = accountById[newId] {
                                switch account.scope {
                                case .fern:
                                    next.paidBy = .fern
                                    next.splitMode = 0
                                case .stark:
                                    next.paidBy = .stark
                                    next.splitMode = 0
                                case .household, .business:
                                    next.splitMode = 1
                                }
                            }
                            draft.wrappedValue = next
                        }
                    )
                )
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func paidFromLabel(for accountId: String, fernName: String, starkName: String) -> String {
        guard let account = accountById[accountId] else { return "Choose" }
        return account.displayLabel(fernName: fernName, starkName: starkName)
    }

    private func isHouseholdAccount(_ id: String) -> Bool {
        accountById[id]?.scope == .household
    }

    private func submitCountIt() {
        guard let draft = countIt else { return }
        countItError = nil
        guard let amountC = InputBounds.centavos(fromPesosText: draft.amountText), amountC > 0 else {
            countItError = "Enter an amount."
            return
        }
        guard accountById[draft.selectedAccountId] != nil else {
            countItError = "Choose where you paid from."
            return
        }

        if let loanId = draft.loanId {
            guard let loan = loans.first(where: { $0.id == loanId }) else {
                countItError = "Couldn't find that loan."
                return
            }
            guard let loanCat = categories.first(where: { $0.system && $0.item == "Loan Payment" }) else {
                countItError = "Loan Payment category missing."
                return
            }
            let intended = AllocationDefaults.justMine(amountC: amountC, paidBy: draft.paidBy)
            let account = accountById[draft.selectedAccountId]
            let routed = AllocationRouting.record(
                intended: intended,
                accountScope: account?.scope ?? .fern,
                paidBy: draft.paidBy
            )
            let decision = Realization.decide(
                purchaseISO: activeAnchor,
                settlement: account?.settlement ?? .instant,
                statementCutoff: account?.statementCutoff
            )
            let tx = TransactionRecord(
                purchaseDate: activeAnchor,
                realizedDate: decision.realizedDate,
                realizedStatus: decision.status,
                proposedRealizedDate: decision.proposedRealizedDate,
                amountC: amountC,
                accountId: draft.selectedAccountId,
                categoryId: loanCat.id,
                paidBy: draft.paidBy,
                allocation: routed,
                settlementRole: .loanPayment,
                linkedId: loanId,
                note: draft.billTitle
            )
            modelContext.insert(tx)
            loan.applyPayment()
            try? modelContext.save()
            markChecklistDone(draft.task.id)
            let months = "\(loan.paidMonths)/\(loan.termMonths)"
            countIt = nil
            Task { @MainActor in
                PantominaMotion.run(reduceMotion) {
                    toast = "Counted · \(months) · \(formatPeso(loan.derivedBalanceC)) left"
                }
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                PantominaMotion.run(reduceMotion) { toast = nil }
            }
            return
        }

        guard let ruleId = draft.ruleId,
              let rule = recurringRules.first(where: { $0.id == ruleId })
        else {
            countItError = "Couldn't find that bill."
            return
        }
        let intended: Allocation
        if draft.splitMode == 1 {
            intended = AllocationDefaults.fiftyFifty(amountC: amountC)
        } else {
            intended = AllocationDefaults.justMine(amountC: amountC, paidBy: draft.paidBy)
        }
        let account = accountById[draft.selectedAccountId]
        let routed = AllocationRouting.record(
            intended: intended,
            accountScope: account?.scope ?? .household,
            paidBy: draft.paidBy
        )

        if let planId = draft.fundingPlanId {
            guard let record = fundingPlans.first(where: { $0.id == planId }) else { return }
            let planBefore = record.enginePlan
            guard let tranche = planBefore.tranches.first(where: { $0.cycleISO == activeAnchor }),
                  !tranche.reserved
            else {
                countIt = nil
                return
            }
            let tx = TransactionRecord(
                purchaseDate: activeAnchor,
                realizedDate: activeAnchor,
                realizedStatus: .realized,
                amountC: amountC,
                accountId: draft.selectedAccountId,
                categoryId: rule.categoryId,
                paidBy: draft.paidBy,
                allocation: routed,
                recurringRuleId: rule.id,
                note: "\(draft.billTitle) · set aside"
            )
            modelContext.insert(tx)
            let plans = Funding.markReserved(planId: planId, cycleISO: activeAnchor, in: [planBefore])
            if let updated = plans.first { record.apply(updated) }
            try? modelContext.save()
            markChecklistDone(draft.task.id)
            let status = plans.first.map(Funding.status) ?? .funded(done: 0, total: 0)
            countIt = nil
            Task { @MainActor in
                PantominaMotion.run(reduceMotion) {
                    toast = "Counted · \(DisplayLabels.fundingStatus(status))"
                }
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                PantominaMotion.run(reduceMotion) { toast = nil }
            }
            return
        }

        let decision = Realization.decide(
            purchaseISO: activeAnchor,
            settlement: account?.settlement ?? .instant,
            statementCutoff: account?.statementCutoff
        )
        let tx = TransactionRecord(
            purchaseDate: activeAnchor,
            realizedDate: decision.realizedDate,
            realizedStatus: decision.status,
            proposedRealizedDate: decision.proposedRealizedDate,
            amountC: amountC,
            accountId: draft.selectedAccountId,
            categoryId: rule.categoryId,
            paidBy: draft.paidBy,
            allocation: routed,
            recurringRuleId: rule.id,
            note: draft.billTitle
        )
        modelContext.insert(tx)
        try? modelContext.save()
        markChecklistDone(draft.task.id)
        countIt = nil
        Task { @MainActor in
            PantominaMotion.run(reduceMotion) { toast = "Counted. Updates everywhere." }
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            PantominaMotion.run(reduceMotion) { toast = nil }
        }
    }

    private func markChecklistDone(_ id: String) {
        var ids = checklistDoneIds
        ids.insert(id)
        checklistDoneRaw = ids.sorted().joined(separator: ",")
    }

    @ViewBuilder
    private func splitPane(
        snap: Settlement.CycleSnapshot?,
        fernName: String,
        starkName: String
    ) -> some View {
        let result = snap?.result
        let shares = cycleShares
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if !anchors.isEmpty {
                    Picker("Cycle", selection: Binding(
                        get: { activeAnchor },
                        set: { selectedAnchor = $0 }
                    )) {
                        ForEach(anchors.reversed(), id: \.self) { anchor in
                            Text(DisplayLabels.displayDate(iso: anchor)).tag(anchor)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Cycle")
                }

                if let result {
                    Card {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            HStack {
                                Eyebrow("Settle this cycle")
                                Spacer()
                                Chip(
                                    label: result.dueC == 0 && shares.pendingCount > 0
                                        ? "Nothing counted yet"
                                        : DisplayLabels.settlementStatus(result.status),
                                    tone: result.dueC == 0 && shares.pendingCount > 0
                                        ? .terra
                                        : (result.status == .partial ? .terra : .sage)
                                )
                            }

                            metricRow("\(starkName)'s share", result.dueC)
                            metricRow("Sent over", result.contributedC)
                            metricRow(
                                "Still open",
                                result.remainingC,
                                emphasize: result.remainingC > 0
                            )

                            GeometryReader { geo in
                                let pct = result.dueC == 0
                                    ? 0.0
                                    : min(1.0, Double(result.contributedC + result.carriedCreditC) / Double(result.dueC))
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.pantomina.hairline)
                                    Capsule()
                                        .fill(Color.pantomina.sage)
                                        .frame(width: pct == 0 ? 0 : max(8, geo.size.width * pct))
                                }
                            }
                            .frame(height: 8)
                            .accessibilityLabel("Contribution progress")

                            if result.carriedCreditC > 0 {
                                Text("Includes \(formatPeso(result.carriedCreditC)) credit from last cycle.")
                                    .font(PantominaFont.caption)
                                    .foregroundStyle(Color.pantomina.muted)
                            }

                            if result.dueC == 0 && shares.fernC == 0 && shares.starkC == 0 {
                                Text("Shared spends land here once counted. Use House cash box, or count the card on Statement day.")
                                    .font(PantominaFont.caption)
                                    .foregroundStyle(Color.pantomina.muted)
                            } else {
                                Text("\(starkName) sent \(formatPeso(result.contributedC)) of \(formatPeso(result.dueC)) this cycle.")
                                    .font(PantominaFont.caption)
                                    .foregroundStyle(Color.pantomina.muted)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: Spacing.md) {
                        if shares.fernC > 0 || shares.starkC > 0 {
                            fernShareCard(shares, fernName: fernName, starkName: starkName)
                        }

                        Button {
                            contributionText = ""
                            contributionError = nil
                            showLogContribution = true
                        } label: {
                            Text("Log a contribution")
                                .font(PantominaFont.body.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 48)
                                .background(Color.pantomina.sage)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: Spacing.radius, style: .continuous))
                        }
                        .buttonStyle(SageButtonStyle())

                        if result.remainingC > 0 {
                            Button {
                                postReceivable(remainingC: result.remainingC, anchor: activeAnchor)
                            } label: {
                                Text("Post remaining to Love Tab")
                                    .font(PantominaFont.body.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: 48)
                                    .background(Color.pantomina.terra.opacity(0.2))
                                    .foregroundStyle(Color.pantomina.terraDeep)
                                    .clipShape(RoundedRectangle(cornerRadius: Spacing.radius, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    Text("Nothing settled in this cycle yet.")
                        .font(PantominaFont.body)
                        .foregroundStyle(Color.pantomina.muted)
                }
            }
            .padding(Spacing.lg)
        }
    }

    private func fernShareCard(
        _ shares: Settlement.HouseholdShares,
        fernName: String,
        starkName: String
    ) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Eyebrow(shares.pendingCount > 0 ? "On the statement" : "Shared spends")
                HStack {
                    Text("\(fernName)'s share")
                        .font(PantominaFont.body)
                        .foregroundStyle(Color.pantomina.muted)
                    Spacer()
                    Text(formatPeso(shares.fernC))
                        .font(PantominaFont.body.weight(.medium).monospacedDigit())
                        .foregroundStyle(Color.pantomina.sageDeep)
                }
                if shares.pendingCount > 0 {
                    Text(
                        "\(shares.pendingCount) card swipe\(shares.pendingCount == 1 ? "" : "s") still waiting. \(starkName)'s half on those (\(formatPeso(shares.starkC))) won’t add to what she owes above."
                    )
                    .font(PantominaFont.caption)
                    .foregroundStyle(Color.pantomina.muted)
                } else {
                    Text("\(fernName)'s half of shared spends this cycle — for planning the bills, not a tab the other way.")
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.muted)
                }
            }
        }
    }

    private func loveTabPane(fernName: String, starkName: String) -> some View {
        let balance = history.last?.result.tabAfterC
            ?? currentSnapshot?.result.tabAfterC
            ?? 0
        let credit = history.last?.result.creditOutC ?? 0
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Card {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Eyebrow("The Love Tab")
                        Text(formatPeso(balance))
                            .font(PantominaFont.amount)
                            .monospacedDigit()
                            .foregroundStyle(Color.pantomina.ink)
                        Text("\(fernName)'s asset · \(starkName)'s open balance. Stays at ₱0 or above.")
                            .font(PantominaFont.caption)
                            .foregroundStyle(Color.pantomina.muted)
                        if credit > 0 {
                            Text("Credit for next cycle: \(formatPeso(credit))")
                                .font(PantominaFont.caption)
                                .foregroundStyle(Color.pantomina.sageDeep)
                        }
                    }
                }

                if history.isEmpty {
                    Text("No cycles on the tab yet.")
                        .font(PantominaFont.body)
                        .foregroundStyle(Color.pantomina.muted)
                } else {
                    Eyebrow("Cycle history")
                    ForEach(history.reversed(), id: \.anchorISO) { snap in
                        Card {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(DisplayLabels.displayDate(iso: snap.anchorISO))
                                        .font(PantominaFont.body.weight(.medium))
                                    Text("due \(formatPeso(snap.result.dueC)) · sent \(formatPeso(snap.result.contributedC))")
                                        .font(PantominaFont.caption)
                                        .foregroundStyle(Color.pantomina.muted)
                                }
                                Spacer()
                                Chip(
                                    label: DisplayLabels.settlementStatus(snap.result.status),
                                    tone: snap.result.status == .partial ? .terra : .sage
                                )
                            }
                        }
                    }
                }
            }
            .padding(Spacing.lg)
        }
    }

    private func contributionSheet(starkName: String) -> some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Amount", text: $contributionText)
                        .keyboardType(.decimalPad)
                    if let contributionError {
                        Text(contributionError)
                            .foregroundStyle(Color.pantomina.terraDeep)
                    }
                } header: {
                    Text("Contribution")
                } footer: {
                    Text("Counts toward \(starkName)'s share for \(DisplayLabels.displayDate(iso: activeAnchor)).")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.pantomina.ground)
            .navigationTitle("Log a contribution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showLogContribution = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveContribution() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func metricRow(_ label: String, _ cents: Int, emphasize: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(PantominaFont.body)
                .foregroundStyle(Color.pantomina.muted)
            Spacer()
            Text(formatPeso(cents))
                .font(
                    emphasize
                        ? PantominaFont.body.weight(.semibold).monospacedDigit()
                        : PantominaFont.body.monospacedDigit()
                )
                .foregroundStyle(Color.pantomina.ink)
        }
    }

    private func carriedCredit(before anchor: String) -> Int {
        guard let idx = history.firstIndex(where: { $0.anchorISO == anchor }), idx > 0 else {
            // Recompute prefix if history doesn't include empty current cycle yet
            let prior = anchors.filter { $0 < anchor }
            return Settlement.history(rows: ledgerRows, anchors: prior).last?.result.creditOutC ?? 0
        }
        return history[idx - 1].result.creditOutC
    }

    private func tabBefore(before anchor: String) -> Int {
        let prior = anchors.filter { $0 < anchor }
        return Settlement.history(rows: ledgerRows, anchors: prior).last?.result.tabAfterC ?? 0
    }

    private func saveContribution() {
        contributionError = nil
        guard let amountC = InputBounds.centavos(fromPesosText: contributionText), amountC > 0 else {
            contributionError = "Enter an amount."
            return
        }
        guard let category = categories.first(where: { $0.system && $0.item == "Partner Contribution" }) else {
            contributionError = "Contribution category missing."
            return
        }
        guard let account = accounts.first(where: { !$0.archived && $0.scope == .household && $0.settlement == .instant })
                ?? accounts.first(where: { !$0.archived && $0.scope == .household })
        else {
            contributionError = "No shared account to post against."
            return
        }
        let tx = TransactionRecord(
            purchaseDate: activeAnchor,
            realizedDate: activeAnchor,
            realizedStatus: .realized,
            amountC: amountC,
            accountId: account.id,
            categoryId: category.id,
            paidBy: .stark,
            allocation: Allocation(fern: 0, stark: 0),
            settlementRole: .contribution,
            note: "Contribution for \(activeAnchor)"
        )
        modelContext.insert(tx)
        do {
            try modelContext.save()
            // Defer UI mutation — same AttributeGraph trap as Add save.
            Task { @MainActor in
                showLogContribution = false
                PantominaMotion.run(reduceMotion) { toast = "Contribution logged." }
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                PantominaMotion.run(reduceMotion) { toast = nil }
            }
        } catch {
            contributionError = "Couldn't save. Try again."
        }
    }

    private func postReceivable(remainingC: Int, anchor: String) {
        // Avoid duplicate receivable for the same cycle.
        let already = transactions.contains {
            $0.settlementRole == .receivable
                && $0.realizedDate == anchor
                && $0.amountC == remainingC
        }
        guard !already else {
            PantominaMotion.run(reduceMotion) { toast = "Already on the Love Tab." }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                PantominaMotion.run(reduceMotion) { toast = nil }
            }
            return
        }
        guard let category = categories.first(where: { $0.system && $0.item == "Partner Receivable" }) else { return }
        guard let account = accounts.first(where: { !$0.archived && $0.scope == .household }) else { return }
        let tx = TransactionRecord(
            purchaseDate: anchor,
            realizedDate: anchor,
            realizedStatus: .realized,
            amountC: remainingC,
            accountId: account.id,
            categoryId: category.id,
            paidBy: .stark,
            allocation: Allocation(fern: 0, stark: remainingC),
            settlementRole: .receivable,
            note: "Remaining for \(anchor)"
        )
        modelContext.insert(tx)
        try? modelContext.save()
        Task { @MainActor in
            PantominaMotion.run(reduceMotion) { toast = "Posted to the Love Tab." }
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            PantominaMotion.run(reduceMotion) { toast = nil }
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

private struct CountItDraft: Identifiable {
    var id: String { task.id }
    var task: Checklist.Task
    var amountText: String
    var selectedAccountId: String
    var paidBy: PersonId
    var splitMode: Int
    var fundingPlanId: String?
    var ruleId: String?
    var loanId: String?
    var billTitle: String
    var amountEditable: Bool
}
