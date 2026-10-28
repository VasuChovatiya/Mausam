import Foundation
import SwiftData

/// A city the user added. The device location isn't stored; it is always the first page.
@Model
final class SavedPlace {
    @Attribute(.unique) var placeID: String
    var name: String
    var detail: String?
    var latitude: Double
    var longitude: Double
    var timeZoneIdentifier: String?
    /// Position in the list and the pager; the user can reorder.
    var sortIndex: Int
    var addedAt: Date

    init(_ place: Place, sortIndex: Int, addedAt: Date = .now) {
        placeID = place.id
        name = place.name
        detail = place.detail
        latitude = place.latitude
        longitude = place.longitude
        timeZoneIdentifier = place.timeZoneIdentifier
        self.sortIndex = sortIndex
        self.addedAt = addedAt
    }

    var place: Place {
        Place(
            id: placeID,
            name: name,
            detail: detail,
            latitude: latitude,
            longitude: longitude,
            timeZoneIdentifier: timeZoneIdentifier
        )
    }
}
