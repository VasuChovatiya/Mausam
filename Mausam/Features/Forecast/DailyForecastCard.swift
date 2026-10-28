import SwiftUI

struct DailyForecastCard: View {
    let days: [DailyForecast]
    let currentTemperature: Double
    let timeZone: TimeZone
    @Environment(\.weatherFormatter) private var format
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.skyTheme) private var theme

    var body: some View {
        // Every bar shares one scale, so a warm day sits to the right of a cold one.
        let range = (days.map(\.low).min() ?? 0)...(days.map(\.high).max() ?? 1)

        WeatherCard(title: "\(days.count)-Day Forecast", systemImage: "calendar") {
            VStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                    if index > 0 {
                        Rectangle().fill(theme.track).frame(height: 0.75)
                    }
                    row(day, isToday: index == 0, range: range)
                        .padding(.vertical, Spacing.s)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(accessibilityLabel(for: day, isToday: index == 0))
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ day: DailyForecast, isToday: Bool, range: ClosedRange<Double>) -> some View {
        let name = isToday ? String(localized: "Today") : format.weekday(day.date, in: timeZone)

        if dynamicTypeSize.isAccessibilitySize {
            // Too big for one line: name and symbol, then low and high, without the bar.
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack {
                    Text(name).font(.headline)
                    Spacer()
                    ConditionSymbol(condition: day.condition, isDaylight: true)
                }
                Text("\(format.temperature(day.low)) to \(format.temperature(day.high))")
                    .foregroundStyle(.secondary)
            }
        } else {
            HStack(spacing: Spacing.s) {
                Text(name)
                    .font(.headline)
                    .frame(width: 56, alignment: .leading)
                VStack(spacing: 0) {
                    ConditionSymbol(condition: day.condition, isDaylight: true)
                        .font(.title3)
                    if day.precipitationChance >= 0.2 {
                        Text(format.percent(day.precipitationChance))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(theme.rain)
                    }
                }
                .frame(width: 40)
                Text(format.temperature(day.low))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
                TemperatureRangeBar(low: day.low, high: day.high, range: range, current: isToday ? currentTemperature : nil)
                Text(format.temperature(day.high))
                    .frame(width: 40, alignment: .trailing)
            }
            .font(.body.weight(.medium))
            .monospacedDigit()
        }
    }

    private func accessibilityLabel(for day: DailyForecast, isToday: Bool) -> Text {
        let name = isToday ? String(localized: "Today") : day.date.formatted(Date.FormatStyle(timeZone: timeZone).weekday(.wide))
        var label = "\(name), \(day.condition.title), low \(format.temperature(day.low)), high \(format.temperature(day.high))"
        if day.precipitationChance >= 0.2 {
            label += String(localized: ", \(format.percent(day.precipitationChance)) chance of precipitation")
        }
        return Text(label)
    }
}
