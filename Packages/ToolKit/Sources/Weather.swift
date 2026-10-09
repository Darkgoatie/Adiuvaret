import Foundation

/// Weather answers from real forecast data instead of a list of links. Pure logic: the app does the two network requests.
public enum Weather {
    public struct Place: Equatable, Sendable {
        public let name: String
        public let region: String
        public let country: String
        public let latitude: Double
        public let longitude: Double
        public var label: String {
            var parts = [name]
            for extra in [region, country] where !extra.isEmpty && !parts.contains(extra) { parts.append(extra) }
            return parts.joined(separator: ", ")
        }
    }

    private static let keywords: Set<String> = ["weather", "forecast", "temperature", "rain", "raining", "snow", "snowing", "sunny", "humidity"]
    private static let joiners: Set<String> = ["in", "for", "at", "near", "around"]
    private static let fillers: Set<String> = [
        "what", "whats", "what's", "how", "is", "the", "a", "an", "like", "it", "there", "will", "be", "going", "to", "today", "tomorrow", "tonight", "now",
        "right", "currently", "current", "this", "next", "week", "weekend", "morning", "afternoon", "evening", "outside", "please", "tell", "me", "give",
        "show", "check", "get", "and", "of", "forecast", "weather", "temperature", "rain", "raining", "snow", "snowing", "sunny", "humidity", "are", "do",
        "does", "i", "need", "an", "umbrella", "hot", "cold", "warm", "much", "on", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday",
        "sunday", "can", "you", "latest", "live", "report", "conditions", "days", "day", "hours", "hour"]

    /// The place a weather question is about, or nil when the message is not about weather or names no place.
    public static func place(in text: String) -> String? {
        let words = text.lowercased().split(whereSeparator: { !($0.isLetter || $0 == "'" || $0 == "-") }).map(String.init)
        guard words.contains(where: { keywords.contains($0) }) else { return nil }
        func take(_ slice: ArraySlice<String>) -> String? {
            var out: [String] = []
            for w in slice {
                if fillers.contains(w) || joiners.contains(w) { if out.isEmpty { continue } else { break } }
                out.append(w)
            }
            let name = out.prefix(4).joined(separator: " ")
            return name.isEmpty ? nil : name
        }
        if let i = words.firstIndex(where: { joiners.contains($0) }), let name = take(words[(i + 1)...]) { return name }
        // "Seville weather today"
        if let k = words.firstIndex(where: { keywords.contains($0) }) {
            let before = words[..<k].filter { !fillers.contains($0) && !joiners.contains($0) }
            if !before.isEmpty { return before.suffix(3).joined(separator: " ") }
            if let name = take(words[(k + 1)...]) { return name }
        }
        return nil
    }

    public static func geocodingURL(_ name: String) -> URL? {
        var parts = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        parts?.queryItems = [URLQueryItem(name: "name", value: name), URLQueryItem(name: "count", value: "1"), URLQueryItem(name: "language", value: "en")]
        return parts?.url
    }

    public static func forecastURL(_ place: Place, fahrenheit: Bool) -> URL? {
        var parts = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        var items = [
            URLQueryItem(name: "latitude", value: String(place.latitude)), URLQueryItem(name: "longitude", value: String(place.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,precipitation"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"),
            URLQueryItem(name: "forecast_days", value: "4"), URLQueryItem(name: "timezone", value: "auto")]
        if fahrenheit {
            items += [URLQueryItem(name: "temperature_unit", value: "fahrenheit"), URLQueryItem(name: "wind_speed_unit", value: "mph")]
        }
        parts?.queryItems = items
        return parts?.url
    }

    public static func parsePlace(_ data: Data) -> Place? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let first = (object["results"] as? [[String: Any]])?.first,
              let name = first["name"] as? String, let lat = first["latitude"] as? Double, let lon = first["longitude"] as? Double else { return nil }
        return Place(name: name, region: (first["admin1"] as? String) ?? "", country: (first["country"] as? String) ?? "", latitude: lat, longitude: lon)
    }

    public static func describe(code: Int) -> String {
        switch code {
        case 0: "clear sky"
        case 1: "mainly clear"
        case 2: "partly cloudy"
        case 3: "overcast"
        case 45, 48: "fog"
        case 51, 53, 55: "drizzle"
        case 56, 57: "freezing drizzle"
        case 61: "light rain"
        case 63: "rain"
        case 65: "heavy rain"
        case 66, 67: "freezing rain"
        case 71: "light snow"
        case 73: "snow"
        case 75: "heavy snow"
        case 77: "snow grains"
        case 80, 81: "rain showers"
        case 82: "heavy rain showers"
        case 85, 86: "snow showers"
        case 95: "thunderstorm"
        case 96, 99: "thunderstorm with hail"
        default: "unknown conditions"
        }
    }

    private static func number(_ v: Any?) -> Double? { (v as? Double) ?? (v as? Int).map(Double.init) }

    private static func fmt(_ v: Double) -> String { v.rounded() == v ? String(Int(v)) : String(format: "%.1f", v) }

    /// A short text for the model: now, then today and the next three days.
    public static func render(_ data: Data, place: Place) -> String? {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cur = o["current"] as? [String: Any], let daily = o["daily"] as? [String: Any],
              let temp = number(cur["temperature_2m"]) else { return nil }
        let units = o["current_units"] as? [String: Any] ?? [:]
        let t = (units["temperature_2m"] as? String) ?? "°C"
        let w = (units["wind_speed_10m"] as? String) ?? "km/h"
        var lines = ["Live weather for \(place.label) from Open-Meteo (use these numbers, name the place):"]
        var now = "Now: \(fmt(temp))\(t)"
        if let feels = number(cur["apparent_temperature"]) { now += ", feels like \(fmt(feels))\(t)" }
        now += ", " + describe(code: Int(number(cur["weather_code"]) ?? -1))
        if let h = number(cur["relative_humidity_2m"]) { now += ", humidity \(fmt(h))%" }
        if let wind = number(cur["wind_speed_10m"]) { now += ", wind \(fmt(wind)) \(w)" }
        lines.append(now)

        let days = daily["time"] as? [String] ?? []
        let highs = daily["temperature_2m_max"] as? [Any] ?? []
        let lows = daily["temperature_2m_min"] as? [Any] ?? []
        let codes = daily["weather_code"] as? [Any] ?? []
        let rain = daily["precipitation_probability_max"] as? [Any] ?? []
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian); parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "UTC"); parser.dateFormat = "yyyy-MM-dd"
        let shown = DateFormatter()
        shown.calendar = parser.calendar; shown.locale = parser.locale; shown.timeZone = parser.timeZone; shown.dateFormat = "EEE d MMM"
        for (i, day) in days.enumerated() where i < highs.count && i < lows.count {
            guard let hi = number(highs[i]), let lo = number(lows[i]) else { continue }
            let name = i == 0 ? "Today" : i == 1 ? "Tomorrow" : (parser.date(from: day).map { shown.string(from: $0) } ?? day)
            var line = "\(name): \(fmt(lo)) to \(fmt(hi))\(t)"
            if i < codes.count, let c = number(codes[i]) { line += ", " + describe(code: Int(c)) }
            if i < rain.count, let r = number(rain[i]) { line += ", rain chance \(fmt(r))%" }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }
}
