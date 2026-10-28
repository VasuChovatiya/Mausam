import Foundation
import NetworkingKit
import Testing
@testable import Mausam

@MainActor
struct ForecastViewModelTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeViewModel(
        _ source: ForecastViewModel.Source,
        provider: StubWeatherProvider,
        cache: ForecastCache = .inMemory(),
        location: StubLocationProvider = StubLocationProvider()
    ) -> ForecastViewModel {
        ForecastViewModel(
            source: source,
            repository: ForecastRepository(provider: provider, cache: cache),
            location: location,
            now: { [now] in now }
        )
    }

    @Test func showsCachedReportThenReplacesAStaleOne() async {
        let cache = ForecastCache.inMemory()
        await cache.store(Fixtures.report(temperature: 10, fetchedAt: now.addingTimeInterval(-3600)), for: Fixtures.london)
        let provider = StubWeatherProvider { _ in Fixtures.report(temperature: 20) }
        let viewModel = makeViewModel(.place(Fixtures.london), provider: provider, cache: cache)

        await viewModel.load()

        #expect(viewModel.report?.current.temperature == 20)
        #expect(viewModel.phase == .loaded)
        #expect(await provider.requests == [Fixtures.london])
        #expect(await cache.entry(for: Fixtures.london.id)?.report.current.temperature == 20)
    }

    @Test func freshCacheSkipsTheNetwork() async {
        let cache = ForecastCache.inMemory()
        await cache.store(Fixtures.report(temperature: 10, fetchedAt: now.addingTimeInterval(-60)), for: Fixtures.london)
        let provider = StubWeatherProvider()
        let viewModel = makeViewModel(.place(Fixtures.london), provider: provider, cache: cache)

        await viewModel.load()

        #expect(viewModel.report?.current.temperature == 10)
        #expect(await provider.requests.isEmpty)
    }

    @Test func offlineKeepsTheCachedReportAndSaysWhy() async {
        let cache = ForecastCache.inMemory()
        await cache.store(Fixtures.report(temperature: 10, fetchedAt: now.addingTimeInterval(-7200)), for: Fixtures.london)
        let provider = StubWeatherProvider { _ in throw Fixtures.offline }
        let viewModel = makeViewModel(.place(Fixtures.london), provider: provider, cache: cache)

        await viewModel.load()

        #expect(viewModel.report?.current.temperature == 10)
        #expect(viewModel.phase == .loaded)
        #expect(viewModel.staleReason == Fixtures.offline.errorDescription)
    }

    @Test func failureWithoutCacheThenRetry() async {
        let failing = FailureSwitch(true)
        let provider = StubWeatherProvider { _ in
            if failing.isOn { throw Fixtures.serverError }
            return Fixtures.report(temperature: 25)
        }
        let viewModel = makeViewModel(.place(Fixtures.london), provider: provider)

        await viewModel.load()
        guard case .failed = viewModel.phase else {
            Issue.record("Expected .failed, got \(viewModel.phase)")
            return
        }

        failing.isOn = false
        await viewModel.refresh()

        #expect(viewModel.phase == .loaded)
        #expect(viewModel.report?.current.temperature == 25)
        #expect(viewModel.staleReason == nil)
    }

    @Test func currentLocationAsksForTheDevicePlace() async {
        let provider = StubWeatherProvider()
        let location = StubLocationProvider(.success(Fixtures.here))
        let viewModel = makeViewModel(.currentLocation, provider: provider, location: location)

        await viewModel.load()

        #expect(viewModel.place == Fixtures.here)
        #expect(location.requestCount == 1)
        #expect(await provider.requests == [Fixtures.here])
    }

    @Test func deniedLocationWithNothingCachedAsksForAccess() async {
        let provider = StubWeatherProvider()
        let viewModel = makeViewModel(.currentLocation, provider: provider, location: StubLocationProvider(.failure(.denied)))

        await viewModel.load()

        #expect(viewModel.phase == .locationDenied)
        #expect(await provider.requests.isEmpty)
    }

    @Test func deniedLocationStillShowsTheLastPlace() async {
        let cache = ForecastCache.inMemory()
        await cache.store(Fixtures.report(fetchedAt: now.addingTimeInterval(-7200)), for: Fixtures.here)
        let viewModel = makeViewModel(
            .currentLocation,
            provider: StubWeatherProvider(),
            cache: cache,
            location: StubLocationProvider(.failure(.denied))
        )

        await viewModel.load()

        #expect(viewModel.place == Fixtures.here)
        #expect(viewModel.phase == .loaded)
        #expect(viewModel.staleReason == LocationError.denied.errorDescription)
    }

    @Test func loadsTheProvidersAttribution() async {
        let viewModel = makeViewModel(.place(Fixtures.london), provider: StubWeatherProvider())

        await viewModel.load()

        #expect(viewModel.attribution == OpenMeteoConfiguration.attribution)
    }
}
