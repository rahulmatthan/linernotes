import Foundation
import MusicKit

@available(macOS 14.0, *)
actor MusicKitService {
    static let shared = MusicKitService()

    private init() {}

    var authorizationStatus: MusicAuthorization.Status {
        MusicAuthorization.currentStatus
    }

    func requestAuthorization() async -> MusicAuthorization.Status {
        let status = await MusicAuthorization.request()
        return status
    }

    func searchSongs(query: String) async throws -> [SongSearchResult] {
        guard !query.isEmpty else { return [] }

        // Try iTunes Search API first (no authentication required)
        do {
            return try await searchWithiTunesAPI(query: query)
        } catch {
            print("iTunes API failed: \(error), trying MusicKit...")
        }

        // Fallback to MusicKit if iTunes API fails
        let status = MusicAuthorization.currentStatus
        guard status == .authorized else {
            throw MusicKitError.unauthorized
        }

        var request = MusicCatalogSearchRequest(term: query, types: [Song.self])
        request.limit = 25

        let response = try await request.response()

        return response.songs.map { SongSearchResult(from: $0) }
    }

    // iTunes Search API - no authentication required
    private func searchWithiTunesAPI(query: String) async throws -> [SongSearchResult] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://itunes.apple.com/search?term=\(encodedQuery)&media=music&entity=song&limit=25"

        guard let url = URL(string: urlString) else {
            throw MusicKitError.networkError
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MusicKitError.networkError
        }

        let result = try JSONDecoder().decode(iTunesSearchResponse.self, from: data)

        return result.results.map { track in
            // Extract Apple Music song ID from trackViewUrl
            // URL format: https://music.apple.com/us/album/song-name/albumId?i=songId
            let appleMusicId = extractAppleMusicSongId(from: track.trackViewUrl)

            return SongSearchResult(
                id: String(track.trackId),
                title: track.trackName,
                artistName: track.artistName,
                albumTitle: track.collectionName ?? "",
                isrc: appleMusicId,  // Store Apple Music ID for direct lookup
                artworkURL: URL(string: track.artworkUrl100?.replacingOccurrences(of: "100x100", with: "600x600") ?? "")
            )
        }
    }

    /// Extract Apple Music song ID from iTunes trackViewUrl
    /// URL format: https://music.apple.com/us/album/song-name/albumId?i=songId
    private func extractAppleMusicSongId(from urlString: String?) -> String? {
        guard let urlString = urlString,
              let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let songIdItem = queryItems.first(where: { $0.name == "i" }),
              let songId = songIdItem.value else {
            return nil
        }
        return songId
    }

    func downloadArtwork(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MusicKitError.networkError
        }

        return data
    }
}

// iTunes Search API response models
struct iTunesSearchResponse: Codable {
    let resultCount: Int
    let results: [iTunesTrack]
}

struct iTunesTrack: Codable {
    let trackId: Int
    let trackName: String
    let artistName: String
    let collectionName: String?
    let artworkUrl100: String?
    let trackViewUrl: String?
}

enum MusicKitError: LocalizedError {
    case unauthorized
    case networkError
    case noResults

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "MusicKit authorization is required to search for songs."
        case .networkError:
            return "Failed to download artwork. Please check your network connection."
        case .noResults:
            return "No songs found for your search query."
        }
    }
}
