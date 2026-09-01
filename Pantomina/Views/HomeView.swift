import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var people: [PersonRecord]
    @Query(sort: \TransactionRecord.purchaseDate, order: .reverse) private var transactions: [TransactionRecord]
    @Query private var categories: [CategoryRecord]
    @Query private var accounts: [AccountRecord]
    @Query private var recurringRules: [RecurringRuleRecord]
    @Query private var fundingPlans: [FundingPlanRecord]

    var onAdd: () -> Void = {}
    var onOpenBills: () -> Void = {}

    private var fern: PersonRecord? { people.first { $0.id == .fern } }
    private var stark: PersonRecord? { people.first { $0.id == .stark } }
    private var recent: [TransactionRecord] { Array(transactions.prefix(3)) }

    private var todayISO: String { Self.isoToday() }

    private var todayCycle: Cycle {
        Cycle.cycleFor(isoDate: todayISO)
    }

    private var dueNext: HomeDueNext.Strip? {
        let next = Cycle.nextHalfMonth(after: todayCycle)
        let after = Cycle.nextHalfMonth(after: next)
        return HomeDueNext.strip(
            todayISO: todayISO,
            upcoming: [
                (next.anchorISO, committedLines(for: next.anchorISO)),
                (after.anchorISO, committedLines(for: after.anchorISO)),
            ]
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if let dueNext {
                        dueNextBlock(dueNext)
                    }
                    QuietPrimaryButton(title: "Add to the pile", action: onAdd)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    recentBlock
                }
            }
            .background(Color.pantomina.ground.ignoresSafeArea())
            .toolbarBackground(Color.pantomina.ground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        PetTitle("Home")
                        Text("Cycle of \(DisplayLabels.displayDate(iso: todayCycle.anchorISO))")
                            .font(PantominaFont.caption)
                            .foregroundStyle(Color.pantomina.muted)
                    }
                }
            }
        }
    }

    private func dueNextBlock(_ strip: HomeDueNext.Strip) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onOpenBills) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Due next")
                        .font(PantominaFont.body.weight(.semibold))
                        .foregroundStyle(Color.pantomina.ink)
                    Spacer()
                    Text("\(strip.billCount) bills · \(formatPeso(strip.totalC))")
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.muted)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens Bills")

            HStack(spacing: 10) {
                ForEach(strip.cards, id: \.id) { card in
                    Button(action: onOpenBills) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(DisplayLabels.displayDateShort(iso: strip.dueISO)) · in \(card.daysUntil) days")
                                .font(PantominaFont.caption.weight(.semibold))
                                .foregroundStyle(Color.pantomina.quietAccent)
                            Text(card.title)
                                .font(PantominaFont.caption)
                                .foregroundStyle(Color.pantomina.ink)
                                .lineLimit(2)
                            Text(formatPeso(card.amountC))
                                .font(PantominaFont.body.weight(.semibold).monospacedDigit())
                                .foregroundStyle(Color.pantomina.ink)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.pantomina.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.pantomina.rule, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.pantomina.rule).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.pantomina.rule).frame(height: 1)
        }
    }

    @ViewBuilder
    private var recentBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent")
                .font(PantominaFont.body.weight(.semibold))
                .foregroundStyle(Color.pantomina.ink)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.pantomina.rule).frame(height: 1)
                }

            if recent.isEmpty {
                QuietEmptyBlock(
                    systemImage: "doc.text",
                    title: "Nothing here yet.",
                    message: "Rare quiet moment. Anything either of you spends shows up here."
                )
                .padding(.top, 48)
                .padding(.bottom, 80)
            } else {
                VStack(spacing: 0) {
                    ForEach(recent, id: \.id) { tx in
                        recentRow(tx)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func recentRow(_ tx: TransactionRecord) -> some View {
        let category = categories.first { $0.id == tx.categoryId }
        let account = accounts.first { $0.id == tx.accountId }
        let fernName = fern?.name ?? "Fern"
        let starkName = stark?.name ?? "Stark"
        return QuietLedgerRow(
            title: category?.displayName ?? "Category",
            amountC: tx.amountC,
            amountColor: Color.pantomina.ledgerAmount(flow: category?.flow),
            caption: DisplayLabels.ledgerMeta(
                eventISO: tx.purchaseDate,
                scope: account?.scope ?? .household,
                fernName: fernName,
                starkName: starkName,
                isAutomatic: tx.isJarEntry
            ),
            pendingLabel: DisplayLabels.status(tx.realizedStatus),
            dimmed: tx.realizedStatus == .projected
        )
    }

    private func committedLines(for cycleISO: String) -> [Forecast.Line] {
        let plans = fundingPlans.map(\.enginePlan)
        let excluded = Funding.excludedBillRuleIds(plans: plans)
        let projected = Projection.rows(forCycleISO: cycleISO, rules: recurringRules.map(\.engineRule))
            .filter { !excluded.contains($0.recurringRuleId) }
        let pendingCards = transactions.compactMap { tx -> Forecast.PendingCard? in
            guard tx.realizedStatus == .pending,
                  tx.proposedRealizedDate == cycleISO,
                  let cat = categories.first(where: { $0.id == tx.categoryId })
            else { return nil }
            return Forecast.PendingCard(id: tx.id, title: cat.displayName, amountC: tx.amountC)
        }
        return Forecast.build(
            cycleISO: cycleISO,
            incomeRows: [],
            projected: projected,
            pendingCards: pendingCards,
            trancheLines: Funding.forecastLines(cycleISO: cycleISO, plans: plans),
            typicalVariableC: 0
        ).committed
    }

    private static func isoToday() -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
