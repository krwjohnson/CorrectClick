import ServiceManagement

/// "Open at Login", via `SMAppService.mainApp` (macOS 13+, works under App
/// Sandbox with no extra entitlement). The system's login-item registration
/// is the only source of truth — nothing is mirrored into UserDefaults — so
/// the toggle stays correct even if the user changes it in System Settings →
/// General → Login Items instead.
///
/// Off by default: it's only ever turned on by the user flipping the toggle.
///
/// Registers whichever copy of the app is running, so toggling this from an
/// Xcode debug build registers the DerivedData copy, not /Applications.
enum LoginItem {

    enum State {
        case enabled
        /// Registered, but the user has switched it off in System Settings
        /// (or macOS wants them to confirm it there) — it won't launch at
        /// login until they turn it back on in Login Items.
        case requiresApproval
        case disabled
    }

    static var state: State {
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        default: return .disabled
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
