import Foundation
import NetworkingKit
import SwiftUI

/// Everything the screens need from the outside world, built once at launch.
nonisolated struct AppDependencies: Sendable {
    let forecasts: ForecastRepository
    let search: any PlaceSearching
    let location: any LocationProviding
    /// True when forecasts come from `DemoCatalog` (UI tests and previews).
    let isDemoMode: Bool

    @MainActor
    static func live(bundle: Bundle = .main) -> AppDependencies {
        if LaunchArguments.usesDemoData {
            return demo(latency: .milliseconds(300))
        }
        let provider: any WeatherProvider = switch WeatherProviderKind.configured(in: bundle) {
        case .weatherKit: WeatherKitProvider()
        case .openMeteo: OpenMeteoWeatherProvider(client: OpenMeteoConfiguration.makeClient(
            baseURL: OpenMeteoConfiguration.forecastBaseURL, transport: URLSession.shared
        ))
        }
        return AppDependencies(
            forecasts: ForecastRepository(provider: provider, cache: .onDisk()),
            search: OpenMeteoPlaceSearch(client: OpenMeteoConfiguration.makeClient(
                baseURL: OpenMeteoConfiguration.geocodingBaseURL, transport: URLSession.shared
            )),
            location: CoreLocationProvider(),
            isDemoMode: false
        )
    }

    /// Instant demo data for SwiftUI previews.
    static let preview = demo(latency: .zero)

    private static func demo(latency: Duration) -> AppDependencies {
        let transport = DemoTransport(latency: latency)
        let forecastClient = OpenMeteoConfiguration.makeClient(baseURL: OpenMeteoConfiguration.forecastBaseURL, transport: transport)
        let searchClient = OpenMeteoConfiguration.makeClient(baseURL: OpenMeteoConfiguration.geocodingBaseURL, transport: transport)
        return AppDependencies(
            forecasts: ForecastRepository(provider: OpenMeteoWeatherProvider(client: forecastClient, source: .demo), cache: .inMemory()),
            search: OpenMeteoPlaceSearch(client: searchClient, language: "en"),
            location: DemoLocationProvider(),
            isDemoMode: true
        )
    }
}

/// Which forecast source the build uses, from `WEATHER_PROVIDER` in `Config/Mausam.xcconfig`.
nonisolated enum WeatherProviderKind: String {
    case openMeteo = "openmeteo"
    case weatherKit = "weatherkit"

    static func configured(in bundle: Bundle) -> WeatherProviderKind {
        let value = (bundle.object(forInfoDictionaryKey: "WeatherProvider") as? String)?.lowercased()
        return value.flatMap(WeatherProviderKind.init(rawValue:)) ?? .openMeteo
    }
}

/// Switches the UI tests pass so they don't depend on the network, location or places saved by an earlier run.
nonisolated enum LaunchArguments {
    static let demoData = "-UITestDemoData"
    static let inMemoryStore = "-UITestInMemoryStore"

    static var usesDemoData: Bool { ProcessInfo.processInfo.arguments.contains(demoData) }
    static var usesInMemoryStore: Bool { ProcessInfo.processInfo.arguments.contains(inMemoryStore) }
}

extension EnvironmentValues {
    @Entry var dependencies: AppDependencies = .preview
}
