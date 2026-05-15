import Foundation
import MediaPlayer
import Combine

struct NowPlayingTrack: Equatable {
    let id: String
    let artist: String
    let track: String
    let duration: TimeInterval
}

class NowPlayingService: ObservableObject {
    @Published private(set) var currentTrack: NowPlayingTrack?

    var onTrackChanged: ((NowPlayingTrack?, NowPlayingTrack?) -> Void)?

    private var timer: Timer?

    private static let apiURL = URL(string: "https://rms.api.bbc.co.uk/v2/services/bbc_6music/segments/latest")!
    private static let pollInterval: TimeInterval = 10

    func start() {
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        URLSession.shared.dataTask(with: Self.apiURL) { [weak self] data, _, _ in
            guard let data else { return }
            let track = Self.parseTrack(from: data)
            DispatchQueue.main.async { self?.update(track: track) }
        }.resume()
    }

    private static func parseTrack(from data: Data) -> NowPlayingTrack? {
        guard let response = try? JSONDecoder().decode(BBCResponse.self, from: data),
              let item = response.data.first(where: { $0.offset.nowPlaying }) else { return nil }
        return NowPlayingTrack(
            id: item.id,
            artist: item.titles.primary,
            track: item.titles.secondary ?? "",
            duration: TimeInterval(max(0, item.offset.end - item.offset.start))
        )
    }

    private func update(track: NowPlayingTrack?) {
        guard track?.id != currentTrack?.id else { return }
        let previous = currentTrack
        currentTrack = track
        onTrackChanged?(previous, track)
        updateNowPlayingCenter(track: track)
    }

    private func updateNowPlayingCenter(track: NowPlayingTrack?) {
        guard let track else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyTitle: track.track,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyIsLiveStream: true
        ]
    }
}

// MARK: - JSON models

private struct BBCResponse: Decodable {
    let data: [SegmentItem]
}

private struct SegmentItem: Decodable {
    let id: String
    let titles: Titles
    let offset: Offset

    struct Titles: Decodable {
        let primary: String
        let secondary: String?
    }

    struct Offset: Decodable {
        let start: Int
        let end: Int
        let nowPlaying: Bool

        enum CodingKeys: String, CodingKey {
            case start, end
            case nowPlaying = "now_playing"
        }
    }
}
