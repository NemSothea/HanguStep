import Foundation

/// Presentation state shared by every screen that loads data.
public enum ViewState<Value: Equatable>: Equatable {
    case idle
    case loading
    case loaded(Value)
    case empty
    case failed(message: String)

    public var value: Value? {
        if case let .loaded(value) = self { return value }
        return nil
    }

    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

extension ViewState: Sendable where Value: Sendable {}
