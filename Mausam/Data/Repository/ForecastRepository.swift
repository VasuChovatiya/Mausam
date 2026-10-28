import Foundation

/// Forecasts with an offline copy: the provider for fresh data, the cache for instant and offline launches.
nonisolated struct ForecastRepository: Sendable {
    let provider: any WeatherProvider
    let cache: ForecastCache
    /// A cached report younger than this is shown without asking the provider again.
    var freshness: TimeInterval = 15 * 60

    func cachedEntry(for placeID: String) async -> ForecastCache.Entry? {
        await cache.entry(for: placeID)
    }

    /// Fetches a new report and keeps it for next time.
    func refresh(_ place: Place) async throws -> WeatherReport {
        let report = try await provider.report(for: place)
        await cache.store(report, for: place)
        return report
    }

    func isFresh(_ report: WeatherReport, now: Date) -> Bool {
        now.timeIntervalSince(report.fetchedAt) < freshness
    }

    func forget(placeID: String) async {
        await cache.remove(placeID: placeID)
    }
}
