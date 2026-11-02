import SwiftUI

/// Renders loading, empty and error states uniformly; the caller supplies only the loaded view.
public struct AsyncStateView<Value: Equatable, Content: View>: View {
    private let state: ViewState<Value>
    private let emptyTitle: LocalizedStringKey
    private let emptyMessage: LocalizedStringKey
    private let emptySystemImage: String
    private let retry: (() -> Void)?
    private let content: (Value) -> Content

    public init(
        _ state: ViewState<Value>,
        emptyTitle: LocalizedStringKey = "Nothing here yet",
        emptyMessage: LocalizedStringKey = "",
        emptySystemImage: String = "tray",
        retry: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Value) -> Content
    ) {
        self.state = state
        self.emptyTitle = emptyTitle
        self.emptyMessage = emptyMessage
        self.emptySystemImage = emptySystemImage
        self.retry = retry
        self.content = content
    }

    public var body: some View {
        switch state {
        case .idle, .loading:
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Loading")
        case let .loaded(value):
            content(value)
        case .empty:
            EmptyStateView(title: emptyTitle, systemImage: emptySystemImage, message: emptyMessage)
        case let .failed(message):
            ErrorStateView(message: message, retry: retry)
        }
    }
}

public struct EmptyStateView: View {
    private let title: LocalizedStringKey
    private let systemImage: String
    private let message: LocalizedStringKey
    private let actionTitle: LocalizedStringKey?
    private let action: (() -> Void)?

    public init(
        title: LocalizedStringKey,
        systemImage: String,
        message: LocalizedStringKey = "",
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(HSButtonStyle(.secondary))
            }
        }
    }
}

public struct ErrorStateView: View {
    private let message: String
    private let retry: (() -> Void)?

    public init(message: String, retry: (() -> Void)? = nil) {
        self.message = message
        self.retry = retry
    }

    public var body: some View {
        ContentUnavailableView {
            Label("Something went wrong", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            if let retry {
                Button("Try again", action: retry)
                    .buttonStyle(HSButtonStyle(.primary))
            }
        }
    }
}
