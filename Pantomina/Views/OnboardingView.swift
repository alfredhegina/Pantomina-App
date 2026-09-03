import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedName: NameField?
    @State private var step = 0
    @State private var reveal = -1
    @State private var nameA = ""
    @State private var nameB = ""
    @State private var payerIsA = true
    @State private var seedStarters = true
    @State private var error: String?

    private let stepCount = 3
    private let fieldFont = Font.custom("DM Sans", size: 19, relativeTo: .title3)
    private let clay = Color(hex: "#8A4C2A")

    private enum NameField: Hashable {
        case a, b
    }

    private var stepCaption: String {
        let name: String
        switch step {
        case 0: name = "Names and currency"
        case 1: name = "Roles"
        default: name = "Starters"
        }
        return "Step \(step + 1) of \(stepCount) · \(name)"
    }

    private var longestNameCount: Int {
        max(nameA.count, nameB.count)
    }

    private var fernPreviewName: String {
        let raw = payerIsA ? nameA : nameB
        if raw.isEmpty { return payerIsA ? "First person" : "Second person" }
        return raw
    }

    private var starkPreviewName: String {
        let raw = payerIsA ? nameB : nameA
        if raw.isEmpty { return payerIsA ? "Second person" : "First person" }
        return raw
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            progress
            Rectangle()
                .fill(Color.pantomina.rule)
                .frame(height: 1)
            GeometryReader { geo in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        stepBody
                            .id(step)
                        if let error {
                            Text(error)
                                .font(PantominaFont.caption.weight(.medium))
                                .foregroundStyle(clay)
                                .padding(.top, 18)
                                .accessibilityIdentifier("onboarding-error")
                        }
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: geo.size.height, alignment: .center)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollIndicators(.hidden)
            }
            footer
        }
        .background(Color.pantomina.ground.ignoresSafeArea())
        .tint(Color.pantomina.quietAccent)
        .onAppear { pulseReveal() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Pantomina")
            Text("Shall we dance?")
                .font(PantominaFont.onboardingTitle)
                .foregroundStyle(Color.pantomina.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(stepCaption)
                .font(.custom("DM Sans", size: 12, relativeTo: .caption))
                .foregroundStyle(Color.pantomina.muted)
            HStack(spacing: 6) {
                ForEach(0..<stepCount, id: \.self) { index in
                    Capsule()
                        .fill(Color.pantomina.rule)
                        .overlay {
                            Capsule()
                                .fill(Color.pantomina.quietAccent)
                                .scaleEffect(x: step >= index ? 1 : 0, y: 1, anchor: .leading)
                        }
                        .clipShape(Capsule())
                        .frame(height: 3)
                }
            }
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stepCaption)
    }

    @ViewBuilder
    private var stepBody: some View {
        switch step {
        case 0: namesStep
        case 1: rolesStep
        default: startersStep
        }
    }

    private var namesStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            introCopy("Two names. Pet names can wait. Add them later in Settings if you want.")
            VStack(alignment: .leading, spacing: 0) {
                nameField("First person", text: $nameA, field: .a)
                nameField("Second person", text: $nameB, field: .b)
                if longestNameCount >= InputBounds.displayNameCounterRevealLength {
                    Text("\(longestNameCount)/\(InputBounds.maxDisplayNameLength)")
                        .font(.custom("DM Sans", size: 12, relativeTo: .caption).monospacedDigit())
                        .foregroundStyle(clay)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, 9)
                        .accessibilityLabel("\(longestNameCount) of \(InputBounds.maxDisplayNameLength) characters")
                }
            }
            .padding(.top, 24)
            .onboardingRise(shown: reveal >= 1, reduceMotion: reduceMotion)

            HStack(alignment: .center, spacing: 14) {
                Text("Currency is Philippine peso only for now.")
                    .font(.custom("DM Sans", size: 14.5, relativeTo: .subheadline))
                    .foregroundStyle(Color.pantomina.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("PHP · ₱")
                    .font(.custom("DM Sans", size: 15, relativeTo: .subheadline).weight(.medium))
                    .foregroundStyle(Color.pantomina.quietAccent)
                    .padding(.horizontal, 15)
                    .frame(minHeight: 44)
                    .background(Color(hex: "#E9F0EC"))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityAddTraits(.isStaticText)
                    .accessibilityLabel("Currency Philippine peso")
            }
            .padding(.top, 18)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.pantomina.rule).frame(height: 1)
            }
            .padding(.top, 28)
            .onboardingRise(shown: reveal >= 2, reduceMotion: reduceMotion)
        }
    }

    private var rolesStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            introCopy("Who fronts the household bills? That person is the payer; the other contributes each cycle. This sets settlement direction and is not swapped later.")
            VStack(spacing: 0) {
                roleRow(
                    title: nameA.isEmpty ? "First person" : nameA,
                    selected: payerIsA,
                    action: { selectPayer(isA: true) }
                )
                roleRow(
                    title: nameB.isEmpty ? "Second person" : nameB,
                    selected: !payerIsA,
                    action: { selectPayer(isA: false) }
                )
            }
            .padding(.top, 20)
            .onboardingRise(shown: reveal >= 1, reduceMotion: reduceMotion)
        }
    }

    private var startersStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            introCopy("Add a small set of starter accounts and categories? You can skip and build from a blank ledger.")
            Button {
                PantominaMotion.run(reduceMotion) { seedStarters.toggle() }
            } label: {
                HStack(alignment: .center, spacing: 16) {
                    Text("Seed starter payment methods + categories")
                        .font(PantominaFont.body)
                        .foregroundStyle(Color.pantomina.ink)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    seedSwitch
                }
                .padding(.vertical, 14)
                .frame(minHeight: 64)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.pantomina.innerRule).frame(height: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Seed starter payment methods and categories")
            .accessibilityValue(seedStarters ? "On" : "Off")
            .accessibilityAddTraits(.isToggle)
            .padding(.top, 20)
            .onboardingRise(shown: reveal >= 1, reduceMotion: reduceMotion)

            Group {
                if seedStarters {
                    previewBlock(
                        caption: "Payment methods · \(SeedCatalog.starterAccounts.count)",
                        body: SeedCatalog.starterAccountPreviewLabels(
                            fernName: fernPreviewName,
                            starkName: starkPreviewName
                        ).joined(separator: ", ")
                    )
                    previewBlock(
                        caption: "Categories · \(SeedCatalog.starterUserCategoryCount) in \(SeedCatalog.starterUserCategoryGroups.count) groups",
                        body: SeedCatalog.starterUserCategoryGroups.joined(separator: ", ")
                    )
                    .padding(.top, 14)
                    .overlay(alignment: .top) {
                        Rectangle().fill(Color.pantomina.innerRule).frame(height: 1)
                    }
                } else {
                    previewBlock(
                        caption: "Categories · \(SeedCatalog.systemCategoryItems.count) system",
                        body: SeedCatalog.systemCategoryItems.joined(separator: ", ")
                    )
                }
            }
            .padding(.top, 18)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.pantomina.rule).frame(height: 1)
            }
            .onboardingRise(shown: reveal >= 2, reduceMotion: reduceMotion)
        }
    }

    private var seedSwitch: some View {
        Capsule()
            .fill(seedStarters ? Color.pantomina.quietAccent : Color.pantomina.rule)
            .frame(width: 52, height: 32)
            .overlay(alignment: seedStarters ? .trailing : .leading) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 28, height: 28)
                    .shadow(color: Color.black.opacity(0.18), radius: 1.5, y: 1)
                    .padding(2)
            }
            .animation(reduceMotion ? nil : PantominaMotion.feedback, value: seedStarters)
            .accessibilityHidden(true)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if step > 0 {
                Button("Back") { go(to: step - 1) }
                    .font(PantominaFont.body.weight(.semibold))
                    .foregroundStyle(Color.pantomina.quietAccent)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 52)
            }
            Button(action: advance) {
                Text(step < 2 ? "Continue" : "Start our ledger")
                    .font(PantominaFont.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(Color.pantomina.quietAccent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.radius, style: .continuous))
            }
            .buttonStyle(SageButtonStyle())
            .accessibilityIdentifier("onboarding-continue")
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.pantomina.rule).frame(height: 1)
        }
        .background(Color.pantomina.ground)
    }

    private func introCopy(_ text: String) -> some View {
        Text(text)
            .font(PantominaFont.body)
            .foregroundStyle(Color.pantomina.muted)
            .onboardingRise(shown: reveal >= 0, reduceMotion: reduceMotion)
    }

    private func nameField(_ placeholder: String, text: Binding<String>, field: NameField) -> some View {
        TextField(placeholder, text: text)
            .font(fieldFont)
            .foregroundStyle(Color.pantomina.ink)
            .textInputAutocapitalization(.words)
            .textFieldStyle(.plain)
            .focused($focusedName, equals: field)
            .submitLabel(field == .a ? .next : .continue)
            .onSubmit {
                if field == .a {
                    focusedName = .b
                } else {
                    advance()
                }
            }
            .frame(minHeight: 58)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(focusedName == field ? Color.pantomina.quietAccent : Color.pantomina.rule)
                    .frame(height: 1)
                    .animation(reduceMotion ? nil : PantominaMotion.feedback, value: focusedName)
            }
            .onChange(of: text.wrappedValue) { _, new in
                error = nil
                let limited = InputBounds.limiting(new, max: InputBounds.maxDisplayNameLength)
                if limited != new { text.wrappedValue = limited }
            }
    }

    private func roleRow(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Color(hex: "#C6CFC9"), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if selected {
                        Circle()
                            .fill(Color.pantomina.quietAccent)
                            .frame(width: 22, height: 22)
                            .overlay {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 22, height: 22)
                .animation(reduceMotion ? nil : PantominaMotion.feedback, value: selected)

                Text(title)
                    .font(.custom("DM Sans", size: 17, relativeTo: .body).weight(selected ? .medium : .regular))
                    .foregroundStyle(Color.pantomina.ink)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(selected ? "Payer" : "Contributes each cycle")
                    .font(PantominaFont.caption.weight(selected ? .medium : .regular))
                    .foregroundStyle(selected ? Color.pantomina.quietAccent : Color.pantomina.muted)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 100, alignment: .trailing)
            }
            .padding(.vertical, 14)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
            .overlay(alignment: .top) {
                Rectangle().fill(Color.pantomina.innerRule).frame(height: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(selected ? "Payer" : "Contributes each cycle")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func previewBlock(caption: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(caption)
                .font(.custom("DM Sans", size: 12, relativeTo: .caption))
                .foregroundStyle(Color.pantomina.muted)
            Text(body)
                .font(.custom("DM Sans", size: 14, relativeTo: .subheadline))
                .foregroundStyle(Color.pantomina.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectPayer(isA: Bool) {
        PantominaMotion.run(reduceMotion) { payerIsA = isA }
    }

    private func go(to newStep: Int) {
        focusedName = nil
        error = nil
        if reduceMotion {
            step = newStep
            reveal = 2
            return
        }
        withAnimation(PantominaMotion.sheet) { step = newStep }
        pulseReveal()
    }

    private func pulseReveal() {
        if reduceMotion {
            reveal = 2
            return
        }
        reveal = -1
        withAnimation(PantominaMotion.sheet) { reveal = 0 }
        withAnimation(PantominaMotion.sheet.delay(0.07)) { reveal = 1 }
        withAnimation(PantominaMotion.sheet.delay(0.14)) { reveal = 2 }
    }

    private func advance() {
        error = nil
        focusedName = nil
        if step == 0 {
            let a = InputBounds.clampDisplayName(nameA)
            let b = InputBounds.clampDisplayName(nameB)
            nameA = a
            nameB = b
            guard !a.isEmpty, !b.isEmpty else {
                error = "Couldn't continue. Enter both names."
                return
            }
            go(to: 1)
            return
        }
        if step < 2 {
            go(to: step + 1)
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

private extension View {
    func onboardingRise(shown: Bool, reduceMotion: Bool) -> some View {
        self
            .opacity(shown || reduceMotion ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 12)
            .animation(reduceMotion ? nil : PantominaMotion.sheet, value: shown)
    }
}
