import SwiftUI

/// Two columns of small tiles: feels like, humidity, wind, UV, visibility, pressure, sun, precipitation.
struct DetailsGrid: View {
    let current: CurrentConditions
    let today: DailyForecast?
    let hours: [HourlyForecast]
    let timeZone: TimeZone
    let now: Date
    @Environment(\.weatherFormatter) private var format
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.m), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)

        LazyVGrid(columns: columns, spacing: Spacing.m) {
            DetailTile(title: "Feels Like", systemImage: "thermometer.medium", value: format.temperature(current.apparentTemperature)) {
                Text(feelsLikeNote)
            }
            DetailTile(title: "Humidity", systemImage: "humidity", value: format.percent(current.humidity)) {
                if let dewPoint = current.dewPoint {
                    Text("The dew point is \(format.temperature(dewPoint)) right now.")
                }
            }
            DetailTile(title: "Wind", systemImage: "wind", value: format.windSpeed(current.windSpeed)) {
                windNote
            }
            if let uvIndex = current.uvIndex {
                DetailTile(
                    title: "UV Index",
                    systemImage: "sun.max",
                    value: uvIndex.formatted(.number.precision(.fractionLength(0)))
                ) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(WeatherFormatter.uvCategory(uvIndex)).font(.headline).foregroundStyle(.primary)
                        UVScale(index: uvIndex)
                    }
                }
            }
            if let sunrise = today?.sunrise, let sunset = today?.sunset {
                let sunIsUp = now >= sunrise && now < sunset
                DetailTile(
                    title: sunIsUp ? "Sunset" : "Sunrise",
                    systemImage: sunIsUp ? "sunset.fill" : "sunrise.fill",
                    value: format.time(sunIsUp ? sunset : sunrise, in: timeZone)
                ) {
                    Text(sunIsUp ? "Sunrise: \(format.time(sunrise, in: timeZone))" : "Sunset: \(format.time(sunset, in: timeZone))")
                }
            }
            if let visibility = current.visibility {
                DetailTile(title: "Visibility", systemImage: "eye.fill", value: format.visibility(visibility)) {
                    Text(visibilityNote(visibility))
                }
            }
            if let pressure = current.pressure {
                DetailTile(title: "Pressure", systemImage: "gauge.with.dots.needle.33percent", value: format.pressure(pressure)) {
                    Text(pressure < 1000 ? "Low pressure often brings unsettled weather." : "Steady conditions are likely.")
                }
            }
            DetailTile(title: "Precipitation", systemImage: "drop.fill", value: format.precipitation(current.precipitation ?? 0)) {
                Text(precipitationNote)
            }
        }
    }

    private var feelsLikeNote: LocalizedStringKey {
        let difference = current.apparentTemperature - current.temperature
        if abs(difference) < 2 { return "Similar to the actual temperature." }
        return difference < 0 ? "Wind is making it feel cooler." : "Humidity is making it feel warmer."
    }

    @ViewBuilder
    private var windNote: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            if let direction = current.windDirection {
                // The arrow points where the wind is going, the opposite of where it comes from.
                Image(systemName: "location.north.fill")
                    .rotationEffect(.degrees(direction + 180))
                    .foregroundStyle(.primary)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                if let direction = current.windDirection {
                    Text("From \(WeatherFormatter.compassPoint(direction))")
                }
                if let gust = current.windGust {
                    Text("Gusts \(format.windSpeed(gust))")
                }
            }
        }
    }

    private func visibilityNote(_ meters: Double) -> LocalizedStringKey {
        switch meters {
        case ..<1000: "Fog is limiting visibility."
        case ..<5000: "Haze is reducing visibility."
        case ..<10000: "Visibility is fair."
        default: "It's perfectly clear right now."
        }
    }

    private var precipitationNote: String {
        guard let wettest = hours.max(by: { $0.precipitationChance < $1.precipitationChance }), wettest.precipitationChance >= 0.2 else {
            return String(localized: "None expected in the next 24 hours.")
        }
        return String(localized: "Up to \(format.percent(wettest.precipitationChance)) chance in the next 24 hours.")
    }
}

struct DetailTile<Note: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    let value: String
    @ViewBuilder let note: Note

    var body: some View {
        WeatherCard(title: title, systemImage: systemImage) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(value)
                    .font(.mausamTileValue)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                note
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Green to violet bar with a dot at the current index (0 to 11+).
struct UVScale: View {
    let index: Double
    @Environment(\.skyTheme) private var theme

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(LinearGradient(
                    colors: [.green, .yellow, .orange, .red, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                Circle()
                    .fill(.white)
                    .overlay(Circle().stroke(theme.ink.opacity(0.45), lineWidth: 1.5))
                    .frame(width: 8, height: 8)
                    .offset(x: min(max(index / 11, 0), 1) * (proxy.size.width - 8))
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}
