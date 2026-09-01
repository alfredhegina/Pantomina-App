import Foundation
import Testing
@testable import Pantomina

@Suite("EmpireCharts")
struct EmpireChartsTests {
    private func line(
        id: String,
        balanceC: Int,
        liability: Bool = false,
        internalDebt: Bool = false
    ) -> Snapshot.Line {
        Snapshot.Line(
            accountId: id,
            balanceC: balanceC,
            source: .confirmed,
            isLiability: liability,
            countsTowardSavingsAssets: false,
            isInternalDebt: internalDebt
        )
    }

    private func snap(
        person: String,
        cycle: String,
        confirmedAt: Date,
        lines: [Snapshot.Line],
        metrics: Snapshot.Metrics? = nil
    ) -> EmpireCharts.SnapInput {
        let m = metrics ?? Snapshot.metrics(lines: lines, prior: nil, lens: .personal)
        return EmpireCharts.SnapInput(
            cycleAnchorISO: cycle,
            personId: person,
            confirmedAt: confirmedAt,
            lines: lines,
            metrics: m
        )
    }

    @Test("personalSeries sorts and dedupes by latest confirm")
    func personalDedupe() {
        let older = snap(
            person: "fern",
            cycle: "2026-08-15",
            confirmedAt: Date(timeIntervalSince1970: 1),
            lines: [line(id: "a", balanceC: 1_000_00)],
            metrics: Snapshot.Metrics(
                assetsC: 1_000_00,
                liabilitiesC: 0,
                netWorthC: 1_000_00,
                netWorthDeltaC: 0,
                assetsDeltaC: 0,
                liabilitiesDeltaC: 0,
                savingsAssetsC: 0
            )
        )
        let newer = snap(
            person: "fern",
            cycle: "2026-08-15",
            confirmedAt: Date(timeIntervalSince1970: 2),
            lines: [line(id: "a", balanceC: 2_000_00)],
            metrics: Snapshot.Metrics(
                assetsC: 2_000_00,
                liabilitiesC: 0,
                netWorthC: 2_000_00,
                netWorthDeltaC: 0,
                assetsDeltaC: 0,
                liabilitiesDeltaC: 0,
                savingsAssetsC: 0
            )
        )
        let laterCycle = snap(
            person: "fern",
            cycle: "2026-08-31",
            confirmedAt: Date(timeIntervalSince1970: 3),
            lines: [],
            metrics: Snapshot.Metrics(
                assetsC: 57_349_347,
                liabilitiesC: 72_503_145,
                netWorthC: -15_153_798,
                netWorthDeltaC: 0,
                assetsDeltaC: 0,
                liabilitiesDeltaC: 0,
                savingsAssetsC: 0
            )
        )
        let series = EmpireCharts.personalSeries(
            snapshots: [laterCycle, older, newer],
            personId: "fern"
        )
        #expect(series.count == 2)
        #expect(series[0].cycleAnchorISO == "2026-08-15")
        #expect(series[0].netWorthC == 2_000_00)
        #expect(series[1].netWorthC == -15_153_798)
    }

    @Test("negative net worth is preserved in series")
    func negativePreserved() {
        let s = snap(
            person: "fern",
            cycle: "2026-08-20",
            confirmedAt: .now,
            lines: [],
            metrics: PortfolioFern0820.metrics
        )
        let series = EmpireCharts.personalSeries(snapshots: [s], personId: "fern")
        #expect(series.first?.netWorthC == PortfolioFern0820.metrics.netWorthC)
        #expect(series.first!.netWorthC < 0)
    }

    @Test("householdSeries nets internal debt and needs both lined snaps")
    func householdNets() {
        let fern = snap(
            person: "fern",
            cycle: "2026-08-31",
            confirmedAt: .now,
            lines: [
                line(id: "cash", balanceC: 10_000_00),
                line(id: "tab", balanceC: 5_000_00, internalDebt: true),
            ]
        )
        let stark = snap(
            person: "stark",
            cycle: "2026-08-31",
            confirmedAt: .now,
            lines: [line(id: "scash", balanceC: 3_000_00)]
        )
        let onlyFern = EmpireCharts.householdSeries(fern: [fern], stark: [])
        #expect(onlyFern.isEmpty)

        let both = EmpireCharts.householdSeries(fern: [fern], stark: [stark])
        #expect(both.count == 1)
        // Personal would include tab; household nets it out → 10k + 3k
        #expect(both[0].assetsC == 13_000_00)
        #expect(both[0].netWorthC == 13_000_00)
    }

    @Test("withLiveTip appends only when anchor missing")
    func liveTip() {
        let existing = [
            EmpireCharts.Point(cycleAnchorISO: "2026-08-15", assetsC: 1, liabilitiesC: 0, netWorthC: 1)
        ]
        let tip = EmpireCharts.Point(
            cycleAnchorISO: "2026-08-31",
            assetsC: 9,
            liabilitiesC: 1,
            netWorthC: 8
        )
        let with = EmpireCharts.withLiveTip(series: existing, live: tip, activeAnchor: "2026-08-31")
        #expect(with.count == 2)
        #expect(with.last?.netWorthC == 8)

        let noDup = EmpireCharts.withLiveTip(series: existing, live: tip, activeAnchor: "2026-08-15")
        // live tip cycle must match activeAnchor — tip is Aug 31, active Aug 15 → unchanged
        #expect(noDup.count == 1)

        let replaceBlocked = EmpireCharts.withLiveTip(
            series: existing + [tip],
            live: EmpireCharts.Point(cycleAnchorISO: "2026-08-31", assetsC: 99, liabilitiesC: 0, netWorthC: 99),
            activeAnchor: "2026-08-31"
        )
        #expect(replaceBlocked.last?.netWorthC == 8)
    }

    @Test("netWorthDeltaVsPrevious is step vs prior point")
    func deltaVsPrevious() {
        let series = [
            EmpireCharts.Point(cycleAnchorISO: "2026-08-15", assetsC: 10, liabilitiesC: 2, netWorthC: 8),
            EmpireCharts.Point(cycleAnchorISO: "2026-08-31", assetsC: 12, liabilitiesC: 2, netWorthC: 10),
            EmpireCharts.Point(cycleAnchorISO: "2026-09-15", assetsC: 9, liabilitiesC: 3, netWorthC: 6),
        ]
        #expect(EmpireCharts.netWorthDeltaVsPrevious(series: series, cycleAnchorISO: "2026-08-15") == nil)
        #expect(EmpireCharts.netWorthDeltaVsPrevious(series: series, cycleAnchorISO: "2026-08-31") == 2)
        #expect(EmpireCharts.netWorthDeltaVsPrevious(series: series, cycleAnchorISO: "2026-09-15") == -4)
        #expect(EmpireCharts.netWorthDeltaVsPrevious(series: series, cycleAnchorISO: "2099-01-01") == nil)
    }

    @Test("points(inYear:) windows series without mutating storage order")
    func pointsInYear() {
        let series = [
            EmpireCharts.Point(cycleAnchorISO: "2025-12-31", assetsC: 1, liabilitiesC: 0, netWorthC: 1),
            EmpireCharts.Point(cycleAnchorISO: "2026-08-15", assetsC: 2, liabilitiesC: 0, netWorthC: 2),
            EmpireCharts.Point(cycleAnchorISO: "2026-08-31", assetsC: 3, liabilitiesC: 0, netWorthC: 3),
            EmpireCharts.Point(cycleAnchorISO: "2027-01-15", assetsC: 4, liabilitiesC: 0, netWorthC: 4),
        ]
        let y26 = EmpireCharts.points(inYear: 2026, series: series)
        #expect(y26.map(\.cycleAnchorISO) == ["2026-08-15", "2026-08-31"])
    }
}
