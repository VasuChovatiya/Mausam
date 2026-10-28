import Foundation
import NetworkingKit

extension Error {
    /// A message worth showing, or nil when the error is a cancellation (the screen moved on).
    var userMessage: String? {
        switch self {
        case is CancellationError:
            nil
        case let error as NetworkError:
            if case .cancelled = error { nil } else { error.errorDescription }
        default:
            localizedDescription
        }
    }
}
