import SwiftUI
import SwiftData

struct MoreView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    SettingsView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("The Fine Print")
                            Text("Settings")
                                .font(PantominaFont.caption)
                                .foregroundStyle(Color.pantomina.muted)
                        }
                    } icon: {
                        Image(systemName: "gearshape")
                    }
                }

                Section {
                    EmptyView()
                } footer: {
                    Text("Settings for now — more rooms later.")
                        .font(PantominaFont.caption)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.pantomina.ground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    PetTitle("Everything else")
                }
            }
        }
    }
}
