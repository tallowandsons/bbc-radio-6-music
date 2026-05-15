import AppKit
import SwiftUI

class PreferencesWindowController: NSWindowController {
    convenience init(playerController: PlayerController, lastFMService: LastFMService) {
        let view = PreferencesView(playerController: playerController, lastFMService: lastFMService)
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Preferences"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 420, height: 430))
        window.center()
        self.init(window: window)
    }
}
