import SwiftUI
import SwiftData

/// Room A Add sheet: composer → confirmation cards → existing form as Fix something.
struct AddCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query private var accounts: [AccountRecord]
    @Query private var categories: [CategoryRecord]
    @Query private var people: [PersonRecord]

    @AppStorage("recentCategoryIds") private var recentCategoryIdsRaw = ""
    @AppStorage("recentAccountIds") private var recentAccountIdsRaw = ""
    @AppStorage("recentCaptureUtterances") private var recentCaptureUtterancesRaw = ""

    @State private var draftText = ""
    @State private var utterance: String?
    @State private var slots: [DraftSlot] = []
    @State private var pageID: UUID?
    @State private var showFix = false
    @State private var fixCard: CaptureParse.Card?
    @State private var fixingSlotID: UUID?
    @State private var savedToast = false
    @State private var saveError: String?
    @FocusState private var composerFocused: Bool

    private struct DraftSlot: Identifiable {
        let id: UUID
        var result: CaptureParse.Result
    }

    private var fernName: String { people.first { $0.id == .fern }?.name ?? "Fern" }
    private var starkName: String { people.first { $0.id == .stark }?.name ?? "Stark" }

    private var catalog: CaptureParse.Catalog {
        CaptureParse.Catalog(
            pockets: accounts.filter { !$0.archived }.map {
                CaptureParse.Pocket(
                    id: $0.id,
                    baseName: $0.baseName,
                    scope: $0.scope,
                    settlement: $0.settlement,
                    statementCutoff: $0.statementCutoff
                )
            },
            categories: categories.map {
                CaptureParse.Category(id: $0.id, group: $0.group, item: $0.item, system: $0.system)
            },
            fernName: fernName,
            starkName: starkName
        )
    }

    private var todayISO: String { Self.isoString(from: Date()) }
    private var showingResults: Bool { utterance != nil }
    private var canSend: Bool {
        !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var pageIndex: Int {
        guard let pageID, let index = slots.firstIndex(where: { $0.id == pageID }) else { return 0 }
        return index
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.pantomina.ground.ignoresSafeArea()
                if showingResults {
                    resultsBody
                } else {
                    composerBody
                }
            }
            .background(Color.pantomina.ground.ignoresSafeArea())
            .tint(Color.pantomina.quietAccent)
            .toolbarBackground(Color.pantomina.ground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        PetTitle("Add to the pile")
                        if !showingResults {
                            Text("New entry")
                                .font(PantominaFont.caption)
                                .foregroundStyle(Color.pantomina.muted)
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showFix) {
                AddEntryView(
                    presentsAsSheet: false,
                    wrapInNavigationStack: false,
                    formPetTitle: "Fix something",
                    capturePrefill: fixCard,
                    onSaved: { formDidSave() }
                )
            }
            .overlay(alignment: .bottom) {
                if savedToast {
                    Text("Saved. Team effort.")
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.pantomina.ink)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .padding(.bottom, 28)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onAppear { composerFocused = true }
        }
    }

    // MARK: - A1 composer

    private var composerBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            composerCard
                .padding(.horizontal, 22)
                .padding(.top, 8)
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow("Things that work")
                    .padding(.bottom, 4)
                ForEach(CaptureUtteranceRecents.display(raw: recentCaptureUtterancesRaw), id: \.self) { example in
                    Button {
                        draftText = InputBounds.clampNote(example)
                    } label: {
                        Text(example)
                            .font(PantominaFont.body)
                            .foregroundStyle(Color.pantomina.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 13)
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .top) {
                        Rectangle().fill(Color.pantomina.hairline).frame(height: 1)
                    }
                    .accessibilityLabel("Example: \(example)")
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 26)
            Spacer(minLength: 12)
            Button {
                openFix(card: nil, slotID: nil)
            } label: {
                Text("Fix something by hand")
                    .font(PantominaFont.body.weight(.medium))
                    .foregroundStyle(Color.pantomina.sageDeep)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 22)
            .padding(.bottom, 8)
        }
    }

    private var composerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField(
                "Say it the way you would say it out loud",
                text: $draftText,
                axis: .vertical
            )
            .font(PantominaFont.body)
            .lineLimit(3...6)
            .focused($composerFocused)
            .foregroundStyle(Color.pantomina.ink)
            .accessibilityLabel("Say it the way you would say it out loud")
            .onChange(of: draftText) { _, new in
                draftText = InputBounds.clampNote(new)
            }
            HStack {
                Spacer(minLength: 0)
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(canSend ? Color(hex: "#FDFDFC") : Color.pantomina.muted)
                        .frame(width: 44, height: 44)
                        .background(canSend ? Color.pantomina.ink : Color(hex: "#EFEDE8"))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .accessibilityLabel("Parse")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 17)
        .padding(.bottom, 13)
        .background(Color.pantomina.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.pantomina.hairline, lineWidth: 1)
        )
    }

    // MARK: - Results (A2–A6)

    private var resultsBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            recapChip
                .padding(.horizontal, 22)
                .padding(.top, 10)
            if !isFailedOnly {
                Text("Using built-in shortcuts")
                    .font(PantominaFont.caption)
                    .foregroundStyle(Color.pantomina.muted)
                    .padding(.horizontal, 22)
                    .padding(.top, 11)
            }
            if slots.count > 1 {
                batchHeader
                    .padding(.horizontal, 22)
                    .padding(.top, 20)
                TabView(selection: $pageID) {
                    ForEach(slots) { slot in
                        ScrollView {
                            slotPage(slot, includeActions: true)
                                .padding(.horizontal, 22)
                                .padding(.bottom, 8)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .tag(Optional(slot.id))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                Text("Saved ones drop off the stack")
                    .font(PantominaFont.body)
                    .foregroundStyle(Color.pantomina.muted)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 22)
            } else if let slot = slots.first {
                ScrollView {
                    slotPage(slot, includeActions: false)
                        .padding(.horizontal, 22)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                singleFooter(slot)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 8)
            }
        }
    }

    private var isFailedOnly: Bool {
        if slots.count == 1, case .failed = slots[0].result { return true }
        return false
    }

    private var recapChip: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(utterance ?? "")
                .font(PantominaFont.body)
                .foregroundStyle(Color.pantomina.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Edit", action: returnToComposer)
                .font(PantominaFont.caption.weight(.medium))
                .foregroundStyle(Color.pantomina.muted)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(hex: "#F4F1EC"))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.pantomina.hairline, lineWidth: 1)
        )
    }

    private var batchHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(Self.thingsPhrase(slots.count))
                .font(PantominaFont.body)
                .foregroundStyle(Color.pantomina.ink)
            Spacer(minLength: 8)
            Text("\(pageIndex + 1) of \(slots.count)")
                .font(PantominaFont.body.weight(.medium).monospacedDigit())
                .foregroundStyle(Color.pantomina.muted)
        }
    }

    @ViewBuilder
    private func slotPage(_ slot: DraftSlot, includeActions: Bool) -> some View {
        switch slot.result {
        case .failed(let title, let hint):
            VStack(spacing: 14) {
                failedCard(title: title, hint: hint)
                if includeActions {
                    failedActions(slotID: slot.id)
                }
            }
        case .ready(let card):
            confirmationCard(slot: slot, card: card, question: nil, choices: [], includeActions: includeActions)
        case .needPick(let card, let question, let choices):
            confirmationCard(slot: slot, card: card, question: question, choices: choices, includeActions: includeActions)
        case .batch:
            EmptyView()
        }
    }

    @ViewBuilder
    private func singleFooter(_ slot: DraftSlot) -> some View {
        switch slot.result {
        case .failed:
            failedActions(slotID: slot.id)
        case .ready(let card):
            cardActions(slot: slot, card: card)
        case .needPick(let card, _, _):
            cardActions(slot: slot, card: card)
        case .batch:
            EmptyView()
        }
    }

    private func failedCard(title: String, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(PantominaFont.body)
                .foregroundStyle(Color.pantomina.ink)
            Text(hint)
                .font(PantominaFont.body)
                .foregroundStyle(Color.pantomina.muted)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pantomina.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.pantomina.hairline, lineWidth: 1)
        )
    }

    private func failedActions(slotID: UUID) -> some View {
        VStack(spacing: 2) {
            Button(action: returnToComposer) {
                Text("Try again")
                    .font(PantominaFont.body.weight(.semibold))
                    .foregroundStyle(Color.pantomina.ink)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 54)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.pantomina.ink, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
            Button {
                openFix(card: nil, slotID: slotID)
            } label: {
                Text("Fill it in by hand")
                    .font(PantominaFont.body.weight(.medium))
                    .foregroundStyle(Color.pantomina.sageDeep)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
            }
            .buttonStyle(.plain)
        }
    }

    private func confirmationCard(
        slot: DraftSlot,
        card: CaptureParse.Card,
        question: String?,
        choices: [CaptureParse.Choice],
        includeActions: Bool
    ) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(formatPeso(card.amountC))
                    .font(PantominaFont.heroAmount(centavos: card.amountC))
                    .foregroundStyle(Color.pantomina.ink)
                    .monospacedDigit()
                if let caption = merchantCaption(card) {
                    Text(caption)
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.muted)
                        .padding(.top, 7)
                }
                ruledRow("Category", value: categoryLabel(card.categoryId), first: true)
                if let question {
                    VStack(alignment: .leading, spacing: 13) {
                        Text(question)
                            .font(PantominaFont.body)
                            .foregroundStyle(Color.pantomina.ink)
                        HStack(spacing: 9) {
                            ForEach(choices, id: \.id) { choice in
                                Button {
                                    applyPick(slotID: slot.id, pocketId: choice.id)
                                } label: {
                                    Text(choice.label)
                                        .font(PantominaFont.body.weight(.medium))
                                        .foregroundStyle(Color.pantomina.ink)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                        .frame(minHeight: 48)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(Color.pantomina.ink, lineWidth: 1.5)
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(choice.label)
                            }
                        }
                    }
                    .padding(.top, 15)
                    .padding(.bottom, 4)
                    .overlay(alignment: .top) {
                        Rectangle().fill(Color.pantomina.hairline).frame(height: 1)
                    }
                } else {
                    ruledRow("Payment method", value: pocketLabel(card.accountId))
                }
                ruledRow("Paid by", value: personName(card.paidBy), person: card.paidBy)
                if card.split != .contribution {
                    ruledRow("Whose is it", value: whoseLabel(card.split))
                }
                ruledRow(
                    "When it counts",
                    value: card.countsHint ?? "–",
                    mutedValue: card.countsHint == nil
                )
                if let extra = card.extraCaption {
                    Text(extra)
                        .font(PantominaFont.body)
                        .foregroundStyle(Color.pantomina.muted)
                        .padding(.top, 14)
                        .padding(.bottom, 3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .top) {
                            Rectangle().fill(Color.pantomina.hairline).frame(height: 1)
                        }
                }
                if includeActions {
                    cardActions(slot: slot, card: card)
                        .padding(.top, 16)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.pantomina.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.pantomina.hairline, lineWidth: 1)
            )
            if let saveError {
                Text(saveError)
                    .font(PantominaFont.caption)
                    .foregroundStyle(Color.pantomina.terraDeep)
                    .padding(.top, 8)
            }
        }
    }

    private func cardActions(slot: DraftSlot, card: CaptureParse.Card) -> some View {
        VStack(spacing: 2) {
            Button {
                save(slot: slot, card: card)
            } label: {
                Text("Save")
                    .font(PantominaFont.body.weight(.semibold))
                    .foregroundStyle(card.saveEnabled ? Color(hex: "#FDFDFC") : Color.pantomina.muted)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 54)
                    .background(card.saveEnabled ? Color.pantomina.ink : Color(hex: "#E4E2DC"))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!card.saveEnabled)
            .accessibilityLabel("Save")
            Button {
                openFix(card: card, slotID: slot.id)
            } label: {
                Text("Fix something")
                    .font(PantominaFont.body.weight(.medium))
                    .foregroundStyle(Color.pantomina.sageDeep)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
            }
            .buttonStyle(.plain)
        }
    }

    private func ruledRow(
        _ title: String,
        value: String,
        first: Bool = false,
        mutedValue: Bool = false,
        person: PersonId? = nil
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(title)
                .font(PantominaFont.body)
                .foregroundStyle(Color.pantomina.muted)
            Spacer(minLength: 8)
            if let person {
                HStack(spacing: 8) {
                    PersonDot(person: person, displayName: value)
                    Text(value)
                        .font(PantominaFont.body)
                        .foregroundStyle(Color.pantomina.ink)
                }
            } else {
                Text(value)
                    .font(PantominaFont.body)
                    .foregroundStyle(mutedValue ? Color.pantomina.muted : Color.pantomina.ink)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.top, first ? 14 : 13)
        .padding(.bottom, 13)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.pantomina.hairline)
                .frame(height: 1)
                .padding(.top, first ? 15 : 0)
        }
    }

    // MARK: - Actions

    private func send() {
        let text = InputBounds.clampNote(draftText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        composerFocused = false
        utterance = text
        saveError = nil
        let parsed = CaptureParse.parse(text, catalog: catalog, eventISO: todayISO)
        switch parsed {
        case .batch(let parts):
            slots = parts.map { DraftSlot(id: UUID(), result: $0) }
        default:
            slots = [DraftSlot(id: UUID(), result: parsed)]
        }
        pageID = slots.first?.id
    }

    private func returnToComposer() {
        utterance = nil
        slots = []
        pageID = nil
        saveError = nil
        composerFocused = true
    }

    private func applyPick(slotID: UUID, pocketId: String) {
        guard let index = slots.firstIndex(where: { $0.id == slotID }) else { return }
        if case .needPick(let draft, _, _) = slots[index].result {
            let card = CaptureParse.applyChoice(pocketId, to: draft, catalog: catalog, eventISO: todayISO)
            slots[index].result = .ready(card)
        }
    }

    private func openFix(card: CaptureParse.Card?, slotID: UUID?) {
        fixCard = card
        fixingSlotID = slotID
        showFix = true
    }

    private func formDidSave() {
        if utterance != nil, fixCard != nil {
            rememberUtterance()
        }
        if let fixingSlotID {
            dropSlot(id: fixingSlotID)
        } else {
            finishSaved(dismissSheet: true)
        }
        showFix = false
        fixCard = nil
        self.fixingSlotID = nil
    }

    private func save(slot: DraftSlot, card: CaptureParse.Card) {
        guard let post = CaptureParse.posting(from: card, purchaseISO: todayISO, catalog: catalog) else {
            return
        }
        let tx = TransactionRecord(
            purchaseDate: post.purchaseISO,
            realizedDate: post.realizedDate,
            realizedStatus: post.realizedStatus,
            proposedRealizedDate: post.proposedRealizedDate,
            amountC: post.amountC,
            accountId: post.accountId,
            categoryId: post.categoryId,
            paidBy: post.paidBy,
            allocation: post.allocation,
            settlementRole: post.settlementRole,
            merchant: post.merchant
        )
        modelContext.insert(tx)
        do {
            try modelContext.save()
            bumpRecent(id: post.categoryId, raw: &recentCategoryIdsRaw)
            bumpRecent(id: post.accountId, raw: &recentAccountIdsRaw)
            rememberUtterance()
            saveError = nil
            dropSlot(id: slot.id)
        } catch {
            saveError = "Couldn't save. Try again."
        }
    }

    private func dropSlot(id: UUID) {
        slots.removeAll { $0.id == id }
        if pageID == id {
            pageID = slots.first?.id
        }
        if slots.isEmpty {
            finishSaved(dismissSheet: true)
        }
    }

    private func finishSaved(dismissSheet: Bool) {
        PantominaMotion.run(reduceMotion) { savedToast = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            PantominaMotion.run(reduceMotion) { savedToast = false }
            if dismissSheet { dismiss() }
        }
    }

    private func rememberUtterance() {
        guard let utterance else { return }
        recentCaptureUtterancesRaw = CaptureUtteranceRecents.bump(utterance, onto: recentCaptureUtterancesRaw)
    }

    private func bumpRecent(id: String, raw: inout String) {
        var ids = raw.split(separator: ",").map(String.init).filter { $0 != id }
        ids.insert(id, at: 0)
        raw = ids.prefix(3).joined(separator: ",")
    }

    private func merchantCaption(_ card: CaptureParse.Card) -> String? {
        if let merchant = card.merchant, !merchant.isEmpty { return merchant }
        if card.split == .contribution { return "Money in" }
        return nil
    }

    private func categoryLabel(_ id: String?) -> String {
        guard let id, let cat = categories.first(where: { $0.id == id }) else { return "–" }
        return cat.displayName
    }

    private func pocketLabel(_ id: String?) -> String {
        guard let id, let account = accounts.first(where: { $0.id == id }) else { return "–" }
        return account.displayLabel(fernName: fernName, starkName: starkName)
    }

    private func personName(_ id: PersonId) -> String {
        id == .fern ? fernName : starkName
    }

    private func whoseLabel(_ split: CaptureParse.Split) -> String {
        switch split {
        case .justMine: return "Just mine"
        case .fiftyFifty: return "50 · 50"
        case .contribution: return "Just mine"
        }
    }

    private static func thingsPhrase(_ n: Int) -> String {
        let words = ["", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten"]
        if n == 1 { return "One thing in there" }
        if n >= 2, n <= 10 { return "\(words[n]) things in there" }
        return "\(n) things in there"
    }

    private static func isoString(from date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
