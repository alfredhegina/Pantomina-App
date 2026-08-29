import Foundation

/// Formats integer centavos as a peso string. Never use floating money in the ledger.
public func formatPeso(_ centavos: Int, fractionDigits: Int = 2) -> String {
    let grouping = NumberFormatter()
    grouping.locale = Locale(identifier: "en_PH")
    grouping.numberStyle = .decimal
    grouping.usesGroupingSeparator = true
    grouping.maximumFractionDigits = 0
    grouping.minimumFractionDigits = 0

    if fractionDigits == 0 {
        let pesos = Int((Double(centavos) / 100.0).rounded())
        let body = grouping.string(from: NSNumber(value: pesos)) ?? "\(pesos)"
        return "₱\(body)"
    }

    let negative = centavos < 0
    let absC = abs(centavos)
    let whole = absC / 100
    let frac = absC % 100
    let groupedWhole = grouping.string(from: NSNumber(value: whole)) ?? "\(whole)"
    let fracStr = String(format: "%02d", frac)
    return "₱\(negative ? "-" : "")\(groupedWhole).\(fracStr)"
}
