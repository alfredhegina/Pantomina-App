import SwiftUI
import SwiftData

struct BaggageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var loans: [LoanRecord]
    @Query private var people: [PersonRecord]

    @State private var journalLoanId: String?
    @State private var journalNote = ""

    private var fernName: String { people.first { $0.id == .fern }?.name ?? "Fern" }
    private var active: [LoanRecord] {
        loans.filter { $0.statusRaw == Loan.Status.active.rawValue }
            .sorted { ($0.snowballOrder ?? 999) < ($1.snowballOrder ?? 999) }
    }
    private var archived: [LoanRecord] {
        loans.filter { $0.statusRaw == Loan.Status.done.rawValue }
    }
    private var journalLoan: LoanRecord? {
        guard let journalLoanId else { return nil }
        return loans.first { $0.id == journalLoanId }
    }

    var body: some View {
        List {
            if active.isEmpty && archived.isEmpty {
                Text("No loans yet. Demo seed adds UB Personal after onboarding.")
                    .font(PantominaFont.body)
                    .foregroundStyle(Color.pantomina.muted)
            }

            if !active.isEmpty {
                Section("Still carrying") {
                    ForEach(active, id: \.id) { loan in
                        loanRow(loan)
                    }
                }
            }

            if !archived.isEmpty {
                Section {
                    ForEach(archived, id: \.id) { loan in
                        loanRow(loan)
                    }
                } header: {
                    Text("Baggage we put down")
                } footer: {
                    Text("Paid off. Kept for the story, not the due.")
                        .font(PantominaFont.caption)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.pantomina.ground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    PetTitle("Baggage We're Carrying")
                    Text("Loans")
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.muted)
                }
            }
        }
        .onAppear {
            try? SeedCatalog.seedDemoLoansIfNeeded(into: modelContext)
            try? modelContext.save()
        }
        .sheet(isPresented: Binding(
            get: { journalLoanId != nil },
            set: { if !$0 { journalLoanId = nil } }
        )) {
            if let loan = journalLoan {
                journalSheet(loan)
            }
        }
    }

    private func loanRow(_ loan: LoanRecord) -> some View {
        let snap = loan.engineLoan
        let balance = loan.derivedBalanceC
        let cost = Loan.costOfBorrowingC(totalLoanC: snap.totalLoanC, principalC: snap.principalC)
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(snap.lender)
                    .font(PantominaFont.body.weight(.semibold))
                Spacer()
                Text(formatPeso(balance))
                    .font(PantominaFont.amount)
                    .monospacedDigit()
            }
            Text(snap.description)
                .font(PantominaFont.caption)
                .foregroundStyle(Color.pantomina.muted)
            Text(snap.purpose)
                .font(PantominaFont.body)
            if snap.status == .active {
                Text(baggageSnowballChips(snap))
                    .font(PantominaFont.caption)
                    .foregroundStyle(Color.pantomina.muted)
            }
            HStack {
                Text("\(snap.paidMonths)/\(snap.termMonths) months")
                    .font(PantominaFont.caption.monospacedDigit())
                Spacer()
                Text(aprLabel(snap.aprPercent))
                    .font(PantominaFont.caption)
            }
            .foregroundStyle(Color.pantomina.muted)
            if cost > 0 {
                Text("Cost of borrowing \(formatPeso(cost))")
                    .font(PantominaFont.caption)
                    .foregroundStyle(Color.pantomina.muted)
            }
            if !snap.journal.isEmpty {
                ForEach(Array(snap.journal.enumerated()), id: \.offset) { _, entry in
                    Text("\(DisplayLabels.displayDate(iso: entry.dateISO)) · \(entry.note)")
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.ink.opacity(0.8))
                }
            }
            if snap.status == .active {
                Button("Add a note") {
                    journalNote = ""
                    journalLoanId = loan.id
                }
                .font(PantominaFont.caption.weight(.medium))
                .foregroundStyle(Color.pantomina.sageDeep)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(snap.description), \(fernName), \(formatPeso(balance)) left, \(snap.paidMonths) of \(snap.termMonths) months")
    }

    private func aprLabel(_ apr: Double) -> String {
        if apr == 0 { return "0% APR" }
        return String(format: "%.1f%% APR", apr)
    }

    private func baggageSnowballChips(_ snap: Loan.Snapshot) -> String {
        let order = snap.snowballOrder.map(String.init) ?? "-"
        var parts = ["Pay next · #\(order)"]
        if Snowball.showsBatchChrome(loans: loans.map(\.engineLoan)) {
            parts.append("Batch \(snap.snowballBatch.map(String.init) ?? "1")")
        }
        parts.append(DisplayLabels.loanStrategy(snap.strategy))
        return parts.joined(separator: " · ")
    }

    private func journalSheet(_ loan: LoanRecord) -> some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What did you decide?", text: $journalNote, axis: .vertical)
                        .lineLimit(3...6)
                        .onChange(of: journalNote) { _, new in
                            let clamped = InputBounds.clampNote(new)
                            if clamped != new { journalNote = clamped }
                        }
                } footer: {
                    Text("Notes stay on this loan. No balance edits here.")
                        .font(PantominaFont.caption)
                }
            }
            .navigationTitle("Decision note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { journalLoanId = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let iso = Cycle.cycleFor(isoDate: Self.todayISO()).anchorISO
                        loan.appendJournal(dateISO: iso, note: InputBounds.clampNote(journalNote))
                        try? modelContext.save()
                        journalLoanId = nil
                    }
                    .disabled(journalNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
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
