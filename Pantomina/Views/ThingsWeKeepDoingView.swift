import SwiftUI
import SwiftData

struct ThingsWeKeepDoingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var rules: [RecurringRuleRecord]
    @Query private var fundingPlans: [FundingPlanRecord]
    @Query private var accounts: [AccountRecord]
    @Query private var categories: [CategoryRecord]
    @Query private var people: [PersonRecord]

    @State private var showAdd = false
    @State private var editingRule: RecurringRuleRecord?
    @State private var pendingDelete: RecurringRuleRecord?

    private var fernName: String { people.first { $0.id == .fern }?.name ?? "Fern" }
    private var starkName: String { people.first { $0.id == .stark }?.name ?? "Stark" }

    var body: some View {
        List {
            if rules.isEmpty {
                Text("Nothing recurring yet. Tap + to keep doing something.")
                    .font(PantominaFont.body)
                    .foregroundStyle(Color.pantomina.muted)
            } else {
                Section("Rules") {
                    ForEach(rules, id: \.id) { rule in
                        ruleRow(rule)
                    }
                }

                if !fundingPlans.isEmpty {
                    Section {
                        ForEach(fundingPlans, id: \.id) { plan in
                            let engine = plan.enginePlan
                            VStack(alignment: .leading, spacing: 4) {
                                Text(engine.billTitle)
                                    .font(PantominaFont.body.weight(.medium))
                                Text(DisplayLabels.fundingStatus(Funding.status(engine)))
                                    .font(PantominaFont.caption)
                                    .foregroundStyle(Color.pantomina.sageDeep)
                                Text("Set aside so far \(formatPeso(engine.reserveC))")
                                    .font(PantominaFont.caption.monospacedDigit())
                                    .foregroundStyle(Color.pantomina.muted)
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Text("Funding plans")
                    } footer: {
                        Text("Each set-aside hits The Receipts. Paid when all halves are in.")
                            .font(PantominaFont.caption)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.pantomina.ground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    PetTitle("Things We Keep Doing")
                    Text("Recurring")
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.muted)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Keep doing this")
            }
        }
        .sheet(isPresented: $showAdd) {
            AddRecurringRuleSheet(
                fernName: fernName,
                starkName: starkName,
                accounts: accounts.filter { !$0.archived },
                categories: categories,
                existing: nil,
                hasFundingPlan: false,
                fundingHasReserved: false,
                onCancel: { showAdd = false },
                onSave: { draft in
                    saveNewRule(draft)
                    showAdd = false
                }
            )
        }
        .sheet(isPresented: Binding(
            get: { editingRule != nil },
            set: { if !$0 { editingRule = nil } }
        )) {
            if let rule = editingRule {
                AddRecurringRuleSheet(
                    fernName: fernName,
                    starkName: starkName,
                    accounts: accounts.filter { !$0.archived },
                    categories: categories,
                    existing: rule,
                    hasFundingPlan: plan(for: rule.id) != nil,
                    fundingHasReserved: planHasReserved(for: rule.id),
                    onCancel: { editingRule = nil },
                    onSave: { draft in
                        updateRule(rule, draft: draft)
                        editingRule = nil
                    }
                )
            }
        }
        .alert(
            pendingDelete.map { "Stop keeping “\($0.title)”?" } ?? "Stop keeping this?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let rule = pendingDelete {
                    deleteRule(rule)
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text("Past receipts stay. Checklist won’t ask for it again.")
        }
        .onAppear {
            try? SeedCatalog.seedDemoFundingIfNeeded(into: modelContext)
            try? modelContext.save()
        }
    }

    @ViewBuilder
    private func ruleRow(_ rule: RecurringRuleRecord) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.title)
                    .font(PantominaFont.body.weight(.medium))
                Text(formatPeso(rule.amountC))
                    .font(PantominaFont.caption.monospacedDigit())
                    .foregroundStyle(Color.pantomina.muted)
            }
            Spacer()
            Toggle(
                rule.paused ? "Paused" : "Active",
                isOn: Binding(
                    get: { !rule.paused },
                    set: { active in
                        rule.paused = !active
                        try? modelContext.save()
                    }
                )
            )
            .labelsHidden()
            .accessibilityLabel(rule.paused ? "Paused" : "Active")
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                editingRule = rule
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(Color.pantomina.sage)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingDelete = rule
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityAction(named: "Edit") {
            editingRule = rule
        }
        .accessibilityAction(named: "Delete") {
            pendingDelete = rule
        }
    }

    private func plan(for ruleId: String) -> FundingPlanRecord? {
        fundingPlans.first { $0.billRecurringRuleId == ruleId }
    }

    private func planHasReserved(for ruleId: String) -> Bool {
        guard let plan = plan(for: ruleId) else { return false }
        return plan.enginePlan.tranches.contains(where: \.reserved)
    }

    private func paidByAndAllocation(for draft: AddRecurringRuleSheet.Draft) -> (PersonId, Allocation) {
        switch draft.whose {
        case .fern:
            return (.fern, Allocation(fern: draft.amountC, stark: 0))
        case .stark:
            return (.stark, Allocation(fern: 0, stark: draft.amountC))
        case .shared:
            let half = draft.amountC / 2
            return (.fern, Allocation(fern: half, stark: draft.amountC - half))
        }
    }

    private func currentStartISO() -> String {
        Cycle.cycleFor(isoDate: {
            let f = DateFormatter()
            f.calendar = Calendar(identifier: .gregorian)
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone.current
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: Date())
        }()).anchorISO
    }

    private func saveNewRule(_ draft: AddRecurringRuleSheet.Draft) {
        let start = currentStartISO()
        let (paidBy, allocation) = paidByAndAllocation(for: draft)
        let rule = RecurringRuleRecord(
            title: draft.title,
            amountC: draft.amountC,
            accountId: draft.accountId,
            categoryId: draft.categoryId,
            paidBy: paidBy,
            allocation: allocation,
            cadence: .biweekly,
            anchorDay: .both,
            amountBehavior: .exact,
            startCycleISO: start,
            flow: .expense,
            fixedVariable: .fixed
        )
        modelContext.insert(rule)

        if draft.splitAcrossTwo {
            insertTwoCycleFunding(rule: rule, accountId: draft.accountId, amountC: draft.amountC, startISO: start)
        }
        try? modelContext.save()
    }

    private func updateRule(_ rule: RecurringRuleRecord, draft: AddRecurringRuleSheet.Draft) {
        let (paidBy, allocation) = paidByAndAllocation(for: draft)
        rule.title = draft.title
        rule.amountC = draft.amountC
        rule.accountId = draft.accountId
        rule.categoryId = draft.categoryId
        rule.paidByRaw = paidBy.rawValue
        rule.allocFernC = allocation.fern
        rule.allocStarkC = allocation.stark

        let existingPlan = plan(for: rule.id)
        let hasReserved = existingPlan?.enginePlan.tranches.contains(where: \.reserved) == true

        if hasReserved {
            if let existingPlan {
                existingPlan.billTitle = draft.title
                existingPlan.sourceAccountId = draft.accountId
            }
            try? modelContext.save()
            return
        }

        if let existingPlan {
            modelContext.delete(existingPlan)
        }
        if draft.splitAcrossTwo {
            insertTwoCycleFunding(
                rule: rule,
                accountId: draft.accountId,
                amountC: draft.amountC,
                startISO: rule.startCycleISO
            )
        }
        try? modelContext.save()
    }

    private func deleteRule(_ rule: RecurringRuleRecord) {
        for plan in fundingPlans where plan.billRecurringRuleId == rule.id {
            modelContext.delete(plan)
        }
        modelContext.delete(rule)
        try? modelContext.save()
    }

    private func insertTwoCycleFunding(
        rule: RecurringRuleRecord,
        accountId: String,
        amountC: Int,
        startISO: String
    ) {
        let first = Cycle(anchorISO: startISO)
        let second = Cycle.nextHalfMonth(after: first)
        let half = amountC / 2
        let secondHalf = amountC - half
        modelContext.insert(
            FundingPlanRecord(
                billRecurringRuleId: rule.id,
                billTitle: rule.title,
                sourceAccountId: accountId,
                payoutCycleISO: second.anchorISO,
                tranches: [
                    Funding.Tranche(cycleISO: first.anchorISO, amountC: half, reserved: false),
                    Funding.Tranche(cycleISO: second.anchorISO, amountC: secondHalf, reserved: false),
                ]
            )
        )
    }
}

private struct AddRecurringRuleSheet: View {
    enum Whose: Int, CaseIterable {
        case fern, stark, shared
    }

    struct Draft {
        var title: String
        var amountC: Int
        var whose: Whose
        var accountId: String
        var categoryId: String
        var splitAcrossTwo: Bool
    }

    let fernName: String
    let starkName: String
    let accounts: [AccountRecord]
    let categories: [CategoryRecord]
    let existing: RecurringRuleRecord?
    let hasFundingPlan: Bool
    let fundingHasReserved: Bool
    let onCancel: () -> Void
    let onSave: (Draft) -> Void

    @State private var title = ""
    @State private var amountText = ""
    @State private var whose: Whose = .shared
    @State private var accountId: String?
    @State private var categoryId: String?
    @State private var splitAcrossTwo = false
    @State private var showAccountPicker = false
    @State private var showCategoryPicker = false
    @State private var error: String?
    @State private var didPrefill = false

    private var expenseCategories: [CategoryRecord] {
        categories
            .filter { !$0.system && $0.flow == .expense }
            .sorted { $0.displayName < $1.displayName }
    }

    private var filteredAccounts: [AccountRecord] {
        switch whose {
        case .fern: return accounts.filter { $0.scope == .fern || $0.scope == .household }
        case .stark: return accounts.filter { $0.scope == .stark || $0.scope == .household }
        case .shared: return accounts.filter { $0.scope == .household }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(Color.pantomina.terraDeep)
                            .accessibilityAddTraits(.isStaticText)
                    }
                }
                Section {
                    TextField("Name", text: $title)
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                    Button {
                        showCategoryPicker = true
                    } label: {
                        HStack {
                            Text("Category")
                                .foregroundStyle(Color.pantomina.ink)
                            Spacer()
                            Text(categoryLabel)
                                .foregroundStyle(Color.pantomina.muted)
                        }
                    }
                }
                Section {
                    Picker("Whose", selection: $whose) {
                        Text("Just \(fernName)").tag(Whose.fern)
                        Text("Just \(starkName)").tag(Whose.stark)
                        Text("Shared").tag(Whose.shared)
                    }
                    .onChange(of: whose) { _, _ in
                        if accountId == nil || !filteredAccounts.contains(where: { $0.id == accountId }) {
                            accountId = filteredAccounts.first?.id
                        }
                    }
                    Button {
                        showAccountPicker = true
                    } label: {
                        HStack {
                            Text("Default pay from")
                                .foregroundStyle(Color.pantomina.ink)
                            Spacer()
                            Text(accountLabel)
                                .foregroundStyle(Color.pantomina.muted)
                        }
                    }
                } header: {
                    Text("Who & how")
                } footer: {
                    Text("We’ll use this account on Checklist. You can change it for one cycle.")
                }
                Section {
                    Toggle("Set aside across 2 cycles", isOn: $splitAcrossTwo)
                        .disabled(fundingHasReserved)
                } footer: {
                    if fundingHasReserved {
                        Text("Set-asides already counted stay as they are.")
                    } else {
                        Text("Splits the amount in half across this cycle and the next. Checklist posts each half — not the full bill twice.")
                    }
                }
            }
            .navigationTitle("Keep doing this")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { prefillIfNeeded() }
            .sheet(isPresented: $showAccountPicker) {
                SearchablePickList(
                    title: "Default pay from",
                    items: filteredAccounts.map {
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
                    selection: $accountId
                )
            }
            .sheet(isPresented: $showCategoryPicker) {
                SearchablePickList(
                    title: "Category",
                    items: expenseCategories.map {
                        SearchablePickItem(id: $0.id, title: $0.displayName)
                    },
                    selection: $categoryId
                )
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var accountLabel: String {
        guard let accountId,
              let account = accounts.first(where: { $0.id == accountId })
        else { return "Choose" }
        return account.displayLabel(fernName: fernName, starkName: starkName)
    }

    private var categoryLabel: String {
        guard let categoryId,
              let category = expenseCategories.first(where: { $0.id == categoryId })
                ?? categories.first(where: { $0.id == categoryId })
        else { return "Choose" }
        return category.displayName
    }

    private func prefillIfNeeded() {
        guard !didPrefill else { return }
        didPrefill = true
        if let existing {
            title = existing.title
            amountText = String(format: "%.2f", Double(existing.amountC) / 100)
            whose = whose(for: existing)
            accountId = existing.accountId
            categoryId = existing.categoryId
            splitAcrossTwo = hasFundingPlan || fundingHasReserved
        } else {
            accountId = filteredAccounts.first?.id
            categoryId = nil
        }
    }

    private func whose(for rule: RecurringRuleRecord) -> Whose {
        if rule.allocStarkC == 0 { return .fern }
        if rule.allocFernC == 0 { return .stark }
        return .shared
    }

    private func save() {
        error = nil
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            error = "Give it a name."
            return
        }
        guard let amountC = InputBounds.centavos(fromPesosText: amountText), amountC > 0 else {
            error = "Enter an amount."
            return
        }
        guard let accountId else {
            error = "Choose how you usually pay."
            return
        }
        guard let categoryId else {
            error = "Choose a category."
            return
        }
        onSave(
            Draft(
                title: cleaned,
                amountC: amountC,
                whose: whose,
                accountId: accountId,
                categoryId: categoryId,
                splitAcrossTwo: fundingHasReserved ? true : splitAcrossTwo
            )
        )
    }
}
