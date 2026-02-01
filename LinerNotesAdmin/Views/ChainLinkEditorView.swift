import SwiftUI

struct ChainLinkEditorView: View {
    @ObservedObject var viewModel: TreasureHuntViewModel
    @State private var editedLink: ChainLink
    @State private var newArtist: String = ""
    @State private var showingMusicSearch = false

    init(viewModel: TreasureHuntViewModel) {
        self.viewModel = viewModel
        self._editedLink = State(initialValue: viewModel.currentLink)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                clueSection

                hintSection

                artistSection

                isrcSection

                albumArtSection

                actionButtons
            }
            .padding()
        }
        .onChange(of: viewModel.selectedLinkIndex) { _, _ in
            editedLink = viewModel.currentLink
        }
        .onChange(of: editedLink) { _, newValue in
            viewModel.updateLink(at: viewModel.selectedLinkIndex, with: newValue)
        }
        .sheet(isPresented: $showingMusicSearch) {
            if #available(macOS 14.0, *) {
                MusicSearchSheet { isrc, artworkData, songTitle, artistName in
                    if let isrc = isrc {
                        editedLink.isrc = isrc
                    }
                    if let artworkData = artworkData {
                        editedLink.albumArtData = artworkData
                    }
                    // Store song title and artist for search fallback
                    editedLink.songTitle = songTitle
                    editedLink.artistName = artistName
                    // Also add artist to correct answers if not present
                    if !artistName.isEmpty && !editedLink.correctAnswers.contains(artistName) {
                        editedLink.correctAnswers.append(artistName)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Chain Link #\(viewModel.selectedLinkIndex + 1)")
                    .font(.title2)
                    .fontWeight(.bold)

                if editedLink.isValid {
                    Label("Complete", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.subheadline)
                } else {
                    Label("Incomplete", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.subheadline)
                }
            }

            Spacer()
        }
    }

    private var clueSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Clue", systemImage: "questionmark.circle.fill")
                .font(.headline)
                .foregroundColor(.primary)

            TextEditor(text: $editedLink.clue)
                .font(.body)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(editedLink.clue.isEmpty ? Color.red.opacity(0.5) : Color.clear, lineWidth: 2)
                )

            if editedLink.clue.isEmpty {
                Text("Clue is required")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private var hintSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Hint 1 (Required)", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundColor(.primary)

            TextEditor(text: $editedLink.hint1)
                .font(.body)
                .frame(minHeight: 80)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)

            Label("Hint 2 (Optional)", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.top, 8)

            TextEditor(text: Binding(
                get: { editedLink.hint2 ?? "" },
                set: { editedLink.hint2 = $0.isEmpty ? nil : $0 }
            ))
                .font(.body)
                .frame(minHeight: 80)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)
        }
    }

    private var artistSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Correct Answers", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Add multiple variations (e.g., 'Pink Floyd', 'pink floyd')")
                .font(.caption)
                .foregroundColor(.secondary)

            FlowLayout(spacing: 8) {
                ForEach(Array(editedLink.correctAnswers.enumerated()), id: \.offset) { index, answer in
                    HStack(spacing: 4) {
                        Text(answer)
                            .font(.body)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)

                        Button {
                            editedLink.correctAnswers.remove(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .background(Color.accentColor.opacity(0.2))
                    .cornerRadius(12)
                }
            }

            HStack {
                TextField("Add answer variant...", text: $newArtist)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addArtist()
                    }

                Button("Add") {
                    addArtist()
                }
                .disabled(newArtist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if editedLink.correctAnswers.isEmpty {
                Text("At least one correct answer is required")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private var isrcSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("ISRC", systemImage: "barcode")
                .font(.headline)
                .foregroundColor(.primary)

            TextField("International Standard Recording Code", text: $editedLink.isrc)
                .textFieldStyle(.roundedBorder)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(editedLink.isrc.isEmpty ? Color.red.opacity(0.5) : Color.clear, lineWidth: 2)
                )

            if editedLink.isrc.isEmpty {
                Text("ISRC is required")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private var albumArtSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Album Art", systemImage: "photo.fill")
                .font(.headline)
                .foregroundColor(.primary)

            if let image = editedLink.albumArtImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 200, maxHeight: 200)
                    .cornerRadius(8)
                    .shadow(radius: 4)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 200, height: 200)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No album art")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                showingMusicSearch = true
            } label: {
                Label("Search Music", systemImage: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)

            if editedLink.albumArtData != nil {
                Button(role: .destructive) {
                    editedLink.albumArtData = nil
                } label: {
                    Label("Remove Album Art", systemImage: "trash")
                }
            }
        }
    }

    private func addArtist() {
        let trimmed = newArtist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !editedLink.correctAnswers.contains(trimmed) else {
            newArtist = ""
            return
        }
        editedLink.correctAnswers.append(trimmed)
        newArtist = ""
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}
