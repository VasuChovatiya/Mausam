import Charts
import SwiftUI

struct HourlyForecastCard: View {
    let hours: [HourlyForecast]
    let current: CurrentConditions
    let timeZone: TimeZone
    @Environment(\.weatherFormatter) private var format
    @Environment(\.skyTheme) private var theme

    var body: some View {
        WeatherCard(title: "Hourly Forecast", systemImage: "clock") {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: Spacing.xs) {
                    ForEach(Array(hours.enumerated()), id: \.element.id) { index, hour in
                        let isNow = index == 0
                        VStack(spacing: Spacing.xs) {
                            Text(isNow ? String(localized: "Now") : format.hour(hour.date, in: timeZone))
                                .font(.footnote.weight(.semibold))
                            VStack(spacing: 2) {
                                ConditionSymbol(
                                    condition: isNow ? current.condition : hour.condition,
                                    isDaylight: isNow ? current.isDaylight : hour.isDaylight
                                )
                                .font(.title3)
                                .frame(height: 26)
                                if hour.precipitationChance >= 0.2 {
                                    Text(format.percent(hour.precipitationChance))
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(theme.rain)
                                }
                            }
                            .frame(minHeight: 42, alignment: .top)
                            Text(format.temperature(isNow ? current.temperature : hour.temperature))
                                .font(.callout.weight(.semibold))
                        }
                        .padding(.vertical, Spacing.s)
                        .frame(minWidth: 52)
                        // "Now" sits in a soft pill so the strip has a clear starting point.
                        .background(isNow ? theme.track : .clear, in: Capsule())
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}

/// Temperature over the next day as a smooth line, with the warmest and coolest hour marked.
struct TemperatureChartCard: View {
    let hours: [HourlyForecast]
    let timeZone: TimeZone
    @Environment(\.weatherFormatter) private var format
    @Environment(\.skyTheme) private var theme

    var body: some View {
        WeatherCard(title: "Temperature", systemImage: "chart.xyaxis.line") {
            let warmest = hours.max { $0.temperature < $1.temperature }
            let coolest = hours.min { $0.temperature < $1.temperature }
            let floor = (coolest?.temperature ?? 0) - 2

            Chart {
                ForEach(hours) { hour in
                    AreaMark(
                        x: .value("Time", hour.date),
                        yStart: .value("Floor", floor),
                        yEnd: .value("Temperature", hour.temperature)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(
                        colors: [
                            .temperature(hour.temperature).opacity(theme.isDark ? 0.35 : 0.45),
                            .temperature(hour.temperature).opacity(0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ))

                    LineMark(x: .value("Time", hour.date), y: .value("Temperature", hour.temperature))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .foregroundStyle(LinearGradient(
                            colors: hours.map { .temperature($0.temperature) },
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                }
                ForEach([warmest, coolest].compactMap(\.self), id: \.date) { hour in
                    PointMark(x: .value("Time", hour.date), y: .value("Temperature", hour.temperature))
                        .foregroundStyle(theme.ink)
                        .symbolSize(40)
                        .annotation(position: hour == warmest ? .top : .bottom, spacing: 4) {
                            Text(format.temperature(hour.temperature))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(theme.ink)
                        }
                }
            }
            .chartYScale(domain: floor...((warmest?.temperature ?? 0) + 2))
            .chartYAxis(.hidden)
            .chartXAxis {
                // Every sixth hour of the place's own clock, not the phone's.
                AxisMarks(values: sixHourMarks) { value in
                    AxisGridLine().foregroundStyle(theme.track)
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(format.hour(date, in: timeZone))
                                .foregroundStyle(theme.ink.opacity(0.6))
                        }
                    }
                }
            }
            .frame(height: 130)
            .accessibilityElement()
            .accessibilityLabel(accessibilitySummary(warmest: warmest, coolest: coolest))
        }
    }

    private var sixHourMarks: [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return hours.map(\.date).filter { calendar.component(.hour, from: $0) % 6 == 0 }
    }

    private func accessibilitySummary(warmest: HourlyForecast?, coolest: HourlyForecast?) -> Text {
        guard let warmest, let coolest else { return Text("Temperature chart") }
        return Text("""
            Warmest \(format.temperature(warmest.temperature)) at \(format.hour(warmest.date, in: timeZone)), \
            coolest \(format.temperature(coolest.temperature)) at \(format.hour(coolest.date, in: timeZone))
            """)
    }
}
