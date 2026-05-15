import AppKit
import Combine

class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let playerController: PlayerController
    private let nowPlayingService: NowPlayingService
    private let lastFMService: LastFMService
    private var cancellables = Set<AnyCancellable>()
    private var preferencesWindowController: PreferencesWindowController?

    private var showNowPlaying: Bool {
        UserDefaults.standard.object(forKey: "showNowPlayingInMenuBar") as? Bool ?? true
    }

    private var leftClickToPause: Bool {
        UserDefaults.standard.object(forKey: "leftClickToPause") as? Bool ?? true
    }

    init(
        playerController: PlayerController,
        nowPlayingService: NowPlayingService,
        lastFMService: LastFMService
    ) {
        self.playerController = playerController
        self.nowPlayingService = nowPlayingService
        self.lastFMService = lastFMService
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        setupButton()
        setupObservers()
    }

    // MARK: - Setup

    private func setupButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateIcon(isPlaying: false)
    }

    private func setupObservers() {
        playerController.$isPlaying
            .combineLatest(nowPlayingService.$currentTrack)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying, track in
                self?.updateButton(isPlaying: isPlaying, track: track)
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateTitle(isPlaying: self.playerController.isPlaying, track: self.nowPlayingService.currentTrack)
            }
            .store(in: &cancellables)
    }

    // MARK: - Button updates

    private func updateButton(isPlaying: Bool, track: NowPlayingTrack?) {
        updateIcon(isPlaying: isPlaying)
        updateTitle(isPlaying: isPlaying, track: track)
    }

    private func updateIcon(isPlaying: Bool) {
        guard let button = statusItem.button,
              let url = Bundle.main.url(forResource: "radio6", withExtension: "svg"),
              let base = NSImage(contentsOf: url) else { return }

        let size = NSSize(width: 18, height: 18)
        base.size = size

        if isPlaying {
            base.isTemplate = true
            button.image = base
            return
        }

        // Paused: overlay a pause badge in the bottom-right corner.
        // Draw the base, then a solid circle, then punch out the pause bars
        // using destinationOut so the result works as a template image.
        let icon = NSImage(size: size, flipped: false) { rect in
            base.draw(in: rect)

            let badgeSize: CGFloat = 10.0
            let badgeRect = CGRect(
                x: rect.width - badgeSize + 1.0,
                y: 0,
                width: badgeSize,
                height: badgeSize
            )

            NSColor.black.setFill()
            NSBezierPath(ovalIn: badgeRect).fill()

            if let ctx = NSGraphicsContext.current {
                ctx.compositingOperation = .destinationOut
                NSColor.black.setFill()
                let barW: CGFloat = 2.5
                let barH: CGFloat = 6.0
                let barY = badgeRect.minY + (badgeSize - barH) / 2
                NSBezierPath(rect: CGRect(x: badgeRect.minX + 1.5, y: barY, width: barW, height: barH)).fill()
                NSBezierPath(rect: CGRect(x: badgeRect.minX + 5.0, y: barY, width: barW, height: barH)).fill()
                ctx.compositingOperation = .sourceOver
            }

            return true
        }
        icon.isTemplate = true
        button.image = icon
    }

    private func updateTitle(isPlaying: Bool, track: NowPlayingTrack?) {
        guard let button = statusItem.button else { return }
        if showNowPlaying, let track {
            let label = "\(track.artist) — \(track.track)"
            let truncated = label.count > 45 ? String(label.prefix(42)) + "…" : label
            button.title = " \(truncated)"
        } else {
            button.title = ""
        }
    }

    // MARK: - Click handling

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || !leftClickToPause {
            showContextMenu(for: sender)
        } else {
            playerController.toggle()
        }
    }

    private func showContextMenu(for button: NSStatusBarButton) {
        let menu = NSMenu()

        if let track = nowPlayingService.currentTrack {
            let item = NSMenuItem(title: "\(track.artist) — \(track.track)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            let item = NSMenuItem(title: playerController.isPlaying ? "No track info" : "Paused", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let playPauseItem = NSMenuItem(
            title: playerController.isPlaying ? "Pause" : "Play",
            action: #selector(togglePlayPause),
            keyEquivalent: ""
        )
        playPauseItem.image = NSImage(systemSymbolName: playerController.isPlaying ? "pause.fill" : "play.fill", accessibilityDescription: nil)
        playPauseItem.target = self
        menu.addItem(playPauseItem)

        menu.addItem(.separator())

        let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.keyEquivalentModifierMask = .command
        prefsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        prefsItem.target = self
        menu.addItem(prefsItem)

        let quitItem = NSMenuItem(title: "Quit BBC Radio 6", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = .command
        menu.addItem(quitItem)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func togglePlayPause() {
        playerController.toggle()
    }

    @objc private func openPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController(playerController: playerController, lastFMService: lastFMService)
        }
        preferencesWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
