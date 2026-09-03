import Foundation

/// Bi-weekly household cycle anchored to the 15th and month-end ("30th").
/// February month-end is the 28th or 29th.
public struct Cycle: Equatable, Sendable {
    /// Anchor date as ISO `YYYY-MM-DD`.
    public let anchorISO: String

    public init(anchorISO: String) {
        self.anchorISO = anchorISO
    }

    /// Cycle containing `isoDate` (also ISO `YYYY-MM-DD`).
    public static func cycleFor(isoDate: String) -> Cycle {
        let parts = isoDate.split(separator: "-").compactMap { Int($0) }
        precondition(parts.count == 3, "isoDate must be YYYY-MM-DD")
        let year = parts[0]
        let month = parts[1]
        let day = parts[2]

        if day <= 15 {
            return Cycle(anchorISO: String(format: "%04d-%02d-15", year, month))
        }

        let lastDay = lastDayOfMonth(year: year, month: month)
        return Cycle(anchorISO: String(format: "%04d-%02d-%02d", year, month, lastDay))
    }

    /// Next statement-cycle anchor after the cycle containing `isoDate`, matching cutoff 15 or month-end (30).
    public static func nextStatementCycle(isoDate: String, cutoff: Int) -> Cycle {
        precondition(cutoff == 15 || cutoff == 30, "cutoff must be 15 or 30")
        var cursor = cycleFor(isoDate: isoDate)
        // Skip the cycle that contains the purchase; land on the next cutoff-matching anchor.
        for _ in 0..<6 {
            cursor = nextHalfMonth(after: cursor)
            if matchesCutoff(cursor, cutoff: cutoff) { return cursor }
        }
        preconditionFailure("could not find next statement cycle")
    }

    /// Cutoff-matching anchors around `aroundISO` for Statement day "Counts on" picker.
    public static func statementAnchorCandidates(
        aroundISO: String,
        cutoff: Int,
        before: Int = 2,
        after: Int = 2
    ) -> [String] {
        precondition(cutoff == 15 || cutoff == 30, "cutoff must be 15 or 30")
        precondition(before >= 0 && after >= 0)
        var center = cycleFor(isoDate: aroundISO)
        for _ in 0..<3 {
            if matchesCutoff(center, cutoff: cutoff) { break }
            center = nextHalfMonth(after: center)
        }
        precondition(matchesCutoff(center, cutoff: cutoff), "no cutoff match near aroundISO")

        var prior: [Cycle] = []
        var cursor = center
        for _ in 0..<before {
            cursor = previousCutoffMatching(before: cursor, cutoff: cutoff)
            prior.insert(cursor, at: 0)
        }

        var later: [Cycle] = []
        cursor = center
        for _ in 0..<after {
            cursor = nextCutoffMatching(after: cursor, cutoff: cutoff)
            later.append(cursor)
        }

        return (prior + [center] + later).map(\.anchorISO)
    }

    public static func nextHalfMonth(after cycle: Cycle) -> Cycle {
        let parts = cycle.anchorISO.split(separator: "-").compactMap { Int($0) }
        precondition(parts.count == 3)
        let year = parts[0]
        let month = parts[1]
        let day = parts[2]
        if day == 15 {
            let last = lastDayOfMonth(year: year, month: month)
            return Cycle(anchorISO: String(format: "%04d-%02d-%02d", year, month, last))
        }
        // Month-end → next month's 15th
        var nextMonth = month + 1
        var nextYear = year
        if nextMonth > 12 {
            nextMonth = 1
            nextYear += 1
        }
        return Cycle(anchorISO: String(format: "%04d-%02d-15", nextYear, nextMonth))
    }

    public static func previousHalfMonth(before cycle: Cycle) -> Cycle {
        let parts = cycle.anchorISO.split(separator: "-").compactMap { Int($0) }
        precondition(parts.count == 3)
        let year = parts[0]
        let month = parts[1]
        let day = parts[2]
        if day == 15 {
            // Previous month's month-end
            var prevMonth = month - 1
            var prevYear = year
            if prevMonth < 1 {
                prevMonth = 12
                prevYear -= 1
            }
            let last = lastDayOfMonth(year: prevYear, month: prevMonth)
            return Cycle(anchorISO: String(format: "%04d-%02d-%02d", prevYear, prevMonth, last))
        }
        // Month-end → same month's 15th
        return Cycle(anchorISO: String(format: "%04d-%02d-15", year, month))
    }

    public static func lastDayOfMonth(year: Int, month: Int) -> Int {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        let cal = Calendar(identifier: .gregorian)
        guard let date = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: date)
        else {
            preconditionFailure("invalid year/month")
        }
        return range.count
    }

    /// Cycle Menu window: anchors whose ISO year matches (≤ ~24 half-months).
    public static func anchors(inYear year: Int, from candidates: [String]) -> [String] {
        let prefix = String(format: "%04d-", year)
        return Array(Set(candidates.filter { $0.hasPrefix(prefix) })).sorted()
    }

    /// Cap an unbounded candidate list to `limit` anchors nearest `aroundISO` (chronological).
    public static func recentAnchors(
        from candidates: [String],
        aroundISO: String,
        limit: Int = 24
    ) -> [String] {
        precondition(limit > 0)
        let sorted = Array(Set(candidates)).sorted()
        guard !sorted.isEmpty else { return [] }
        if sorted.count <= limit { return sorted }
        let target = cycleFor(isoDate: aroundISO).anchorISO
        let idx = sorted.firstIndex(of: target)
            ?? sorted.firstIndex(where: { $0 >= target })
            ?? (sorted.count - 1)
        var end = min(sorted.count, idx + 1 + limit / 2)
        var start = max(0, end - limit)
        end = min(sorted.count, start + limit)
        start = max(0, end - limit)
        return Array(sorted[start..<end])
    }

    private static func matchesCutoff(_ cycle: Cycle, cutoff: Int) -> Bool {
        let day = Int(cycle.anchorISO.split(separator: "-")[2]) ?? 0
        if cutoff == 15 { return day == 15 }
        return day != 15
    }

    private static func nextCutoffMatching(after cycle: Cycle, cutoff: Int) -> Cycle {
        var cursor = cycle
        for _ in 0..<4 {
            cursor = nextHalfMonth(after: cursor)
            if matchesCutoff(cursor, cutoff: cutoff) { return cursor }
        }
        preconditionFailure("could not find next cutoff match")
    }

    private static func previousCutoffMatching(before cycle: Cycle, cutoff: Int) -> Cycle {
        var cursor = cycle
        for _ in 0..<4 {
            cursor = previousHalfMonth(before: cursor)
            if matchesCutoff(cursor, cutoff: cutoff) { return cursor }
        }
        preconditionFailure("could not find previous cutoff match")
    }
}
