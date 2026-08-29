import SwiftUI
import SwiftData

struct AddEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var accounts: [AccountRecord]
    @Query private var categories: [CategoryRecord]
    @Query private var people: [PersonRecord]

    /// When false, view is presented as a sheet and dismisses after save.
    var presentsAsSheet: Bool = true

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
    @FocusState private var focusedField: Field?

    private enum Field {
        case amount, customFern, customStark, note
    }

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
        pickerCategories.first { $0.id == selectedCategoryId }
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    heroAmount
                    detailsCard
                    splitCard
                    dateCard
                    if let error {
                        Text(error)
                            .font(PantominaFont.caption)
                            .foregroundStyle(Color.pantomina.rose)
                    }
                }
                .padding(Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.pantomina.ground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        PetTitle("Add to the pile")
                        Text("New entry")
                            .font(PantominaFont.caption)
                            .foregroundStyle(Color.pantomina.muted)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                stickySave
            }
            .overlay(alignment: .bottom) {
                if savedToast {
                    Text("Saved. Team effort.")
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
            .onAppear {
                if selectedAccountId == nil {
                    selectedAccountId = orderedAccounts().first?.id
                }
                if selectedCategoryId == nil {
                    selectedCategoryId = orderedCategories().first?.id
                }
                applyAccountDefaults()
            }
            .onDisappear {
                focusedField = nil
            }
            .onChange(of: selectedAccountId) { _, _ in
                applyAccountDefaults()
            }
        }
    }

    private var heroAmount: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Eyebrow("Amount")
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("₱")
                        .font(PantominaFont.amount)
                        .foregroundStyle(Color.pantomina.muted)
                    TextField("0.00", text: $amountText)
                        .font(PantominaFont.amount)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .amount)
                        .monospacedDigit()
                        .foregroundStyle(Color.pantomina.ink)
                        .accessibilityLabel("Amount")
                }
            }
        }
    }

    private var detailsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.md) {
                pickRow(title: "Category", value: selectedCategory?.displayName ?? "Choose") {
                    showCategoryPicker = true
                }
                Divider().overlay(Color.pantomina.hairline)
                pickRow(title: "Payment method", value: selectedAccount.map {
                    $0.displayLabel(fernName: fernName, starkName: starkName)
                } ?? "Choose") {
                    showAccountPicker = true
                }
                if !realizationHint.isEmpty {
                    Text(realizationHint)
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.muted)
                }
                Divider().overlay(Color.pantomina.hairline)
                Text("Paid by")
                    .font(PantominaFont.caption)
                    .foregroundStyle(Color.pantomina.muted)
                Picker("Paid by", selection: $paidBy) {
                    Text(fernName).tag(PersonId.fern)
                    Text(starkName).tag(PersonId.stark)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var splitCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Split")
                    .font(PantominaFont.caption)
                    .foregroundStyle(Color.pantomina.muted)
                Picker("Split", selection: $splitMode) {
                    Text("Just mine").tag(0)
                    Text("50·50").tag(1)
                    Text("Custom").tag(2)
                }
                .pickerStyle(.segmented)
                if splitMode == 2 {
                    TextField("\(fernName) ₱", text: $customFern)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .customFern)
                        .onChange(of: customFern) { _, new in autofill(fromFern: true, text: new) }
                    TextField("\(starkName) ₱", text: $customStark)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .customStark)
                        .onChange(of: customStark) { _, new in autofill(fromFern: false, text: new) }
                    if let ok = customSplitSumOK {
                        Text(ok ? "Splits add up." : "Splits must add up to the amount.")
                            .font(PantominaFont.caption)
                            .foregroundStyle(ok ? Color.pantomina.sageDeep : Color.pantomina.rose)
                    }
                }
            }
        }
    }

    private var dateCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.md) {
                DatePicker(
                    "When it happened",
                    selection: $purchaseDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                TextField("Note", text: $note)
                    .focused($focusedField, equals: .note)
                    .onChange(of: note) { _, new in
                        let clamped = InputBounds.clampNote(new)
                        if clamped != new { note = clamped }
                    }
            }
        }
    }

    private var stickySave: some View {
        VStack(spacing: 0) {
            Divider().overlay(Color.pantomina.hairline)
            Button(action: save) {
                Text("Save")
                    .font(PantominaFont.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .background(Color.pantomina.sage)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.radius, style: .continuous))
            }
            .buttonStyle(SageButtonStyle())
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.sm)
            .background(Color.pantomina.ground)
        }
    }

    private func pickRow(title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.muted)
                    Text(value)
                        .font(PantominaFont.body)
                        .foregroundStyle(Color.pantomina.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(PantominaFont.caption)
                    .foregroundStyle(Color.pantomina.sage)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        guard let accountId = selectedAccountId, let categoryId = selectedCategoryId else {
            error = "Couldn't save. Choose category and payment method."
            return
        }
        let allocation: Allocation
        switch splitMode {
        case 0:
            allocation = AllocationDefaults.justMine(amountC: amountC, paidBy: paidBy)
        case 1:
            allocation = AllocationDefaults.fiftyFifty(amountC: amountC)
        default:
            guard let f = InputBounds.centavos(fromPesosText: customFern),
                  let s = InputBounds.centavos(fromPesosText: customStark),
                  f + s == amountC
            else {
                error = "Couldn't save. Custom split must add up."
                return
            }
            allocation = Allocation(fern: f, stark: s)
        }

        let account = selectedAccount
        let decision = Realization.decide(
            purchaseISO: purchaseISO,
            settlement: account?.settlement ?? .instant,
            statementCutoff: account?.statementCutoff
        )

        let tx = TransactionRecord(
            purchaseDate: purchaseISO,
            realizedDate: decision.realizedDate,
            realizedStatus: decision.status,
            proposedRealizedDate: decision.proposedRealizedDate,
            amountC: amountC,
            accountId: accountId,
            categoryId: categoryId,
            paidBy: paidBy,
            allocation: allocation,
            note: {
                let trimmed = InputBounds.clampNote(note).trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }()
        )
        modelContext.insert(tx)
        do {
            try modelContext.save()
            bumpRecent(id: categoryId, raw: &recentCategoryIdsRaw)
            bumpRecent(id: accountId, raw: &recentAccountIdsRaw)
            PantominaMotion.run(reduceMotion) { savedToast = true }
            amountText = ""
            note = ""
            applyAccountDefaults()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                PantominaMotion.run(reduceMotion) { savedToast = false }
                if presentsAsSheet { dismiss() }
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
