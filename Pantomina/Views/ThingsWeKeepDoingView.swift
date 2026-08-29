import SwiftUI
import SwiftData

struct ThingsWeKeepDoingView: View {
    @Query private var rules: [RecurringRuleRecord]

    var body: some View {
        List {
            if rules.isEmpty {
                Text("No recurring rules yet. Seed starters on a fresh install, or add them in a later update.")
                    .font(PantominaFont.body)
                    .foregroundStyle(Color.pantomina.muted)
            } else {
                Section {
                    ForEach(rules, id: \.id) { rule in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rule.title)
                                .font(PantominaFont.body.weight(.medium))
                            Text("\(formatPeso(rule.amountC)) · \(rule.paused ? "Paused" : "Active")")
                                .font(PantominaFont.caption.monospacedDigit())
                                .foregroundStyle(Color.pantomina.muted)
                        }
                        .padding(.vertical, 2)
                    }
                } footer: {
                    Text("Read-only for now. Pause and edit land with funding plans.")
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
                    PetTitle("Things We Keep Doing")
                    Text("Recurring")
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.muted)
                }
            }
        }
    }
}
