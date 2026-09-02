import SwiftUI
import SwiftData

/// Forecast + Checklist panes for Bills (Slice A).
struct BillsForecastPane: View {
    let cycleISO: String
    let forecast: Forecast.Result
    var onCoverShortfall: (() -> Void)? = nil
    var onParkLeftover: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero

                if forecast.expectedIn.isEmpty && forecast.committed.isEmpty {
                    Text("Nothing projected this cycle yet. Rules live under More → Things We Keep Doing.")
                        .font(PantominaFont.body)
                        .foregroundStyle(Color.pantomina.muted)
                        .padding(20)
                } else {
                    if !forecast.expectedIn.isEmpty {
                        sectionHead("Expected in")
                        VStack(spacing: 0) {
                            ForEach(forecast.expectedIn, id: \.id) { line in
                                forecastRow(line)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    if !forecast.committed.isEmpty {
                        sectionHead("Committed")
                            .padding(.top, 6)
                            .overlay(alignment: .top) {
                                Rectangle().fill(Color.pantomina.rule).frame(height: 1)
                            }
                        VStack(spacing: 0) {
                            ForEach(forecast.committed, id: \.id) { line in
                                forecastRow(line)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This cycle")
                .font(PantominaFont.body.weight(.semibold))
                .foregroundStyle(Color.pantomina.ink)
            VStack(alignment: .leading, spacing: 4) {
                if forecast.verdict == .tight {
                    Text("Right on the line")
                        .font(PantominaFont.body.weight(.semibold))
                        .foregroundStyle(Color.pantomina.ink)
                } else {
                    Text(formatPeso(abs(forecast.breathingRoomC)))
                        .font(PantominaFont.heroAmount(centavos: abs(forecast.breathingRoomC)))
                        .foregroundStyle(Color.pantomina.ink)
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(forecast.verdict == .over ? "over" : "breathing room")
                        .font(PantominaFont.body)
                        .foregroundStyle(Color.pantomina.muted)
                }
            }
            if forecast.verdict == .over {
                Button {
                    onCoverShortfall?()
                } label: {
                    Text("Short? Borrow from a fund to cover it.")
                        .font(PantominaFont.caption.weight(.medium))
                        .foregroundStyle(Color.pantomina.terraDeep)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Borrow from a fund to cover the shortfall")
            } else if forecast.verdict == .breathingRoom, forecast.breathingRoomC > 0 {
                Button {
                    onParkLeftover?()
                } label: {
                    Text("Leftover? Park it toward loan payoff.")
                        .font(PantominaFont.caption.weight(.medium))
                        .foregroundStyle(Color.pantomina.quietAccent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Park leftover toward loan payoff")
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("In \(formatPeso(forecast.expectedInC))")
                Text("Committed \(formatPeso(forecast.committedC))")
                Text("Typical variable \(formatPeso(forecast.typicalVariableC))")
            }
            .font(PantominaFont.caption.monospacedDigit())
            .foregroundStyle(Color.pantomina.muted)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.pantomina.rule).frame(height: 1)
        }
    }

    private func sectionHead(_ title: String) -> some View {
        Text(title)
            .font(PantominaFont.body.weight(.semibold))
            .foregroundStyle(Color.pantomina.ink)
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func forecastRow(_ line: Forecast.Line) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(line.title)
                    .font(PantominaFont.body.weight(.medium))
                    .foregroundStyle(Color.pantomina.ink)
                Text(DisplayLabels.forecastReason(line.reason))
                    .font(PantominaFont.caption)
                    .foregroundStyle(Color.pantomina.muted)
            }
            Spacer(minLength: 8)
            Text(formatPeso(line.amountC))
                .font(PantominaFont.body.weight(.medium).monospacedDigit())
                .foregroundStyle(
                    line.reason == .income ? Color.pantomina.quietAccent : Color.pantomina.ink
                )
        }
        .padding(.vertical, 11)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.pantomina.innerRule).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

struct BillsChecklistPane: View {
    let cycleISO: String
    let tasks: [Checklist.Task]
    let summary: Checklist.Summary
    let accountLabels: [String: String]
    /// Task id while Count it sheet is open — keeps toggle visually on until cancel/count.
    var pendingTaskId: String? = nil
    let onToggle: (Checklist.Task) -> Void
    let onOpenStatement: (String) -> Void

    /// Armed in the same frame as the Toggle gesture so get stays true before parent sets pendingTaskId.
    @State private var armedTaskId: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(summary.doneCount) of \(summary.totalCount) paid · \(formatPeso(summary.stillToSendC)) still to send")
                    .font(PantominaFont.body.weight(.medium).monospacedDigit())
                    .foregroundStyle(Color.pantomina.ink)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.pantomina.rule).frame(height: 1)
                    }

                if tasks.isEmpty {
                    Text("Nothing on the checklist this cycle yet. Rules live under More → Things We Keep Doing.")
                        .font(PantominaFont.body)
                        .foregroundStyle(Color.pantomina.muted)
                        .padding(20)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                            checklistRow(task, ruled: index > 0)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .onChange(of: pendingTaskId) { _, newValue in
            if newValue == nil {
                armedTaskId = nil
            }
        }
    }

    @ViewBuilder
    private func checklistRow(_ task: Checklist.Task, ruled: Bool) -> some View {
        Group {
            if task.kind == .ccStatement {
                Button {
                    onOpenStatement(task.sourceAccountId)
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .font(PantominaFont.body.weight(.medium))
                                .foregroundStyle(Color.pantomina.ink)
                            Text(accountLabels[task.sourceAccountId] ?? "Card")
                                .font(PantominaFont.caption)
                                .foregroundStyle(Color.pantomina.muted)
                            if task.pastCutoff {
                                Text("Past cutoff — still waiting")
                                    .font(PantominaFont.caption)
                                    .foregroundStyle(Color.pantomina.terraDeep)
                            }
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.pantomina.quietAccent)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
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
                            .strikethrough(task.done)
                            .foregroundStyle(task.done ? Color(hex: "#9A9691") : Color.pantomina.ink)
                        if task.kind == .fundTranche {
                            Text(
                                DisplayLabels.fundingStatus(
                                    .funded(done: task.paymentsDone, total: max(1, task.paymentsRequired))
                                )
                            )
                            .font(PantominaFont.caption)
                            .foregroundStyle(Color.pantomina.quietAccent)
                        }
                        Text(formatPeso(task.amountC))
                            .font(PantominaFont.caption.monospacedDigit())
                            .strikethrough(task.done)
                            .foregroundStyle(task.done ? Color(hex: "#9A9691") : Color.pantomina.muted)
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
                .tint(task.done ? Color(hex: "#B9C7BF") : Color.pantomina.quietAccent)
                .disabled(task.done)
                .transaction { $0.animation = nil }
            }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            if ruled {
                Rectangle().fill(Color.pantomina.innerRule).frame(height: 1)
            }
        }
    }
}
