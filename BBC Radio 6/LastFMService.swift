import Foundation
import CryptoKit
import Combine

class LastFMService: ObservableObject {
    @Published private(set) var connectedUsername: String?

    private var cancellables = Set<AnyCancellable>()
    private var pendingToken: String?
    private var trackStartedAt: Date?
    private var lastScrobbledId: String?

    var apiKey: String {
        get { UserDefaults.standard.string(forKey: "lastfm_api_key") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "lastfm_api_key") }
    }

    var apiSecret: String {
        get { UserDefaults.standard.string(forKey: "lastfm_api_secret") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "lastfm_api_secret") }
    }

    var sessionKey: String? {
        get { UserDefaults.standard.string(forKey: "lastfm_session_key") }
        set { UserDefaults.standard.set(newValue, forKey: "lastfm_session_key") }
    }

    var isConnected: Bool { sessionKey != nil }

    var scrobblingEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "lastfm_scrobbling_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "lastfm_scrobbling_enabled") }
    }

    private var playerController: PlayerController

    init(playerController: PlayerController, nowPlayingService: NowPlayingService) {
        self.playerController = playerController
        connectedUsername = UserDefaults.standard.string(forKey: "lastfm_username")

        nowPlayingService.onTrackChanged = { [weak self] previous, current in
            self?.handleTrackChange(from: previous, to: current)
        }

        playerController.$isPlaying
            .sink { [weak self] isPlaying in
                guard let self else { return }
                if isPlaying {
                    // Start counting from now for scrobble threshold
                    if nowPlayingService.currentTrack != nil {
                        self.trackStartedAt = Date()
                        if let track = nowPlayingService.currentTrack {
                            self.updateNowPlaying(artist: track.artist, track: track.track)
                        }
                    }
                } else {
                    // Scrobble the current track if it earned it before we lose trackStartedAt
                    if let track = nowPlayingService.currentTrack, let startedAt = self.trackStartedAt {
                        self.maybeScrobble(track: track, startedAt: startedAt)
                    }
                    self.trackStartedAt = nil
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Auth

    func startAuth(completion: @escaping (Result<URL, Error>) -> Void) {
        guard !apiKey.isEmpty else {
            completion(.failure(LastFMError.missingCredentials))
            return
        }
        let urlString = "https://ws.audioscrobbler.com/2.0/?method=auth.getToken&api_key=\(apiKey)&format=json"
        guard let url = URL(string: urlString) else {
            completion(.failure(LastFMError.invalidResponse))
            return
        }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let data,
                  let json = try? JSONDecoder().decode([String: String].self, from: data),
                  let token = json["token"] else {
                DispatchQueue.main.async { completion(.failure(LastFMError.invalidResponse)) }
                return
            }
            self.pendingToken = token
            let authURL = URL(string: "https://www.last.fm/api/auth/?api_key=\(self.apiKey)&token=\(token)")!
            DispatchQueue.main.async { completion(.success(authURL)) }
        }.resume()
    }

    func completeAuth(completion: @escaping (Result<String, Error>) -> Void) {
        guard let token = pendingToken else {
            completion(.failure(LastFMError.noToken))
            return
        }
        let params = ["method": "auth.getSession", "api_key": apiKey, "token": token]
        let sig = signature(params: params)
        let urlString = "https://ws.audioscrobbler.com/2.0/?method=auth.getSession&api_key=\(apiKey)&token=\(token)&api_sig=\(sig)&format=json"
        guard let url = URL(string: urlString) else {
            completion(.failure(LastFMError.invalidResponse))
            return
        }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let session = json["session"] as? [String: Any],
                  let key = session["key"] as? String,
                  let name = session["name"] as? String else {
                DispatchQueue.main.async { completion(.failure(LastFMError.invalidResponse)) }
                return
            }
            self.sessionKey = key
            UserDefaults.standard.set(name, forKey: "lastfm_username")
            self.pendingToken = nil
            DispatchQueue.main.async {
                self.connectedUsername = name
                completion(.success(name))
            }
        }.resume()
    }

    func disconnect() {
        sessionKey = nil
        connectedUsername = nil
        pendingToken = nil
        UserDefaults.standard.removeObject(forKey: "lastfm_username")
    }

    // MARK: - Scrobbling

    private func handleTrackChange(from previous: NowPlayingTrack?, to current: NowPlayingTrack?) {
        guard playerController.isPlaying else { return }

        let now = Date()

        if let previous, let startedAt = trackStartedAt {
            maybeScrobble(track: previous, startedAt: startedAt)
        }

        trackStartedAt = current != nil ? now : nil

        if let current {
            updateNowPlaying(artist: current.artist, track: current.track)
        }
    }

    private func maybeScrobble(track: NowPlayingTrack, startedAt: Date) {
        guard scrobblingEnabled else { return }
        guard track.id != lastScrobbledId else { return }
        let elapsed = Date().timeIntervalSince(startedAt)
        guard elapsed >= 30 else { return }
        lastScrobbledId = track.id
        scrobble(artist: track.artist, track: track.track, timestamp: Int(startedAt.timeIntervalSince1970))
    }

    private func updateNowPlaying(artist: String, track: String) {
        guard scrobblingEnabled else { return }
        guard let sessionKey else { return }
        post(params: [
            "method": "track.updateNowPlaying",
            "artist": artist,
            "track": track,
            "api_key": apiKey,
            "sk": sessionKey
        ])
    }

    private func scrobble(artist: String, track: String, timestamp: Int) {
        guard let sessionKey else { return }
        post(params: [
            "method": "track.scrobble",
            "artist": artist,
            "track": track,
            "timestamp": String(timestamp),
            "api_key": apiKey,
            "sk": sessionKey
        ])
    }

    // MARK: - Networking

    private func post(params: [String: String]) {
        guard !apiKey.isEmpty, !apiSecret.isEmpty else { return }
        var body = params
        body["api_sig"] = signature(params: params)
        body["format"] = "json"

        var request = URLRequest(url: URL(string: "https://ws.audioscrobbler.com/2.0/")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
            .map { k, v in "\(k)=\(v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? v)" }
            .joined(separator: "&")
            .data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error {
                print("[LastFM] \(params["method"] ?? "?") error: \(error)")
            } else if let data, let body = String(data: data, encoding: .utf8) {
                print("[LastFM] \(params["method"] ?? "?") response: \(body)")
            }
        }.resume()
    }

    private func signature(params: [String: String]) -> String {
        let sorted = params
            .filter { $0.key != "format" && $0.key != "callback" }
            .sorted { $0.key < $1.key }
            .map { "\($0.key)\($0.value)" }
            .joined()
        let toHash = sorted + apiSecret
        return Insecure.MD5.hash(data: Data(toHash.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    // MARK: - Errors

    enum LastFMError: LocalizedError {
        case missingCredentials
        case invalidResponse
        case noToken

        var errorDescription: String? {
            switch self {
            case .missingCredentials: return "API key and secret are required."
            case .invalidResponse: return "Unexpected response from Last.fm."
            case .noToken: return "No pending auth token. Start the auth flow first."
            }
        }
    }
}
