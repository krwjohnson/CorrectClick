import SwiftUI

struct MenuItemsPreferencesView: View {

    /// A single row's UI-facing state. Kept separate from `MenuItemState`
    /// so `title` (display-only) doesn't need to round-trip through disk.
    struct MenuItemRow: Identifiable {
        let id: String
        let title: String
        var enabled: Bool
    }

    @State private var createRows: [MenuItemRow]
    @State private var clipboardRows: [MenuItemRow]

    private let store = MenuPreferencesStore.shared

    init() {
        let states = MenuPreferencesStore.shared.load()
        _createRows = State(initialValue: Self.rows(for: .create, states: states))
        _clipboardRows = State(initialValue: Self.rows(for: .clipboard, states: states))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Menu Items")
                .font(.system(size: 20, weight: .bold))
                .padding(.top, 20)
                .padding(.horizontal, 20)

            Text("Choose which actions appear in the CorrectClick Finder menu, and drag to reorder them.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            List {
                Section("New File") {
                    ForEach($createRows) { $row in
                        Toggle(isOn: $row.enabled) { Text(row.title) }
                            .onChange(of: row.enabled) { _ in persist() }
                    }
                    .onMove { indices, newOffset in
                        createRows.move(fromOffsets: indices, toOffset: newOffset)
                        persist()
                    }
                }

                Section("From Clipboard") {
                    ForEach($clipboardRows) { $row in
                        Toggle(isOn: $row.enabled) { Text(row.title) }
                            .onChange(of: row.enabled) { _ in persist() }
                    }
                    .onMove { indices, newOffset in
                        clipboardRows.move(fromOffsets: indices, toOffset: newOffset)
                        persist()
                    }
                }
            }
            .listStyle(.inset)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private static func rows(for category: MenuItemCategory, states: [MenuItemState]) -> [MenuItemRow] {
        MenuPreferencesStore.shared.orderedItems(in: category, from: states).map { definition, state in
            MenuItemRow(id: definition.id, title: definition.title, enabled: state.enabled)
        }
    }

    /// Writes the current on-screen order and enabled state to disk
    /// immediately — the extension re-reads this file on every right-click,
    /// so there's no separate "apply" step.
    private func persist() {
        var states: [MenuItemState] = []
        for (index, row) in createRows.enumerated() {
            states.append(MenuItemState(id: row.id, enabled: row.enabled, sortIndex: index))
        }
        for (index, row) in clipboardRows.enumerated() {
            states.append(MenuItemState(id: row.id, enabled: row.enabled, sortIndex: index))
        }
        store.save(states)
    }
}

#Preview {
    MenuItemsPreferencesView()
}
