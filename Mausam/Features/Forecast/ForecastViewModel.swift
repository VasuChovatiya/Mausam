import Foundation

/// One page of the pager: the forecast for the device location or a saved place.
///
/// Loading is cache first: the last saved report appears at once (also offline), then a fresh one
/// replaces it unless the cached one is recent enough. A failed refresh keeps the old report on
/// screen and says why, instead of swapping it for an error.
@Observable
final class ForecastViewModel {
    enum Source: Equatable {
        case currentLocation
        case place(Place)

        var placeID: String {
            switch self {
            case .currentLocation: Place.currentID
            case .place(let place): place.id
            }
        }
    }

    enum Phase: Equatable {
        case loading
        case loaded
        case failed(String)
        /// Device-location page with location access off and nothing cached.
        case locationDenied
    }

    let source: Source
    private(set) var place: Place?
    private(set) var report: WeatherReport?
    private(set) var phase: Phase = .loading
    /// Why the report on screen is older than it should be, e.g. "You appear to be offline."
    private(set) var staleReason: String?
    private(set) var isRefreshing = false
    private(set) var attribution: DataAttribution?

    @ObservationIgnored private let repository: ForecastRepository
    @ObservationIgnored private let location: any LocationProviding
    @ObservationIgnored private let now: () -> Date

    init(
        source: Source,
        repository: ForecastRepository,
        location: any LocationProviding,
        now: @escaping () -> Date = { .now }
    ) {
        self.source = source
        self.repository = repository
        self.location = location
        self.now = now
        if case .place(let place) = source {
            self.place = place
        }
    }

    /// On appear and on returning to the foreground.
    func load() async {
        if report == nil, let entry = await repository.cachedEntry(for: source.placeID) {
            if source == .currentLocation {
                // Wherever the device last was, until a new fix arrives.
                place = entry.place
            }
            report = entry.report
            phase = .loaded
        }
        if let report, repository.isFresh(report, now: now()) {
            await loadAttribution()
            return
        }
        await refresh()
    }

    /// Pull to refresh and Try Again. Always asks the provider.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        if report == nil {
            phase = .loading
        }

        do {
            let target = try await resolvePlace()
            place = target
            report = try await repository.refresh(target)
            staleReason = nil
            phase = .loaded
        } catch {
            show(error)
        }
        await loadAttribution()
    }

    private func resolvePlace() async throws -> Place {
        switch source {
        case .place(let place): place
        case .currentLocation: try await location.currentPlace()
        }
    }

    private func show(_ error: any Error) {
        guard let message = error.userMessage else { return }
        if report != nil {
            staleReason = message
        } else if error as? LocationError == .denied {
            phase = .locationDenied
        } else {
            phase = .failed(message)
        }
    }

    private func loadAttribution() async {
        guard attribution == nil else { return }
        attribution = try? await repository.provider.attribution()
    }
}
