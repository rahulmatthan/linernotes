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
        let song = try await findSong(isrc: isrc, songTitle: songTitle, artistName: artistName)
        print("✅ Found song: \(song.title) by \(song.artistName)")

        if nowPlaying == nil {
            // No song playing, start immediately
            print("🎵 Starting playback...")
            nowPlaying = song
            duration = song.duration ?? 0
            updateSongMetadata(song)
            player.queue = [song]
            try await player.play()
            print("✅ Playback started!")
            isPlaying = true
            startPlaybackObserver()
        } else {
            // Song playing, queue for next
            print("🎵 Queueing song for next...")
            queuedNext = song
        }
    }

    // NEW: Start observing playback position
    private func startPlaybackObserver() {
        stopPlaybackObserver() // Stop any existing observer

        playbackObserver = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor in
                // Update playback time
                self.playbackTime = self.player.playbackTime

                // Check if song finished
                if self.playbackTime >= self.duration - 0.5 && self.duration > 0 {
                    await self.onSongComplete()
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
            // No queued song, just stop
            isPlaying = false
            stopPlaybackObserver()
            return
        }

        // Play the queued song
        nowPlaying = nextSong
        queuedNext = nil
        duration = nextSong.duration ?? 0
        playbackTime = 0
        updateSongMetadata(nextSong)

        player.queue = [nextSong]
        do {
            try await player.play()
            isPlaying = true
        } catch {
            print("Failed to play queued song: \(error)")
            isPlaying = false
            stopPlaybackObserver()
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

    private func findSong(isrc: String, songTitle: String?, artistName: String?) async throws -> Song {
        print("🔍 Looking up song with ID/ISRC: \(isrc)")

        // First, try direct lookup by Apple Music ID (numeric string)
        // The "isrc" field now contains the Apple Music song ID from iTunes API
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

        // Fallback: search using song title and artist name
        var searchTerm: String
        if let title = songTitle, let artist = artistName, !title.isEmpty, !artist.isEmpty {
            searchTerm = "\(title) \(artist)"
            print("🔍 Using stored song metadata for search: \(searchTerm)")
        } else if let title = songTitle, !title.isEmpty {
            searchTerm = title
            print("🔍 Using stored song title for search: \(searchTerm)")
        } else {
            // Last resort: try hardcoded mapping (for demo data)
            searchTerm = isrcToSearchTerm(isrc)
            print("🔍 Using hardcoded fallback search: \(searchTerm)")
        }

        var termRequest = MusicCatalogSearchRequest(term: searchTerm, types: [Song.self])
        termRequest.limit = 1

        let termResponse = try await termRequest.response()
        print("🔍 Term search returned \(termResponse.songs.count) results")

        guard let song = termResponse.songs.first else {
            print("❌ No song found")
            throw MusicKitError.noResults
        }

        print("✅ Found via term: \(song.title) by \(song.artistName)")
        return song
    }

    private func isrcToSearchTerm(_ isrc: String) -> String {
        // Map known ISRCs to search terms as fallback (for demo/legacy data)
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
