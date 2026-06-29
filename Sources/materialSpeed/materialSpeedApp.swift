import SwiftUI

@main
struct materialSpeedApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 440, idealWidth: 440, maxWidth: 440,
                       minHeight: 700, idealHeight: 700, maxHeight: 700)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
