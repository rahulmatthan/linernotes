import SwiftUI
import MusicKit

@available(macOS 14.0, *)
struct MusicSearchSheet: View {
    @StateObject private var viewModel = MusicSearchViewModel()
    @Environment(\.dismiss) private var dismiss
    /// Callback: (isrc, artworkData, songTitle, artistName)
    let onSongSelected: (String?, Data?, String, String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            if viewModel.authorizationStatus != .authorized {
                authorizationView
            } else {
                searchView
            }
        }
        .frame(width: 600, height: 500)
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error occurred")
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Search Apple Music")
                .font(.title2)
                .fontWeight(.semibold)

            if viewModel.authorizationStatus == .authorized {
                TextField("Search for songs...", text: $viewModel.searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task {
                            await viewModel.searchSongs()
                        }
                    }
            }
        }
        .padding()
    }

    private var authorizationView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Apple Music Access Required")
                .font(.title3)
                .fontWeight(.medium)

            Text("LinerNotes Admin needs access to Apple Music to search for songs and populate accurate metadata.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 400)

            Button("Grant Access") {
                Task {
                    await viewModel.requestAuthorization()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var searchView: some View {
        VStack(spacing: 0) {
            if viewModel.isSearching {
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty {
                emptyStateView
            } else {
                resultsList
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No results found")
                .font(.headline)

            Text("Try a different search term")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.searchResults) { song in
                    SongResultRow(song: song) {
                        Task {
                            await viewModel.selectSong(song) { result in
                                onSongSelected(result.isrc, result.artworkData, result.songTitle, result.artistName)
                                dismiss()
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct SongResultRow: View {
    let song: SongSearchResult
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: song.artworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                    }
            }
            .frame(width: 60, height: 60)
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if !song.albumTitle.isEmpty {
                    Text(song.albumTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if let isrc = song.isrc {
                    Text("ISRC: \(isrc)")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }

            Spacer()

            Button("Use This Song") {
                onSelect()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}
