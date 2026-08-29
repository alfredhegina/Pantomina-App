import SwiftUI

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let radius: CGFloat = 14
}

enum PantominaFont {
    static let eyebrow = Font.system(size: 12, weight: .semibold)
    static let petTitle = Font.system(.title2, design: .serif).italic()
    static let body = Font.system(size: 16, weight: .regular)
    static let amount = Font.system(size: 28, weight: .semibold).monospacedDigit()
    static let caption = Font.system(size: 13, weight: .regular)
}

enum PantominaMotion {
    static let feedback = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.28)
    static let sheet = Animation.timingCurve(0.32, 0.72, 0, 1, duration: 0.4)
    static let spring = Animation.spring(duration: 0.5, bounce: 0.2)
}
