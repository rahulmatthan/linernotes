import Foundation
import SwiftUI
import MusicKit

@available(macOS 14.0, *)
@MainActor
class MusicSearchViewModel: ObservableObject {
    @Published var searchQuery: String = ""
    @Published var searchResults: [SongSearchResult] = []
    @Published var isSearching: Bool = false
    @Published var authorizationStatus: MusicAuthorization.Status = .authorized  // Default to authorized for iTunes API
    @Published var errorMessage: String?
    @Published var showingError: Bool = false

    private let musicService = MusicKitService.shared

    init() {
        // No need to check authorization - iTunes API doesn't require it
    }

    func updateAuthorizationStatus() async {
        // Always allow - iTunes API doesn't need authorization
        authorizationStatus = .authorized
    }

    func requestAuthorization() async {
        // Always allow - iTunes API doesn't need authorization
        authorizationStatus = .authorized
    }

    func searchSongs() async {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            searchResults = try await musicService.searchSongs(query: searchQuery)
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
            searchResults = []
        }
    }

    /// Selection result containing ISRC, song title, artist name, and artwork data
    struct SongSelectionResult {
        let isrc: String
        let songTitle: String
        let artistName: String
        let artworkData: Data?
    }

    func selectSong(_ song: SongSearchResult, completion: @escaping (SongSelectionResult) -> Void) async {
        // For iTunes API results, we need to look up ISRC separately or use track ID
        let isrc = song.isrc ?? "ITUNES-\(song.id)"  // Fallback identifier
        var artworkData: Data?

        if let artworkURL = song.artworkURL {
            do {
                artworkData = try await musicService.downloadArtwork(from: artworkURL)
            } catch {
                print("Failed to download artwork: \(error)")
            }
        }

        let result = SongSelectionResult(
            isrc: isrc,
            songTitle: song.title,
            artistName: song.artistName,
            artworkData: artworkData
        )
        completion(result)
    }
}
