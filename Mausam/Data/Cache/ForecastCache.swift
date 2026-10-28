import Foundation

/// The last forecast for each place, kept as JSON in Caches so the app opens with data even offline.
///
/// Reads go through memory first. The system may purge Caches under storage pressure, which only
/// costs one network round trip.
actor ForecastCache {
    nonisolated struct Entry: Codable, Sendable, Equatable {
        let place: Place
        let report: WeatherReport
    }

    /// nil keeps entries in memory only (UI tests and previews).
    private let directory: URL?
    private var memory: [String: Entry] = [:]

    init(directory: URL?) {
        self.directory = directory
    }

    static func onDisk() -> ForecastCache {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return ForecastCache(directory: caches.appending(path: "Forecasts", directoryHint: .isDirectory))
    }

    static func inMemory() -> ForecastCache {
        ForecastCache(directory: nil)
    }

    func entry(for placeID: String) -> Entry? {
        if let entry = memory[placeID] { return entry }
        guard let url = fileURL(for: placeID),
              let data = try? Data(contentsOf: url),
              let entry = try? JSONDecoder().decode(Entry.self, from: data) else { return nil }
        memory[placeID] = entry
        return entry
    }

    func store(_ report: WeatherReport, for place: Place) {
        let entry = Entry(place: place, report: report)
        memory[place.id] = entry
        guard let directory, let url = fileURL(for: place.id) else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(entry).write(to: url, options: .atomic)
        } catch {
            // A failed write only loses the offline copy; the screen already has the data.
        }
    }

    func remove(placeID: String) {
        memory[placeID] = nil
        if let url = fileURL(for: placeID) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Ids are GeoNames numbers or "current", but keep file names safe whatever they are.
    private func fileURL(for placeID: String) -> URL? {
        let name = placeID.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == "-" }
        guard let directory, !name.isEmpty else { return nil }
        return directory.appending(path: "\(String(String.UnicodeScalarView(name))).json")
    }
}
