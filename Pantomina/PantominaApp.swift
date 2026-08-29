import SwiftUI

@main
struct PantominaApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.light)
        }
        .modelContainer(PantominaSchema.modelContainer)
    }
}
