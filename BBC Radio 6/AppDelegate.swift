import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private var playerController: PlayerController!
    private var nowPlayingService: NowPlayingService!
    private var lastFMService: LastFMService!

    func applicationDidFinishLaunching(_ notification: Notification) {
        playerController = PlayerController()
        nowPlayingService = NowPlayingService()
        lastFMService = LastFMService(playerController: playerController, nowPlayingService: nowPlayingService)
        statusBarController = StatusBarController(
            playerController: playerController,
            nowPlayingService: nowPlayingService,
            lastFMService: lastFMService
        )
        playerController.play()
        nowPlayingService.start()
    }
}
