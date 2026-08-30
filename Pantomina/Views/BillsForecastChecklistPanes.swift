import SwiftUI
import SwiftData

/// Forecast + Checklist panes for Bills (Slice A).
struct BillsForecastPane: View {
    let cycleISO: String
    let forecast: Forecast.Result
    let onPickCycle: () -> AnyView

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                onPickCycle()

                Card {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Eyebrow("This cycle")
                        Text(DisplayLabels.forecastVerdict(forecast.verdict, roomC: forecast.breathingRoomC))
                            .font(PantominaFont.amount)
                            .foregroundStyle(
                                forecast.verdict == .over ? Color.pantomina.terraDeep : Color.pantomina.ink
                            )
                        if forecast.verdict == .over {
                            Text("Short? Fund raids land in Phase 5 — for now, trim spends or log a contribution on The split.")
                                .font(PantominaFont.caption)
                                .foregroundStyle(Color.pantomina.terraDeep)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("In \(formatPeso(forecast.expectedInC))")
                            Text("Committed \(formatPeso(forecast.committedC))")
                            Text("Typical variable \(formatPeso(forecast.typicalVariableC))")
                        }
                        .font(PantominaFont.caption.monospacedDigit())
                        .foregroundStyle(Color.pantomina.muted)
                    }
                }

                if forecast.expectedIn.isEmpty && forecast.committed.isEmpty {
                    Text("Nothing projected this cycle yet. Rules live under More → Things We Keep Doing.")
                        .font(PantominaFont.body)
                        .foregroundStyle(Color.pantomina.muted)
                } else {
                    if !forecast.expectedIn.isEmpty {
                        Eyebrow("Expected in")
                        ForEach(forecast.expectedIn, id: \.id) { line in
                            forecastRow(line)
                        }
                    }
                    if !forecast.committed.isEmpty {
                        Eyebrow("Committed")
                        ForEach(forecast.committed, id: \.id) { line in
                            forecastRow(line)
                        }
                    }
                }
            }
            .padding(Spacing.lg)
        }
    }

    private func forecastRow(_ line: Forecast.Line) -> some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.title)
                        .font(PantominaFont.body)
                    Text(DisplayLabels.forecastReason(line.reason))
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.muted)
                }
                Spacer()
                Text(formatPeso(line.amountC))
                    .font(PantominaFont.body.weight(.semibold).monospacedDigit())
            }
        }
    }
}

struct BillsChecklistPane: View {
    let cycleISO: String
    let tasks: [Checklist.Task]
    let summary: Checklist.Summary
    let accountLabels: [String: String]
    /// Task id while Count it sheet is open — keeps toggle visually on until cancel/count.
    var pendingTaskId: String? = nil
    let onPickCycle: () -> AnyView
    let onToggle: (Checklist.Task) -> Void
    let onOpenStatement: (String) -> Void

    /// Armed in the same frame as the Toggle gesture so get stays true before parent sets pendingTaskId.
    @State private var armedTaskId: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                onPickCycle()

                Text("\(summary.doneCount) of \(summary.totalCount) paid · \(formatPeso(summary.stillToSendC)) still to send")
                    .font(PantominaFont.body.weight(.medium).monospacedDigit())
                    .foregroundStyle(Color.pantomina.ink)

                if tasks.isEmpty {
                    Text("Nothing on the checklist this cycle yet. Rules live under More → Things We Keep Doing.")
                        .font(PantominaFont.body)
                        .foregroundStyle(Color.pantomina.muted)
                } else {
                    ForEach(tasks, id: \.id) { task in
                        Card {
                            if task.kind == .ccStatement {
                                Button {
                                    onOpenStatement(task.sourceAccountId)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(task.title)
                                                .font(PantominaFont.body.weight(.medium))
                                            Text(accountLabels[task.sourceAccountId] ?? "Card")
                                                .font(PantominaFont.caption)
                                                .foregroundStyle(Color.pantomina.muted)
                                            if task.pastCutoff {
                                                Text("Past cutoff — still waiting")
                                                    .font(PantominaFont.caption)
                                                    .foregroundStyle(Color.pantomina.terraDeep)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(Color.pantomina.sage)
                                    }
                                }
                                .buttonStyle(.plain)
                            } else {
                                Toggle(isOn: Binding(
                                    get: {
                                        task.done || pendingTaskId == task.id || armedTaskId == task.id
                                    },
                                    set: { isOn in
                                        guard isOn, !task.done else { return }
                                        armedTaskId = task.id
                                        onToggle(task)
                                    }
                                )) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(task.title)
                                            .font(PantominaFont.body)
                                        if task.kind == .fundTranche {
                                            Text(
                                                DisplayLabels.fundingStatus(
                                                    .funded(done: task.paymentsDone, total: max(1, task.paymentsRequired))
                                                )
                                            )
                                            .font(PantominaFont.caption)
                                            .foregroundStyle(Color.pantomina.sageDeep)
                                        }
                                        Text(formatPeso(task.amountC))
                                            .font(PantominaFont.caption.monospacedDigit())
                                            .foregroundStyle(Color.pantomina.muted)
                                        if task.pastCutoff && !task.done {
                                            Text("Past cutoff — still waiting")
                                                .font(PantominaFont.caption)
                                                .foregroundStyle(Color.pantomina.terraDeep)
                                        }
                                        if task.amountBehavior == .estimate && !task.done {
                                            Text("Estimate — you’ll confirm the amount")
                                                .font(PantominaFont.caption)
                                                .foregroundStyle(Color.pantomina.muted)
                                        }
                                    }
                                }
                                .disabled(task.done)
                                .transaction { $0.animation = nil }
                            }
                        }
                    }
                }
            }
            .padding(Spacing.lg)
        }
        .onChange(of: pendingTaskId) { _, newValue in
            if newValue == nil {
                armedTaskId = nil
            }
        }
    }
}
