import AVFoundation
import MediaPlayer
import Combine

class PlayerController: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published var volume: Float {
        didSet {
            player?.volume = volume
            UserDefaults.standard.set(volume, forKey: "player_volume")
        }
    }

    private var player: AVPlayer?
    private var timeControlObservation: NSKeyValueObservation?
    private var itemStatusObservation: NSKeyValueObservation?
    private var reconnectWorkItem: DispatchWorkItem?

    private static let streamURL = URL(string: "http://as-hls-uk-live.akamaized.net/pool_81827798/live/uk/bbc_6music/bbc_6music.isml/bbc_6music-audio=320000.norewind.m3u8")!

    init() {
        let saved = UserDefaults.standard.float(forKey: "player_volume")
        volume = saved > 0 ? saved : 1.0
    }

    func play() {
        if player == nil { setupPlayer() }
        player?.play()
    }

    func pause() {
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        player?.pause()
    }

    func toggle() {
        isPlaying ? pause() : play()
    }

    private func setupPlayer() {
        let item = AVPlayerItem(url: Self.streamURL)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.volume = volume
        player = newPlayer

        timeControlObservation = newPlayer.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                self?.isPlaying = player.timeControlStatus == .playing
            }
        }

        itemStatusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            if item.status == .failed {
                DispatchQueue.main.async { self?.scheduleReconnect() }
            }
        }

        setupRemoteCommands()
    }

    private func scheduleReconnect() {
        guard reconnectWorkItem == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            self?.reconnectWorkItem = nil
            self?.player = nil
            self?.timeControlObservation = nil
            self?.itemStatusObservation = nil
            self?.setupPlayer()
            self?.player?.play()
        }
        reconnectWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.removeTarget(nil)

        center.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.toggle()
            return .success
        }
    }
}
