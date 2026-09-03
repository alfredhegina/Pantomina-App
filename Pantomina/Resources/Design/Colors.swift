import SwiftUI

extension Color {
    static let pantomina = PantominaColors()
}

struct PantominaColors {
    let ground = Color(hex: "#FAF8F5")
    let card = Color(hex: "#FDFDFC")
    let ink = Color(hex: "#1D212B")
    let muted = Color(hex: "#6A7181")
    let hairline = Color(hex: "#E9E7E2")
    let sage = Color(hex: "#498D6D")
    let sageDeep = Color(hex: "#3B7157")
    let terra = Color(hex: "#EF8F6C")
    let terraDeep = Color(hex: "#D9764F")
    let blush = Color(hex: "#F6DCE1")
    let rose = Color(hex: "#B8405E")

    /// Quiet ledger accent (1c): AA-friendlier green for chrome / Earned.
    let quietAccent = Color(hex: "#2F6B52")
    /// Chart expense fill only (not amount text): 1c warm clay.
    let expenseBar = Color(hex: "#C98A6B")
    let rule = Color(hex: "#E4E1DA")
    /// Hairline between rows inside a quiet section.
    let innerRule = Color(hex: "#EDEAE3")
    /// Track behind quiet segmented pills.
    let segmentTrack = Color(hex: "#EFEDE7")

    /// Where it Went expense slices: amount-rank palette (tweak here; not Charts auto hues).
    let categoryAmber = Color(hex: "#D9A066")
    let categoryOlive = Color(hex: "#7A8F6E")
    let categorySlateTeal = Color(hex: "#6E8B8A")
    let categoryCocoa = Color(hex: "#8B6B5C")

    /// Rank 0…4 then muted for Other / overflow. Stable for later aesthetic retunes.
    func categorySlice(rank: Int) -> Color {
        switch rank {
        case 0: return expenseBar
        case 1: return categoryAmber
        case 2: return categoryOlive
        case 3: return categorySlateTeal
        case 4: return categoryCocoa
        default: return muted
        }
    }

    /// Quiet ledger: amounts are ink; only income is green.
    func ledgerAmount(flow: FlowType?) -> Color {
        flow == .income ? quietAccent : ink
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
