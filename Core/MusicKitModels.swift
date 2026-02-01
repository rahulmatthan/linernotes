import Foundation
#if canImport(MusicKit)
import MusicKit

struct SongSearchResult: Identifiable {
    let id: String
    let title: String
    let artistName: String
    let albumTitle: String
    let isrc: String?
    let artworkURL: URL?

    init(id: String, title: String, artistName: String, albumTitle: String, isrc: String?, artworkURL: URL?) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.isrc = isrc
        self.artworkURL = artworkURL
    }
}

@available(macOS 14.0, *)
extension SongSearchResult {
    init(from song: Song) {
        self.id = song.id.rawValue
        self.title = song.title
        self.artistName = song.artistName
        self.albumTitle = song.albumTitle ?? ""
        self.isrc = song.isrc
        self.artworkURL = song.artwork?.url(width: 600, height: 600)
    }
}
#endif
