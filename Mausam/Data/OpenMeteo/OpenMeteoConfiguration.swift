import Foundation
import NetworkingKit

nonisolated enum OpenMeteoConfiguration {
    static let forecastBaseURL = URL(string: "https://api.open-meteo.com/v1")!
    static let geocodingBaseURL = URL(string: "https://geocoding-api.open-meteo.com/v1")!
    /// Open-Meteo data is CC BY 4.0, which asks for this credit.
    static let attribution = DataAttribution(
        serviceName: "Open-Meteo.com",
        legalURL: URL(string: "https://open-meteo.com/en/license")!,
        markURL: nil
    )

    static func makeClient(baseURL: URL, transport: any HTTPTransport) -> APIClient {
        #if DEBUG
        let logger = NetworkLogger()
        #else
        let logger = NetworkLogger.disabled
        #endif

        return APIClient(baseURL: baseURL, transport: transport, logger: logger)
    }
}
