import SwiftUI
import SwiftData

/// Where the Money Sleeps — account map by scope; spoken-for from envelopes. Not Empire NW.
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
        List {
            if visibleAccounts.isEmpty {
                Section {
                    Text("No pockets yet. Add accounts in The Fine Print when you’re ready.")
                        .foregroundStyle(Color.pantomina.muted)
                }
            } else {
                ForEach(Scope.allCases, id: \.rawValue) { scope in
                    let rows = visibleAccounts.filter { $0.scope == scope }
                    if !rows.isEmpty {
                        Section {
                            ForEach(rows, id: \.id) { account in
                                let pocket = pocketResult(for: account)
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(account.displayLabel(fernName: fernName, starkName: starkName))
                                            .foregroundStyle(Color.pantomina.ink)
                                        if pocket.spokenForC > 0 {
                                            Text("Spoken for \(formatPeso(pocket.spokenForC))")
                                                .font(PantominaFont.caption)
                                                .foregroundStyle(Color.pantomina.muted)
                                        }
                                    }
                                    Spacer()
                                    if pocket.source == .unknown {
                                        Text("—")
                                            .foregroundStyle(Color.pantomina.muted)
                                    } else {
                                        Text(formatPeso(pocket.balanceC))
                                            .font(PantominaFont.body.weight(.semibold))
                                            .monospacedDigit()
                                            .foregroundStyle(Color.pantomina.ink)
                                    }
                                }
                            }
                        } header: {
                            Text(scopeHeader(scope))
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.pantomina.ground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                PetTitle("Where the Money Sleeps")
            }
        }
        .safeAreaInset(edge: .bottom) {
            Text("Spoken for is earmarked in funds — not a second pile. Edit pockets on Receipts.")
                .font(PantominaFont.caption)
                .foregroundStyle(Color.pantomina.muted)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.pantomina.ground.opacity(0.95))
        }
    }

    private func scopeHeader(_ scope: Scope) -> String {
        switch scope {
        case .household: return "Shared"
        case .fern: return fernName
        case .stark: return starkName
        case .business: return "Business"
        }
    }
}
