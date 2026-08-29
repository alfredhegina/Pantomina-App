import SwiftUI
import SwiftData

@main
struct PantominaApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(PantominaSchema.modelContainer)
    }
}
