import SwiftUI

struct OnboardingView: View {

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
                Text("Get started in two steps")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 16)

                StepRow(
                    number: 1,
                    title: "Enable the Finder extension",
                    detail: "Click the button below to open System Settings, then tick the checkbox next to CorrectClick Extension."
                )

                Rectangle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 1, height: 20)
                    .padding(.leading, 16)

                StepRow(
                    number: 2,
                    title: "Right-click any folder in Finder",
                    detail: "Look for the CorrectClick submenu. Choose New Text File, New Text File from Clipboard, or New PNG from Clipboard."
                )
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)

            Divider()

            // MARK: Buttons
            HStack(spacing: 12) {
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
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
        }
        .frame(width: 480)
        .background(Color(nsColor: .windowBackgroundColor))
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

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 32, height: 32)
                Text("\(number)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
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
