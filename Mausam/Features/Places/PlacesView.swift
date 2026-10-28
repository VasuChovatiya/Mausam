import SwiftData
import SwiftUI

/// The list behind the pager: your location, saved cities (reorder, delete) and city search.
struct PlacesView: View {
    @Binding var selection: String
    @Environment(\.dependencies) private var dependencies
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SavedPlace.sortIndex) private var savedPlaces: [SavedPlace]
    @AppStorage("temperatureUnit") private var unit = TemperatureUnit.system
    @AppStorage("appearance") private var appearance = AppAppearance.system
    @State private var search: PlaceSearchViewModel

    init(selection: Binding<String>, search: any PlaceSearching) {
        _selection = selection
        _search = State(initialValue: PlaceSearchViewModel(search: search))
    }

    var body: some View {
        NavigationStack {
            List {
                if search.isSearching {
                    searchResults
                } else {
                    savedList
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Weather")
            .searchable(text: $search.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search for a city")
            .autocorrectionDisabled()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker(selection: $unit) {
                            ForEach(TemperatureUnit.allCases) { unit in
                                Text(unit.title).tag(unit)
                            }
                        } label: {
                            Label("Temperature Unit", systemImage: "thermometer.medium")
                        }
                        .pickerStyle(.menu)
                        Picker(selection: $appearance) {
                            ForEach(AppAppearance.allCases) { appearance in
                                Label(appearance.title, systemImage: appearance.systemImage).tag(appearance)
                            }
                        } label: {
                            Label("Appearance", systemImage: "circle.lefthalf.filled")
                        }
                        .pickerStyle(.menu)
                    } label: {
                        Label("Settings", systemImage: "ellipsis.circle")
                    }
                    .accessibilityIdentifier("settings-menu")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var savedList: some View {
        Button {
            show(Place.currentID)
        } label: {
            PlaceRow(place: nil, repository: dependencies.forecasts)
        }
        .placeRowStyle()
        .accessibilityIdentifier("place-row")

        ForEach(savedPlaces) { saved in
            Button {
                show(saved.placeID)
            } label: {
                PlaceRow(place: saved.place, repository: dependencies.forecasts)
            }
            .placeRowStyle()
            .accessibilityIdentifier("place-row")
        }
        .onDelete(perform: delete)
        .onMove(perform: move)
    }

    @ViewBuilder
    private var searchResults: some View {
        switch search.phase {
        case .idle:
            EmptyView()
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        case .results:
            ForEach(search.results) { place in
                Button {
                    add(place)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.name).font(.headline)
                        if let detail = place.detail {
                            Text(detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("search-result")
            }
        case .empty(let term):
            ContentUnavailableView.search(text: term)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        case .failed(let message):
            ContentUnavailableView {
                Label("Search Failed", systemImage: "exclamationmark.magnifyingglass")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { search.retry() }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private func show(_ placeID: String) {
        selection = placeID
        dismiss()
    }

    /// Saves the place (once) and jumps to its page.
    private func add(_ place: Place) {
        if !savedPlaces.contains(where: { $0.placeID == place.id }) {
            let nextIndex = (savedPlaces.map(\.sortIndex).max() ?? -1) + 1
            modelContext.insert(SavedPlace(place, sortIndex: nextIndex))
        }
        search.query = ""
        show(place.id)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let saved = savedPlaces[index]
            let placeID = saved.placeID
            modelContext.delete(saved)
            Task { await dependencies.forecasts.forget(placeID: placeID) }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = savedPlaces
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, saved) in reordered.enumerated() where saved.sortIndex != index {
            saved.sortIndex = index
        }
    }
}

/// A saved place as a small sky-coloured card: name, local time, condition and temperature.
struct PlaceRow: View {
    /// nil for the device location, which shows whatever was cached last.
    let place: Place?
    let repository: ForecastRepository
    @State private var entry: ForecastCache.Entry?
    @Environment(\.weatherFormatter) private var format
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shown = place ?? entry?.place
        let report = entry?.report
        let condition = report?.current.condition ?? .partlyCloudy
        let isDaylight = report?.current.isDaylight ?? true
        let theme = SkyTheme(condition: condition, isDaylight: isDaylight, colorScheme: colorScheme)
        let shape = RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)

        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(place == nil ? String(localized: "My Location") : (shown?.name ?? ""))
                    .font(.mausamRowTitle)
                Group {
                    if place == nil {
                        Text(shown?.name ?? String(localized: "Current location"))
                    } else if let shown {
                        Text(Date.now, format: Date.FormatStyle(date: .omitted, time: .shortened, timeZone: shown.timeZone))
                    }
                }
                .font(.subheadline.weight(.medium))
                Spacer(minLength: Spacing.s)
                if let report {
                    Label {
                        Text(report.current.condition.title)
                    } icon: {
                        ConditionSymbol(condition: report.current.condition, isDaylight: report.current.isDaylight)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                if let report {
                    Text(format.temperature(report.current.temperature))
                        .font(.system(.largeTitle, design: .rounded).weight(.light))
                    if let today = report.today(from: .now, in: shown?.timeZone ?? .current) {
                        Text("H:\(format.temperature(today.high))  L:\(format.temperature(today.low))")
                            .font(.subheadline.weight(.medium))
                    }
                } else {
                    ProgressView()
                }
            }
        }
        .foregroundStyle(theme.ink)
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            SkyBackground(condition: condition, isDaylight: isDaylight, showsParticles: false)
                .clipShape(shape)
        }
        .overlay(shape.strokeBorder(theme.cardStroke, lineWidth: 0.75))
        .shadow(color: theme.cardShadow, radius: 12, y: 5)
        .accessibilityElement(children: .combine)
        .task(id: place?.id) {
            await load()
        }
    }

    private func load() async {
        let placeID = place?.id ?? Place.currentID
        entry = await repository.cachedEntry(for: placeID)
        guard let place else { return }
        if let report = entry?.report, repository.isFresh(report, now: .now) { return }
        if let report = try? await repository.refresh(place) {
            entry = ForecastCache.Entry(place: place, report: report)
        }
    }
}

private extension View {
    func placeRowStyle() -> some View {
        buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.m, bottom: Spacing.xs, trailing: Spacing.m))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

#Preview {
    PlacesView(selection: .constant(Place.currentID), search: AppDependencies.preview.search)
        .modelContainer(for: SavedPlace.self, inMemory: true)
}
