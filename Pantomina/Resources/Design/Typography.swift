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
    /// Fraunces italic for pet-titles (falls back to system serif if unregistered).
    static let petTitle = Font.custom("Fraunces", size: 22, relativeTo: .title2).italic()
    static let eyebrow = Font.custom("DM Sans", size: 12, relativeTo: .caption).weight(.semibold)
    static let body = Font.custom("DM Sans", size: 16, relativeTo: .body)
    static let amount = Font.custom("DM Sans", size: 28, relativeTo: .title).weight(.semibold).monospacedDigit()
    static let caption = Font.custom("DM Sans", size: 13, relativeTo: .caption)
}

enum PantominaMotion {
    static let feedback = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.28)
    static let sheet = Animation.timingCurve(0.32, 0.72, 0, 1, duration: 0.4)
    static let spring = Animation.spring(duration: 0.5, bounce: 0.2)

    @MainActor
    static func run(_ reduceMotion: Bool, _ body: () -> Void) {
        if reduceMotion {
            body()
        } else {
            withAnimation(feedback, body)
        }
    }
}
