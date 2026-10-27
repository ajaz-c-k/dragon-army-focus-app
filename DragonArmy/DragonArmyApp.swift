import SwiftUI
import SwiftData

@main
struct DragonArmyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Dragon.self, DragonEgg.self, FocusSession.self, KingdomItem.self])
    }
}
