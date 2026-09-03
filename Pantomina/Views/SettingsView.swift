import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var people: [PersonRecord]
    @Query private var accounts: [AccountRecord]

    @State private var fernName = ""
    @State private var starkName = ""
    @State private var fernPet = ""
    @State private var starkPet = ""
    @State private var showPets = false
    @State private var showOddities = false
    @State private var toast: String?

    private var fern: PersonRecord? { people.first { $0.id == .fern } }
    private var stark: PersonRecord? { people.first { $0.id == .stark } }

    private var displayFern: String { fernName.isEmpty ? (fern?.name ?? "") : fernName }
    private var displayStark: String { starkName.isEmpty ? (stark?.name ?? "") : starkName }

    var body: some View {
        Form {
            Section {
                TextField("Payer name", text: $fernName)
                    .onChange(of: fernName) { _, new in
                        let limited = InputBounds.limiting(new, max: InputBounds.maxDisplayNameLength)
                        if limited != new { fernName = limited }
                    }
                TextField("Contributor name", text: $starkName)
                    .onChange(of: starkName) { _, new in
                        let limited = InputBounds.limiting(new, max: InputBounds.maxDisplayNameLength)
                        if limited != new { starkName = limited }
                    }
                Toggle("Add pet names", isOn: $showPets)
                if showPets {
                    TextField("Payer pet name", text: $fernPet)
                        .onChange(of: fernPet) { _, new in
                            let limited = InputBounds.limiting(new, max: InputBounds.maxPetNameLength)
                            if limited != new { fernPet = limited }
                        }
                    TextField("Contributor pet name", text: $starkPet)
                        .onChange(of: starkPet) { _, new in
                            let limited = InputBounds.limiting(new, max: InputBounds.maxPetNameLength)
                            if limited != new { starkPet = limited }
                        }
                }
                Button("Save names") { saveNames() }
            } header: {
                Text("The Fine Print")
            } footer: {
                Text("Roles stay payer / contributor. Renaming updates every account label and greeting. Nothing is stored with a name baked in.")
            }

            Section("Where the money sleeps") {
                ForEach(accounts.filter { !$0.archived }, id: \.id) { account in
                    HStack {
                        Text(account.displayLabel(
                            fernName: displayFern,
                            starkName: displayStark
                        ))
                        Spacer()
                        Chip(
                            label: DisplayLabels.scope(
                                account.scope,
                                fernName: displayFern,
                                starkName: displayStark
                            ),
                            tone: .neutral
                        )
                    }
                }
            }

            Section {
                DisclosureGroup("CoA migration oddities", isExpanded: $showOddities) {
                    ForEach(SeedCatalog.migrationOddityPrompts, id: \.legacy) { row in
                        let mapped = CoAMigration.map(legacy: row.legacy)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.legacy).font(PantominaFont.body)
                            Text(oddityCopy(row.oddity))
                                .font(PantominaFont.caption)
                                .foregroundStyle(Color.pantomina.muted)
                            if let mapped {
                                Text("→ \(mapped.group) · \(mapped.item)")
                                    .font(PantominaFont.caption)
                                    .foregroundStyle(Color.pantomina.sageDeep)
                            }
                        }
                    }
                }
            }

            Section("Roles") {
                LabeledContent("Payer", value: fern?.name ?? "-")
                LabeledContent("Contributor", value: stark?.name ?? "-")
                Text("Not swappable in this version.")
                    .font(PantominaFont.caption)
                    .foregroundStyle(Color.pantomina.muted)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.pantomina.ground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                PetTitle("The Fine Print")
            }
        }
        .onAppear { load() }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .padding()
                    .background(Color.pantomina.ink)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func load() {
        fernName = fern?.name ?? ""
        starkName = stark?.name ?? ""
        fernPet = fern?.petName ?? ""
        starkPet = stark?.petName ?? ""
        showPets = !(fern?.petName ?? "").isEmpty || !(stark?.petName ?? "").isEmpty
    }

    private func saveNames() {
        let a = InputBounds.clampDisplayName(fernName)
        let b = InputBounds.clampDisplayName(starkName)
        guard !a.isEmpty, !b.isEmpty else {
            showToast("Couldn't save. Enter both names.")
            return
        }
        fernName = a
        starkName = b
        fern?.name = a
        stark?.name = b
        let petA = InputBounds.clampPetName(fernPet)
        let petB = InputBounds.clampPetName(starkPet)
        fernPet = petA
        starkPet = petB
        fern?.petName = showPets ? petA.nilIfEmpty : nil
        stark?.petName = showPets ? petB.nilIfEmpty : nil
        try? modelContext.save()
        showToast("Names updated everywhere.")
    }

    private func showToast(_ message: String) {
        PantominaMotion.run(reduceMotion) { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            PantominaMotion.run(reduceMotion) { toast = nil }
        }
    }

    private func oddityCopy(_ oddity: CoAOddity) -> String {
        switch oddity {
        case .loanMarkedWant: return "Tagged as Want. Confirm that still feels right."
        case .childSupportBirthdayWant: return "Birthday under Child Support is Want; Siblings Birthday is Need."
        case .smartPostpaidWant: return "Only utility marked Want."
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
