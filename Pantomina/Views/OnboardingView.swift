import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var step = 0
    @State private var nameA = ""
    @State private var nameB = ""
    @State private var payerIsA = true
    @State private var seedStarters = true
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Eyebrow("Pantomina")
                PetTitle("Shall we dance?")

                Group {
                    switch step {
                    case 0: namesStep
                    case 1: rolesStep
                    case 2: currencyStep
                    default: startersStep
                    }
                }

                if let error {
                    Text(error)
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.rose)
                }

                Spacer(minLength: Spacing.lg)
            }
            .padding(Spacing.lg)
            .background(Color.pantomina.ground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Button(action: advance) {
                    Text(step < 3 ? "Continue" : "Start our ledger")
                        .font(PantominaFont.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                        .background(Color.pantomina.sage)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Spacing.radius, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.sm)
                .background(Color.pantomina.ground)
            }
        }
    }

    private var namesStep: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Two names. Pet names can wait — add them later in Settings if you want.")
                .font(PantominaFont.body)
                .foregroundStyle(Color.pantomina.muted)
            TextField("First person", text: $nameA)
                .textFieldStyle(.roundedBorder)
                .onChange(of: nameA) { _, new in
                    let limited = InputBounds.limiting(new, max: InputBounds.maxDisplayNameLength)
                    if limited != new { nameA = limited }
                }
            TextField("Second person", text: $nameB)
                .textFieldStyle(.roundedBorder)
                .onChange(of: nameB) { _, new in
                    let limited = InputBounds.limiting(new, max: InputBounds.maxDisplayNameLength)
                    if limited != new { nameB = limited }
                }
        }
    }

    private var rolesStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Who fronts the household bills? That person is the payer; the other contributes each cycle. This sets settlement direction and is not swapped later.")
                .font(PantominaFont.body)
                .foregroundStyle(Color.pantomina.muted)
            roleButton(title: nameA.isEmpty ? "First person" : nameA, selected: payerIsA) { payerIsA = true }
            roleButton(title: nameB.isEmpty ? "Second person" : nameB, selected: !payerIsA) { payerIsA = false }
        }
    }

    private var currencyStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Currency is Philippine peso only for now.")
                .font(PantominaFont.body)
                .foregroundStyle(Color.pantomina.muted)
            Chip(label: "PHP · ₱", tone: .sage)
        }
    }

    private var startersStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Add a small set of starter accounts and categories? You can skip and build from a blank ledger.")
                .font(PantominaFont.body)
                .foregroundStyle(Color.pantomina.muted)
            Toggle("Seed starter payment methods + categories", isOn: $seedStarters)
        }
    }

    private func roleButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if selected {
                    Text("Payer")
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.sageDeep)
                }
            }
            .padding(Spacing.md)
            .background(selected ? Color.pantomina.sage.opacity(0.12) : Color.pantomina.card)
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radius, style: .continuous)
                    .stroke(selected ? Color.pantomina.sage : Color.pantomina.hairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Spacing.radius, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.pantomina.ink)
    }

    private func advance() {
        error = nil
        if step == 0 {
            let a = InputBounds.clampDisplayName(nameA)
            let b = InputBounds.clampDisplayName(nameB)
            nameA = a
            nameB = b
            guard !a.isEmpty, !b.isEmpty else {
                error = "Couldn't continue. Enter both names."
                return
            }
            step = 1
            return
        }
        if step < 3 {
            step += 1
            return
        }

        let fernName = payerIsA ? nameA : nameB
        let starkName = payerIsA ? nameB : nameA
        do {
            try Bootstrap.completeOnboarding(
                fernName: fernName,
                starkName: starkName,
                fernIsPayer: true,
                seedStarters: seedStarters,
                context: modelContext
            )
        } catch {
            self.error = "Couldn't save. Try again."
        }
    }
}
