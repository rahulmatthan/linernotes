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

    func validateSongIdentifier(
        isrc: String,
        songTitle: String?,
        artistName: String?
    ) async -> SongValidationResult {
        let trimmedId = isrc.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = songTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedArtist = artistName?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedId.isEmpty || !(trimmedTitle ?? "").isEmpty else {
            return SongValidationResult(
                isValid: false,
                message: "Enter a Song ID/ISRC or title to validate.",
                resolvedTitle: nil,
                resolvedArtist: nil
            )
        }

        // 0) iTunes Apple Music ID lookup (numeric values)
        if !trimmedId.isEmpty, trimmedId.allSatisfy({ $0.isNumber }) {
            if let track = await lookupiTunesTrackByAppleMusicID(trimmedId) {
                return SongValidationResult(
                    isValid: true,
                    message: "Valid (iTunes ID lookup): resolves to \"\(track.trackName)\" by \(track.artistName).",
                    resolvedTitle: track.trackName,
                    resolvedArtist: track.artistName
                )
            }
        }

        // 1) iTunes ISRC lookup (real ISRC format, non-numeric, non-placeholder)
        if !trimmedId.isEmpty, !trimmedId.hasPrefix("ITUNES-"), !trimmedId.allSatisfy({ $0.isNumber }) {
            if let track = await lookupiTunesTrackByISRC(trimmedId) {
                return SongValidationResult(
                    isValid: true,
                    message: "Valid (iTunes ISRC lookup): resolves to \"\(track.trackName)\" by \(track.artistName).",
                    resolvedTitle: track.trackName,
                    resolvedArtist: track.artistName
                )
            }
        }

        // 2) iTunes metadata validation (no MusicKit token required)
        if let title = trimmedTitle, !title.isEmpty {
            if let track = await lookupiTunesTrack(title: title, artist: trimmedArtist) {
                return SongValidationResult(
                    isValid: true,
                    message: "Valid (iTunes metadata): resolves to \"\(track.trackName)\" by \(track.artistName).",
                    resolvedTitle: track.trackName,
                    resolvedArtist: track.artistName
                )
            }
        }

        return SongValidationResult(
            isValid: false,
            message: "Could not validate this song via iTunes lookup. Try reselecting with Search Music or verify the ID/title.",
            resolvedTitle: nil,
            resolvedArtist: nil
        )
    }

    private func lookupiTunesTrack(title: String, artist: String?) async -> iTunesTrack? {
        let term = artist.map { "\(title) \($0)" } ?? title
        let encodedQuery = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? term
        let urlString = "https://itunes.apple.com/search?term=\(encodedQuery)&media=music&entity=song&limit=25"

        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            let result = try JSONDecoder().decode(iTunesSearchResponse.self, from: data)
            return bestiTunesMatch(in: result.results, title: title, artist: artist)
        } catch {
            return nil
        }
    }

    private func lookupiTunesTrackByAppleMusicID(_ id: String) async -> iTunesTrack? {
        let urlString = "https://itunes.apple.com/lookup?id=\(id)&entity=song"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            let result = try JSONDecoder().decode(iTunesSearchResponse.self, from: data)
            return result.results.first
        } catch {
            return nil
        }
    }

    private func lookupiTunesTrackByISRC(_ isrc: String) async -> iTunesTrack? {
        let encoded = isrc.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? isrc
        let urlString = "https://itunes.apple.com/search?term=\(encoded)&media=music&entity=song&attribute=isrcTerm&limit=10"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            let result = try JSONDecoder().decode(iTunesSearchResponse.self, from: data)
            return result.results.first
        } catch {
            return nil
        }
    }

    private func normalize(_ value: String) -> String {
        value
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func bestiTunesMatch(in tracks: [iTunesTrack], title: String, artist: String?) -> iTunesTrack? {
        guard !tracks.isEmpty else { return nil }
        guard let artist, !artist.isEmpty else { return tracks.first }

        let nTitle = normalize(title)
        let nArtist = normalize(artist)

        if let exact = tracks.first(where: {
            normalize($0.trackName) == nTitle && normalize($0.artistName) == nArtist
        }) {
            return exact
        }

        if let partial = tracks.first(where: {
            normalize($0.trackName).contains(nTitle) && normalize($0.artistName).contains(nArtist)
        }) {
            return partial
        }

        return tracks.first
    }
}

struct SongValidationResult {
    let isValid: Bool
    let message: String
    let resolvedTitle: String?
    let resolvedArtist: String?
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
