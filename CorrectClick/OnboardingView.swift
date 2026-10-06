import FinderSync
import SwiftUI

struct OnboardingView: View {

    /// Live, so step 1 ticks itself off the moment the user flips the switch
    /// in System Settings — polled, because macOS doesn't notify the app when
    /// that changes, and System Settings is frontmost while they do it.
    @State private var isExtensionEnabled = FIFinderSyncController.isExtensionEnabled
    private let enabledCheck = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Header
            VStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 4)

                Text("Welcome to CorrectClick")
                    .font(.system(size: 24, weight: .bold))

                Text("Right-click any folder in Finder to create a new file instantly — no app windows, no dialogs.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
            .padding(.top, 36)
            .padding(.bottom, 32)

            Divider()

            // MARK: Steps
            VStack(alignment: .leading, spacing: 0) {
                Text("Get started")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 16)

                StepRow(
                    number: 1,
                    title: "Enable the Finder extension",
                    detail: isExtensionEnabled
                        ? "CorrectClick is turned on."
                        : "Click the button below to open System Settings, then turn on CorrectClick in the list of extensions.",
                    isComplete: isExtensionEnabled
                )

                Rectangle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 1, height: 20)
                    .padding(.leading, 16)

                StepRow(
                    number: 2,
                    title: "Right-click any folder in Finder",
                    detail: "Look for the CorrectClick submenu to create new files, turn your clipboard into a file, or act on selected files."
                )

                Rectangle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 1, height: 20)
                    .padding(.leading, 16)

                StepRow(
                    number: 3,
                    title: "Using iCloud Drive or OneDrive? Add the toolbar button",
                    detail: "macOS doesn't show right-click menus from extensions in cloud folders. In Finder, choose View → Customize Toolbar… and drag the CorrectClick button into the toolbar — it has the same menu and works everywhere."
                )
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)

            Divider()

            // MARK: Buttons
            HStack(spacing: 12) {
                if isExtensionEnabled {
                    Spacer()

                    Button {
                        OnboardingWindowController.shared.close()
                    } label: {
                        Text("Done")
                            .font(.system(size: 14, weight: .medium))
                            .frame(minWidth: 80)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Done") {
                        OnboardingWindowController.shared.close()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Spacer()

                    Button(action: openExtensionSettings) {
                        Label("Open Extensions Settings", systemImage: "arrow.forward.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
        }
        .frame(width: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(.easeInOut(duration: 0.2), value: isExtensionEnabled)
        .onReceive(enabledCheck) { _ in
            let enabled = FIFinderSyncController.isExtensionEnabled
            if enabled != isExtensionEnabled {
                isExtensionEnabled = enabled
            }
        }
    }

    private func openExtensionSettings() {
        AppDelegate.openExtensionPreferences()
    }
}

// MARK: - Step row

private struct StepRow: View {
    let number: Int
    let title: String
    let detail: String
    var isComplete = false

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(isComplete ? Color.green : Color.accentColor)
                    .frame(width: 32, height: 32)
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(number)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
        }
    }
}

#Preview {
    OnboardingView()
}
