import SwiftUI
import SwiftData

struct BillsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var transactions: [TransactionRecord]
    @Query private var accounts: [AccountRecord]
    @Query private var categories: [CategoryRecord]
    @Query private var people: [PersonRecord]

    @State private var pane = 0
    @State private var selectedAnchor: String?
    @State private var showLogContribution = false
    @State private var contributionText = ""
    @State private var contributionError: String?
    @State private var toast: String?

    private var accountById: [String: AccountRecord] {
        Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
    }

    private var ledgerRows: [Settlement.LedgerRow] {
        transactions.map { tx in
            let account = accountById[tx.accountId]
            return Settlement.LedgerRow(
                realizedDate: tx.realizedDate,
                realizedStatus: tx.realizedStatus,
                accountScope: account?.scope ?? .household,
                allocationStarkC: tx.allocStarkC,
                allocationFernC: tx.allocFernC,
                amountC: tx.amountC,
                settlementRole: tx.settlementRole,
                isStatement: account?.settlement == .statement,
                proposedRealizedDate: tx.proposedRealizedDate
            )
        }
    }

    private var history: [Settlement.CycleSnapshot] {
        Settlement.history(rows: ledgerRows)
    }

    private var anchors: [String] {
        let fromLedger = Settlement.cycleAnchors(in: ledgerRows)
        let today = Self.todayISO()
        let current = Cycle.cycleFor(isoDate: today).anchorISO
        if fromLedger.contains(current) { return fromLedger }
        return (fromLedger + [current]).sorted()
    }

    private var activeAnchor: String {
        selectedAnchor ?? anchors.last ?? Cycle.cycleFor(isoDate: Self.todayISO()).anchorISO
    }

    private var currentSnapshot: Settlement.CycleSnapshot? {
        history.first { $0.anchorISO == activeAnchor }
            ?? Settlement.CycleSnapshot(
                anchorISO: activeAnchor,
                result: Settlement.compute(
                    cycleAnchorISO: activeAnchor,
                    rows: ledgerRows,
                    carriedCreditC: carriedCredit(before: activeAnchor),
                    tabBeforeC: tabBefore(before: activeAnchor)
                )
            )
    }

    private var cycleShares: Settlement.HouseholdShares {
        Settlement.householdShares(cycleAnchorISO: activeAnchor, rows: ledgerRows)
    }

    var body: some View {
        let snap = currentSnapshot
        let fern = people.first { $0.id == .fern }?.name ?? "Fern"
        let stark = people.first { $0.id == .stark }?.name ?? "Stark"
        NavigationStack {
            VStack(spacing: 0) {
                Seg(options: ["The split", "The Love Tab"], selection: $pane)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)

                if pane == 0 {
                    splitPane(snap: snap, fernName: fern, starkName: stark)
                } else {
                    loveTabPane(fernName: fern, starkName: stark)
                }
            }
            .background(Color.pantomina.ground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        PetTitle("Whose Turn Is It")
                        Text("Bills due · \(DisplayLabels.displayDate(iso: activeAnchor))")
                            .font(PantominaFont.caption)
                            .foregroundStyle(Color.pantomina.muted)
                    }
                }
            }
            .sheet(isPresented: $showLogContribution) {
                contributionSheet(starkName: stark)
            }
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast)
                        .padding()
                        .background(Color.pantomina.ink)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .padding(.bottom, 24)
                }
            }
            .onAppear {
                if selectedAnchor == nil {
                    selectedAnchor = anchors.last
                }
            }
        }
    }

    @ViewBuilder
    private func splitPane(
        snap: Settlement.CycleSnapshot?,
        fernName: String,
        starkName: String
    ) -> some View {
        let result = snap?.result
        let shares = cycleShares
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if !anchors.isEmpty {
                    Picker("Cycle", selection: Binding(
                        get: { activeAnchor },
                        set: { selectedAnchor = $0 }
                    )) {
                        ForEach(anchors.reversed(), id: \.self) { anchor in
                            Text(DisplayLabels.displayDate(iso: anchor)).tag(anchor)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Cycle")
                }

                if let result {
                    Card {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            HStack {
                                Eyebrow("Settle this cycle")
                                Spacer()
                                Chip(
                                    label: result.dueC == 0 && shares.pendingCount > 0
                                        ? "Nothing counted yet"
                                        : DisplayLabels.settlementStatus(result.status),
                                    tone: result.dueC == 0 && shares.pendingCount > 0
                                        ? .terra
                                        : (result.status == .partial ? .terra : .sage)
                                )
                            }

                            metricRow("\(starkName)'s share", result.dueC)
                            metricRow("Sent over", result.contributedC)
                            metricRow(
                                "Still open",
                                result.remainingC,
                                emphasize: result.remainingC > 0
                            )

                            GeometryReader { geo in
                                let pct = result.dueC == 0
                                    ? 0.0
                                    : min(1.0, Double(result.contributedC + result.carriedCreditC) / Double(result.dueC))
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.pantomina.hairline)
                                    Capsule()
                                        .fill(Color.pantomina.sage)
                                        .frame(width: pct == 0 ? 0 : max(8, geo.size.width * pct))
                                }
                            }
                            .frame(height: 8)
                            .accessibilityLabel("Contribution progress")

                            if result.carriedCreditC > 0 {
                                Text("Includes \(formatPeso(result.carriedCreditC)) credit from last cycle.")
                                    .font(PantominaFont.caption)
                                    .foregroundStyle(Color.pantomina.muted)
                            }

                            if result.dueC == 0 && shares.fernC == 0 && shares.starkC == 0 {
                                Text("Shared spends land here once counted. Use House cash box, or count the card on Statement day.")
                                    .font(PantominaFont.caption)
                                    .foregroundStyle(Color.pantomina.muted)
                            } else {
                                Text("\(starkName) sent \(formatPeso(result.contributedC)) of \(formatPeso(result.dueC)) this cycle.")
                                    .font(PantominaFont.caption)
                                    .foregroundStyle(Color.pantomina.muted)
                            }
                        }
                    }

                    if shares.fernC > 0 || shares.starkC > 0 {
                        fernShareCard(shares, fernName: fernName, starkName: starkName)
                    }

                    Button {
                        contributionText = ""
                        contributionError = nil
                        showLogContribution = true
                    } label: {
                        Text("Log a contribution")
                            .font(PantominaFont.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 48)
                            .background(Color.pantomina.sage)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: Spacing.radius, style: .continuous))
                    }
                    .buttonStyle(SageButtonStyle())

                    if result.remainingC > 0 {
                        Button {
                            postReceivable(remainingC: result.remainingC, anchor: activeAnchor)
                        } label: {
                            Text("Post remaining to Love Tab")
                                .font(PantominaFont.body.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 48)
                                .background(Color.pantomina.terra.opacity(0.2))
                                .foregroundStyle(Color.pantomina.terraDeep)
                                .clipShape(RoundedRectangle(cornerRadius: Spacing.radius, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text("Nothing settled in this cycle yet.")
                        .font(PantominaFont.body)
                        .foregroundStyle(Color.pantomina.muted)
                }
            }
            .padding(Spacing.lg)
        }
    }

    private func fernShareCard(
        _ shares: Settlement.HouseholdShares,
        fernName: String,
        starkName: String
    ) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Eyebrow(shares.pendingCount > 0 ? "On the statement" : "Shared spends")
                HStack {
                    Text("\(fernName)'s share")
                        .font(PantominaFont.body)
                        .foregroundStyle(Color.pantomina.muted)
                    Spacer()
                    Text(formatPeso(shares.fernC))
                        .font(PantominaFont.body.weight(.medium).monospacedDigit())
                        .foregroundStyle(Color.pantomina.sageDeep)
                }
                if shares.pendingCount > 0 {
                    Text(
                        "\(shares.pendingCount) card swipe\(shares.pendingCount == 1 ? "" : "s") still waiting. \(starkName)'s half on those (\(formatPeso(shares.starkC))) won’t add to what she owes above."
                    )
                    .font(PantominaFont.caption)
                    .foregroundStyle(Color.pantomina.muted)
                } else {
                    Text("\(fernName)'s half of shared spends this cycle — for planning the bills, not a tab the other way.")
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.muted)
                }
            }
        }
    }

    private func loveTabPane(fernName: String, starkName: String) -> some View {
        let balance = history.last?.result.tabAfterC
            ?? currentSnapshot?.result.tabAfterC
            ?? 0
        let credit = history.last?.result.creditOutC ?? 0
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Card {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Eyebrow("The Love Tab")
                        Text(formatPeso(balance))
                            .font(PantominaFont.amount)
                            .monospacedDigit()
                            .foregroundStyle(Color.pantomina.ink)
                        Text("\(fernName)'s asset · \(starkName)'s open balance. Stays at ₱0 or above.")
                            .font(PantominaFont.caption)
                            .foregroundStyle(Color.pantomina.muted)
                        if credit > 0 {
                            Text("Credit for next cycle: \(formatPeso(credit))")
                                .font(PantominaFont.caption)
                                .foregroundStyle(Color.pantomina.sageDeep)
                        }
                    }
                }

                if history.isEmpty {
                    Text("No cycles on the tab yet.")
                        .font(PantominaFont.body)
                        .foregroundStyle(Color.pantomina.muted)
                } else {
                    Eyebrow("Cycle history")
                    ForEach(history.reversed(), id: \.anchorISO) { snap in
                        Card {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(DisplayLabels.displayDate(iso: snap.anchorISO))
                                        .font(PantominaFont.body.weight(.medium))
                                    Text("due \(formatPeso(snap.result.dueC)) · sent \(formatPeso(snap.result.contributedC))")
                                        .font(PantominaFont.caption)
                                        .foregroundStyle(Color.pantomina.muted)
                                }
                                Spacer()
                                Chip(
                                    label: DisplayLabels.settlementStatus(snap.result.status),
                                    tone: snap.result.status == .partial ? .terra : .sage
                                )
                            }
                        }
                    }
                }
            }
            .padding(Spacing.lg)
        }
    }

    private func contributionSheet(starkName: String) -> some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Amount", text: $contributionText)
                        .keyboardType(.decimalPad)
                    if let contributionError {
                        Text(contributionError)
                            .foregroundStyle(Color.pantomina.terraDeep)
                    }
                } header: {
                    Text("Contribution")
                } footer: {
                    Text("Counts toward \(starkName)'s share for \(DisplayLabels.displayDate(iso: activeAnchor)).")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.pantomina.ground)
            .navigationTitle("Log a contribution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showLogContribution = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveContribution() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func metricRow(_ label: String, _ cents: Int, emphasize: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(PantominaFont.body)
                .foregroundStyle(Color.pantomina.muted)
            Spacer()
            Text(formatPeso(cents))
                .font(
                    emphasize
                        ? PantominaFont.body.weight(.semibold).monospacedDigit()
                        : PantominaFont.body.monospacedDigit()
                )
                .foregroundStyle(Color.pantomina.ink)
        }
    }

    private func carriedCredit(before anchor: String) -> Int {
        guard let idx = history.firstIndex(where: { $0.anchorISO == anchor }), idx > 0 else {
            // Recompute prefix if history doesn't include empty current cycle yet
            let prior = anchors.filter { $0 < anchor }
            return Settlement.history(rows: ledgerRows, anchors: prior).last?.result.creditOutC ?? 0
        }
        return history[idx - 1].result.creditOutC
    }

    private func tabBefore(before anchor: String) -> Int {
        let prior = anchors.filter { $0 < anchor }
        return Settlement.history(rows: ledgerRows, anchors: prior).last?.result.tabAfterC ?? 0
    }

    private func saveContribution() {
        contributionError = nil
        guard let amountC = InputBounds.centavos(fromPesosText: contributionText), amountC > 0 else {
            contributionError = "Enter an amount."
            return
        }
        guard let category = categories.first(where: { $0.system && $0.item == "Partner Contribution" }) else {
            contributionError = "Contribution category missing."
            return
        }
        guard let account = accounts.first(where: { !$0.archived && $0.scope == .household && $0.settlement == .instant })
                ?? accounts.first(where: { !$0.archived && $0.scope == .household })
        else {
            contributionError = "No shared account to post against."
            return
        }
        let tx = TransactionRecord(
            purchaseDate: activeAnchor,
            realizedDate: activeAnchor,
            realizedStatus: .realized,
            amountC: amountC,
            accountId: account.id,
            categoryId: category.id,
            paidBy: .stark,
            allocation: Allocation(fern: 0, stark: 0),
            settlementRole: .contribution,
            note: "Contribution for \(activeAnchor)"
        )
        modelContext.insert(tx)
        do {
            try modelContext.save()
            // Defer UI mutation — same AttributeGraph trap as Add save.
            Task { @MainActor in
                showLogContribution = false
                PantominaMotion.run(reduceMotion) { toast = "Contribution logged." }
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                PantominaMotion.run(reduceMotion) { toast = nil }
            }
        } catch {
            contributionError = "Couldn't save. Try again."
        }
    }

    private func postReceivable(remainingC: Int, anchor: String) {
        // Avoid duplicate receivable for the same cycle.
        let already = transactions.contains {
            $0.settlementRole == .receivable
                && $0.realizedDate == anchor
                && $0.amountC == remainingC
        }
        guard !already else {
            PantominaMotion.run(reduceMotion) { toast = "Already on the Love Tab." }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                PantominaMotion.run(reduceMotion) { toast = nil }
            }
            return
        }
        guard let category = categories.first(where: { $0.system && $0.item == "Partner Receivable" }) else { return }
        guard let account = accounts.first(where: { !$0.archived && $0.scope == .household }) else { return }
        let tx = TransactionRecord(
            purchaseDate: anchor,
            realizedDate: anchor,
            realizedStatus: .realized,
            amountC: remainingC,
            accountId: account.id,
            categoryId: category.id,
            paidBy: .stark,
            allocation: Allocation(fern: 0, stark: remainingC),
            settlementRole: .receivable,
            note: "Remaining for \(anchor)"
        )
        modelContext.insert(tx)
        try? modelContext.save()
        Task { @MainActor in
            PantominaMotion.run(reduceMotion) { toast = "Posted to the Love Tab." }
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            PantominaMotion.run(reduceMotion) { toast = nil }
        }
    }

    private static func todayISO() -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
