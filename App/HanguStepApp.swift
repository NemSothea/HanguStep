import DesignSystem
import Features
import SwiftUI

@main
struct HanguStepApp: App {
    private let container = AppContainer()

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if CommandLine.arguments.contains("--component-gallery") {
                NavigationStack { ComponentGalleryView() }
            } else {
                RootView(dependencies: container.dependencies)
            }
            #else
            RootView(dependencies: container.dependencies)
            #endif
        }
    }
}
