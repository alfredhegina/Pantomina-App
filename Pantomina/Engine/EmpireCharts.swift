import Foundation

/// Empire chart series — pure. UI plots these points; does not recompute NW.
enum EmpireCharts {
    struct Point: Equatable, Sendable {
        var cycleAnchorISO: String
        var assetsC: Int
        var liabilitiesC: Int
        var netWorthC: Int

        init(cycleAnchorISO: String, assetsC: Int, liabilitiesC: Int, netWorthC: Int) {
            self.cycleAnchorISO = cycleAnchorISO
            self.assetsC = assetsC
            self.liabilitiesC = liabilitiesC
            self.netWorthC = netWorthC
        }

        init(cycleAnchorISO: String, metrics: Snapshot.Metrics) {
            self.cycleAnchorISO = cycleAnchorISO
            self.assetsC = metrics.assetsC
            self.liabilitiesC = metrics.liabilitiesC
            self.netWorthC = metrics.netWorthC
        }
    }

    /// One Balance Day / demo row for series building.
    struct SnapInput: Equatable, Sendable {
        var cycleAnchorISO: String
        var personId: String
        var confirmedAt: Date
        var lines: [Snapshot.Line]
        var metrics: Snapshot.Metrics

        var hasLinedPockets: Bool { !lines.isEmpty }
    }

    /// Personal history: one point per cycle (latest confirm wins). Includes metrics-only demos.
    static func personalSeries(snapshots: [SnapInput], personId: String) -> [Point] {
        let mine = snapshots.filter { $0.personId == personId }
        let byAnchor = Dictionary(grouping: mine, by: \.cycleAnchorISO)
        return byAnchor.keys.sorted().compactMap { anchor in
            guard let best = byAnchor[anchor]?.max(by: { $0.confirmedAt < $1.confirmedAt }) else {
                return nil
            }
            return Point(cycleAnchorISO: anchor, metrics: best.metrics)
        }
    }

    /// Household: anchors where **both** have lined snaps; metrics via household lens.
    static func householdSeries(fern: [SnapInput], stark: [SnapInput]) -> [Point] {
        let fernBy = Dictionary(
            grouping: fern.filter(\.hasLinedPockets),
            by: \.cycleAnchorISO
        )
        let starkBy = Dictionary(
            grouping: stark.filter(\.hasLinedPockets),
            by: \.cycleAnchorISO
        )
        let shared = Set(fernBy.keys).intersection(starkBy.keys).sorted()
        return shared.compactMap { anchor in
            guard let f = fernBy[anchor]?.max(by: { $0.confirmedAt < $1.confirmedAt }),
                  let s = starkBy[anchor]?.max(by: { $0.confirmedAt < $1.confirmedAt })
            else { return nil }
            let m = Snapshot.metrics(
                lines: f.lines + s.lines,
                prior: nil,
                lens: .household
            )
            return Point(cycleAnchorISO: anchor, metrics: m)
        }
    }

    /// Append live tip when there is no snapshot point for `activeAnchor` yet.
    static func withLiveTip(series: [Point], live: Point?, activeAnchor: String) -> [Point] {
        guard let live else { return series }
        guard live.cycleAnchorISO == activeAnchor else { return series }
        if series.contains(where: { $0.cycleAnchorISO == activeAnchor }) {
            return series
        }
        return (series + [live]).sorted { $0.cycleAnchorISO < $1.cycleAnchorISO }
    }

    /// Chart series for one calendar year (store-all, plot-windowed).
    static func points(inYear year: Int, series: [Point]) -> [Point] {
        let prefix = String(format: "%04d-", year)
        return series.filter { $0.cycleAnchorISO.hasPrefix(prefix) }
    }

    /// NW step vs previous point in series (nil for first / missing). Pure; for tooltip copy.
    static func netWorthDeltaVsPrevious(series: [Point], cycleAnchorISO: String) -> Int? {
        let sorted = series.sorted { $0.cycleAnchorISO < $1.cycleAnchorISO }
        guard let idx = sorted.firstIndex(where: { $0.cycleAnchorISO == cycleAnchorISO }),
              idx > 0
        else { return nil }
        return sorted[idx].netWorthC - sorted[idx - 1].netWorthC
    }
}
