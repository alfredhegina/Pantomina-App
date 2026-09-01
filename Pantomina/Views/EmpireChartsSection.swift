import Charts
import SwiftUI

/// Empire history charts — hero NW line (above fold), or assets/liabilities below.
struct EmpireChartsSection: View {
    enum Style {
        /// Full-width NW line + area for the Empire hero.
        case hero
        /// Assets & liabilities only (NW lives in the hero).
        case assetsLiabilities
    }

    let series: [EmpireCharts.Point]
    var style: Style = .hero
    /// Soft blush wash on hero when NW gained this cycle.
    var celebrateGain: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedNW: String?
    @State private var selectedAL: String?
    @State private var reveal: CGFloat = 0

    private var seriesFingerprint: String {
        series.map { "\($0.cycleAnchorISO):\($0.netWorthC)" }.joined(separator: "|")
    }

    private var selectedNWPoint: EmpireCharts.Point? {
        guard let selectedNW else { return nil }
        return series.first { $0.cycleAnchorISO == selectedNW }
    }

    private var selectedALPoint: EmpireCharts.Point? {
        guard let selectedAL else { return nil }
        return series.first { $0.cycleAnchorISO == selectedAL }
    }

    private var selectedNWStepDeltaC: Int? {
        guard let selectedNW else { return nil }
        return EmpireCharts.netWorthDeltaVsPrevious(series: series, cycleAnchorISO: selectedNW)
    }

    var body: some View {
        switch style {
        case .hero:
            heroBody
        case .assetsLiabilities:
            assetsLiabilitiesBody
        }
    }

    @ViewBuilder
    private var heroBody: some View {
        if series.isEmpty {
            Text("Confirm a cycle’s balances—the empire line starts here.")
                .font(PantominaFont.caption)
                .foregroundStyle(Color.pantomina.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                heroChart
                    .frame(height: 168)
                    .padding(.vertical, Spacing.xs)
                    .padding(.horizontal, Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Spacing.radius, style: .continuous)
                            .fill(celebrateGain ? Color.pantomina.blush.opacity(0.45) : Color.pantomina.card)
                    )
                    .mask(alignment: .leading) {
                        Rectangle()
                            .scaleEffect(x: max(reveal, 0.001), anchor: .leading)
                    }
                    .onAppear { runReveal() }
                    .onChange(of: seriesFingerprint) { _, _ in runReveal() }
                    .accessibilityLabel("Net worth over cycles")

                if let p = selectedNWPoint {
                    selectionTooltip(
                        dateISO: p.cycleAnchorISO,
                        amountLine: formatPeso(p.netWorthC),
                        stepDeltaC: selectedNWStepDeltaC
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var assetsLiabilitiesBody: some View {
        if series.isEmpty {
            Section {
                Text("Confirm a cycle’s balances—the empire line starts here.")
                    .foregroundStyle(Color.pantomina.muted)
            }
        } else {
            Section {
                assetsLiabilitiesChart
                    .frame(height: 180)
                if let p = selectedALPoint {
                    Text(
                        "\(DisplayLabels.displayDate(iso: p.cycleAnchorISO)) · assets \(formatPeso(p.assetsC)) · liabilities \(formatPeso(p.liabilitiesC))"
                    )
                    .font(PantominaFont.caption)
                    .foregroundStyle(Color.pantomina.muted)
                } else {
                    HStack(spacing: Spacing.md) {
                        legendDot(Color.pantomina.sage, "Assets")
                        legendDot(Color.pantomina.terra, "Liabilities")
                    }
                    .font(PantominaFont.caption)
                }
            } header: {
                Text("Assets & liabilities")
            }
        }
    }

    private func selectionTooltip(dateISO: String, amountLine: String, stepDeltaC: Int?) -> some View {
        let gainedStep = (stepDeltaC ?? 0) > 0
        return VStack(alignment: .leading, spacing: 2) {
            Text(DisplayLabels.displayDate(iso: dateISO))
                .font(PantominaFont.caption)
                .foregroundStyle(Color.pantomina.muted)
            Text(amountLine)
                .font(PantominaFont.body.weight(.semibold))
                .foregroundStyle(Color.pantomina.ink)
                .monospacedDigit()
            if let stepDeltaC {
                Text(stepDeltaC > 0 ? "Up \(formatPeso(stepDeltaC))" : formatPeso(stepDeltaC))
                    .font(PantominaFont.caption)
                    .foregroundStyle(gainedStep ? Color.pantomina.sageDeep : Color.pantomina.muted)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Spacing.radius, style: .continuous)
                .fill(gainedStep ? Color.pantomina.blush.opacity(0.4) : Color.pantomina.card)
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.radius, style: .continuous)
                        .stroke(Color.pantomina.hairline, lineWidth: 1)
                )
        )
        .accessibilityLabel("Selected net worth")
    }

    private var heroChart: some View {
        Chart(series, id: \.cycleAnchorISO) { point in
            AreaMark(
                x: .value("Cycle", point.cycleAnchorISO),
                y: .value("Net worth", pesos(point.netWorthC))
            )
            .foregroundStyle(Color.pantomina.sage.opacity(0.22))
            .interpolationMethod(.linear)

            LineMark(
                x: .value("Cycle", point.cycleAnchorISO),
                y: .value("Net worth", pesos(point.netWorthC))
            )
            .foregroundStyle(Color.pantomina.sageDeep)
            .lineStyle(StrokeStyle(lineWidth: 2.5))
            .interpolationMethod(.linear)

            if series.count == 1 || selectedNW == point.cycleAnchorISO {
                PointMark(
                    x: .value("Cycle", point.cycleAnchorISO),
                    y: .value("Net worth", pesos(point.netWorthC))
                )
                .foregroundStyle(Color.pantomina.sageDeep)
                .symbolSize(selectedNW == point.cycleAnchorISO ? 64 : 36)
            }

            if let selectedNW, selectedNW == point.cycleAnchorISO {
                RuleMark(x: .value("Selected", selectedNW))
                    .foregroundStyle(Color.pantomina.hairline)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .chartXSelection(value: $selectedNW)
        .chartYScale(domain: yDomain(for: series.map(\.netWorthC)))
        .chartXAxis { cycleAxis }
        .chartYAxis { pesoAxis }
    }

    private var assetsLiabilitiesChart: some View {
        Chart {
            ForEach(series, id: \.cycleAnchorISO) { point in
                AreaMark(
                    x: .value("Cycle", point.cycleAnchorISO),
                    y: .value("Assets", pesos(point.assetsC)),
                    stacking: .unstacked
                )
                .foregroundStyle(Color.pantomina.sage.opacity(0.28))
                .interpolationMethod(.linear)

                LineMark(
                    x: .value("Cycle", point.cycleAnchorISO),
                    y: .value("Assets", pesos(point.assetsC)),
                    series: .value("Series", "Assets")
                )
                .foregroundStyle(Color.pantomina.sageDeep)
                .interpolationMethod(.linear)

                AreaMark(
                    x: .value("Cycle", point.cycleAnchorISO),
                    y: .value("Liabilities", pesos(point.liabilitiesC)),
                    stacking: .unstacked
                )
                .foregroundStyle(Color.pantomina.terra.opacity(0.22))
                .interpolationMethod(.linear)

                LineMark(
                    x: .value("Cycle", point.cycleAnchorISO),
                    y: .value("Liabilities", pesos(point.liabilitiesC)),
                    series: .value("Series", "Liabilities")
                )
                .foregroundStyle(Color.pantomina.terraDeep)
                .interpolationMethod(.linear)
            }

            if let selectedAL {
                RuleMark(x: .value("Selected", selectedAL))
                    .foregroundStyle(Color.pantomina.hairline)
            }
        }
        .chartXSelection(value: $selectedAL)
        .chartYScale(domain: yDomain(for: series.flatMap { [$0.assetsC, $0.liabilitiesC] }))
        .chartXAxis { cycleAxis }
        .chartYAxis { pesoAxis }
    }

    private func runReveal() {
        if reduceMotion {
            reveal = 1
            return
        }
        reveal = 0
        withAnimation(.easeOut(duration: 0.35)) {
            reveal = 1
        }
    }

    @AxisContentBuilder
    private var cycleAxis: some AxisContent {
        AxisMarks(values: .automatic) { value in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                .foregroundStyle(Color.pantomina.hairline)
            AxisValueLabel {
                if let iso = value.as(String.self) {
                    Text(shortCycleLabel(iso))
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.muted)
                }
            }
        }
    }

    @AxisContentBuilder
    private var pesoAxis: some AxisContent {
        AxisMarks(values: .automatic) { value in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                .foregroundStyle(Color.pantomina.hairline)
            AxisValueLabel {
                if let v = value.as(Double.self) {
                    Text(compactPeso(v))
                        .font(PantominaFont.caption)
                        .foregroundStyle(Color.pantomina.muted)
                }
            }
        }
    }

    private func legendDot(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .foregroundStyle(Color.pantomina.muted)
        }
    }

    private func pesos(_ centavos: Int) -> Double {
        Double(centavos) / 100.0
    }

    private func yDomain(for values: [Int]) -> ClosedRange<Double> {
        guard let minC = values.min(), let maxC = values.max() else { return -1 ... 1 }
        var lo = pesos(minC)
        var hi = pesos(maxC)
        if lo == hi {
            lo -= abs(lo) * 0.1 + 1
            hi += abs(hi) * 0.1 + 1
        } else {
            let pad = (hi - lo) * 0.08
            lo -= pad
            hi += pad
        }
        return lo ... hi
    }

    private func shortCycleLabel(_ iso: String) -> String {
        let parts = iso.split(separator: "-")
        guard parts.count == 3 else { return DisplayLabels.displayDate(iso: iso) }
        let month = Int(parts[1]) ?? 0
        let day = Int(parts[2]) ?? 0
        return "\(month)/\(day)"
    }

    private func compactPeso(_ pesos: Double) -> String {
        let absV = abs(pesos)
        let sign = pesos < 0 ? "−" : ""
        if absV >= 1_000_000 {
            return "\(sign)₱\(String(format: "%.1f", absV / 1_000_000))M"
        }
        if absV >= 1_000 {
            return "\(sign)₱\(String(format: "%.0f", absV / 1_000))k"
        }
        return "\(sign)₱\(String(format: "%.0f", absV))"
    }
}

/// Spec §1 micro-moment — rose heart pulse when net worth gained; static under Reduce Motion.
struct EmpireGainHeart: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 14))
            .foregroundStyle(Color.pantomina.rose)
            .scaleEffect(pulse ? 1.18 : 1.0)
            .accessibilityLabel("Net worth up this cycle")
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(PantominaMotion.spring) { pulse = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    withAnimation(PantominaMotion.feedback) { pulse = false }
                }
            }
    }
}
