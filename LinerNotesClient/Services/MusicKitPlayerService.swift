import Foundation
import MusicKit
import AVFoundation

@available(iOS 15.0, *)
@MainActor
class MusicKitPlayerService: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var nowPlaying: Song?
    @Published var queuedNext: Song?
    @Published var playbackTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var authorizationStatus: MusicAuthorization.Status = .notDetermined
    @Published var currentArtworkURL: URL?
    @Published var currentSongTitle: String = ""
    @Published var currentArtistName: String = ""

    private let player = ApplicationMusicPlayer.shared
    private var playbackObserver: Timer?
    private var isHandlingSongCompletion = false

    init() {
        Task {
            authorizationStatus = MusicAuthorization.currentStatus
        }
    }

    func requestAuthorization() async -> Bool {
        print("🔐 Current auth status: \(MusicAuthorization.currentStatus)")
        print("🔐 Requesting authorization...")
        let status = await MusicAuthorization.request()
        print("🔐 Authorization result: \(status)")
        authorizationStatus = status
        return status == .authorized
    }

    // NEW: Play song immediately as reward for correct answer
    /// - Parameters:
    ///   - isrc: The ISRC code (may be fake "ITUNES-xxx" from iTunes API)
    ///   - songTitle: Optional song title for fallback search
    ///   - artistName: Optional artist name for fallback search
    func playReward(isrc: String, songTitle: String? = nil, artistName: String? = nil) async throws {
        print("🎵 playReward called with ISRC: \(isrc), songTitle: \(songTitle ?? "nil"), artistName: \(artistName ?? "nil")")
        print("🎵 Authorization status: \(authorizationStatus)")

        guard authorizationStatus == .authorized else {
            print("❌ Not authorized!")
            throw MusicKitError.unauthorized
        }

        print("🎵 Searching for song...")
        var song = try await SongLookupService.findSong(
            isrc: isrc,
            songTitle: songTitle,
            artistName: artistName,
            includeDemoFallback: true
        )
        print("✅ Found song: \(song.title) by \(song.artistName)")

        if !isPlaying || nowPlaying == nil {
            // No song actively playing, start immediately.
            print("🎵 Starting playback...")
            do {
                try await startPlayback(song)
                print("✅ Playback started!")
            } catch {
                // Some ID/ISRC matches are not playable in the current storefront.
                // Retry with a metadata-only search when possible.
                guard let title = songTitle, let artist = artistName else { throw error }
                print("⚠️ Initial playback failed: \(error). Retrying with metadata search...")
                song = try await SongLookupService.findSongByMetadata(title: title, artist: artist)
                do {
                    try await startPlayback(song)
                } catch {
                    print("⚠️ Metadata retry failed: \(error). Trying alternative versions...")
                    let candidates = try await SongLookupService.findCandidateSongsByMetadata(title: title, artist: artist, limit: 15)
                    var lastError: Error = error
                    var playedAlternative = false
                    for candidate in candidates where candidate.id.rawValue != song.id.rawValue {
                        do {
                            try await startPlayback(candidate)
                            song = candidate
                            playedAlternative = true
                            print("✅ Playback started on alternative: \(candidate.title) by \(candidate.artistName)")
                            break
                        } catch {
                            lastError = error
                            continue
                        }
                    }
                    // If nothing worked, bubble up the final failure.
                    if !playedAlternative {
                        throw lastError
                    }
                }
                print("✅ Playback started on retry: \(song.title) by \(song.artistName)")
            }
            isPlaying = true
            startPlaybackObserver()
        } else {
            // Song playing, queue for next
            print("🎵 Queueing song for next...")
            queuedNext = song
        }
    }

    private func startPlayback(_ song: Song) async throws {
        nowPlaying = song
        duration = song.duration ?? 0
        updateSongMetadata(song)
        player.queue = [song]
        try await player.play()
    }

    // NEW: Start observing playback position
    private func startPlaybackObserver() {
        stopPlaybackObserver() // Stop any existing observer

        playbackObserver = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor in
                // Update playback time
                self.playbackTime = self.player.playbackTime

                // Check if song finished and transition to queued song.
                if self.duration > 0,
                   self.playbackTime >= self.duration - 0.5,
                   !self.isHandlingSongCompletion {
                    self.isHandlingSongCompletion = true
                    await self.onSongComplete()
                    self.isHandlingSongCompletion = false
                }
            }
        }
    }

    // NEW: Stop the playback observer
    private func stopPlaybackObserver() {
        playbackObserver?.invalidate()
        playbackObserver = nil
    }

    // NEW: Handle natural song completion
    private func onSongComplete() async {
        guard let nextSong = queuedNext else {
            // No queued song, clear playback state.
            isPlaying = false
            nowPlaying = nil
            playbackTime = 0
            duration = 0
            currentArtworkURL = nil
            currentSongTitle = ""
            currentArtistName = ""
            stopPlaybackObserver()
            return
        }

        do {
            try await startPlayback(nextSong)
            queuedNext = nil
            isPlaying = true
            print("✅ Auto-played queued song: \(nextSong.title)")
        } catch {
            print("⚠️ Failed to play queued song: \(error). Trying alternatives...")
            if let alternative = try? await findPlayableAlternative(for: nextSong) {
                try? await startPlayback(alternative)
                queuedNext = nil
                isPlaying = true
                print("✅ Auto-played alternative queued song: \(alternative.title)")
            } else {
                // Keep queued song so the game can continue waiting or user can retry skip.
                queuedNext = nextSong
                nowPlaying = nil
                isPlaying = false
                stopPlaybackObserver()
            }
        }
    }

    // Update published metadata for UI
    private func updateSongMetadata(_ song: Song) {
        currentSongTitle = song.title
        currentArtistName = song.artistName
        // Get artwork URL at a good resolution for background
        if let artwork = song.artwork {
            currentArtworkURL = artwork.url(width: 800, height: 800)
        } else {
            currentArtworkURL = nil
        }
        print("🎨 Artwork URL: \(currentArtworkURL?.absoluteString ?? "none")")
    }

    /// Skip to the next queued song immediately
    func skipToNext() async {
        guard let nextSong = queuedNext else {
            print("⏭️ No queued song to skip to")
            return
        }

        print("⏭️ Skipping to next song: \(nextSong.title)")

        // Stop current playback
        player.stop()
        isHandlingSongCompletion = false

        do {
            try await startPlayback(nextSong)
            queuedNext = nil
            isPlaying = true
            print("✅ Now playing: \(nextSong.title)")
            startPlaybackObserver()
        } catch {
            print("⚠️ Failed to play next song: \(error). Trying alternatives...")
            if let alternative = try? await findPlayableAlternative(for: nextSong) {
                do {
                    try await startPlayback(alternative)
                    queuedNext = nil
                    isPlaying = true
                    print("✅ Now playing alternative: \(alternative.title)")
                    startPlaybackObserver()
                } catch {
                    print("❌ Failed to play alternative next song: \(error)")
                    queuedNext = nextSong
                    nowPlaying = nil
                    isPlaying = false
                    stopPlaybackObserver()
                }
            } else {
                print("❌ No playable alternatives found for queued song")
                queuedNext = nextSong
                nowPlaying = nil
                isPlaying = false
                stopPlaybackObserver()
            }
        }
    }

    private func findPlayableAlternative(for song: Song) async throws -> Song? {
        let candidates = try await SongLookupService.findCandidateSongsByMetadata(
            title: song.title,
            artist: song.artistName,
            limit: 15
        )
        return candidates.first(where: { $0.id.rawValue != song.id.rawValue })
    }

    func pause() {
        player.pause()
        isPlaying = false
        stopPlaybackObserver()
    }

    func resume() async throws {
        try await player.play()
        isPlaying = true
        if nowPlaying != nil {
            startPlaybackObserver()
        }
    }

    func stop() {
        player.stop()
        isHandlingSongCompletion = false
        isPlaying = false
        nowPlaying = nil
        queuedNext = nil
        playbackTime = 0
        duration = 0
        currentArtworkURL = nil
        currentSongTitle = ""
        currentArtistName = ""
        stopPlaybackObserver()
    }
}

enum SongLookupService {
    static func findSong(
        isrc: String,
        songTitle: String?,
        artistName: String?,
        includeDemoFallback: Bool
    ) async throws -> Song {
        print("🔍 Looking up song with ID/ISRC: \(isrc)")

        // First, try direct lookup by Apple Music ID (numeric string)
        if isrc.allSatisfy({ $0.isNumber }) {
            do {
                let musicItemID = MusicItemID(isrc)
                var request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: musicItemID)
                request.limit = 1

                let response = try await request.response()
                print("🔍 Direct ID lookup returned \(response.items.count) results")

                if let song = response.items.first {
                    print("✅ Found via Apple Music ID: \(song.title) by \(song.artistName)")
                    return song
                }
            } catch {
                print("⚠️ Direct ID lookup failed: \(error), trying ISRC search...")
            }
        }

        // Try ISRC search (for real ISRCs like "USUG12000523")
        if !isrc.hasPrefix("ITUNES-") && !isrc.allSatisfy({ $0.isNumber }) {
            do {
                var request = MusicCatalogResourceRequest<Song>(matching: \.isrc, equalTo: isrc)
                request.limit = 1

                let response = try await request.response()
                print("🔍 ISRC search returned \(response.items.count) results")

                if let song = response.items.first {
                    print("✅ Found via ISRC: \(song.title) by \(song.artistName)")
                    return song
                }
            } catch {
                print("⚠️ ISRC search failed: \(error), trying term search...")
            }
        }

        var searchTerm: String?
        if let title = songTitle, let artist = artistName, !title.isEmpty, !artist.isEmpty {
            searchTerm = "\(title) \(artist)"
            print("🔍 Using stored song metadata for search: \(searchTerm!)")
        } else if let title = songTitle, !title.isEmpty {
            searchTerm = title
            print("🔍 Using stored song title for search: \(searchTerm!)")
        } else if includeDemoFallback {
            searchTerm = fallbackSearchTerm(for: isrc)
            print("🔍 Using hardcoded fallback search: \(searchTerm!)")
        }

        guard let searchTerm else {
            print("❌ No song metadata available for lookup")
            throw MusicKitError.noResults
        }

        let songs = try await searchSongsByTerm(searchTerm)
        guard let song = selectBestSong(from: songs, preferredTitle: songTitle, preferredArtist: artistName) else {
            print("❌ No song found")
            throw MusicKitError.noResults
        }

        print("✅ Found via term: \(song.title) by \(song.artistName)")
        return song
    }

    static func findSongByMetadata(title: String, artist: String) async throws -> Song {
        let term = "\(title) \(artist)"
        let songs = try await searchSongsByTerm(term)
        guard let song = selectBestSong(from: songs, preferredTitle: title, preferredArtist: artist) else {
            throw MusicKitError.noResults
        }
        return song
    }

    static func findCandidateSongsByMetadata(title: String, artist: String, limit: Int = 15) async throws -> [Song] {
        let term = "\(title) \(artist)"
        var termRequest = MusicCatalogSearchRequest(term: term, types: [Song.self])
        termRequest.limit = limit
        let termResponse = try await termRequest.response()
        let songs = Array(termResponse.songs)

        // Rank by match quality (title+artist proximity) and return all candidates.
        let normalizedTitle = normalize(title)
        let normalizedArtist = normalize(artist)

        return songs.sorted { lhs, rhs in
            score(lhs, normalizedTitle: normalizedTitle, normalizedArtist: normalizedArtist) >
            score(rhs, normalizedTitle: normalizedTitle, normalizedArtist: normalizedArtist)
        }
    }

    private static func searchSongsByTerm(_ term: String) async throws -> [Song] {
        var termRequest = MusicCatalogSearchRequest(term: term, types: [Song.self])
        termRequest.limit = 10
        let termResponse = try await termRequest.response()
        print("🔍 Term search returned \(termResponse.songs.count) results")
        return Array(termResponse.songs)
    }

    private static func selectBestSong(
        from songs: [Song],
        preferredTitle: String?,
        preferredArtist: String?
    ) -> Song? {
        guard !songs.isEmpty else { return nil }
        guard let preferredTitle, let preferredArtist else { return songs.first }

        let normalizedTitle = normalize(preferredTitle)
        let normalizedArtist = normalize(preferredArtist)

        // Prefer exact title+artist match first, then partial matches.
        if let exact = songs.first(where: {
            normalize($0.title) == normalizedTitle && normalize($0.artistName) == normalizedArtist
        }) {
            return exact
        }

        if let partial = songs.first(where: {
            normalize($0.title).contains(normalizedTitle) && normalize($0.artistName).contains(normalizedArtist)
        }) {
            return partial
        }

        return songs.first
    }

    private static func score(_ song: Song, normalizedTitle: String, normalizedArtist: String) -> Int {
        let title = normalize(song.title)
        let artist = normalize(song.artistName)
        var value = 0
        if title == normalizedTitle { value += 100 }
        if artist == normalizedArtist { value += 100 }
        if title.contains(normalizedTitle) { value += 30 }
        if artist.contains(normalizedArtist) { value += 30 }
        return value
    }

    private static func normalize(_ value: String) -> String {
        value
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func fallbackSearchTerm(for isrc: String) -> String {
        // Map known legacy/demo ISRCs to search terms as a final fallback.
        let mapping: [String: String] = [
            "USUG12000523": "Blinding Lights The Weeknd",
            "GBAHS1600463": "Shape of You Ed Sheeran",
            "GBARL1401524": "Uptown Funk Bruno Mars",
            "GBUM71029604": "Bohemian Rhapsody Queen",
            "GBAYE7300017": "Money Pink Floyd",
            "GBAYE0601498": "Hey Jude Beatles"
        ]
        return mapping[isrc] ?? "popular music"
    }
}

enum MusicKitError: LocalizedError {
    case unauthorized
    case noResults
    case playbackFailed

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Apple Music access is required to play songs."
        case .noResults:
            return "Could not find the song in Apple Music."
        case .playbackFailed:
            return "Failed to play the song."
        }
    }
}
