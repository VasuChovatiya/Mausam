import Foundation

/// Debounced city search.
///
/// Each keystroke cancels the pending search and restarts the timer, so typing "london" sends one
/// request, not six. A response for an older query is dropped if the field has changed since.
@Observable
final class PlaceSearchViewModel {
    enum Phase: Equatable {
        /// Fewer than `minimumQueryLength` characters: the saved places list shows instead.
        case idle
        case loading
        case results
        case empty(String)
        case failed(String)
    }

    static let minimumQueryLength = 2

    var query = "" {
        didSet {
            guard query != oldValue else { return }
            scheduleSearch()
        }
    }

    private(set) var phase: Phase = .idle
    private(set) var results: [Place] = []

    /// Exposed so tests can await the debounced search instead of sleeping.
    @ObservationIgnored private(set) var searchTask: Task<Void, Never>?
    @ObservationIgnored private var searchedTerm: String?
    @ObservationIgnored private let search: any PlaceSearching
    @ObservationIgnored private let debounce: Duration

    init(search: any PlaceSearching, debounce: Duration = .milliseconds(350)) {
        self.search = search
        self.debounce = debounce
    }

    var isSearching: Bool { phase != .idle }

    func retry() {
        searchedTerm = nil
        scheduleSearch(debounced: false)
    }

    private var term: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func scheduleSearch(debounced: Bool = true) {
        searchTask?.cancel()
        let term = self.term

        guard term.count >= Self.minimumQueryLength else {
            searchedTerm = nil
            results = []
            phase = .idle
            return
        }
        // "london" → "london " shouldn't search again.
        guard term != searchedTerm else { return }
        if results.isEmpty {
            phase = .loading
        }

        let delay = debounced ? debounce : .zero
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.runSearch(term)
        }
    }

    private func runSearch(_ term: String) async {
        do {
            let places = try await search.places(matching: term)
            guard !Task.isCancelled, term == self.term else { return }
            searchedTerm = term
            results = places
            phase = places.isEmpty ? .empty(term) : .results
        } catch {
            guard !Task.isCancelled, term == self.term, let message = error.userMessage else { return }
            searchedTerm = nil
            results = []
            phase = .failed(message)
        }
    }
}
