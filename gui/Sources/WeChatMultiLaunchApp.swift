import SwiftUI

@main
struct WeChatMultiLaunchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 600, minHeight: 680)
        }
        .windowResizability(.contentSize)
    }
}