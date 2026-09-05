import SwiftUI
import SwiftData

struct AddEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var accounts: [AccountRecord]
    @Query private var categories: [CategoryRecord]
    @Query private var people: [PersonRecord]
    @Query private var jarSources: [JarSourceRecord]

    /// When false, view is presented as a sheet and dismisses after save.
    var presentsAsSheet: Bool = true
    var wrapInNavigationStack: Bool = true
    var formPetTitle: String? = nil
    var capturePrefill: CaptureParse.Card? = nil
    var onSaved: (() -> Void)? = nil
    /// When set, Save updates this row instead of inserting.
    var editingTransaction: TransactionRecord? = nil

    @AppStorage("recentCategoryIds") private var recentCategoryIdsRaw = ""
    @AppStorage("recentAccountIds") private var recentAccountIdsRaw = ""

    @State private var amountText = ""
    @State private var selectedAccountId: String?
    @State private var selectedCategoryId: String?
    @State private var paidBy: PersonId = .fern
    @State private var splitMode = 0
    @State private var customFern = ""
    @State private var customStark = ""
    @State private var purchaseDate = Date()
    @State private var note = ""
    @State private var error: String?
    @State private var savedToast = false
    @State private var showCategoryPicker = false
    @State private var showAccountPicker = false
    @State private var showJarSourcePicker = false
    @State private var cookieJarOn = false
    @State private var jarKind: CookieJar.Kind = .spend
    @State private var jarSourceId: String?
    @State private var didPrefillEdit = false
    @State private var skipAccountDefaults = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case amount, customFern, customStark, note
    }

    private var isEditing: Bool { editingTransaction != nil }

    private var pickerCategories: [CategoryRecord] {
        categories.filter { !$0.system }.sorted { $0.displayName < $1.displayName }
    }

    private var activeAccounts: [AccountRecord] {
        accounts.filter { !$0.archived }
    }

    private var fernName: String { people.first { $0.id == .fern }?.name ?? "Fern" }
    private var starkName: String { people.first { $0.id == .stark }?.name ?? "Stark" }

    private var selectedAccount: AccountRecord? {
        activeAccounts.first { $0.id == selectedAccountId }
    }

    private var selectedCategory: CategoryRecord? {
        if cookieJarOn, let petty = pettyCashCategory { return petty }
        return categories.first { $0.id == selectedCategoryId }
    }

    private var pettyCashCategory: CategoryRecord? {
        categories.first { $0.system && $0.item == "Petty Cash" }
    }

    private var purchaseISO: String {
        Self.isoString(from: purchaseDate)
    }

    private var realizationHint: String {
        guard let account = selectedAccount else { return "" }
        let anchor = Cycle.cycleFor(isoDate: purchaseISO).anchorISO
        return DisplayLabels.settlementHint(
            isStatement: account.settlement == .statement,
            anchorISO: anchor
        )
    }

    private var customSplitSumOK: Bool? {
        guard splitMode == 2, let total = amountCentavos() else { return nil }
        guard let f = InputBounds.centavos(fromPesosText: customFern),
              let s = InputBounds.centavos(fromPesosText: customStark)
        else { return false }
        return f + s == total
    }

    private var canSave: Bool {
        guard amountCentavos() != nil, selectedAccountId != nil else { return false }
        if cookieJarOn {
            if jarKind == .income, jarSourceId == nil { return false }
            return pettyCashCategory != nil
        }
        guard selectedCategoryId != nil else { return false }
        if splitMode == 2 { return customSplitSumOK == true }
        return true
    }

    var body: some View {
        Group {
            if wrapInNavigationStack {
                NavigationStack { formScroll }
            } else {
                formScroll
            }
        }
    }

    private var formScroll: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heroAmount
                    detailsSection
                    splitSection
                    dateSection
                    jarSection
                    if let error {
                        Text(error)
                            .font(PantominaFont.caption)
                            .foregroundStyle(Color.pantomina.terraDeep)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.pantomina.ground.ignoresSafeArea())
            .tint(Color.pantomina.quietAccent)
            .toolbarBackground(Color.pantomina.ground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        PetTitle(formPetTitle ?? (isEditing ? "Edit the pile" : "Add to the pile"))
                        if formPetTitle == nil {
                            Text(isEditing ? "Update entry" : "New entry")
                                .font(PantominaFont.caption)
                                .foregroundStyle(Color.pantomina.muted)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                stickySave
            }
            .overlay(alignment: .bottom) {
                if savedToast {
                    Text(isEditing ? "Updated." : "Saved. Team effort.")
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.pantomina.ink)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .padding(.bottom, 72)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .sheet(isPresented: $showCategoryPicker) {
                SearchablePickList(
                    title: "Category",
                    items: categoryPickItems,
                    selection: $selectedCategoryId
                )
            }
            .sheet(isPresented: $showAccountPicker) {
                SearchablePickList(
                    title: "Payment method",
                    items: accountPickItems,
                    selection: $selectedAccountId
                )
            }
            .sheet(isPresented: $showJarSourcePicker) {
                SearchablePickList(
                    title: "Jar source",
                    items: jarSources.sorted { $0.label < $1.label }.map {
                        SearchablePickItem(
                            id: $0.id,
                            title: $0.label,
                            subtitle: $0.kind == .unit ? "Unit" : "Person"
                        )
                    },
                    selection: $jarSourceId
                )
            }
            .onAppear {
                try? SeedCatalog.seedDemoJarIfNeeded(into: modelContext)
                try? modelContext.save()
                if let capturePrefill, !didPrefillEdit {
                    applyCapturePrefill(capturePrefill)
                    didPrefillEdit = true
                } else if let tx = editingTransaction, !didPrefillEdit {
                    prefill(from: tx)
                    didPrefillEdit = true
                } else if editingTransaction == nil, capturePrefill == nil {
                    if selectedAccountId == nil {
                        selectedAccountId = orderedAccounts().first?.id
                    }
                    if selectedCategoryId == nil {
                        selectedCategoryId = orderedCategories().first?.id
                    }
                    applyAccountDefaults()
                }
            }
            .onDisappear {
                focusedField = nil
            }
            .onChange(of: selectedAccountId) { _, _ in
                if skipAccountDefaults {
                    skipAccountDefaults = false
                    return
                }
                applyAccountDefaults()
            }
    }

    private var heroAmount: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Amount")
                .font(PantominaFont.caption)
                .foregroundStyle(Color.pantomina.muted)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("₱")
                    .font(PantominaFont.heroAmount(centavos: amountCentavos() ?? 0))
                    .foregroundStyle(Color.pantomina.muted)
                TextField("0.00", text: $amountText)
                    .font(PantominaFont.heroAmount(centavos: amountCentavos() ?? 0))
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .amount)
                    .monospacedDigit()
                    .foregroundStyle(amountText.isEmpty ? Color(hex: "#C6C2BA") : Color.pantomina.ink)
                    .accessibilityLabel("Amount")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.pantomina.rule).frame(height: 1)
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if cookieJarOn {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Category")
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.muted)
                    Text(pettyCashCategory?.displayName ?? "Petty Cash")
                        .font(PantominaFont.body)
                        .foregroundStyle(Color.pantomina.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
                Text("Jar rows stay on Petty Cash, a system tag rather than a second utility bill.")
                    .font(PantominaFont.caption)
                    .foregroundStyle(Color.pantomina.muted)
                    .padding(.bottom, 8)
            } else {
                pickRow(
                    title: "Category",
                    value: selectedCategory?.displayName ?? "Choose",
                    placeholder: selectedCategory == nil,
                    showRule: false
                ) {
                    showCategoryPicker = true
                }
            }
            pickRow(
                title: "Payment method",
                value: selectedAccount.map {
                    $0.displayLabel(fernName: fernName, starkName: starkName)
                } ?? "Choose",
                placeholder: selectedAccount == nil
            ) {
                showAccountPicker = true
            }
            if !realizationHint.isEmpty {
                Text(realizationHint)
                    .font(PantominaFont.caption)
                    .foregroundStyle(Color.pantomina.muted)
                    .padding(.vertical, 2)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Paid by")
                    .font(PantominaFont.caption)
                    .foregroundStyle(Color.pantomina.muted)
                QuietSegmented(
                    options: [
                        (fernName, PersonId.fern),
                        (starkName, PersonId.stark),
                    ],
                    selection: $paidBy,
                    enabled: !cookieJarOn
                )
            }
            .padding(.top, 10)
            .padding(.bottom, 2)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.pantomina.innerRule).frame(height: 1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 14)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.pantomina.rule).frame(height: 1)
        }
    }

    private var splitSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Split")
                .font(PantominaFont.caption)
                .foregroundStyle(Color.pantomina.muted)
            if cookieJarOn {
                Text("Just mine")
                    .font(PantominaFont.body)
                    .foregroundStyle(Color.pantomina.ink)
                Text("Jar cash doesn't add to \(starkName)'s bill due. Keep unit shares off The split.")
                    .font(PantominaFont.caption)
                    .foregroundStyle(Color.pantomina.muted)
            } else {
                QuietSegmented(
                    options: [
                        ("Just mine", 0),
                        ("50·50", 1),
                        ("Custom", 2),
                    ],
                    selection: $splitMode
                )
                if splitMode == 2 {
                    HStack(spacing: 10) {
                        customSplitField(
                            name: fernName,
                            text: $customFern,
                            field: .customFern,
                            fromFern: true,
                            invalid: customSplitSumOK == false
                        )
                        customSplitField(
                            name: starkName,
                            text: $customStark,
                            field: .customStark,
                            fromFern: false,
                            invalid: customSplitSumOK == false
                        )
                    }
                    if let ok = customSplitSumOK {
                        Text(ok ? "Splits add up." : "Splits must add up to the amount.")
                            .font(PantominaFont.caption.weight(ok ? .regular : .medium))
                            .foregroundStyle(ok ? Color.pantomina.quietAccent : Color(hex: "#8A4C2A"))
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.pantomina.rule).frame(height: 1)
        }
    }

    private func customSplitField(
        name: String,
        text: Binding<String>,
        field: Field,
        fromFern: Bool,
        invalid: Bool
    ) -> some View {
        HStack {
            Text("\(name) ₱")
                .font(PantominaFont.caption)
                .foregroundStyle(Color.pantomina.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 6)
            TextField("0.00", text: text)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: field)
                .multilineTextAlignment(.trailing)
                .font(PantominaFont.body.weight(.medium).monospacedDigit())
                .foregroundStyle(Color.pantomina.ink)
                .onChange(of: text.wrappedValue) { _, new in
                    autofill(fromFern: fromFern, text: new)
                }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(Color.pantomina.card)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(invalid ? Color(hex: "#8A4C2A") : Color.pantomina.rule, lineWidth: 1)
        )
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            DatePicker(
                "When it happened",
                selection: $purchaseDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .font(PantominaFont.body)
            .frame(minHeight: 44)
            TextField("Note", text: $note)
                .font(PantominaFont.body)
                .focused($focusedField, equals: .note)
                .frame(minHeight: 44)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.pantomina.innerRule).frame(height: 1)
                }
                .onChange(of: note) { _, new in
                    let clamped = InputBounds.clampNote(new)
                    if clamped != new { note = clamped }
                }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.pantomina.rule).frame(height: 1)
        }
    }

    private var jarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Cookie Jar", isOn: $cookieJarOn)
                .font(PantominaFont.body)
                .tint(Color.pantomina.quietAccent)
                .frame(minHeight: 44)
                .onChange(of: cookieJarOn) { _, on in
                    if on { applyJarDefaults() }
                }
            if cookieJarOn {
                QuietSegmented(
                    options: [
                        ("In", CookieJar.Kind.income),
                        ("Spend", CookieJar.Kind.spend),
                        ("Borrow", CookieJar.Kind.borrow),
                    ],
                    selection: $jarKind
                )
                pickRow(
                    title: "Source",
                    value: jarSources.first { $0.id == jarSourceId }?.label
                        ?? (jarKind == .income ? "Choose" : "Optional"),
                    placeholder: jarSourceId == nil
                ) {
                    showJarSourcePicker = true
                }
                Text(jarKindFooter)
                    .font(PantominaFont.caption)
                    .foregroundStyle(Color.pantomina.muted)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.pantomina.rule).frame(height: 1)
        }
    }

    private var jarKindFooter: String {
        switch jarKind {
        case .income:
            return "Unit shares come In here. Full internet/water stays on Receipts."
        case .spend:
            return "Spend dips the jar."
        case .borrow:
            return "Borrow is expected back."
        }
    }

    private var stickySave: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.pantomina.rule).frame(height: 1)
            QuietPrimaryButton(title: "Save", enabled: canSave, action: save)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 10)
        }
        .background(Color.pantomina.ground)
    }

    private func pickRow(
        title: String,
        value: String,
        placeholder: Bool = false,
        showRule: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.muted)
                    Text(value)
                        .font(PantominaFont.body)
                        .foregroundStyle(placeholder ? Color(hex: "#9A9691") : Color.pantomina.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(PantominaFont.caption)
                    .foregroundStyle(Color.pantomina.quietAccent)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            if showRule {
                Rectangle().fill(Color.pantomina.innerRule).frame(height: 1)
            }
        }
    }

    private var categoryPickItems: [SearchablePickItem] {
        orderedCategories().map { SearchablePickItem(id: $0.id, title: $0.displayName) }
    }

    private var accountPickItems: [SearchablePickItem] {
        orderedAccounts().map {
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
        }
    }

    private func orderedCategories() -> [CategoryRecord] {
        let recent = recentIds(from: recentCategoryIdsRaw)
        let byId = Dictionary(uniqueKeysWithValues: pickerCategories.map { ($0.id, $0) })
        let head = recent.compactMap { byId[$0] }
        let tail = pickerCategories.filter { !recent.contains($0.id) }
        return head + tail
    }

    private func orderedAccounts() -> [AccountRecord] {
        let recent = recentIds(from: recentAccountIdsRaw)
        let byId = Dictionary(uniqueKeysWithValues: activeAccounts.map { ($0.id, $0) })
        let head = recent.compactMap { byId[$0] }
        let tail = activeAccounts.filter { !recent.contains($0.id) }
        return head + tail
    }

    private func recentIds(from raw: String) -> [String] {
        raw.split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }

    private func bumpRecent(id: String, raw: inout String) {
        var ids = recentIds(from: raw).filter { $0 != id }
        ids.insert(id, at: 0)
        raw = ids.prefix(3).joined(separator: ",")
    }

    private func applyAccountDefaults() {
        guard let account = selectedAccount else { return }
        if cookieJarOn {
            applyJarDefaults()
            return
        }
        switch account.scope {
        case .fern:
            paidBy = .fern
            splitMode = 0
        case .stark:
            paidBy = .stark
            splitMode = 0
        case .household, .business:
            splitMode = 1
        }
    }

    private func applyJarDefaults() {
        if let petty = pettyCashCategory {
            selectedCategoryId = petty.id
        }
        splitMode = 0
        paidBy = .fern
    }

    private func prefill(from tx: TransactionRecord) {
        skipAccountDefaults = true
        amountText = String(format: "%.2f", Double(tx.amountC) / 100)
        selectedAccountId = tx.accountId
        selectedCategoryId = tx.categoryId
        paidBy = tx.paidBy
        note = tx.note ?? ""
        purchaseDate = Self.date(fromISO: tx.purchaseDate) ?? Date()

        let half = tx.amountC / 2
        let justMine = (tx.paidBy == .fern && tx.allocStarkC == 0 && tx.allocFernC == tx.amountC)
            || (tx.paidBy == .stark && tx.allocFernC == 0 && tx.allocStarkC == tx.amountC)
        if justMine {
            splitMode = 0
        } else if abs(tx.allocFernC - half) <= 1 && abs(tx.allocStarkC - (tx.amountC - half)) <= 1 {
            splitMode = 1
        } else {
            splitMode = 2
            customFern = String(format: "%.2f", Double(tx.allocFernC) / 100)
            customStark = String(format: "%.2f", Double(tx.allocStarkC) / 100)
        }

        if let kind = tx.jarKind {
            cookieJarOn = true
            jarKind = kind
            jarSourceId = tx.jarSourceId
            applyJarDefaults()
        } else {
            cookieJarOn = false
            jarKind = .spend
            jarSourceId = nil
        }
    }

    private func applyCapturePrefill(_ card: CaptureParse.Card) {
        skipAccountDefaults = true
        amountText = String(format: "%.2f", Double(card.amountC) / 100)
        selectedAccountId = card.accountId
        selectedCategoryId = card.categoryId
        paidBy = card.paidBy
        note = card.merchant ?? ""
        switch card.split {
        case .justMine, .contribution:
            splitMode = 0
        case .fiftyFifty:
            splitMode = 1
        }
    }

    private func amountCentavos() -> Int? {
        InputBounds.centavos(fromPesosText: amountText)
    }

    private func autofill(fromFern: Bool, text: String) {
        guard let total = amountCentavos(), let part = InputBounds.centavos(fromPesosText: text) else { return }
        let other = max(0, total - part)
        if fromFern {
            customStark = String(format: "%.2f", Double(other) / 100)
        } else {
            customFern = String(format: "%.2f", Double(other) / 100)
        }
    }

    private func save() {
        error = nil
        focusedField = nil
        let cleanedAmount = amountText.replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let pesos = Double(cleanedAmount), pesos.isFinite {
            let rawC = Int((pesos * 100).rounded())
            if rawC > InputBounds.maxAmountC {
                error = "Couldn't save. Amount is too large."
                return
            }
        }
        guard let amountC = amountCentavos() else {
            error = "Couldn't save. Enter an amount."
            return
        }
        guard let accountId = selectedAccountId else {
            error = "Couldn't save. Choose category and payment method."
            return
        }
        let categoryId: String
        if cookieJarOn {
            guard let pettyId = pettyCashCategory?.id else {
                error = "Couldn't save. Petty Cash category missing."
                return
            }
            categoryId = pettyId
        } else if let selectedCategoryId {
            categoryId = selectedCategoryId
        } else {
            error = "Couldn't save. Choose category and payment method."
            return
        }
        let account = selectedAccount
        let effectiveSplit = cookieJarOn ? 0 : splitMode
        let intended: Allocation
        switch effectiveSplit {
        case 0:
            intended = AllocationDefaults.justMine(amountC: amountC, paidBy: cookieJarOn ? .fern : paidBy)
        case 1:
            intended = AllocationDefaults.fiftyFifty(amountC: amountC)
        default:
            guard let f = InputBounds.centavos(fromPesosText: customFern),
                  let s = InputBounds.centavos(fromPesosText: customStark),
                  f + s == amountC
            else {
                error = "Couldn't save. Custom split must add up."
                return
            }
            intended = Allocation(fern: f, stark: s)
        }
        let scope = account?.scope ?? .household
        let allocation = AllocationRouting.record(
            intended: intended,
            accountScope: scope,
            paidBy: cookieJarOn ? .fern : paidBy
        )

        let decision = Realization.decide(
            purchaseISO: purchaseISO,
            settlement: account?.settlement ?? .instant,
            statementCutoff: account?.statementCutoff
        )

        let category = categories.first { $0.id == categoryId }
        let settlementRole: SettlementRole? = {
            guard let category, category.system else { return nil }
            switch category.item {
            case "Partner Contribution": return .contribution
            case "Partner Receivable": return .receivable
            case "Fund Move": return .fundMove
            case "Loan Payment": return .loanPayment
            default: return nil
            }
        }()

        let noteValue: String? = {
            let trimmed = InputBounds.clampNote(note).trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }()

        if cookieJarOn, jarKind == .income, jarSourceId == nil {
            error = "Couldn't save. Choose which unit or person paid In."
            return
        }

        let resolvedJarKind: CookieJar.Kind? = cookieJarOn ? jarKind : nil
        let resolvedJarReturned: Bool? = resolvedJarKind == .borrow ? false : nil
        let savePaidBy: PersonId = cookieJarOn ? .fern : paidBy

        if let existing = editingTransaction {
            existing.purchaseDate = purchaseISO
            existing.realizedDate = decision.realizedDate
            existing.realizedStatus = decision.status
            existing.proposedRealizedDate = decision.proposedRealizedDate
            existing.amountC = amountC
            existing.accountId = accountId
            existing.categoryId = categoryId
            existing.paidByRaw = savePaidBy.rawValue
            existing.allocFernC = allocation.fern
            existing.allocStarkC = allocation.stark
            existing.settlementRole = settlementRole
            existing.note = noteValue
            existing.jarKind = resolvedJarKind
            existing.jarSourceId = cookieJarOn ? jarSourceId : nil
            existing.jarReturned = resolvedJarReturned
            existing.updatedAt = .now
        } else {
            let tx = TransactionRecord(
                purchaseDate: purchaseISO,
                realizedDate: decision.realizedDate,
                realizedStatus: decision.status,
                proposedRealizedDate: decision.proposedRealizedDate,
                amountC: amountC,
                accountId: accountId,
                categoryId: categoryId,
                paidBy: savePaidBy,
                allocation: allocation,
                settlementRole: settlementRole,
                note: noteValue,
                merchant: capturePrefill?.merchant,
                jarKind: resolvedJarKind,
                jarSourceId: cookieJarOn ? jarSourceId : nil,
                jarReturned: resolvedJarReturned
            )
            modelContext.insert(tx)
        }

        do {
            try modelContext.save()
            let catId = categoryId
            let accId = accountId
            let editing = isEditing
            Task { @MainActor in
                bumpRecent(id: catId, raw: &recentCategoryIdsRaw)
                bumpRecent(id: accId, raw: &recentAccountIdsRaw)
                PantominaMotion.run(reduceMotion) { savedToast = true }
                if !editing {
                    amountText = ""
                    note = ""
                    cookieJarOn = false
                    jarKind = .spend
                    jarSourceId = nil
                    applyAccountDefaults()
                }
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                PantominaMotion.run(reduceMotion) { savedToast = false }
                if presentsAsSheet { dismiss() }
                onSaved?()
            }
        } catch {
            self.error = "Couldn't save. Try again."
        }
    }

    private static func isoString(from date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private static func date(fromISO iso: String) -> Date? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: iso)
    }
}

struct SearchablePickItem: Identifiable, Hashable {
    var id: String
    var title: String
    var subtitle: String?
}

struct SearchablePickList: View {
    let title: String
    let items: [SearchablePickItem]
    @Binding var selection: String?
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [SearchablePickItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return items }
        return items.filter {
            $0.title.localizedCaseInsensitiveContains(q)
                || ($0.subtitle?.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { item in
                Button {
                    selection = item.id
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .foregroundStyle(Color.pantomina.ink)
                            if let subtitle = item.subtitle {
                                Text(subtitle)
                                    .font(PantominaFont.caption)
                                    .foregroundStyle(Color.pantomina.muted)
                            }
                        }
                        Spacer()
                        if selection == item.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.pantomina.sage)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $query, prompt: "Search")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
