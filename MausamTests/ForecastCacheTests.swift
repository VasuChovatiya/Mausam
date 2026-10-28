import Foundation
import Testing
@testable import Mausam

struct ForecastCacheTests {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "ForecastCacheTests-\(UUID().uuidString)")
    }

    @Test func survivesANewInstance() async {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let report = Fixtures.report(temperature: 17, fetchedAt: Date(timeIntervalSince1970: 1_800_000_000))

        await ForecastCache(directory: directory).store(report, for: Fixtures.london)
        let entry = await ForecastCache(directory: directory).entry(for: Fixtures.london.id)

        #expect(entry?.report == report)
        #expect(entry?.place == Fixtures.london)
    }

    @Test func removeForgetsMemoryAndDisk() async {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = ForecastCache(directory: directory)
        await cache.store(Fixtures.report(), for: Fixtures.london)

        await cache.remove(placeID: Fixtures.london.id)

        #expect(await cache.entry(for: Fixtures.london.id) == nil)
        #expect(await ForecastCache(directory: directory).entry(for: Fixtures.london.id) == nil)
    }

    @Test func inMemoryCacheWritesNothing() async {
        let cache = ForecastCache.inMemory()
        await cache.store(Fixtures.report(), for: Fixtures.here)

        #expect(await cache.entry(for: Place.currentID) != nil)
        #expect(await cache.entry(for: "missing") == nil)
    }
}
