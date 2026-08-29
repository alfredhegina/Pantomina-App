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
