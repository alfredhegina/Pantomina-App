import SwiftUI
import SwiftData

/// Confirm booking unexplained positive pocket drift as interest income.
struct InterestDriftSheet: View {
    let prompt: InterestDrift.Prompt
    let accountLabel: String
    let onBook: () -> Void
    let onSkip: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("\(accountLabel) looks \(formatPeso(prompt.unexplainedPositiveC)) higher than the last check-in, without matching income.")
                        .foregroundStyle(Color.pantomina.ink)
                } footer: {
                    Text("Booking adds interest income on this pocket. Skip leaves the books as they are.")
                        .font(PantominaFont.caption)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.pantomina.ground)
            .navigationTitle("Book as interest?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip", action: onSkip)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Book interest", action: onBook)
                        .foregroundStyle(Color.pantomina.sageDeep)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
