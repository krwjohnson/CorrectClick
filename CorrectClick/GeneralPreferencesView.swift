import AppKit
import SwiftUI

struct GeneralPreferencesView: View {

    @State private var authorName: String = AuthorPreferenceStore.load()
    @State private var loginItemState: LoginItem.State = LoginItem.state
    @State private var loginItemError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General")
                .font(.system(size: 20, weight: .bold))

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Open CorrectClick at login", isOn: openAtLoginBinding)
                Text("The Finder menu works whether or not CorrectClick is running. Opening at login keeps the menu bar icon and daily update checks available.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 320, alignment: .leading)

                if loginItemState == .requiresApproval {
                    HStack(spacing: 8) {
                        Text("Turned off in System Settings.")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                        Button("Open Login Items Settings…") {
                            LoginItem.openSystemSettings()
                        }
                        .controlSize(.small)
                    }
                }

                if let loginItemError {
                    Text(loginItemError)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                        .frame(maxWidth: 320, alignment: .leading)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Author Name")
                    .font(.system(size: 13, weight: .medium))
                Text("Used to fill in {{author}} in your snippet templates.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("e.g. Jane Doe", text: $authorName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 280)
                    .onChange(of: authorName) { newValue in
                        AuthorPreferenceStore.save(newValue)
                    }
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: refreshLoginItemState)
        // The user may have changed it in System Settings while this window
        // was open in the background.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshLoginItemState()
        }
    }

    /// Reads and writes the system registration directly (see `LoginItem`),
    /// so a failed register/unregister leaves the toggle showing what's
    /// actually true rather than what the user tried to set.
    private var openAtLoginBinding: Binding<Bool> {
        Binding(
            get: { loginItemState != .disabled },
            set: { newValue in
                do {
                    try LoginItem.setEnabled(newValue)
                    loginItemError = nil
                } catch {
                    loginItemError = "Couldn't change this: \(error.localizedDescription)"
                }
                refreshLoginItemState()
            }
        )
    }

    private func refreshLoginItemState() {
        loginItemState = LoginItem.state
    }
}

#Preview {
    GeneralPreferencesView()
}
