import Foundation
import SwiftUI

/// The user's temperature unit choice, stored with `@AppStorage`.
nonisolated enum TemperatureUnit: String, CaseIterable, Identifiable {
    case system = "system"
    case celsius = "celsius"
    case fahrenheit = "fahrenheit"

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .system: "System Setting"
        case .celsius: "Celsius (°C)"
        case .fahrenheit: "Fahrenheit (°F)"
        }
    }

    func resolved(for locale: Locale = .current) -> UnitTemperature {
        switch self {
        case .celsius: .celsius
        case .fahrenheit: .fahrenheit
        case .system: locale.measurementSystem == .us ? .fahrenheit : .celsius
        }
    }
}

/// Turns the report's metric values into display strings in the user's units and the place's time zone.
nonisolated struct WeatherFormatter: Sendable {
    var temperatureUnit: UnitTemperature = .celsius
    var locale: Locale = .current

    /// "21°". Rounds first so -0.4 shows as "0°", not "-0°".
    func temperature(_ celsius: Double) -> String {
        let value = Measurement(value: celsius, unit: UnitTemperature.celsius).converted(to: temperatureUnit).value
        let rounded = value.rounded() + 0
        return "\(rounded.formatted(.number.precision(.fractionLength(0)).locale(locale)))°"
    }

    func percent(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    func windSpeed(_ kilometersPerHour: Double) -> String {
        Measurement(value: kilometersPerHour, unit: UnitSpeed.kilometersPerHour)
            .formatted(.measurement(width: .abbreviated, usage: .wind, numberFormatStyle: Self.wholeNumber).locale(locale))
    }

    func visibility(_ meters: Double) -> String {
        let measurement = Measurement(value: meters, unit: UnitLength.meters).converted(to: usesMetric ? .kilometers : .miles)
        let digits = measurement.value < 10 ? 1 : 0
        return format(measurement, fractionDigits: digits)
    }

    func pressure(_ hectopascals: Double) -> String {
        Measurement(value: hectopascals, unit: UnitPressure.hectopascals)
            .formatted(.measurement(width: .abbreviated, usage: .barometric, numberFormatStyle: Self.wholeNumber).locale(locale))
    }

    func precipitation(_ millimeters: Double) -> String {
        let measurement = Measurement(value: millimeters, unit: UnitLength.millimeters)
            .converted(to: usesMetric ? .millimeters : .inches)
        return format(measurement, fractionDigits: usesMetric ? 1 : 2)
    }

    private static let wholeNumber = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0))

    private var usesMetric: Bool { locale.measurementSystem != .us }

    /// As given, with up to `fractionDigits` decimals ("0.6 mm", "24 km").
    private func format(_ measurement: Measurement<UnitLength>, fractionDigits: Int) -> String {
        let number = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...fractionDigits))
        return measurement.formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: number).locale(locale))
    }

    /// "3 PM" in the place's time zone, which may not be the phone's.
    func hour(_ date: Date, in timeZone: TimeZone) -> String {
        date.formatted(style(timeZone).hour(.defaultDigits(amPM: .abbreviated)))
    }

    /// "6:42 AM"
    func time(_ date: Date, in timeZone: TimeZone) -> String {
        date.formatted(style(timeZone).hour(.defaultDigits(amPM: .abbreviated)).minute())
    }

    /// "Mon"
    func weekday(_ date: Date, in timeZone: TimeZone) -> String {
        date.formatted(style(timeZone).weekday(.abbreviated))
    }

    private func style(_ timeZone: TimeZone) -> Date.FormatStyle {
        var style = Date.FormatStyle(date: .omitted, time: .omitted, locale: locale)
        style.timeZone = timeZone
        return style
    }

    /// Eight-point compass name for where the wind comes from.
    static func compassPoint(_ degrees: Double) -> String {
        let points = [
            String(localized: "N"), String(localized: "NE"), String(localized: "E"), String(localized: "SE"),
            String(localized: "S"), String(localized: "SW"), String(localized: "W"), String(localized: "NW"),
        ]
        let normalized = (degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return points[Int((normalized / 45).rounded()) % points.count]
    }

    /// WHO UV index bands.
    static func uvCategory(_ index: Double) -> String {
        switch index {
        case ..<3: String(localized: "Low")
        case ..<6: String(localized: "Moderate")
        case ..<8: String(localized: "High")
        case ..<11: String(localized: "Very High")
        default: String(localized: "Extreme")
        }
    }
}

extension EnvironmentValues {
    @Entry var weatherFormatter = WeatherFormatter()
}
