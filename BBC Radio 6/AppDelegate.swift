import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private var playerController: PlayerController!
    private var nowPlayingService: NowPlayingService!
    private var scheduleService: ScheduleService!
    private var lastFMService: LastFMService!
    private var updateChecker: UpdateChecker!

    func applicationDidFinishLaunching(_ notification: Notification) {
        playerController = PlayerController()
        nowPlayingService = NowPlayingService()
        scheduleService = ScheduleService()
        updateChecker = UpdateChecker()
        lastFMService = LastFMService(playerController: playerController, nowPlayingService: nowPlayingService)
        statusBarController = StatusBarController(
            playerController: playerController,
            nowPlayingService: nowPlayingService,
            scheduleService: scheduleService,
            updateChecker: updateChecker,
            lastFMService: lastFMService
        )
        playerController.play()
        nowPlayingService.start()
        scheduleService.start()
        updateChecker.start()
    }
}
