import Features
import SwiftUI

@main
struct HanguStepApp: App {
    private let container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: container.dependencies)
        }
    }
}
