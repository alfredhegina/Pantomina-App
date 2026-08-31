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

                NavigationLink {
                    StatementDayView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Statement day")
                            Text("Count card swipes")
                                .font(PantominaFont.caption)
                                .foregroundStyle(Color.pantomina.muted)
                        }
                    } icon: {
                        Image(systemName: "creditcard")
                    }
                }

                NavigationLink {
                    CookieJarView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("The Cookie Jar")
                            Text("Petty cash")
                                .font(PantominaFont.caption)
                                .foregroundStyle(Color.pantomina.muted)
                        }
                    } icon: {
                        Image(systemName: "archivebox")
                    }
                }

                NavigationLink {
                    BaggageView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Baggage We're Carrying")
                            Text("Loans")
                                .font(PantominaFont.caption)
                                .foregroundStyle(Color.pantomina.muted)
                        }
                    } icon: {
                        Image(systemName: "suitcase")
                    }
                }

                NavigationLink {
                    WarChestView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("The War Chest")
                            Text("Funds")
                                .font(PantominaFont.caption)
                                .foregroundStyle(Color.pantomina.muted)
                        }
                    } icon: {
                        Image(systemName: "shield.lefthalf.filled")
                    }
                }

                NavigationLink {
                    ThingsWeKeepDoingView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Things We Keep Doing")
                            Text("Recurring")
                                .font(PantominaFont.caption)
                                .foregroundStyle(Color.pantomina.muted)
                        }
                    } icon: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }

                Section {
                    EmptyView()
                } footer: {
                    Text("Cookie Jar, loans, funds, recurring, Statement day, and settings.")
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
