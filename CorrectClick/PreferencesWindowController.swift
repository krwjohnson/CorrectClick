import AppKit
import SwiftUI

final class PreferencesWindowController: NSObject {

    static let shared = PreferencesWindowController()

    private var window: NSWindow?

    override private init() {}

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: PreferencesView())
            let w = NSWindow(contentViewController: hosting)
            w.title = "CorrectClick Preferences"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.setContentSize(hosting.view.fittingSize)
            w.center()
            w.delegate = self
            window = w
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        // Float above other windows to bypass focus-stealing prevention,
        // which silently blocks LSUIElement apps from coming to front.
        window?.level = .floating
        window?.makeKeyAndOrderFront(nil)
    }
}

extension PreferencesWindowController: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        window?.level = .normal
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
