import SwiftUI
import SwiftData

/// Accounts: live pocket map plus create/edit for pockets and user categories. Not Empire NW.
struct AccountsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var people: [PersonRecord]
    @Query(sort: \AccountRecord.baseName) private var accounts: [AccountRecord]
    @Query(sort: \CategoryRecord.group) private var categories: [CategoryRecord]
    @Query private var funds: [FundRecord]
    @Query private var loans: [LoanRecord]
    @Query private var transactions: [TransactionRecord]
    @Query private var rules: [RecurringRuleRecord]
    @Query private var plans: [FundingPlanRecord]

    @State private var editingPocket: AccountRecord?
    @State private var addingPocket = false
    @State private var editingCategory: CategoryRecord?
    @State private var addingCategory = false

    private var fernName: String { people.first { $0.id == .fern }?.name ?? "Fern" }
    private var starkName: String { people.first { $0.id == .stark }?.name ?? "Stark" }

    private var categoryFlow: [String: FlowType] {
        Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.flow) })
    }

    private var visibleAccounts: [AccountRecord] {
        accounts.filter { !$0.archived }
    }

    private var userCategories: [CategoryRecord] {
        categories.filter { !$0.system }.sorted {
            if $0.group == $1.group { return $0.item < $1.item }
            return $0.group < $1.group
        }
    }

    private var categoryGroups: [String] {
        Array(Set(userCategories.map(\.group))).sorted()
    }

    private var totalSpokenForC: Int {
        visibleAccounts.reduce(0) { $0 + spokenForC(accountId: $1.id) }
    }

    private var accountsSubtitle: String {
        let n = visibleAccounts.count
        if n == 0 { return "No pockets yet" }
        let pocketWord = n == 1 ? "pocket" : "pockets"
        if totalSpokenForC > 0 {
            return "\(n) \(pocketWord) · spoken for \(formatPeso(totalSpokenForC))"
        }
        return "\(n) \(pocketWord)"
    }

    private var existingPockets: [LedgerCatalog.ExistingPocket] {
        visibleAccounts.map { LedgerCatalog.ExistingPocket(id: $0.id, baseName: $0.baseName, scope: $0.scope) }
    }

    private var existingCategories: [LedgerCatalog.ExistingCategory] {
        categories.map {
            LedgerCatalog.ExistingCategory(id: $0.id, group: $0.group, item: $0.item, system: $0.system)
        }
    }

    private var transactionAccountIds: Set<String> { Set(transactions.map(\.accountId)) }
    private var ruleAccountIds: Set<String> { Set(rules.map(\.accountId)) }
    private var fundHomeAccountIds: Set<String> { Set(funds.map(\.homeAccountId)) }
    private var loanPaymentAccountIds: Set<String> { Set(loans.map(\.paymentAccountId)) }
    private var fundingSourceAccountIds: Set<String> { Set(plans.map(\.sourceAccountId)) }
    private var transactionCategoryIds: Set<String> { Set(transactions.map(\.categoryId)) }
    private var ruleCategoryIds: Set<String> { Set(rules.map(\.categoryId)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                pocketsSection
                categoriesSection
            }
        }
        .background(Color.pantomina.ground)
        .toolbarBackground(Color.pantomina.ground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("Accounts")
                        .font(PantominaFont.body.weight(.semibold))
                        .foregroundStyle(Color.pantomina.ink)
                    Text(accountsSubtitle)
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Text("Spoken for is earmarked in funds, not a second pile.")
                .font(PantominaFont.caption)
                .foregroundStyle(Color.pantomina.muted)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.pantomina.ground)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.pantomina.rule).frame(height: 1)
                }
        }
        .sheet(isPresented: $addingPocket) {
            CatalogPocketSheet(
                fernName: fernName,
                starkName: starkName,
                existing: existingPockets,
                record: nil,
                inUse: false,
                onCancel: { addingPocket = false },
                onSave: { draft in
                    insertPocket(draft)
                    addingPocket = false
                }
            )
        }
        .sheet(item: $editingPocket) { record in
            CatalogPocketSheet(
                fernName: fernName,
                starkName: starkName,
                existing: existingPockets,
                record: record,
                inUse: pocketInUse(record.id),
                onCancel: { editingPocket = nil },
                onSave: { draft in
                    applyPocket(draft, to: record)
                    editingPocket = nil
                }
            )
        }
        .sheet(isPresented: $addingCategory) {
            CatalogCategorySheet(
                existing: existingCategories,
                record: nil,
                inUse: false,
                onCancel: { addingCategory = false },
                onSave: { draft in
                    insertCategory(draft)
                    addingCategory = false
                }
            )
        }
        .sheet(item: $editingCategory) { record in
            CatalogCategorySheet(
                existing: existingCategories,
                record: record,
                inUse: categoryInUse(record.id),
                onCancel: { editingCategory = nil },
                onSave: { draft in
                    applyCategory(draft, to: record)
                    editingCategory = nil
                }
            )
        }
    }

    private var pocketsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Pockets")
            if visibleAccounts.isEmpty {
                emptyBlock(
                    "No pockets yet. Add cash, cards, or wallets here.",
                    addTitle: "Add a pocket"
                ) { addingPocket = true }
            } else {
                ForEach(LedgerCatalog.userScopes, id: \.rawValue) { scope in
                    let rows = visibleAccounts.filter { $0.scope == scope }
                    if !rows.isEmpty {
                        scopeGroup(scope, rows: rows)
                    }
                }
                addRow("Add a pocket") { addingPocket = true }
            }
        }
    }

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("What it was for")
            if userCategories.isEmpty {
                emptyBlock(
                    "No categories yet. Add Rent · House and the rest here.",
                    addTitle: "Add a category"
                ) { addingCategory = true }
            } else {
                ForEach(categoryGroups, id: \.self) { group in
                    groupHeader(group)
                    ForEach(userCategories.filter { $0.group == group }, id: \.id) { category in
                        categoryRow(category)
                    }
                }
                addRow("Add a category") { addingCategory = true }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(PantominaFont.caption.weight(.semibold))
            .foregroundStyle(Color.pantomina.muted)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.pantomina.rule).frame(height: 1)
            }
    }

    private func scopeGroup(_ scope: Scope, rows: [AccountRecord]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            groupHeader(DisplayLabels.scope(scope, fernName: fernName, starkName: starkName))
            ForEach(rows, id: \.id) { account in
                pocketRow(account)
            }
        }
    }

    private func groupHeader(_ title: String) -> some View {
        Text(title)
            .font(PantominaFont.caption.weight(.semibold))
            .foregroundStyle(Color.pantomina.muted)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    private func emptyBlock(_ copy: String, addTitle: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(copy)
                .font(PantominaFont.body)
                .foregroundStyle(Color.pantomina.muted)
            QuietPrimaryButton(title: addTitle, fillsWidth: false, action: action)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func addRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(PantominaFont.body.weight(.medium))
                .foregroundStyle(Color.pantomina.quietAccent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.pantomina.innerRule).frame(height: 1)
        }
        .accessibilityLabel(title)
    }

    private func pocketRow(_ account: AccountRecord) -> some View {
        let pocket = pocketResult(for: account)
        return Button {
            editingPocket = account
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.displayLabel(fernName: fernName, starkName: starkName))
                        .font(PantominaFont.body)
                        .foregroundStyle(Color.pantomina.ink)
                    if pocket.source == .unknown {
                        Text("Needs a check-in. Confirm on Balance Day")
                            .font(PantominaFont.caption)
                            .foregroundStyle(Color.pantomina.muted)
                    }
                    if pocket.spokenForC > 0 {
                        Text("Spoken for \(formatPeso(pocket.spokenForC))")
                            .font(PantominaFont.caption)
                            .foregroundStyle(Color.pantomina.muted)
                    }
                }
                Spacer(minLength: 8)
                if pocket.source == .unknown {
                    Text("-")
                        .font(PantominaFont.body)
                        .foregroundStyle(Color.pantomina.muted)
                } else {
                    Text(formatPeso(pocket.balanceC))
                        .font(PantominaFont.body.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Color.pantomina.ink)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.pantomina.innerRule).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private func categoryRow(_ category: CategoryRecord) -> some View {
        Button {
            editingCategory = category
        } label: {
            HStack {
                Text(category.item)
                    .font(PantominaFont.body)
                    .foregroundStyle(Color.pantomina.ink)
                Spacer()
                Text(DisplayLabels.flow(category.flow))
                    .font(PantominaFont.caption)
                    .foregroundStyle(Color.pantomina.muted)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.pantomina.innerRule).frame(height: 1)
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(category.displayName)
    }

    private func spokenForC(accountId: String) -> Int {
        funds
            .filter { $0.homeAccountId == accountId }
            .reduce(0) { $0 + $1.balanceC }
    }

    private func pocketResult(for account: AccountRecord) -> PocketBalance.Result {
        let legs = transactions
            .filter { $0.accountId == account.id }
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
        let spoken = spokenForC(accountId: account.id)
        let loanBal: Int?
        if account.kind == .loan {
            let active = loans.filter { $0.statusRaw != Loan.Status.done.rawValue }
            if let loan = active.first(where: { $0.paymentAccountId == account.id })
                ?? active.first(where: { $0.id == account.id }) {
                loanBal = Loan.derivedBalanceC(
                    totalLoanC: loan.totalLoanC,
                    paidMonths: loan.paidMonths,
                    monthlyC: loan.monthlyC
                )
            } else {
                loanBal = 0
            }
        } else {
            loanBal = nil
        }
        return PocketBalance.compute(
            kind: account.kind,
            legs: legs,
            loanBalanceC: loanBal,
            lastConfirmedC: account.lastConfirmedBalanceC,
            spokenForC: spoken,
            receivableBalanceC: account.kind == .receivable ? account.lastConfirmedBalanceC : nil,
            asOfISO: nil,
            lastConfirmedCycleISO: account.lastConfirmedCycleISO
        )
    }

    private func pocketInUse(_ id: String) -> Bool {
        LedgerCatalog.pocketInUse(
            id: id,
            transactionAccountIds: transactionAccountIds,
            ruleAccountIds: ruleAccountIds,
            fundHomeAccountIds: fundHomeAccountIds,
            loanPaymentAccountIds: loanPaymentAccountIds,
            fundingSourceAccountIds: fundingSourceAccountIds
        )
    }

    private func categoryInUse(_ id: String) -> Bool {
        LedgerCatalog.categoryInUse(
            id: id,
            transactionCategoryIds: transactionCategoryIds,
            ruleCategoryIds: ruleCategoryIds
        )
    }

    private func insertPocket(_ draft: LedgerCatalog.PocketDraft) {
        modelContext.insert(
            AccountRecord(
                baseName: draft.baseName,
                owner: draft.owner,
                scope: draft.scope,
                kind: draft.kind,
                settlement: draft.settlement,
                statementCutoff: draft.statementCutoff
            )
        )
        try? modelContext.save()
    }

    private func applyPocket(_ draft: LedgerCatalog.PocketDraft, to record: AccountRecord) {
        record.baseName = draft.baseName
        record.ownerRaw = draft.owner
        record.scopeRaw = draft.scope.rawValue
        record.kindRaw = draft.kind.rawValue
        record.settlementRaw = draft.settlement.rawValue
        record.statementCutoff = draft.statementCutoff
        try? modelContext.save()
    }

    private func insertCategory(_ draft: LedgerCatalog.CategoryDraft) {
        modelContext.insert(
            CategoryRecord(
                group: draft.group,
                item: draft.item,
                flow: draft.flow,
                needWant: draft.needWant,
                fixedVariable: draft.fixedVariable
            )
        )
        try? modelContext.save()
    }

    private func applyCategory(_ draft: LedgerCatalog.CategoryDraft, to record: CategoryRecord) {
        record.group = draft.group
        record.item = draft.item
        record.flowRaw = draft.flow.rawValue
        record.needWantRaw = draft.needWant?.rawValue
        record.fixedVariableRaw = draft.fixedVariable?.rawValue
        try? modelContext.save()
    }
}
