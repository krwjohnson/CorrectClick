import Combine
import Sparkle
import SwiftUI

/// Tracks whether a check is already in progress, so the "Check for Updates
/// Now" button disables itself instead of letting the user queue a second
/// concurrent check — mirrors Sparkle's own recommended SwiftUI pattern.
private final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false
    private var cancellable: AnyCancellable?

    init() {
        cancellable = UpdaterManager.shared.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.canCheckForUpdates = $0 }
    }
}

struct UpdatesPreferencesView: View {

    @StateObject private var checkForUpdatesViewModel = CheckForUpdatesViewModel()
    @State private var automaticallyChecksForUpdates = UpdaterManager.shared.updater.automaticallyChecksForUpdates

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Updates")
                .font(.system(size: 20, weight: .bold))

            Toggle("Automatically check for updates", isOn: $automaticallyChecksForUpdates)
                .onChange(of: automaticallyChecksForUpdates) { newValue in
                    // Sparkle persists this itself (UserDefaults key
                    // "SUEnableAutomaticChecks") — no separate store needed.
                    UpdaterManager.shared.updater.automaticallyChecksForUpdates = newValue
                }

            Text("Checks once a day when enabled. Declining an update doesn't ask again until the next scheduled check.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: 320, alignment: .leading)

            Button("Check for Updates Now") {
                UpdaterManager.shared.checkForUpdates()
            }
            .disabled(!checkForUpdatesViewModel.canCheckForUpdates)

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    UpdatesPreferencesView()
}
