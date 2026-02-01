import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

struct ChainLink: Identifiable, Codable, Equatable {
    let id: UUID

    // Question & Hints
    var clue: String
    var hint1: String
    var hint2: String?
    var multipleChoiceOptions: [String]

    // Answers
    var correctAnswers: [String]

    // Song Metadata
    var isrc: String
    var songTitle: String?      // For search fallback when ISRC unavailable
    var artistName: String?     // For search fallback when ISRC unavailable
    var songInfoText: String?
    var albumArtData: Data?

    // Character Limits
    static let maxClueLength = 200
    static let maxHint1Length = 150
    static let maxHint2Length = 150
    static let maxMCOptionLength = 50
    static let maxSongInfoLength = 300

    init(
        id: UUID = UUID(),
        clue: String,
        hint1: String,
        hint2: String? = nil,
        multipleChoiceOptions: [String] = ["", "", "", ""],
        correctAnswers: [String],
        isrc: String,
        songTitle: String? = nil,
        artistName: String? = nil,
        songInfoText: String? = nil,
        albumArtData: Data? = nil
    ) {
        self.id = id
        self.clue = clue
        self.hint1 = hint1
        self.hint2 = hint2
        self.multipleChoiceOptions = multipleChoiceOptions
        self.correctAnswers = correctAnswers
        self.isrc = isrc
        self.songTitle = songTitle
        self.artistName = artistName
        self.songInfoText = songInfoText
        self.albumArtData = albumArtData
    }

    // Character limit validation
    var isWithinCharacterLimits: Bool {
        clue.count <= Self.maxClueLength &&
        hint1.count <= Self.maxHint1Length &&
        (hint2 == nil || hint2!.count <= Self.maxHint2Length) &&
        multipleChoiceOptions.allSatisfy { $0.count <= Self.maxMCOptionLength } &&
        (songInfoText == nil || songInfoText!.count <= Self.maxSongInfoLength)
    }

    // Character limit warnings (for Admin UI)
    var characterLimitWarnings: [String] {
        var warnings: [String] = []
        if clue.count > Self.maxClueLength {
            warnings.append("Clue exceeds \(Self.maxClueLength) characters")
        }
        if hint1.count > Self.maxHint1Length {
            warnings.append("Hint 1 exceeds \(Self.maxHint1Length) characters")
        }
        if let hint2 = hint2, hint2.count > Self.maxHint2Length {
            warnings.append("Hint 2 exceeds \(Self.maxHint2Length) characters")
        }
        for (index, option) in multipleChoiceOptions.enumerated() where option.count > Self.maxMCOptionLength {
            warnings.append("MC Option \(["A","B","C","D"][index]) exceeds \(Self.maxMCOptionLength) characters")
        }
        if let songInfo = songInfoText, songInfo.count > Self.maxSongInfoLength {
            warnings.append("Song info exceeds \(Self.maxSongInfoLength) characters")
        }
        return warnings
    }

    var isValid: Bool {
        !clue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isrc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !correctAnswers.isEmpty &&
        multipleChoiceOptions.count == 4 &&
        multipleChoiceOptions.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } &&
        isWithinCharacterLimits
    }

    #if canImport(AppKit)
    var albumArtImage: NSImage? {
        guard let data = albumArtData else { return nil }
        return NSImage(data: data)
    }
    #elseif canImport(UIKit)
    var albumArtImage: UIImage? {
        guard let data = albumArtData else { return nil }
        return UIImage(data: data)
    }
    #endif

    // MARK: - Migration Support

    enum CodingKeys: String, CodingKey {
        case id
        case clue
        case hint1
        case hint2
        case multipleChoiceOptions
        case correctAnswers
        case isrc
        case songTitle
        case artistName
        case songInfoText
        case albumArtData
        // Old keys for backward compatibility
        case hint
        case correctArtist
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        clue = try container.decode(String.self, forKey: .clue)
        isrc = try container.decode(String.self, forKey: .isrc)
        albumArtData = try container.decodeIfPresent(Data.self, forKey: .albumArtData)

        // Migration: hint → hint1
        if let oldHint = try? container.decode(String.self, forKey: .hint) {
            hint1 = oldHint
            hint2 = nil
        } else {
            hint1 = try container.decode(String.self, forKey: .hint1)
            hint2 = try container.decodeIfPresent(String.self, forKey: .hint2)
        }

        // Migration: correctArtist → correctAnswers
        if let oldArtist = try? container.decode([String].self, forKey: .correctArtist) {
            correctAnswers = oldArtist
        } else {
            correctAnswers = try container.decode([String].self, forKey: .correctAnswers)
        }

        // New fields with defaults for old files
        multipleChoiceOptions = (try? container.decode([String].self, forKey: .multipleChoiceOptions)) ?? ["", "", "", ""]
        songTitle = try container.decodeIfPresent(String.self, forKey: .songTitle)
        artistName = try container.decodeIfPresent(String.self, forKey: .artistName)
        songInfoText = try container.decodeIfPresent(String.self, forKey: .songInfoText)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(clue, forKey: .clue)
        try container.encode(hint1, forKey: .hint1)
        try container.encodeIfPresent(hint2, forKey: .hint2)
        try container.encode(multipleChoiceOptions, forKey: .multipleChoiceOptions)
        try container.encode(correctAnswers, forKey: .correctAnswers)
        try container.encode(isrc, forKey: .isrc)
        try container.encodeIfPresent(songTitle, forKey: .songTitle)
        try container.encodeIfPresent(artistName, forKey: .artistName)
        try container.encodeIfPresent(songInfoText, forKey: .songInfoText)
        try container.encodeIfPresent(albumArtData, forKey: .albumArtData)
    }
}

extension ChainLink {
    static let example = ChainLink(
        clue: "This 1973 album took you to the dark side",
        hint1: "Think lunar and progressive",
        hint2: "The band is known for elaborate concept albums",
        multipleChoiceOptions: ["Pink Floyd", "Led Zeppelin", "The Beatles", "The Rolling Stones"],
        correctAnswers: ["Pink Floyd", "pink floyd"],
        isrc: "GBAYE7300017",
        songInfoText: "Dark Side of the Moon spent 937 weeks on the Billboard 200 chart."
    )

    static var empty: ChainLink {
        ChainLink(
            clue: "",
            hint1: "",
            hint2: nil,
            multipleChoiceOptions: ["", "", "", ""],
            correctAnswers: [],
            isrc: "",
            songTitle: nil,
            artistName: nil,
            songInfoText: nil,
            albumArtData: nil
        )
    }
}
