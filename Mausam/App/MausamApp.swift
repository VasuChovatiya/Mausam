import SwiftData
import SwiftUI

@main
struct MausamApp: App {
    private let dependencies = AppDependencies.live()

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
                .environment(\.dependencies, dependencies)
        }
        .modelContainer(for: SavedPlace.self, inMemory: LaunchArguments.usesInMemoryStore)
    }
}
