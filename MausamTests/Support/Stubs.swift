import Foundation
@testable import Mausam

/// A `WeatherProvider` whose answers each test scripts. Records every request.
actor StubWeatherProvider: WeatherProvider {
    typealias Handler = @Sendable (Place) async throws -> WeatherReport

    private let handler: Handler
    private(set) var requests: [Place] = []

    init(_ handler: @escaping Handler = { _ in Fixtures.report() }) {
        self.handler = handler
    }

    func report(for place: Place) async throws -> WeatherReport {
        requests.append(place)
        return try await handler(place)
    }

    nonisolated func attribution() async throws -> DataAttribution {
        OpenMeteoConfiguration.attribution
    }
}

actor StubPlaceSearch: PlaceSearching {
    typealias Handler = @Sendable (String) async throws -> [Place]

    private let handler: Handler
    private(set) var queries: [String] = []

    init(_ handler: @escaping Handler = { _ in [] }) {
        self.handler = handler
    }

    func places(matching query: String) async throws -> [Place] {
        queries.append(query)
        return try await handler(query)
    }
}

@MainActor
final class StubLocationProvider: LocationProviding {
    var result: Result<Place, LocationError>
    private(set) var requestCount = 0

    init(_ result: Result<Place, LocationError> = .success(Fixtures.here)) {
        self.result = result
    }

    func currentPlace() async throws -> Place {
        requestCount += 1
        return try result.get()
    }
}

/// A switch tests can flip between calls, e.g. to fail one request and succeed on retry.
final class FailureSwitch: @unchecked Sendable {
    private let lock = NSLock()
    private var _isOn: Bool

    init(_ isOn: Bool = false) {
        _isOn = isOn
    }

    var isOn: Bool {
        get { lock.withLock { _isOn } }
        set { lock.withLock { _isOn = newValue } }
    }
}
