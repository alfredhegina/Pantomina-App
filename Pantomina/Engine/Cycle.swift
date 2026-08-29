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
            let day = Int(cursor.anchorISO.split(separator: "-")[2]) ?? 0
            if cutoff == 15, day == 15 { return cursor }
            if cutoff == 30, day != 15 { return cursor }
        }
        preconditionFailure("could not find next statement cycle")
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
}
