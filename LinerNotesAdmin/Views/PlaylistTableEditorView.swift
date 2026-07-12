import SwiftUI

struct PlaylistTableEditorView: View {
    @ObservedObject var viewModel: TreasureHuntViewModel
    @State private var showingMusicSearch: Bool = false
    @State private var editingRowIndex: Int? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Column Headers
            HStack(alignment: .center, spacing: 8) {
                Text("#")
                    .frame(width: 35)
                Text("Clue")
                    .frame(width: 160)
                Text("Hint")
                    .frame(width: 160)
                Text("MC Options (A-D)")
                    .frame(width: 200)
                Text("Correct Answers")
                    .frame(width: 130)
                Text("ISRC")
                    .frame(width: 110)
                Text("Answer Text")
                    .frame(width: 120)
                Text("Song Start")
                    .frame(width: 120)
                Text("Trivia")
                    .frame(width: 60)
                Text("Art")
                    .frame(width: 50)
                Text("")
                    .frame(width: 25)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Scrollable Rows
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.currentHunt.links.indices, id: \.self) { index in
                        VStack(spacing: 0) {
                            PlaylistRowView(
                                rowNumber: index + 1,
                                link: $viewModel.currentHunt.links[index],
                                onSearchMusic: {
                                    editingRowIndex = index
                                    showingMusicSearch = true
                                },
                                onDelete: {
                                    viewModel.deleteLink(at: index)
                                }
                            )

                            Divider()
                        }
                    }

                    // Add new row button
                    Button {
                        viewModel.addNewLink()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                            Text("Add New Row")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                }
            }
        }
        .sheet(isPresented: $showingMusicSearch) {
            if #available(macOS 14.0, *) {
                MusicSearchSheet { isrc, artworkData, songTitle, artistName in
                    if let index = editingRowIndex {
                        if let isrc = isrc {
                            viewModel.currentHunt.links[index].isrc = isrc
                        }
                        if let artworkData = artworkData {
                            viewModel.currentHunt.links[index].albumArtData = artworkData
                        }
                        // Store song title and artist for search fallback
                        viewModel.currentHunt.links[index].songTitle = songTitle
                        viewModel.currentHunt.links[index].artistName = artistName
                        // Also add artist to correct answers if not present
                        if !artistName.isEmpty && !viewModel.currentHunt.links[index].correctAnswers.contains(artistName) {
                            viewModel.currentHunt.links[index].correctAnswers.append(artistName)
                        }
                        viewModel.hasUnsavedChanges = true
                    }
                    editingRowIndex = nil
                }
            }
        }
    }
}

#Preview {
    PlaylistTableEditorView(viewModel: TreasureHuntViewModel())
        .frame(width: 1400, height: 600)
}
