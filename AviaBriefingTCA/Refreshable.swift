import ComposableArchitecture
import SwiftUI

private let readMe = """
  This application demonstrates live-searching with the Composable Architecture. As you type the \
  events are debounced for 300ms, and when you stop typing an API request is made to load \
  locations. Then tapping on a location will load weather.
  """

// MARK: - Search feature domain

struct Search: Reducer {
struct State: Equatable {
    var results: [GeocodingSearch.Result] = []
    var resultForecastRequestInFlight: GeocodingSearch.Result?
    var searchQuery = ""
    var weather: Weather?

    struct Weather: Equatable {
      var id: GeocodingSearch.Result.ID
      var days: [Day]

      struct Day: Equatable {
        var date: Date
        var temperatureMax: Double
        var temperatureMaxUnit: String
        var temperatureMin: Double
        var temperatureMinUnit: String
      }
    }
  }

  enum Action: Equatable {
    case forecastResponse(GeocodingSearch.Result.ID, TaskResult<Forecast>)
    case searchQueryChanged(String)
    case searchQueryChangeDebounced
    case searchResponse(TaskResult<GeocodingSearch>)
    case searchResultTapped(GeocodingSearch.Result)
  }

  @Dependency(\.weatherClient) var weatherClient
  private enum CancelID { case location, weather }

  func reduce(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .forecastResponse(_, .failure):
      state.weather = nil
      state.resultForecastRequestInFlight = nil
      return .none

    case let .forecastResponse(id, .success(forecast)):
      state.weather = State.Weather(
        id: id,
        days: forecast.daily.time.indices.map {
          State.Weather.Day(
            date: forecast.daily.time[$0],
            temperatureMax: forecast.daily.temperatureMax[$0],
            temperatureMaxUnit: forecast.dailyUnits.temperatureMax,
            temperatureMin: forecast.daily.temperatureMin[$0],
            temperatureMinUnit: forecast.dailyUnits.temperatureMin
          )
        }
      )
      state.resultForecastRequestInFlight = nil
      return .none

    case let .searchQueryChanged(query):
      state.searchQuery = query

      // When the query is cleared we can clear the search results, but we have to make sure to cancel
      // any in-flight search requests too, otherwise we may get data coming in later.
      guard !query.isEmpty else {
        state.results = []
        state.weather = nil
        return .cancel(id: CancelID.location)
      }
      return .none

    case .searchQueryChangeDebounced:
      guard !state.searchQuery.isEmpty else {
        return .none
      }
      return .run { [query = state.searchQuery] send in
        await send(.searchResponse(TaskResult { try await self.weatherClient.search(query) }))
      }
      .cancellable(id: CancelID.location)

    case .searchResponse(.failure):
      state.results = []
      return .none

    case let .searchResponse(.success(response)):
      state.results = response.results
      return .none

    case let .searchResultTapped(location):
      state.resultForecastRequestInFlight = location

      return .run { send in
        await send(
          .forecastResponse(
            location.id,
            TaskResult { try await self.weatherClient.forecast(location) }
          )
        )
      }
      .cancellable(id: CancelID.weather, cancelInFlight: true)
    }
  }
}

// MARK: - Search feature view

struct SearchView: View {
  let store: StoreOf<Search>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      NavigationStack {
        VStack(alignment: .leading) {
          Text(readMe)
            .padding()

          HStack {
            Image(systemName: "magnifyingglass")
            TextField(
              "New York, San Francisco, ...",
              text: viewStore.binding(get: \.searchQuery, send: { .searchQueryChanged($0) })
            )
            .textFieldStyle(.roundedBorder)
            .autocapitalization(.none)
            .disableAutocorrection(true)
          }
          .padding(.horizontal, 16)

          List {
            ForEach(viewStore.results) { location in
              VStack(alignment: .leading) {
                Button {
                  viewStore.send(.searchResultTapped(location))
                } label: {
                  HStack {
                    Text(location.name)

                    if viewStore.resultForecastRequestInFlight?.id == location.id {
                      ProgressView()
                    }
                  }
                }

                if location.id == viewStore.weather?.id {
                  self.weatherView(locationWeather: viewStore.weather)
                }
              }
            }
          }

          Button("Weather API provided by Open-Meteo") {
            UIApplication.shared.open(URL(string: "https://open-meteo.com/en")!)
          }
          .foregroundColor(.gray)
          .padding(.all, 16)
        }
        .navigationTitle("Search")
      }
      .task(id: viewStore.searchQuery) {
        do {
          try await Task.sleep(for: .seconds(3))
          await viewStore.send(.searchQueryChangeDebounced).finish()
        } catch {}
      }
    }
  }

  @ViewBuilder
  func weatherView(locationWeather: Search.State.Weather?) -> some View {
    if let locationWeather = locationWeather {
      let days = locationWeather.days
        .enumerated()
        .map { idx, weather in formattedWeather(day: weather, isToday: idx == 0) }

      VStack(alignment: .leading) {
        ForEach(days, id: \.self) { day in
          Text(day)
        }
      }
      .padding(.leading, 16)
    }
  }
}

// MARK: - Private helpers

private func formattedWeather(day: Search.State.Weather.Day, isToday: Bool) -> String {
  let date =
    isToday
    ? "Today"
    : dateFormatter.string(from: day.date).capitalized
  let min = "\(day.temperatureMin)\(day.temperatureMinUnit)"
  let max = "\(day.temperatureMax)\(day.temperatureMaxUnit)"

  return "\(date), \(min) – \(max)"
}

private let dateFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateFormat = "EEEE"
  return formatter
}()

// MARK: - SwiftUI previews

struct SearchView_Previews: PreviewProvider {
  static var previews: some View {
    SearchView(
      store: Store(initialState: Search.State()) {
        Search()
      }
    )
  }
}

struct GeocodingSearch: Decodable, Equatable, Sendable {
  var results: [Result]

  struct Result: Decodable, Equatable, Identifiable, Sendable {
    var country: String
    var latitude: Double
    var longitude: Double
    var id: Int
    var name: String
    var admin1: String?
  }
}

struct Forecast: Decodable, Equatable, Sendable {
  var daily: Daily
  var dailyUnits: DailyUnits

  struct Daily: Decodable, Equatable, Sendable {
    var temperatureMax: [Double]
    var temperatureMin: [Double]
    var time: [Date]
  }

  struct DailyUnits: Decodable, Equatable, Sendable {
    var temperatureMax: String
    var temperatureMin: String
  }
}

// MARK: - API client interface

// Typically this interface would live in its own module, separate from the live implementation.
// This allows the search feature to compile faster since it only depends on the interface.

struct WeatherClient {
  var forecast: @Sendable (GeocodingSearch.Result) async throws -> Forecast
  var search: @Sendable (String) async throws -> GeocodingSearch
}

extension WeatherClient: TestDependencyKey {
  static let previewValue = Self(
    forecast: { _ in .mock },
    search: { _ in .mock }
  )

  static let testValue = Self(
    forecast: unimplemented("\(Self.self).forecast"),
    search: unimplemented("\(Self.self).search")
  )
}

extension DependencyValues {
  var weatherClient: WeatherClient {
    get { self[WeatherClient.self] }
    set { self[WeatherClient.self] = newValue }
  }
}

// MARK: - Live API implementation

extension WeatherClient: DependencyKey {
  static let liveValue = WeatherClient(
    forecast: { result in
      var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
      components.queryItems = [
        URLQueryItem(name: "latitude", value: "\(result.latitude)"),
        URLQueryItem(name: "longitude", value: "\(result.longitude)"),
        URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
        URLQueryItem(name: "timezone", value: TimeZone.autoupdatingCurrent.identifier),
      ]

      let (data, _) = try await URLSession.shared.data(from: components.url!)
      return try jsonDecoder.decode(Forecast.self, from: data)
    },
    search: { query in
      var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
      components.queryItems = [URLQueryItem(name: "name", value: query)]

      let (data, _) = try await URLSession.shared.data(from: components.url!)
      return try jsonDecoder.decode(GeocodingSearch.self, from: data)
    }
  )
}

// MARK: - Mock data

extension Forecast {
  static let mock = Self(
    daily: Daily(
      temperatureMax: [90, 70, 100],
      temperatureMin: [70, 50, 80],
      time: [0, 86_400, 172_800].map(Date.init(timeIntervalSince1970:))
    ),
    dailyUnits: DailyUnits(temperatureMax: "°F", temperatureMin: "°F")
  )
}

extension GeocodingSearch {
  static let mock = Self(
    results: [
      GeocodingSearch.Result(
        country: "United States",
        latitude: 40.6782,
        longitude: -73.9442,
        id: 1,
        name: "Brooklyn",
        admin1: nil
      ),
      GeocodingSearch.Result(
        country: "United States",
        latitude: 34.0522,
        longitude: -118.2437,
        id: 2,
        name: "Los Angeles",
        admin1: nil
      ),
      GeocodingSearch.Result(
        country: "United States",
        latitude: 37.7749,
        longitude: -122.4194,
        id: 3,
        name: "San Francisco",
        admin1: nil
      ),
    ]
  )
}

// MARK: - Private helpers

private let jsonDecoder: JSONDecoder = {
  let decoder = JSONDecoder()
  let formatter = DateFormatter()
  formatter.calendar = Calendar(identifier: .iso8601)
  formatter.dateFormat = "yyyy-MM-dd"
  formatter.timeZone = TimeZone(secondsFromGMT: 0)
  formatter.locale = Locale(identifier: "en_US_POSIX")
  decoder.dateDecodingStrategy = .formatted(formatter)
  return decoder
}()

extension Forecast {
  private enum CodingKeys: String, CodingKey {
    case daily
    case dailyUnits = "daily_units"
  }
}

extension Forecast.Daily {
  private enum CodingKeys: String, CodingKey {
    case temperatureMax = "temperature_2m_max"
    case temperatureMin = "temperature_2m_min"
    case time
  }
}

extension Forecast.DailyUnits {
  private enum CodingKeys: String, CodingKey {
    case temperatureMax = "temperature_2m_max"
    case temperatureMin = "temperature_2m_min"
  }
}
