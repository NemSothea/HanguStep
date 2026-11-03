import DesignSystem
import Domain
import SwiftUI

/// Identifies a quiz to present. Either a fresh configuration or a resumed snapshot.
struct QuizLaunch: Identifiable {
    enum Source {
        case new(QuizConfiguration)
        case resume(QuizSessionSnapshot)
    }
    let id = UUID()
    let source: Source

    init(configuration: QuizConfiguration) { source = .new(configuration) }
    init(resume snapshot: QuizSessionSnapshot) { source = .resume(snapshot) }
}

extension View {
    /// Presents the quiz flow modally. Sheet on every platform; dismissal is
    /// controlled by the flow itself so an answered question is never lost.
    func quizSheet(launch: Binding<QuizLaunch?>, dependencies: AppDependencies, onDismiss: (() -> Void)? = nil) -> some View {
        sheet(item: launch, onDismiss: onDismiss) { launch in
            QuizFlowView(viewModel: QuizSessionViewModel(launch: launch, dependencies: dependencies))
                .interactiveDismissDisabled()
                #if os(macOS)
                .frame(minWidth: 560, minHeight: 640)
                #endif
        }
    }
}
