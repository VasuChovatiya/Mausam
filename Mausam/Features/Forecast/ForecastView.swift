import SwiftUI

/// One page of the pager: sky background, current conditions, hourly, ten-day and details.
struct ForecastView: View {
    @State private var viewModel: ForecastViewModel
    let isDemoMode: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme

    init(source: ForecastViewModel.Source, dependencies: AppDependencies) {
        _viewModel = State(initialValue: ForecastViewModel(
            source: source,
            repository: dependencies.forecasts,
            location: dependencies.location
        ))
        isDemoMode = dependencies.isDemoMode
    }

    var body: some View {
        let condition = viewModel.report?.current.condition ?? .partlyCloudy
        let isDaylight = viewModel.report?.current.isDaylight ?? true
        let theme = SkyTheme(condition: condition, isDaylight: isDaylight, colorScheme: colorScheme)

        ZStack {
            SkyBackground(condition: condition, isDaylight: isDaylight)
                .ignoresSafeArea()

            content

            StatusBarScrim(color: theme.gradient.first ?? .clear)
        }
        .environment(\.skyTheme, theme)
        .foregroundStyle(theme.ink)
        .task {
            await viewModel.load()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await viewModel.load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let report = viewModel.report, let place = viewModel.place {
            ScrollView {
                ForecastSections(
                    place: place,
                    report: report,
                    staleReason: viewModel.staleReason,
                    attribution: viewModel.attribution,
                    isDemoMode: isDemoMode
                )
                .padding(.horizontal, Spacing.m)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.bottom, 96, for: .scrollContent)
            .refreshable {
                await viewModel.refresh()
            }
        } else {
            switch viewModel.phase {
            case .loading, .loaded:
                ProgressView {
                    Text(viewModel.source == .currentLocation ? "Finding your location…" : "Loading forecast…")
                }
                .controlSize(.large)
            case .failed(let message):
                ContentUnavailableView {
                    Label("Couldn't Load the Forecast", systemImage: "cloud.slash")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again") {
                        Task { await viewModel.refresh() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            case .locationDenied:
                ContentUnavailableView {
                    Label("Location Is Off", systemImage: "location.slash")
                } description: {
                    Text("Allow location access to see the weather where you are, or search for a city with the list button.")
                } actions: {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

/// The scrolling content of a loaded forecast.
struct ForecastSections: View {
    let place: Place
    let report: WeatherReport
    let staleReason: String?
    let attribution: DataAttribution?
    let isDemoMode: Bool

    var body: some View {
        // Re-evaluated each minute so "Now", "Today" and "Updated … ago" stay right on a long-open screen.
        TimelineView(.everyMinute) { context in
            let now = context.date
            let hours = report.upcomingHours(from: now)
            let days = report.upcomingDays(from: now, in: place.timeZone)

            VStack(spacing: Spacing.m) {
                CurrentConditionsHeader(place: place, report: report, today: days.first, now: now)
                    .padding(.top, Spacing.xl)
                    .padding(.bottom, Spacing.s)

                if let staleReason {
                    StaleBanner(reason: staleReason)
                }
                if !hours.isEmpty {
                    HourlyForecastCard(hours: hours, current: report.current, timeZone: place.timeZone)
                    TemperatureChartCard(hours: hours, timeZone: place.timeZone)
                }
                if !days.isEmpty {
                    DailyForecastCard(days: days, currentTemperature: report.current.temperature, timeZone: place.timeZone)
                }
                DetailsGrid(current: report.current, today: days.first, hours: hours, timeZone: place.timeZone, now: now)

                if let attribution {
                    AttributionFooter(attribution: attribution, isDemoMode: isDemoMode)
                }
            }
        }
    }
}

struct CurrentConditionsHeader: View {
    let place: Place
    let report: WeatherReport
    let today: DailyForecast?
    let now: Date
    @Environment(\.weatherFormatter) private var format
    @Environment(\.skyTheme) private var theme
    @ScaledMetric(relativeTo: .largeTitle) private var temperatureSize = 104

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xs) {
                if place.isCurrentLocation {
                    Image(systemName: "location.fill")
                        .font(.footnote)
                        .accessibilityLabel("Current location,")
                }
                Text(place.name)
            }
            .font(.mausamPlaceName)
            .multilineTextAlignment(.center)

            Text(format.temperature(report.current.temperature))
                .font(.system(size: temperatureSize, weight: .thin, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(.leading, temperatureSize * 0.12)

            Label {
                Text(report.current.condition.title)
            } icon: {
                ConditionSymbol(condition: report.current.condition, isDaylight: report.current.isDaylight)
            }
            .font(.mausamCondition)

            if let today {
                Text("H:\(format.temperature(today.high))  L:\(format.temperature(today.low))")
                    .font(.headline)
                    .accessibilityLabel("High \(format.temperature(today.high)), low \(format.temperature(today.low))")
            }

            Group {
                if now.timeIntervalSince(report.fetchedAt) < 60 {
                    Text("Updated just now")
                } else {
                    Text("Updated \(report.fetchedAt.formatted(.relative(presentation: .named, unitsStyle: .wide)))")
                }
            }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, Spacing.xxs)
        }
        .shadow(color: theme.isDark ? .black.opacity(0.2) : .white.opacity(0.35), radius: 8, y: 2)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("forecast-header")
    }
}

/// Fades scrolled cards out under the status bar so the clock stays readable.
private struct StatusBarScrim: View {
    let color: Color
    private let fade: CGFloat = 20

    var body: some View {
        GeometryReader { proxy in
            let top = proxy.safeAreaInsets.top
            LinearGradient(
                stops: [
                    .init(color: color, location: 0),
                    .init(color: color, location: top / (top + fade)),
                    .init(color: color.opacity(0), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: top + fade)
            .offset(y: -top)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// "You appear to be offline" over a report that couldn't be refreshed.
struct StaleBanner: View {
    let reason: String

    var body: some View {
        Label {
            Text(reason)
        } icon: {
            Image(systemName: "wifi.exclamationmark")
        }
        .font(.footnote.weight(.medium))
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.3), in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .accessibilityIdentifier("stale-banner")
    }
}

#Preview("Light") {
    ForecastView(source: .currentLocation, dependencies: .preview)
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    ForecastView(source: .currentLocation, dependencies: .preview)
        .preferredColorScheme(.dark)
}
