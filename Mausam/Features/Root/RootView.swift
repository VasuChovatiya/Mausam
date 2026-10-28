import SwiftData
import SwiftUI

/// Swipe between your location and saved cities; the list button opens search and reordering.
struct RootView: View {
    let dependencies: AppDependencies
    @Query(sort: \SavedPlace.sortIndex) private var savedPlaces: [SavedPlace]
    @AppStorage("temperatureUnit") private var unit = TemperatureUnit.system
    @AppStorage("appearance") private var appearance = AppAppearance.system
    @State private var selection = Place.currentID
    @State private var showsPlaces = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selection) {
                ForecastView(source: .currentLocation, dependencies: dependencies)
                    .tag(Place.currentID)
                ForEach(savedPlaces) { saved in
                    ForecastView(source: .place(saved.place), dependencies: dependencies)
                        .tag(saved.placeID)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            PageBar(pageIDs: [Place.currentID] + savedPlaces.map(\.placeID), selection: selection) {
                showsPlaces = true
            }
        }
        .sheet(isPresented: $showsPlaces) {
            PlacesView(selection: $selection, search: dependencies.search)
        }
        .onChange(of: savedPlaces.map(\.placeID)) { _, ids in
            // The page on screen was deleted from the list.
            if selection != Place.currentID, !ids.contains(selection) {
                selection = Place.currentID
            }
        }
        .environment(\.weatherFormatter, WeatherFormatter(temperatureUnit: unit.resolved()))
        .preferredColorScheme(appearance.colorScheme)
    }
}

/// Page dots (an arrow for your location) and the button that opens the places list.
struct PageBar: View {
    let pageIDs: [String]
    let selection: String
    let showPlaces: () -> Void

    var body: some View {
        let selectedIndex = pageIDs.firstIndex(of: selection) ?? 0

        HStack {
            Color.clear.frame(width: 48, height: 48)
            Spacer()
            HStack(spacing: Spacing.xs) {
                ForEach(Array(pageIDs.enumerated()), id: \.element) { index, id in
                    Group {
                        if id == Place.currentID {
                            Image(systemName: "location.fill").font(.system(size: 9, weight: .bold))
                        } else {
                            Circle().frame(width: 7, height: 7)
                        }
                    }
                    .foregroundStyle(index == selectedIndex ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                    .scaleEffect(index == selectedIndex ? 1.15 : 1)
                }
            }
            .animation(.snappy, value: selectedIndex)
            .padding(.horizontal, Spacing.s)
            .frame(height: 28)
            .glass(in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Page \(selectedIndex + 1) of \(pageIDs.count)")
            Spacer()
            Button(action: showPlaces) {
                Image(systemName: "list.bullet")
                    .font(.body.weight(.semibold))
                    .frame(width: 48, height: 48)
                    .glass(in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Places")
            .accessibilityIdentifier("places-button")
        }
        .padding(.horizontal, Spacing.l)
        .padding(.bottom, Spacing.xs)
    }
}

private extension View {
    /// Frosted fill with a hairline edge, for controls that float over the sky.
    func glass(in shape: some Shape) -> some View {
        background(.ultraThinMaterial, in: shape)
            .overlay(shape.stroke(.primary.opacity(0.12), lineWidth: 0.75))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}

#Preview {
    RootView(dependencies: .preview)
        .modelContainer(for: SavedPlace.self, inMemory: true)
}
