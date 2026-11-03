import DesignSystem
import Features
import SwiftUI

@main
struct HanguStepApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if CommandLine.arguments.contains("--component-gallery") {
                NavigationStack { ComponentGalleryView() }
            } else {
                root
            }
            #else
            root
            #endif
        }
    }

    @ViewBuilder
    private var root: some View {
        switch container.state {
        case .starting:
            ProgressView("Preparing your library")
                .task { await container.bootstrap() }
        case let .ready(dependencies, preferences):
            RootView(dependencies: dependencies, preferences: preferences)
        case let .failed(message):
            ErrorStateView(message: message)
        }
    }
}
