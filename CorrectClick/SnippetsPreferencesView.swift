import SwiftUI
import UniformTypeIdentifiers

struct SnippetsPreferencesView: View {

    @State private var templates: [UserTemplate]
    // Drives the sheet directly via .sheet(item:) — a single Identifiable
    // optional, not a separate Bool alongside it. Two independently-updated
    // @State vars (an isPresenting Bool + the item) is a known SwiftUI-on-
    // macOS trap: the sheet's content closure can evaluate before the item
    // is observed as non-nil, silently rendering EmptyView() — a blank,
    // undismissable sheet (no Cancel button ever appears) until force-quit.
    @State private var editingTemplate: UserTemplate?
    @State private var statusMessage: String?

    private let store = UserTemplateStore.shared

    init() {
        _templates = State(initialValue: UserTemplateStore.shared.load().sorted { $0.sortOrder < $1.sortOrder })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Snippets")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                Button("Import…", action: importTemplates)
                Button("Export…", action: exportTemplates)
                    .disabled(templates.isEmpty)
                Button(action: addTemplate) {
                    Label("Add", systemImage: "plus")
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)

            Text("Define your own \"New [X] File\" menu entries with your own boilerplate content.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            if templates.isEmpty {
                Spacer()
                Text("No snippets yet — click Add to create one.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                List {
                    ForEach($templates) { $template in
                        HStack(spacing: 10) {
                            Toggle("", isOn: $template.enabled)
                                .labelsHidden()
                                .onChange(of: template.enabled) { _ in persist() }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(template.displayName)
                                    .font(.system(size: 13, weight: .medium))
                                Text(template.normalizedExtension.isEmpty ? "no extension" : ".\(template.normalizedExtension)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Edit") { edit(template) }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.accentColor)

                            Button {
                                delete(template)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .onMove { indices, newOffset in
                        templates.move(fromOffsets: indices, toOffset: newOffset)
                        persist()
                    }
                }
                .listStyle(.inset)
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $editingTemplate) { template in
            TemplateEditorView(
                template: template,
                onSave: { saved in
                    upsert(saved)
                    editingTemplate = nil
                },
                onCancel: { editingTemplate = nil }
            )
        }
    }

    // MARK: - CRUD

    private func addTemplate() {
        editingTemplate = UserTemplate(
            displayName: "New Template",
            fileExtension: "txt",
            starterContent: "",
            sortOrder: templates.count
        )
    }

    private func edit(_ template: UserTemplate) {
        editingTemplate = template
    }

    private func upsert(_ template: UserTemplate) {
        if templates.contains(where: { $0.id == template.id }) {
            templates = UserTemplateOperations.update(template, in: templates)
        } else {
            templates = UserTemplateOperations.add(template, to: templates)
        }
        persist()
    }

    private func delete(_ template: UserTemplate) {
        templates = UserTemplateOperations.delete(id: template.id, from: templates)
        persist()
    }

    private func persist() {
        templates = UserTemplateOperations.reindexed(templates)
        store.save(templates)
    }

    // MARK: - Import / export

    private func exportTemplates() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "CorrectClick Templates.json"
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try JSONEncoder().encode(templates)
            try data.write(to: url, options: .atomic)
            statusMessage = "Exported \(templates.count) template\(templates.count == 1 ? "" : "s")."
        } catch {
            statusMessage = "Couldn't export templates: \(error.localizedDescription)"
        }
    }

    private func importTemplates() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let imported = try JSONDecoder().decode([UserTemplate].self, from: data)
            templates = UserTemplateOperations.merge(existing: templates, importing: imported)
            persist()
            statusMessage = "Imported \(imported.count) template\(imported.count == 1 ? "" : "s")."
        } catch {
            statusMessage = "Couldn't import templates: \(error.localizedDescription)"
        }
    }
}

#Preview {
    SnippetsPreferencesView()
}
