import SwiftUI

/// Editor view for a single manifest entry
/// Shown before save/push to ensure manifest details are provided
struct ManifestEntryEditorView: View {
    @Binding var entry: HuntManifestEntry
    let huntName: String
    let linkCount: Int
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var entryId: String = ""
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var difficulty: String = ""
    @State private var isPublished: Bool = false

    @Environment(\.dismiss) private var dismiss

    private var isValid: Bool {
        !entryId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)

                Text("Manifest Entry Required")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Before saving, please provide the details for this hunt's manifest entry. This information is displayed in the app's hunt selection screen.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            // Form
            Form {
                Section {
                    LabeledContent("Hunt File ID") {
                        TextField("e.g., Version 1", text: $entryId)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 300)
                    }
                    .help("Unique identifier used as the JSON filename (without .json extension)")

                    LabeledContent("Display Name") {
                        TextField("e.g., Classic Hits", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 300)
                    }
                    .help("Name shown in the hunt selection screen")

                    LabeledContent("Description") {
                        TextField("Short description for selection screen", text: $description, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                            .frame(maxWidth: 300)
                    }
                    .help("Brief description shown below the hunt name")

                    LabeledContent("Difficulty (Optional)") {
                        TextField("e.g., Easy, Medium, Hard", text: $difficulty)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 300)
                    }
                    .help("Optional difficulty indicator")

                    Toggle("Publish in app", isOn: $isPublished)
                        .help("If enabled, this hunt will be included in the client app manifest.")
                } header: {
                    Text("Manifest Details")
                }

                Section {
                    LabeledContent("Song Count") {
                        Text("\(linkCount)")
                            .foregroundColor(.secondary)
                    }
                    .help("Automatically calculated from the number of links")

                    LabeledContent("Source Hunt") {
                        Text(huntName)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Auto-Calculated")
                }
            }
            .formStyle(.grouped)

            Divider()

            // Buttons
            HStack {
                Button("Cancel") {
                    onCancel()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if !isValid {
                    Text("Please fill in all required fields")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                Button("Save & Continue") {
                    saveEntry()
                    onSave()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 550, height: 520)
        .onAppear {
            loadEntry()
        }
    }

    private func loadEntry() {
        // Pre-populate from existing entry or hunt
        if !entry.id.isEmpty {
            entryId = entry.id
            name = entry.name
            description = entry.description
            difficulty = entry.difficulty ?? ""
            isPublished = entry.isPublished
        } else {
            // Default to hunt name
            entryId = huntName
            name = huntName
            isPublished = false
        }
    }

    private func saveEntry() {
        entry = HuntManifestEntry(
            id: entryId.trimmingCharacters(in: .whitespacesAndNewlines),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            difficulty: difficulty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : difficulty.trimmingCharacters(in: .whitespacesAndNewlines),
            songCount: linkCount,
            isPublished: isPublished
        )
    }
}

/// Full manifest manager view for viewing all entries
struct ManifestManagerView: View {
    @Binding var manifest: HuntManifest
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Manifest Manager")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("\(manifest.publishedOnly.hunts.count) published of \(manifest.hunts.count) total")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            if manifest.hunts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No Hunts in Manifest")
                        .font(.headline)

                    Text("Save a treasure hunt to add it to the manifest.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(manifest.hunts) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.name)
                                    .font(.headline)

                                Text(entry.description)
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)

                                HStack(spacing: 12) {
                                    Label("\(entry.songCount) songs", systemImage: "music.note")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    if let difficulty = entry.difficulty {
                                        Text(difficulty)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Text("ID: \(entry.id)")
                                        .font(.caption)
                                        .foregroundColor(.secondary.opacity(0.7))
                                }
                            }

                            Spacer()

                            Toggle("Published", isOn: publishedBinding(for: entry.id))
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .help("Include this hunt in the client app manifest")

                            Button {
                                manifest.remove(id: entry.id)
                                persistManifest()
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Remove from manifest")
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .frame(width: 600, height: 450)
        .onDisappear {
            persistManifest()
        }
    }

    private func publishedBinding(for entryId: String) -> Binding<Bool> {
        Binding(
            get: {
                manifest.hunts.first(where: { $0.id == entryId })?.isPublished ?? false
            },
            set: { newValue in
                guard let idx = manifest.hunts.firstIndex(where: { $0.id == entryId }) else { return }
                manifest.hunts[idx].isPublished = newValue
                // Persist immediately so publishing selection is never lost.
                persistManifest()
            }
        )
    }

    private func persistManifest() {
        try? FileManager.saveManifest(manifest)
    }
}

#Preview("Entry Editor") {
    ManifestEntryEditorView(
        entry: .constant(.empty),
        huntName: "My Treasure Hunt",
        linkCount: 15,
        onSave: {},
        onCancel: {}
    )
}

#Preview("Manifest Manager") {
    ManifestManagerView(
        manifest: .constant(HuntManifest(hunts: [
            HuntManifestEntry(id: "Version 1", name: "Classic Hits", description: "A journey through iconic songs", difficulty: "Medium", songCount: 20, isPublished: true),
            HuntManifestEntry(id: "80s Classics", name: "80s Classics", description: "The best of the 1980s", difficulty: nil, songCount: 15, isPublished: false)
        ]))
    )
}
