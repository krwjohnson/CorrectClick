import SwiftUI

struct GeneralPreferencesView: View {

    @State private var authorName: String = AuthorPreferenceStore.load()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General")
                .font(.system(size: 20, weight: .bold))

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
    }
}

#Preview {
    GeneralPreferencesView()
}
