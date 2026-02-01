import SwiftUI

struct TreasureHuntEditorView: View {
    @StateObject private var viewModel = TreasureHuntViewModel()
    @State private var editingMetadata = false

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
                            await viewModel.saveToFile()
                        }
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .help("Save treasure hunt to file")
                    .disabled(!viewModel.currentHunt.isComplete)

                    Divider()
                        .frame(height: 20)

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

            // Table editor
            PlaylistTableEditorView(viewModel: viewModel)
        }
        .frame(minWidth: 1100, minHeight: 500)
        .sheet(isPresented: $viewModel.showingPreview) {
            PreviewSheet(hunt: viewModel.currentHunt, selectedLinkIndex: $viewModel.selectedLinkIndex)
        }
        .sheet(isPresented: $editingMetadata) {
            MetadataEditor(hunt: $viewModel.currentHunt)
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error occurred")
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
