import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var people: [PersonRecord]
    @Query private var metaRows: [AppMeta]

    private var fern: PersonRecord? { people.first { $0.id == .fern } }
    private var stark: PersonRecord? { people.first { $0.id == .stark } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Eyebrow("Pantomina")
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

                Card {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Eyebrow("Together")
                        Text("Ledger is ready. Add a receipt when something lands.")
                            .font(PantominaFont.body)
                            .foregroundStyle(Color.pantomina.muted)
                        HStack(spacing: Spacing.sm) {
                            if let fern {
                                PersonDot(person: .fern)
                                Text(fern.name).font(PantominaFont.body)
                            }
                            if let stark {
                                PersonDot(person: .stark)
                                Text(stark.name).font(PantominaFont.body)
                            }
                        }
                    }
                }
            }
            .padding(Spacing.lg)
        }
        .background(Color.pantomina.ground.ignoresSafeArea())
    }

    private var todayLine: String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        let today = iso.string(from: Date()).prefix(10)
        let cycle = Cycle.cycleFor(isoDate: String(today))
        return "Cycle of \(cycle.anchorISO)"
    }
}
