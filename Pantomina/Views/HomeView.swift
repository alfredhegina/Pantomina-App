import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var people: [PersonRecord]
    @Query(sort: \TransactionRecord.purchaseDate, order: .reverse) private var transactions: [TransactionRecord]
    @Query private var categories: [CategoryRecord]

    var onAdd: () -> Void = {}

    private var fern: PersonRecord? { people.first { $0.id == .fern } }
    private var stark: PersonRecord? { people.first { $0.id == .stark } }
    private var recent: [TransactionRecord] { Array(transactions.prefix(3)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Eyebrow("Home")
                        if let fern, let stark {
                            Text(AccountLabels.greeting(
                                fernName: fern.name,
                                fernPet: fern.petName,
                                starkName: stark.name,
                                starkPet: stark.petName
                            ))
                            .font(PantominaFont.petTitle)
                            .foregroundStyle(Color.pantomina.ink)
                        }
                        Text(todayLine)
                            .font(PantominaFont.caption)
                            .foregroundStyle(Color.pantomina.muted)
                    }

                    Button(action: onAdd) {
                        Text("Add to the pile")
                            .font(PantominaFont.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 48)
                            .background(Color.pantomina.sage)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: Spacing.radius, style: .continuous))
                    }
                    .buttonStyle(SageButtonStyle())

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Eyebrow("Latest")
                        if recent.isEmpty {
                            Text("Nothing here yet. Rare quiet moment.")
                                .font(PantominaFont.body)
                                .foregroundStyle(Color.pantomina.muted)
                        } else {
                            ForEach(recent, id: \.id) { tx in
                                recentRow(tx)
                            }
                        }
                    }
                }
                .padding(Spacing.lg)
            }
            .background(Color.pantomina.ground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        PetTitle("Home")
                        Text("Today")
                            .font(PantominaFont.caption)
                            .foregroundStyle(Color.pantomina.muted)
                    }
                }
            }
        }
    }

    private func recentRow(_ tx: TransactionRecord) -> some View {
        let category = categories.first { $0.id == tx.categoryId }
        return Card {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(category?.displayName ?? "Category")
                        .font(PantominaFont.body.weight(.medium))
                    Text(DisplayLabels.displayDate(iso: tx.purchaseDate))
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.muted)
                }
                Spacer()
                Text(formatPeso(tx.amountC))
                    .font(PantominaFont.body.monospacedDigit())
                    .foregroundStyle(category?.flow == .income ? Color.pantomina.sageDeep : Color.pantomina.terraDeep)
            }
        }
    }

    private var todayLine: String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        let today = iso.string(from: Date()).prefix(10)
        let cycle = Cycle.cycleFor(isoDate: String(today))
        return "Cycle of \(DisplayLabels.displayDate(iso: cycle.anchorISO))"
    }
}
