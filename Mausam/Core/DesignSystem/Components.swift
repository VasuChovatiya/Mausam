import SwiftUI

/// A frosted panel with a small uppercase title, used for every section of the forecast.
struct WeatherCard<Content: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    @ViewBuilder let content: Content
    @Environment(\.skyTheme) private var theme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)

        VStack(alignment: .leading, spacing: Spacing.s) {
            Label(title, systemImage: systemImage)
                .font(.mausamCardTitle)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            content
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardFill, in: shape)
        .background(.ultraThinMaterial, in: shape)
        .overlay(shape.strokeBorder(theme.cardStroke, lineWidth: 0.75))
        .shadow(color: theme.cardShadow, radius: 14, y: 6)
    }
}

/// A condition's SF Symbol in its own colours (yellow sun, blue rain) at a steady size.
struct ConditionSymbol: View {
    let condition: Condition
    let isDaylight: Bool

    var body: some View {
        Image(systemName: condition.symbolName(isDaylight: isDaylight))
            .symbolRenderingMode(.multicolor)
            .accessibilityLabel(condition.title)
    }
}

/// Where a day's low-to-high sits within the whole week's range, coloured by temperature.
struct TemperatureRangeBar: View {
    let low: Double
    let high: Double
    /// The lowest low and highest high across the days shown, so bars line up.
    let range: ClosedRange<Double>
    /// The temperature right now, drawn as a dot on today's bar.
    var current: Double?
    @Environment(\.skyTheme) private var theme

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let span = max(range.upperBound - range.lowerBound, 1)
            let start = (low - range.lowerBound) / span * width
            let end = (high - range.lowerBound) / span * width

            ZStack(alignment: .leading) {
                Capsule().fill(theme.track)
                Capsule()
                    .fill(LinearGradient(colors: [.temperature(low), .temperature(high)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(end - start, proxy.size.height))
                    .offset(x: start)
                if let current {
                    let x = min(max((current - range.lowerBound) / span * width, 0), width)
                    Circle()
                        .fill(.white)
                        .overlay(Circle().stroke(theme.ink.opacity(0.45), lineWidth: 1.5))
                        .frame(width: proxy.size.height + 3, height: proxy.size.height + 3)
                        .offset(x: x - (proxy.size.height + 3) / 2)
                }
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}

/// Shown under the forecast as the provider's terms require.
struct AttributionFooter: View {
    let attribution: DataAttribution
    let isDemoMode: Bool

    var body: some View {
        VStack(spacing: Spacing.xs) {
            if let markURL = attribution.markURL {
                AsyncImage(url: markURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Text(attribution.serviceName)
                }
                .frame(height: 14)
                .accessibilityLabel(attribution.serviceName)
                Link("Other data sources", destination: attribution.legalURL)
            } else {
                Link(destination: attribution.legalURL) {
                    Text("Weather data by \(attribution.serviceName)")
                }
            }
            if isDemoMode {
                Text("Demo data")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.2), in: Capsule())
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .tint(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.s)
    }
}
