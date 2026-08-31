import SwiftUI
import SwiftData

struct CookieJarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [TransactionRecord]
    @Query private var jarSources: [JarSourceRecord]
    @Query private var accounts: [AccountRecord]
    @Query private var categories: [CategoryRecord]
    @Query private var people: [PersonRecord]

    @State private var filterSourceId: String?
    @State private var toast: String?
    @State private var showAdd = false
    @State private var pendingReturn: CookieJar.Entry?

    private var fernName: String { people.first { $0.id == .fern }?.name ?? "Fern" }

    private var jarEntries: [CookieJar.Entry] {
        transactions.compactMap { $0.asJarEntry() }
    }

    private var activeCycleISO: String {
        Cycle.cycleFor(isoDate: Self.todayISO()).anchorISO
    }

    private var statementRows: [CookieJar.StatementRow] {
        CookieJar.statement(entries: jarEntries, sourceId: filterSourceId)
    }

    private var balanceC: Int {
        CookieJar.balance(entries: jarEntries)
    }

    private var whosPaid: [CookieJar.PaidChip] {
        CookieJar.whosPaid(
            cycleISO: activeCycleISO,
            sources: jarSources.map(\.engineSource),
            entries: jarEntries
        )
    }

    private var ious: [CookieJar.Entry] {
        CookieJar.unreturnedBorrows(entries: jarEntries)
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("In the jar")
                        .foregroundStyle(Color.pantomina.muted)
                    Spacer()
                    Text(formatPeso(balanceC))
                        .font(PantominaFont.amount)
                        .foregroundStyle(Color.pantomina.ink)
                }
            }

            if !whosPaid.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.sm) {
                            ForEach(whosPaid, id: \.sourceId) { chip in
                                Button {
                                    if filterSourceId == chip.sourceId {
                                        filterSourceId = nil
                                    } else {
                                        filterSourceId = chip.sourceId
                                    }
                                } label: {
                                    Text("\(chip.label) \(chip.paid ? "✓" : "—")")
                                        .font(PantominaFont.caption.weight(.medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            filterSourceId == chip.sourceId
                                                ? Color.pantomina.sage.opacity(0.2)
                                                : Color.pantomina.card
                                        )
                                        .foregroundStyle(
                                            chip.paid ? Color.pantomina.sageDeep : Color.pantomina.muted
                                        )
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(
                                    "\(chip.label) \(chip.paid ? "paid" : "not paid")"
                                        + (filterSourceId == chip.sourceId ? ", filtering" : "")
                                )
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("Who’s paid")
                } footer: {
                    Text("Tap a unit to filter; tap again to show all.")
                        .font(PantominaFont.caption)
                }
            }

            if !ious.isEmpty {
                Section {
                    ForEach(ious, id: \.id) { iou in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(iou.note ?? sourceLabel(iou.sourceId) ?? "Borrow")
                                    .font(PantominaFont.body.weight(.medium))
                                Text(DisplayLabels.displayDate(iso: iou.dateISO))
                                    .font(PantominaFont.caption)
                                    .foregroundStyle(Color.pantomina.muted)
                            }
                            Spacer()
                            Text("(\(formatPeso(iou.amountC)))")
                                .font(PantominaFont.body.monospacedDigit())
                                .foregroundStyle(Color.pantomina.terraDeep)
                            Button("Returned") {
                                pendingReturn = iou
                            }
                            .font(PantominaFont.caption.weight(.semibold))
                            .foregroundStyle(Color.pantomina.sage)
                        }
                    }
                } header: {
                    Text("Still out")
                }
            }

            Section {
                if statementRows.isEmpty {
                    Text("Nothing in the jar yet. Tap + to add In, Spend, or Borrow.")
                        .font(PantominaFont.body)
                        .foregroundStyle(Color.pantomina.muted)
                } else {
                    ForEach(statementRows, id: \.entry.id) { row in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rowTitle(row))
                                    .font(PantominaFont.body.weight(.medium))
                                Text(DisplayLabels.displayDate(iso: row.entry.dateISO))
                                    .font(PantominaFont.caption)
                                    .foregroundStyle(Color.pantomina.muted)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(amountLabel(row))
                                    .font(PantominaFont.body.monospacedDigit())
                                    .foregroundStyle(amountColor(row))
                                Text(formatPeso(row.balanceAfterC))
                                    .font(PantominaFont.caption.monospacedDigit())
                                    .foregroundStyle(Color.pantomina.muted)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: {
                Text("Statement")
            } footer: {
                Text("Balance after each line. Borrows still out show in parentheses. Full internet/water stays on Receipts — unit shares come In here.")
                    .font(PantominaFont.caption)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.pantomina.ground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    PetTitle("The Cookie Jar")
                    Text("Petty cash")
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
                .accessibilityLabel("Add to the jar")
            }
        }
        .sheet(isPresented: $showAdd) {
            AddToJarSheet(
                sources: jarSources.sorted { $0.label < $1.label },
                onCancel: { showAdd = false },
                onSave: { draft in
                    saveJarDraft(draft)
                    showAdd = false
                    toast = "Added to the jar."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { toast = nil }
                }
            )
        }
        .alert(
            pendingReturn.map { "Mark “\($0.note ?? sourceLabel($0.sourceId) ?? "borrow")” returned?" }
                ?? "Mark returned?",
            isPresented: Binding(
                get: { pendingReturn != nil },
                set: { if !$0 { pendingReturn = nil } }
            )
        ) {
            Button("Returned") {
                if let id = pendingReturn?.id {
                    markReturned(id)
                }
                pendingReturn = nil
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) {
                pendingReturn = nil
            }
        } message: {
            if let iou = pendingReturn {
                Text("Puts \(formatPeso(iou.amountC)) back in the jar.")
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
            try? SeedCatalog.seedDemoJarIfNeeded(into: modelContext)
            try? modelContext.save()
        }
    }

    private func rowTitle(_ row: CookieJar.StatementRow) -> String {
        if let note = row.entry.note, !note.isEmpty { return note }
        if let label = sourceLabel(row.entry.sourceId) { return label }
        switch row.entry.kind {
        case .income: return "In"
        case .spend: return "Out"
        case .borrow: return "Borrow"
        }
    }

    private func sourceLabel(_ id: String?) -> String? {
        guard let id else { return nil }
        if let source = jarSources.first(where: { $0.id == id }) {
            return source.label
        }
        if id == "fern" { return fernName }
        return id
    }

    private func amountLabel(_ row: CookieJar.StatementRow) -> String {
        let pesos = formatPeso(row.entry.amountC)
        if row.parenthesized { return "(\(pesos))" }
        switch row.entry.kind {
        case .income: return "+\(pesos)"
        case .spend, .borrow: return "−\(pesos)"
        }
    }

    private func amountColor(_ row: CookieJar.StatementRow) -> Color {
        switch row.entry.kind {
        case .income: return Color.pantomina.sageDeep
        case .spend, .borrow: return Color.pantomina.terraDeep
        }
    }

    private func markReturned(_ entryId: String) {
        guard let tx = transactions.first(where: { $0.id == entryId }) else { return }
        tx.jarReturned = true
        tx.updatedAt = .now
        try? modelContext.save()
        toast = "Marked returned"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { toast = nil }
    }

    private func saveJarDraft(_ draft: AddToJarSheet.Draft) {
        guard
            let cash = accounts.first(where: { $0.baseName == "House cash box" && $0.scope == .household })
                ?? accounts.first(where: { !$0.archived }),
            let petty = categories.first(where: { $0.system && $0.item == "Petty Cash" })
                ?? categories.first(where: { !$0.system && $0.flow == .expense })
        else { return }

        let returned: Bool? = draft.kind == .borrow ? false : nil
        modelContext.insert(
            TransactionRecord(
                purchaseDate: draft.dateISO,
                realizedDate: draft.dateISO,
                realizedStatus: .realized,
                amountC: draft.amountC,
                accountId: cash.id,
                categoryId: petty.id,
                paidBy: .fern,
                allocation: Allocation(fern: draft.amountC, stark: 0),
                note: draft.note,
                jarKind: draft.kind,
                jarSourceId: draft.sourceId,
                jarReturned: returned
            )
        )
        try? modelContext.save()
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

private struct AddToJarSheet: View {
    enum KindTab: Int, CaseIterable {
        case income, spend, borrow

        var jarKind: CookieJar.Kind {
            switch self {
            case .income: return .income
            case .spend: return .spend
            case .borrow: return .borrow
            }
        }
    }

    struct Draft {
        var amountC: Int
        var kind: CookieJar.Kind
        var sourceId: String?
        var note: String?
        var dateISO: String
    }

    let sources: [JarSourceRecord]
    let onCancel: () -> Void
    let onSave: (Draft) -> Void

    @State private var amountText = ""
    @State private var kindTab: KindTab = .income
    @State private var sourceId: String?
    @State private var note = ""
    @State private var happenedOn = Date()
    @State private var showSourcePicker = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(Color.pantomina.terraDeep)
                    }
                }
                Section {
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                    Picker("Kind", selection: $kindTab) {
                        Text("In").tag(KindTab.income)
                        Text("Spend").tag(KindTab.spend)
                        Text("Borrow").tag(KindTab.borrow)
                    }
                    .pickerStyle(.segmented)
                    Button {
                        showSourcePicker = true
                    } label: {
                        HStack {
                            Text("Source")
                                .foregroundStyle(Color.pantomina.ink)
                            Spacer()
                            Text(sourceLabel)
                                .foregroundStyle(Color.pantomina.muted)
                        }
                    }
                    TextField("Note", text: $note)
                        .onChange(of: note) { _, new in
                            let clamped = InputBounds.clampNote(new)
                            if clamped != new { note = clamped }
                        }
                    DatePicker(
                        "When it happened",
                        selection: $happenedOn,
                        displayedComponents: .date
                    )
                } footer: {
                    Text("Full internet/water stays on Receipts. Unit shares come In here.")
                }
            }
            .navigationTitle("Add to the jar")
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
            .sheet(isPresented: $showSourcePicker) {
                SearchablePickList(
                    title: "Source",
                    items: sources.map {
                        SearchablePickItem(
                            id: $0.id,
                            title: $0.label,
                            subtitle: $0.kind == .unit ? "Unit" : "Person"
                        )
                    },
                    selection: $sourceId
                )
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var sourceLabel: String {
        if let sourceId, let source = sources.first(where: { $0.id == sourceId }) {
            return source.label
        }
        return kindTab == .income ? "Choose" : "Optional"
    }

    private func save() {
        error = nil
        guard let amountC = InputBounds.centavos(fromPesosText: amountText), amountC > 0 else {
            error = "Enter an amount."
            return
        }
        if kindTab == .income, sourceId == nil {
            error = "Choose which unit or person paid In."
            return
        }
        let noteValue = InputBounds.clampNote(note).trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(
            Draft(
                amountC: amountC,
                kind: kindTab.jarKind,
                sourceId: sourceId,
                note: noteValue.isEmpty ? nil : noteValue,
                dateISO: Self.isoString(from: happenedOn)
            )
        )
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
