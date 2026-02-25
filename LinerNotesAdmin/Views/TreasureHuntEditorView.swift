import SwiftUI

struct TreasureHuntEditorView: View {
    @StateObject private var viewModel = TreasureHuntViewModel()
    @State private var editingMetadata = false
    @State private var viewMode: ViewMode = .detail

    private enum ViewMode {
        case detail
        case table
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar header
            HStack(spacing: 16) {
                // Hunt info
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.currentHunt.name)
                        .font(.headline)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text("\(viewModel.currentHunt.links.count) links")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("•")
                            .foregroundColor(.secondary)

                        Text("\(Int(viewModel.currentHunt.completionPercentage))% Complete")
                            .font(.caption)
                            .foregroundColor(viewModel.currentHunt.isComplete ? .green : .secondary)

                        // Manifest status indicator
                        if viewModel.currentManifestEntry.isValid {
                            Text("•")
                                .foregroundColor(.secondary)

                            Label("In Manifest", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }

                Spacer()

                // Toolbar buttons
                HStack(spacing: 12) {
                    Button {
                        viewModel.newHunt()
                    } label: {
                        Label("New", systemImage: "doc")
                    }
                    .help("Create a new treasure hunt")

                    Button {
                        Task {
                            await viewModel.loadFromFile()
                        }
                    } label: {
                        Label("Load", systemImage: "folder")
                    }
                    .help("Load a treasure hunt from file")

                    Button {
                        Task {
                            if viewModel.hasValidManifestEntry {
                                await viewModel.saveToFile()
                            } else {
                                await viewModel.saveDraft()
                            }
                        }
                    } label: {
                        Label(viewModel.hasValidManifestEntry ? "Save" : "Save Draft", systemImage: "square.and.arrow.down")
                    }
                    .help(viewModel.hasValidManifestEntry ? "Save treasure hunt and manifest to file" : "Save a local draft of this treasure hunt")

                    Button {
                        Task {
                            await viewModel.pushToGitHub()
                        }
                    } label: {
                        if viewModel.isPushing {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        } else {
                            Label("Publish", systemImage: "icloud.and.arrow.up")
                        }
                    }
                    .help("Publish this treasure hunt to GitHub for the app to download")
                    .disabled(viewModel.isPushing)

                    Divider()
                        .frame(height: 20)

                    Picker("View Mode", selection: $viewMode) {
                        Text("Detail").tag(ViewMode.detail)
                        Text("Table").tag(ViewMode.table)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)

                    Divider()
                        .frame(height: 20)

                    Button {
                        viewModel.showingManifestManager = true
                    } label: {
                        Label("Manifest", systemImage: "list.bullet.rectangle")
                    }
                    .help("View and manage the hunt manifest")

                    Button {
                        viewModel.showingPreview = true
                    } label: {
                        Label("Preview", systemImage: "eye")
                    }
                    .help("Preview all chain links")

                    Button {
                        editingMetadata = true
                    } label: {
                        Label("Info", systemImage: "info.circle")
                    }
                    .help("Edit treasure hunt metadata")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Editor content
            Group {
                switch viewMode {
                case .detail:
                    HStack(spacing: 0) {
                        // Sidebar list of links
                        VStack(spacing: 0) {
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 4) {
                                    ForEach(viewModel.currentHunt.links.indices, id: \.self) { index in
                                        ChainLinkListItemView(
                                            linkNumber: index + 1,
                                            link: viewModel.currentHunt.links[index],
                                            isSelected: viewModel.selectedLinkIndex == index
                                        )
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            viewModel.selectedLinkIndex = index
                                        }
                                    }
                                }
                                .padding(8)
                            }

                            Divider()

                            Button {
                                viewModel.addNewLink()
                                viewModel.selectedLinkIndex = max(0, viewModel.currentHunt.links.count - 1)
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add Link")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(8)
                        }
                        .frame(minWidth: 260, maxWidth: 320)
                        .background(Color(nsColor: .underPageBackgroundColor))

                        Divider()

                        // Detail editor
                        Group {
                            if viewModel.currentHunt.links.indices.contains(viewModel.selectedLinkIndex) {
                                ChainLinkEditorView(viewModel: viewModel)
                            } else {
                                VStack {
                                    Text("Select a link to start editing")
                                        .font(.title3)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                case .table:
                    PlaylistTableEditorView(viewModel: viewModel)
                }
            }
        }
        .frame(minWidth: 1100, minHeight: 500)
        .sheet(isPresented: $viewModel.showingPreview, onDismiss: {
            // Ensure we return to the focused detail editor when closing preview
            viewMode = .detail
        }) {
            PreviewSheet(hunt: viewModel.currentHunt, selectedLinkIndex: $viewModel.selectedLinkIndex)
        }
        .sheet(isPresented: $editingMetadata) {
            MetadataEditor(hunt: $viewModel.currentHunt)
        }
        .sheet(isPresented: $viewModel.showingManifestEditor) {
            ManifestEntryEditorView(
                entry: $viewModel.currentManifestEntry,
                huntName: viewModel.currentHunt.name,
                linkCount: viewModel.currentHunt.links.count,
                onSave: {
                    viewModel.onManifestEditorSave()
                },
                onCancel: {
                    viewModel.onManifestEditorCancel()
                }
            )
        }
        .sheet(isPresented: $viewModel.showingManifestManager) {
            ManifestManagerView(manifest: $viewModel.manifest)
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error occurred")
        }
        .alert("GitHub", isPresented: $viewModel.showingPushSuccess) {
            Button("OK") { }
        } message: {
            Text(viewModel.pushSuccessMessage ?? "Done")
        }
    }
}

struct MetadataEditor: View {
    @Binding var hunt: TreasureHunt
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var description: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Treasure Hunt Information")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)

                TextField("Description", text: $description, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    hunt.name = name
                    hunt.description = description
                    hunt.modifiedDate = Date()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 250)
        .onAppear {
            name = hunt.name
            description = hunt.description
        }
    }
}

#Preview {
    TreasureHuntEditorView()
        .frame(width: 1000, height: 700)
}
