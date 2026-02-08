import Foundation
import MusicKit

@available(iOS 16.0, *)
@MainActor
class PlaylistService: ObservableObject {
    @Published var lastError: String?
    @Published var playlistCreationFailed: Bool = false
    @Published private(set) var addedSongIds: Set<String> = []
    @Published var isAddingCurrentSong: Bool = false

    private static let playlistIdKey = "linerNotesPlaylistId"

    init() {}

    /// Check if a song has already been added to the playlist
    func hasBeenAdded(_ song: Song) -> Bool {
        return addedSongIds.contains(song.id.rawValue)
    }

    /// Add a song to the Liner Notes playlist (user-initiated)
    /// - Parameter song: The MusicKit Song to add
    /// - Returns: true if successful, false otherwise
    @discardableResult
    func addSongToPlaylist(_ song: Song) async -> Bool {
        // Don't keep trying if playlist creation already failed this session
        guard !playlistCreationFailed else {
            print("📋 Skipping playlist add - creation previously failed")
            return false
        }

        // Check if we already added this song
        let songIdString = song.id.rawValue
        guard !addedSongIds.contains(songIdString) else {
            print("📋 Song already added to playlist: \(song.title)")
            return true
        }

        isAddingCurrentSong = true
        defer { isAddingCurrentSong = false }

        do {
            let playlist = try await getOrCreatePlaylist()
            try await addSongToPlaylist(song: song, playlist: playlist)
            addedSongIds.insert(songIdString)
            print("✅ Added to playlist: \(song.title)")
            return true
        } catch {
            print("⚠️ Failed to add to playlist: \(error)")
            lastError = error.localizedDescription

            // If this is a permission/entitlement error, disable further attempts
            let errorString = String(describing: error)
            if errorString.contains("not entitled") || errorString.contains("PermissionDenied") ||
               errorString.contains("not supported") {
                playlistCreationFailed = true
                print("⚠️ Playlist feature unavailable - disabling for this session")
            }
            return false
        }
    }

    /// Get existing playlist or create a new one
    private func getOrCreatePlaylist() async throws -> Playlist {
        let playlistName = "Liner Notes"

        // Try to find existing playlist by searching library
        if let savedId = UserDefaults.standard.string(forKey: Self.playlistIdKey) {
            do {
                let musicItemID = MusicItemID(savedId)
                var request = MusicLibraryRequest<Playlist>()
                request.filter(matching: \.id, equalTo: musicItemID)

                let response = try await request.response()
                if let playlist = response.items.first {
                    print("📋 Found existing playlist: \(playlist.name)")
                    return playlist
                }
            } catch {
                print("⚠️ Could not find saved playlist: \(error)")
            }
        }

        // Create new playlist
        print("📋 Creating new playlist: \(playlistName)")
        let playlist = try await MusicLibrary.shared.createPlaylist(
            name: playlistName,
            description: ""
        )

        // Save the playlist ID for future use
        UserDefaults.standard.set(playlist.id.rawValue, forKey: Self.playlistIdKey)
        print("✅ Created playlist: \(playlist.name) (ID: \(playlist.id.rawValue))")

        return playlist
    }

    /// Add a song to an existing playlist
    private func addSongToPlaylist(song: Song, playlist: Playlist) async throws {
        // MusicLibrary.add takes a single MusicPlaylistAddable item, not an array
        _ = try await MusicLibrary.shared.add(song, to: playlist)
    }

    /// Clear the session's added songs (for when starting a new game)
    func clearSession() {
        addedSongIds.removeAll()
    }
}
