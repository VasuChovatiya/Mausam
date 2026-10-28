import Foundation
import NetworkingKit
import Testing
@testable import Mausam

@MainActor
struct PlaceSearchViewModelTests {
    private static let debounce: Duration = .milliseconds(30)

    @Test func typingQuicklySearchesOnceForTheFinalTerm() async {
        let search = StubPlaceSearch { _ in [Fixtures.london] }
        let viewModel = PlaceSearchViewModel(search: search, debounce: Self.debounce)

        viewModel.query = "Lo"
        viewModel.query = "Lon"
        viewModel.query = "Lond"
        await viewModel.searchTask?.value

        #expect(await search.queries == ["Lond"])
        #expect(viewModel.phase == .results)
        #expect(viewModel.results == [Fixtures.london])
    }

    @Test func shortQueriesDoNotSearch() async {
        let search = StubPlaceSearch()
        let viewModel = PlaceSearchViewModel(search: search, debounce: Self.debounce)

        viewModel.query = "L"
        try? await Task.sleep(for: Self.debounce * 3)

        #expect(viewModel.phase == .idle)
        #expect(!viewModel.isSearching)
        #expect(await search.queries.isEmpty)
    }

    @Test func clearingTheQueryReturnsToTheSavedList() async {
        let viewModel = PlaceSearchViewModel(search: StubPlaceSearch { _ in [Fixtures.london] }, debounce: Self.debounce)
        viewModel.query = "London"
        await viewModel.searchTask?.value

        viewModel.query = ""

        #expect(viewModel.phase == .idle)
        #expect(viewModel.results.isEmpty)
    }

    @Test func trailingWhitespaceDoesNotSearchAgain() async {
        let search = StubPlaceSearch { _ in [Fixtures.london] }
        let viewModel = PlaceSearchViewModel(search: search, debounce: Self.debounce)
        viewModel.query = "London"
        await viewModel.searchTask?.value

        viewModel.query = "London "
        await viewModel.searchTask?.value

        #expect(await search.queries.count == 1)
    }

    @Test func noMatchesShowsTheEmptyState() async {
        let viewModel = PlaceSearchViewModel(search: StubPlaceSearch(), debounce: Self.debounce)

        viewModel.query = "Atlantis"
        await viewModel.searchTask?.value

        #expect(viewModel.phase == .empty("Atlantis"))
    }

    @Test func failureThenRetry() async {
        let failing = FailureSwitch(true)
        let search = StubPlaceSearch { _ in
            if failing.isOn { throw Fixtures.offline }
            return [Fixtures.london]
        }
        let viewModel = PlaceSearchViewModel(search: search, debounce: Self.debounce)

        viewModel.query = "London"
        await viewModel.searchTask?.value
        #expect(viewModel.phase == .failed(Fixtures.offline.errorDescription ?? ""))

        failing.isOn = false
        viewModel.retry()
        await viewModel.searchTask?.value

        #expect(viewModel.phase == .results)
        #expect(await search.queries.count == 2)
    }
}
