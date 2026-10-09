import Testing
import Foundation
@testable import ToolKit

@Suite struct WeatherTests {
    @Test func placesAreFoundInPlainQuestions() {
        let cases: [(String, String?)] = [
            ("What's the weather in Seville?", "seville"),
            ("what is the weather like in Sevilla tomorrow", "sevilla"),
            ("weather in New York today", "new york"),
            ("Seville weather", "seville"),
            ("forecast for Istanbul this week", "istanbul"),
            ("will it rain in London tonight", "london"),
            ("weather Madrid", "madrid"),
            ("What's the weather?", nil),
            ("When is Real Betis' next game?", nil),
            ("Tell me a joke", nil)]
        for (text, want) in cases { #expect(Weather.place(in: text) == want, "\(text) -> \(Weather.place(in: text) ?? "nil")") }
    }

    @Test func geocodingAndForecastAddressesAreBuilt() {
        #expect(Weather.geocodingURL("new york")?.absoluteString.contains("name=new%20york") == true)
        let place = Weather.Place(name: "Seville", region: "Andalusia", country: "Spain", latitude: 37.38, longitude: -5.97)
        let metric = Weather.forecastURL(place, fahrenheit: false)?.absoluteString ?? ""
        #expect(metric.hasPrefix("https://api.open-meteo.com/v1/forecast?") && metric.contains("latitude=37.38") && !metric.contains("fahrenheit"))
        #expect(Weather.forecastURL(place, fahrenheit: true)?.absoluteString.contains("temperature_unit=fahrenheit") == true)
    }

    private let geo = #"{"results":[{"id":2510911,"name":"Seville","latitude":37.38283,"longitude":-5.97317,"country":"Spain","admin1":"Andalusia"}]}"#
    private let forecast = #"{"current_units":{"temperature_2m":"°C","wind_speed_10m":"km/h"},"current":{"temperature_2m":19.7,"apparent_temperature":18.2,"relative_humidity_2m":44,"weather_code":0,"wind_speed_10m":4.8},"daily":{"time":["2026-10-10","2026-10-11","2026-10-12"],"weather_code":[3,2,45],"temperature_2m_max":[28.6,29.4,31.2],"temperature_2m_min":[15.1,12.7,14.8],"precipitation_probability_max":[0,0,10]}}"#

    @Test func aPlaceIsReadFromTheGeocodingAnswer() {
        let p = Weather.parsePlace(Data(geo.utf8))
        #expect(p?.name == "Seville" && p?.country == "Spain", "\(String(describing: p))")
        #expect(p?.label == "Seville, Andalusia, Spain", "\(p?.label ?? "")")
        #expect(Weather.parsePlace(Data(#"{"generationtime_ms":0.5}"#.utf8)) == nil)
        #expect(Weather.parsePlace(Data("nonsense".utf8)) == nil)
    }

    @Test func theForecastIsRenderedWithRealNumbers() throws {
        let place = try #require(Weather.parsePlace(Data(geo.utf8)))
        let text = try #require(Weather.render(Data(forecast.utf8), place: place))
        #expect(text.contains("Seville, Andalusia, Spain"))
        #expect(text.contains("Now: 19.7°C, feels like 18.2°C, clear sky, humidity 44%, wind 4.8 km/h"), text)
        #expect(text.contains("Today: 15.1 to 28.6°C, overcast, rain chance 0%"), text)
        #expect(text.contains("Tomorrow: 12.7 to 29.4°C, partly cloudy"), text)
        #expect(text.contains("Mon 12 Oct: 14.8 to 31.2°C, fog, rain chance 10%"), text)
        #expect(Weather.render(Data("{}".utf8), place: place) == nil)
    }

    @Test func conditionNamesCoverTheCommonCodes() {
        #expect(Weather.describe(code: 0) == "clear sky" && Weather.describe(code: 63) == "rain" && Weather.describe(code: 95) == "thunderstorm")
        #expect(Weather.describe(code: 1234) == "unknown conditions")
    }
}
