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

    @State private var pane = 0
    @State private var selectedAnchor: String?
    @State private var showLogContribution = false
    @State private var contributionText = ""
    @State private var contributionError: String?
    @State private var toast: String?
    @State private var estimateTask: Checklist.Task?
    @State private var estimateText = ""
    @State private var statementRoute: String?
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
        let fromLedger = Settlement.cycleAnchors(in: ledgerRows)
        let today = Self.todayISO()
        let current = Cycle.cycleFor(isoDate: today).anchorISO
        if fromLedger.contains(current) { return fromLedger }
        return (fromLedger + [current]).sorted()
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

    private var forecastResult: Forecast.Result {
        let projected = Projection.rows(forCycleISO: activeAnchor, rules: projectionRules)
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
        return Forecast.build(
            cycleISO: activeAnchor,
            incomeRows: income,
            projected: projected,
            pendingCards: pendingCards,
            trancheLines: [],
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
        return Checklist.tasks(
            cycleISO: activeAnchor,
            todayISO: Self.todayISO(),
            rules: projectionRules,
            statementAccountsWithPending: Array(statementPending).sorted(),
            trancheTasks: [],
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
                        onPickCycle: { AnyView(cycleMenu) }
                    )
                case 2:
                    BillsChecklistPane(
                        cycleISO: activeAnchor,
                        tasks: tasks,
                        summary: summary,
                        accountLabels: Dictionary(uniqueKeysWithValues: accounts.map {
                            ($0.id, $0.displayLabel(fernName: fern, starkName: stark))
                        }),
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
            .sheet(item: $estimateTask) { task in
                estimateSheet(task)
            }
            .sheet(isPresented: $showLogContribution) {
                contributionSheet(starkName: stark)
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
        if task.amountBehavior == .estimate {
            estimateText = String(format: "%.2f", Double(task.amountC) / 100)
            estimateTask = task
            return
        }
        confirmChecklistTask(task, amountC: task.amountC)
    }

    private func confirmChecklistTask(_ task: Checklist.Task, amountC: Int) {
        guard let ruleId = task.linkedId,
              let rule = recurringRules.first(where: { $0.id == ruleId })
        else {
            markChecklistDone(task.id)
            return
        }
        let fernShare: Int
        let starkShare: Int
        if rule.allocFernC + rule.allocStarkC == rule.amountC, rule.amountC > 0 {
            fernShare = Int((Double(rule.allocFernC) / Double(rule.amountC) * Double(amountC)).rounded())
            starkShare = amountC - fernShare
        } else {
            fernShare = amountC
            starkShare = 0
        }
        let draft = Projection.DraftRow(
            id: task.id,
            recurringRuleId: rule.id,
            title: rule.title,
            amountC: amountC,
            accountId: rule.accountId,
            categoryId: rule.categoryId,
            paidBy: PersonId(rawValue: rule.paidByRaw) ?? .fern,
            allocationFernC: fernShare,
            allocationStarkC: starkShare,
            status: .projected,
            realizedDate: nil,
            proposedRealizedDate: activeAnchor,
            amountBehavior: Projection.AmountBehavior(rawValue: rule.amountBehaviorRaw) ?? .exact,
            flow: FlowType(rawValue: rule.flowRaw) ?? .expense,
            fixedVariable: rule.fixedVariableRaw.flatMap(FixedVariable.init(rawValue:))
        )
        let confirmed = rule.amountBehaviorRaw == Projection.AmountBehavior.estimate.rawValue
            ? Projection.confirmEstimate(draft, cycleISO: activeAnchor, amountC: amountC)
            : Projection.confirmExact(draft, cycleISO: activeAnchor)
        let routed = AllocationRouting.record(
            intended: Allocation(fern: confirmed.allocationFernC, stark: confirmed.allocationStarkC),
            accountScope: accountById[confirmed.accountId]?.scope ?? .household,
            paidBy: confirmed.paidBy
        )
        let tx = TransactionRecord(
            purchaseDate: activeAnchor,
            realizedDate: confirmed.realizedDate,
            realizedStatus: .realized,
            amountC: confirmed.amountC,
            accountId: confirmed.accountId,
            categoryId: confirmed.categoryId,
            paidBy: confirmed.paidBy,
            allocation: routed,
            recurringRuleId: confirmed.recurringRuleId,
            note: confirmed.title
        )
        modelContext.insert(tx)
        try? modelContext.save()
        markChecklistDone(task.id)
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

    private func estimateSheet(_ task: Checklist.Task) -> some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Amount", text: $estimateText)
                        .keyboardType(.decimalPad)
                } header: {
                    Text(task.title)
                } footer: {
                    Text("Confirm what actually hit for \(DisplayLabels.displayDate(iso: activeAnchor)).")
                }
            }
            .navigationTitle("Confirm amount")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { estimateTask = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amountC = InputBounds.centavos(fromPesosText: estimateText), amountC > 0 else {
                            return
                        }
                        estimateTask = nil
                        confirmChecklistTask(task, amountC: amountC)
                    }
                }
            }
        }
        .presentationDetents([.medium])
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
