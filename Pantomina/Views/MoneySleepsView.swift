import SwiftUI
import SwiftData

/// Where the Money Sleeps: account map by scope; spoken-for from envelopes. Not Empire NW.
struct MoneySleepsView: View {
    @Query private var people: [PersonRecord]
    @Query(sort: \AccountRecord.baseName) private var accounts: [AccountRecord]
    @Query private var funds: [FundRecord]
    @Query private var loans: [LoanRecord]
    @Query private var transactions: [TransactionRecord]
    @Query private var categories: [CategoryRecord]

    private var fernName: String { people.first { $0.id == .fern }?.name ?? "Fern" }
    private var starkName: String { people.first { $0.id == .stark }?.name ?? "Stark" }

    private var categoryFlow: [String: FlowType] {
        Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.flow) })
    }

    private var visibleAccounts: [AccountRecord] {
        accounts.filter { !$0.archived }
    }

    private var totalSpokenForC: Int {
        visibleAccounts.reduce(0) { $0 + spokenForC(accountId: $1.id) }
    }

    private var sleepsSubtitle: String {
        let n = visibleAccounts.count
        if n == 0 { return "No pockets yet" }
        let pocketWord = n == 1 ? "pocket" : "pockets"
        if totalSpokenForC > 0 {
            return "\(n) \(pocketWord) · spoken for \(formatPeso(totalSpokenForC))"
        }
        return "\(n) \(pocketWord)"
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if visibleAccounts.isEmpty {
                    emptyState
                } else {
                    ForEach(Scope.allCases, id: \.rawValue) { scope in
                        let rows = visibleAccounts.filter { $0.scope == scope }
                        if !rows.isEmpty {
                            scopeSection(scope, rows: rows)
                        }
                    }
                }
            }
        }
        .background(Color.pantomina.ground)
        .toolbarBackground(Color.pantomina.ground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    PetTitle("Where the Money Sleeps")
                    Text(sleepsSubtitle)
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Text("Spoken for is earmarked in funds, not a second pile. Edit pockets on Receipts.")
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
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("No pockets yet. Add accounts in The Fine Print when you're ready.")
                .font(PantominaFont.body)
                .foregroundStyle(Color.pantomina.muted)
            NavigationLink {
                SettingsView()
            } label: {
                Text("Open The Fine Print")
                    .font(PantominaFont.body.weight(.semibold))
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .foregroundStyle(Color.pantomina.quietAccent)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(hex: "#C6CFC9"), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open The Fine Print")
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.pantomina.rule).frame(height: 1)
        }
    }

    private func scopeSection(_ scope: Scope, rows: [AccountRecord]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(scopeHeader(scope))
                .font(PantominaFont.caption.weight(.semibold))
                .foregroundStyle(Color.pantomina.muted)
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.pantomina.rule).frame(height: 1)
                }

            ForEach(rows, id: \.id) { account in
                pocketRow(account)
            }
        }
    }

    private func pocketRow(_ account: AccountRecord) -> some View {
        let pocket = pocketResult(for: account)
        return HStack(alignment: .top, spacing: 12) {
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
        .overlay(alignment: .top) {
            Rectangle().fill(Color.pantomina.innerRule).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func scopeHeader(_ scope: Scope) -> String {
        DisplayLabels.scope(scope, fernName: fernName, starkName: starkName)
    }
}
