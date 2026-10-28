import SwiftUI

/// Colours for one forecast page, from the sky's condition, day or night, and light or dark mode.
///
/// Light mode is airy: pale skies, white frosted cards and deep navy text. Dark mode is deep and
/// saturated, with smoked-glass cards and white text. Night at a place still looks like night in
/// light mode, as a soft twilight.
nonisolated struct SkyTheme: Equatable, Sendable {
    /// Top to bottom.
    let gradient: [Color]
    /// The sun or moon glow in the top corner.
    let glow: Color
    /// Primary text; secondary and tertiary text derive from it.
    let ink: Color
    let track: Color
    let rain: Color
    let cardFill: Color
    let cardStroke: Color
    let cardShadow: Color
    /// Raindrops, snowflakes and stars.
    let particle: Color
    let isDark: Bool

    static let standard = SkyTheme(condition: .partlyCloudy, isDaylight: true, colorScheme: .light)

    init(condition: Condition, isDaylight: Bool, colorScheme: ColorScheme) {
        let isDark = colorScheme == .dark
        self.isDark = isDark
        gradient = Self.gradient(for: condition, isDaylight: isDaylight, isDark: isDark)
        glow = Self.glow(for: condition, isDaylight: isDaylight, isDark: isDark)

        if isDark {
            ink = .white
            track = .white.opacity(0.16)
            rain = Color(hex: 0x7DD3FF)
            cardFill = .black.opacity(0.16)
            cardStroke = .white.opacity(0.12)
            cardShadow = .clear
            particle = .white
        } else {
            ink = Color(hex: 0x0F1C38)
            track = Color(hex: 0x0F1C38, opacity: 0.1)
            rain = Color(hex: 0x1C6FD1)
            cardFill = .white.opacity(0.42)
            cardStroke = .white.opacity(0.7)
            cardShadow = Color(hex: 0x1B3A6B, opacity: 0.08)
            particle = Color(hex: 0x2B4A7A)
        }
    }

    /// Sky colours, top to bottom, as light day, light night (twilight), dark day and dark night.
    private static let palettes: [Sky: [[UInt32]]] = [
        .clear: [[0x5EA8F7, 0x9FCFFF, 0xE4F2FF], [0x8794DC, 0xAFB7EA, 0xE0E2F7],
                 [0x1E5FAE, 0x2F7BCB, 0x173E73], [0x070B1F, 0x16214A, 0x24336A]],
        .partlyCloudy: [[0x7DB0E6, 0xB3D3F2, 0xEAF3FB], [0x8F99C9, 0xB3BADF, 0xE0E3F2],
                        [0x2B5D96, 0x4B7DB2, 0x1F3D63], [0x0D1426, 0x212E4D, 0x2C3B5E]],
        .cloudy: [[0x9FAFC1, 0xC6D1DC, 0xEEF2F6], [0x939BAE, 0xB6BCCA, 0xDDE0E7],
                  [0x43515F, 0x617183, 0x2D3742], [0x12171E, 0x29323D, 0x333D4A]],
        .fog: [[0xB4BEC5, 0xD3D9DD, 0xF1F3F4], [0xA1A7AF, 0xC0C5CA, 0xE2E4E7],
               [0x515B63, 0x737D85, 0x353C42], [0x191D22, 0x343B42, 0x3D454D]],
        .rain: [[0x7E95B0, 0xA9BACD, 0xDDE5EE], [0x7684A0, 0x9EAAC0, 0xD2D8E2],
                [0x2C3A4B, 0x4A5C71, 0x1E2834], [0x0A0F16, 0x1D2733, 0x253140]],
        .snow: [[0xA9C3E2, 0xD1E2F3, 0xF5F9FD], [0x9DABCC, 0xC0CAE0, 0xE5EAF3],
                [0x3F5E85, 0x6685AB, 0x2A405D], [0x111A2E, 0x2D3E5D, 0x384C70]],
        .storm: [[0x8990A3, 0xACB3C1, 0xDADDE4], [0x7D8397, 0xA3A8B8, 0xD3D5DD],
                 [0x22252E, 0x3C414F, 0x16181E], [0x08090D, 0x1B1D25, 0x23252F]],
    ]

    private static func gradient(for condition: Condition, isDaylight: Bool, isDark: Bool) -> [Color] {
        let variant = (isDark ? 2 : 0) + (isDaylight ? 0 : 1)
        return (palettes[Sky(condition)]?[variant] ?? []).map { Color(hex: $0) }
    }

    private static func glow(for condition: Condition, isDaylight: Bool, isDark: Bool) -> Color {
        switch (condition, isDaylight) {
        // Over blue, a saturated yellow turns green in light mode, so light mode gets a warm white haze.
        case (.clear, true), (.mostlyClear, true):
            Color(hex: isDark ? 0xFFD25E : 0xFFF6DD, opacity: isDark ? 0.4 : 0.95)
        case (.partlyCloudy, true), (.windy, true):
            Color(hex: isDark ? 0xFFD978 : 0xFFF8E6, opacity: isDark ? 0.25 : 0.7)
        case (.clear, false), (.mostlyClear, false), (.partlyCloudy, false):
            Color(hex: isDark ? 0xC9D6FF : 0xFFFFFF, opacity: isDark ? 0.2 : 0.6)
        case (.thunderstorm, _):
            Color(hex: 0xB9A6FF, opacity: isDark ? 0.14 : 0.3)
        default:
            Color.white.opacity(isDark ? 0.08 : 0.45)
        }
    }
}

/// Conditions that share a sky.
nonisolated private enum Sky {
    case clear, partlyCloudy, cloudy, fog, rain, snow, storm

    init(_ condition: Condition) {
        switch condition {
        case .clear, .mostlyClear: self = .clear
        case .partlyCloudy, .windy: self = .partlyCloudy
        case .cloudy: self = .cloudy
        case .fog: self = .fog
        case .drizzle, .rain, .heavyRain, .freezingRain: self = .rain
        case .snow, .heavySnow: self = .snow
        case .thunderstorm: self = .storm
        }
    }
}

extension EnvironmentValues {
    @Entry var skyTheme = SkyTheme.standard
}

/// The full-screen sky behind a forecast: gradient, sun or moon glow, and falling weather.
struct SkyBackground: View {
    let condition: Condition
    let isDaylight: Bool
    var showsParticles = true
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = SkyTheme(condition: condition, isDaylight: isDaylight, colorScheme: colorScheme)

        ZStack {
            LinearGradient(colors: theme.gradient, startPoint: .top, endPoint: .bottom)
            GeometryReader { proxy in
                let size = max(proxy.size.width, 240) * 1.1
                RadialGradient(colors: [theme.glow, theme.glow.opacity(0)], center: .center, startRadius: 0, endRadius: size / 2)
                    .frame(width: size, height: size)
                    .position(x: proxy.size.width * 0.85, y: proxy.size.height * 0.04)
                    .blendMode(theme.isDark ? .screen : .normal)
            }
            if showsParticles {
                WeatherParticles(condition: condition, isDaylight: isDaylight, color: theme.particle)
            }
        }
        .animation(.easeInOut(duration: 0.8), value: theme)
        .accessibilityHidden(true)
    }
}

/// Rain streaks, drifting snow, twinkling stars or a lightning flicker, drawn in one `Canvas`.
/// Positions come from a fixed hash, so every page looks the same each time it appears.
struct WeatherParticles: View {
    let condition: Condition
    let isDaylight: Bool
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Kind {
        case rain(count: Int, speed: Double), snow(count: Int), stars, none
    }

    private var kind: Kind {
        switch condition {
        case .drizzle: .rain(count: 40, speed: 700)
        case .rain, .freezingRain: .rain(count: 80, speed: 900)
        case .heavyRain, .thunderstorm: .rain(count: 130, speed: 1100)
        case .snow: .snow(count: 60)
        case .heavySnow: .snow(count: 110)
        case .clear, .mostlyClear, .partlyCloudy: isDaylight ? .none : .stars
        case .cloudy, .fog, .windy: .none
        }
    }

    var body: some View {
        if case .none = kind {
            EmptyView()
        } else {
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
                Canvas { canvas, size in
                    let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                    draw(in: &canvas, size: size, time: time)
                }
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
        }
    }

    private func draw(in canvas: inout GraphicsContext, size: CGSize, time: Double) {
        switch kind {
        case .rain(let count, let speed):
            for index in 0..<count {
                let x = hash(index, 1) * (size.width + 60) - 30
                let length = 14 + hash(index, 2) * 18
                let travel = size.height + length
                let fallen = hash(index, 3) * travel + time * speed * (0.8 + hash(index, 4) * 0.4)
                let y = fallen.truncatingRemainder(dividingBy: travel) - length
                var path = Path()
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x - length * 0.18, y: y + length))
                canvas.stroke(path, with: .color(color.opacity(0.18 + hash(index, 5) * 0.22)), lineWidth: 1.2)
            }
            if condition == .thunderstorm {
                // A double flicker every seven seconds.
                let phase = time.truncatingRemainder(dividingBy: 7)
                let flash = phase < 0.08 || (phase > 0.16 && phase < 0.22) ? 0.22 : 0
                if flash > 0 {
                    canvas.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(flash)))
                }
            }
        case .snow(let count):
            for index in 0..<count {
                let radius = 1.5 + hash(index, 2) * 2.5
                let travel = size.height + radius * 2
                let y = (hash(index, 3) * travel + time * (30 + hash(index, 4) * 40)).truncatingRemainder(dividingBy: travel) - radius
                let sway = sin(time * (0.6 + hash(index, 5)) + hash(index, 6) * 6) * 18
                let x = hash(index, 1) * size.width + sway
                let flake = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                canvas.fill(flake, with: .color(color.opacity(0.45 + hash(index, 7) * 0.4)))
            }
        case .stars:
            for index in 0..<70 {
                let x = hash(index, 1) * size.width
                let y = hash(index, 2) * size.height * 0.55
                let radius = 0.6 + hash(index, 3) * 1.2
                let twinkle = 0.55 + 0.45 * sin(time * (0.8 + hash(index, 4) * 1.6) + hash(index, 5) * 6)
                let star = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                canvas.fill(star, with: .color(color.opacity(0.75 * twinkle)))
            }
        case .none:
            break
        }
    }

    /// A stable pseudo-random number in 0..<1 for particle `index` and property `salt`.
    private func hash(_ index: Int, _ salt: Int) -> Double {
        let value = sin(Double(index) * 12.9898 + Double(salt) * 78.233) * 43_758.5453
        return value - value.rounded(.down)
    }
}

#Preview {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
            ForEach(Condition.allCases, id: \.self) { condition in
                ForEach([true, false], id: \.self) { isDaylight in
                    SkyBackground(condition: condition, isDaylight: isDaylight)
                        .frame(height: 140)
                        .overlay {
                            ConditionSymbol(condition: condition, isDaylight: isDaylight)
                                .font(.largeTitle)
                        }
                }
            }
        }
    }
}
