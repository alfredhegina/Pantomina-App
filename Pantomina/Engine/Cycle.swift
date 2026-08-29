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
