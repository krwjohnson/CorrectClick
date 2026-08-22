import SwiftUI

struct TemplateEditorView: View {

    @State private var draft: UserTemplate
    let onSave: (UserTemplate) -> Void
    let onCancel: () -> Void

    init(template: UserTemplate, onSave: @escaping (UserTemplate) -> Void, onCancel: @escaping () -> Void) {
        _draft = State(initialValue: template)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var isValid: Bool {
        !draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var previewText: String {
        let author = AuthorPreferenceStore.load()
        let context = TemplateContext(
            author: author.isEmpty ? "Jane Doe" : author,
            clipboardText: "example clipboard text",
            filenameAtCreation: draft.fileNameStem
        )
        return TemplateVariableSubstitution.resolve(draft.starterContent, context: context)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Template")
                .font(.system(size: 16, weight: .bold))

            VStack(alignment: .leading, spacing: 4) {
                Text("Name").font(.system(size: 12, weight: .medium))
                TextField("e.g. New Daily Note", text: $draft.displayName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Extension (no dot; leave blank for none)").font(.system(size: 12, weight: .medium))
                TextField("e.g. md", text: $draft.fileExtension)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Starter Content").font(.system(size: 12, weight: .medium))
                Text("Supports {{date}}, {{time}}, {{datetime}}, {{filename}}, {{clipboard}}, {{author}}.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextEditor(text: $draft.starterContent)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 110)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Preview (using placeholder values)").font(.system(size: 12, weight: .medium))
                ScrollView {
                    Text(previewText.isEmpty ? " " : previewText)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                }
                .frame(height: 90)
                .background(Color.secondary.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Save") { onSave(draft) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 440, height: 540)
    }
}

#Preview {
    TemplateEditorView(
        template: UserTemplate(displayName: "New Daily Note", fileExtension: "md", starterContent: "# {{date}}\n\n", sortOrder: 0),
        onSave: { _ in },
        onCancel: {}
    )
}
