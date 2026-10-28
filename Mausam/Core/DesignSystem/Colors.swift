import SwiftUI

extension Color {
    nonisolated init(hex: UInt32, opacity: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// A colour for a temperature in °C, from icy blue through green to hot red, for range bars and charts.
    nonisolated static func temperature(_ celsius: Double) -> Color {
        let stops: [(Double, (Double, Double, Double))] = [
            (-10, (0.42, 0.55, 1.0)),
            (0, (0.36, 0.75, 1.0)),
            (10, (0.2, 0.8, 0.72)),
            (20, (0.62, 0.84, 0.25)),
            (28, (1.0, 0.66, 0.2)),
            (36, (0.98, 0.33, 0.25)),
        ]
        guard let first = stops.first, let last = stops.last else { return .gray }
        if celsius <= first.0 { return Color(red: first.1.0, green: first.1.1, blue: first.1.2) }
        if celsius >= last.0 { return Color(red: last.1.0, green: last.1.1, blue: last.1.2) }
        for (lower, upper) in zip(stops, stops.dropFirst()) where celsius <= upper.0 {
            let fraction = (celsius - lower.0) / (upper.0 - lower.0)
            return Color(
                red: lower.1.0 + (upper.1.0 - lower.1.0) * fraction,
                green: lower.1.1 + (upper.1.1 - lower.1.1) * fraction,
                blue: lower.1.2 + (upper.1.2 - lower.1.2) * fraction
            )
        }
        return .gray
    }
}
