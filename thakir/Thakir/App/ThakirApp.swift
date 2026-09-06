import SwiftUI

@main
struct ThakirApp: App {
    @State private var store = Store()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Color.accentColor)
        }
    }
}
