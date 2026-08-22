import SwiftUI

struct PreferencesView: View {
    var body: some View {
        TabView {
            GeneralPreferencesView()
                .tabItem { Label("General", systemImage: "gearshape") }

            MenuItemsPreferencesView()
                .tabItem { Label("Menu Items", systemImage: "checklist") }

            SnippetsPreferencesView()
                .tabItem { Label("Snippets", systemImage: "doc.badge.plus") }

            UpdatesPreferencesView()
                .tabItem { Label("Updates", systemImage: "arrow.triangle.2.circlepath") }
        }
        .frame(width: 480, height: 520)
    }
}

#Preview {
    PreferencesView()
}
