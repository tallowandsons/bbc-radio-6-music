import AppKit
import SwiftUI

class PreferencesWindowController: NSWindowController {
    convenience init(playerController: PlayerController, lastFMService: LastFMService) {
        let view = PreferencesView(playerController: playerController, lastFMService: lastFMService)
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Preferences"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 560, height: 540))
        window.minSize = NSSize(width: 480, height: 480)
        window.level = .floating
        window.center()
        self.init(window: window)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        // NSHostingController sets focus after showWindow, so defer the clear
        DispatchQueue.main.async {
            self.window?.makeFirstResponder(nil)
        }
    }
}
