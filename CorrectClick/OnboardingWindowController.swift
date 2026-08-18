import AppKit
import SwiftUI

final class OnboardingWindowController: NSObject {

    static let shared = OnboardingWindowController()

    private var window: NSWindow?

    override private init() {}

    func showIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else { return }
        show()
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: OnboardingView())
            let w = NSWindow(contentViewController: hosting)
            w.title = "Welcome to CorrectClick"
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

    func dropFloating() {
        window?.level = .normal
    }

    func close() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }
}

extension OnboardingWindowController: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        // Once the user has focused the window we no longer need it floating.
        dropFloating()
    }
}

extension Notification.Name {
    static let onboardingDismissed = Notification.Name("onboardingDismissed")
}
