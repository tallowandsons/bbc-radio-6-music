import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private var playerController: PlayerController!
    private var nowPlayingService: NowPlayingService!
    private var scheduleService: ScheduleService!
    private var lastFMService: LastFMService!

    func applicationDidFinishLaunching(_ notification: Notification) {
        playerController = PlayerController()
        nowPlayingService = NowPlayingService()
        scheduleService = ScheduleService()
        lastFMService = LastFMService(playerController: playerController, nowPlayingService: nowPlayingService)
        statusBarController = StatusBarController(
            playerController: playerController,
            nowPlayingService: nowPlayingService,
            scheduleService: scheduleService,
            lastFMService: lastFMService
        )
        playerController.play()
        nowPlayingService.start()
        scheduleService.start()
    }
}
