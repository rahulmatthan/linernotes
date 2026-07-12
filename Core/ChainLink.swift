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
    var answerText: String?     // Shown in "Correct" overlay when clue is solved
    var songStartInfo: String?  // Shown when this song starts playing (after queued)
    var triviaItems: [String]   // Up to 10 trivia items shown while waiting
    var albumArtData: Data?

    // Character Limits
    static let maxClueLength = 300
    static let maxHint1Length = 150
    static let maxHint2Length = 150
    static let maxMCOptionLength = 50
    static let maxAnswerTextLength = 300
    static let maxSongStartInfoLength = 300
    static let maxTriviaItemLength = 200
    static let maxTriviaItems = 10

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
        answerText: String? = nil,
        songStartInfo: String? = nil,
        triviaItems: [String] = [],
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
        self.answerText = answerText
        self.songStartInfo = songStartInfo
        self.triviaItems = triviaItems
        self.albumArtData = albumArtData
    }

    // Character limit validation
    var isWithinCharacterLimits: Bool {
        let basicLimits = clue.count <= Self.maxClueLength &&
            hint1.count <= Self.maxHint1Length &&
            (hint2 == nil || hint2!.count <= Self.maxHint2Length) &&
            multipleChoiceOptions.allSatisfy { $0.count <= Self.maxMCOptionLength }

        let infoLimits = (answerText == nil || answerText!.count <= Self.maxAnswerTextLength) &&
            (songStartInfo == nil || songStartInfo!.count <= Self.maxSongStartInfoLength)

        let triviaLimits = triviaItems.count <= Self.maxTriviaItems &&
            triviaItems.allSatisfy { $0.count <= Self.maxTriviaItemLength }

        return basicLimits && infoLimits && triviaLimits
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
        if let answerText = answerText, answerText.count > Self.maxAnswerTextLength {
            warnings.append("Answer text exceeds \(Self.maxAnswerTextLength) characters")
        }
        if let songStartInfo = songStartInfo, songStartInfo.count > Self.maxSongStartInfoLength {
            warnings.append("Song start info exceeds \(Self.maxSongStartInfoLength) characters")
        }
        if triviaItems.count > Self.maxTriviaItems {
            warnings.append("Too many trivia items (max \(Self.maxTriviaItems))")
        }
        for (index, trivia) in triviaItems.enumerated() where trivia.count > Self.maxTriviaItemLength {
            warnings.append("Trivia \(index + 1) exceeds \(Self.maxTriviaItemLength) characters")
        }
        return warnings
    }

    /// Minimum requirements for the game engine to function correctly.
    /// Used by the client for runtime validation.
    var isValid: Bool {
        let trimmedClue = clue.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedISRC = isrc.trimmingCharacters(in: .whitespacesAndNewlines)

        return !trimmedClue.isEmpty &&
        !trimmedISRC.isEmpty &&
        !correctAnswers.isEmpty &&
        multipleChoiceOptions.count == 4 &&
        multipleChoiceOptions.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } &&
        isWithinCharacterLimits
    }

    /// Stricter definition of completion used by the admin app to drive
    /// the overall hunt completion percentage.
    ///
    /// A link is considered "authoring complete" only when:
    /// - Clue and primary hint are filled
    /// - MC options and correct answers are filled
    /// - ISRC is set
    /// - Answer text and song start info are provided
    /// - At least one non-empty trivia item exists (within limits)
    var isAuthoringComplete: Bool {
        let trimmedClue = clue.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHint1 = hint1.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedISRC = isrc.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAnswerText = answerText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedSongStartInfo = songStartInfo?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let hasRequiredTrivia = !triviaItems.isEmpty &&
        triviaItems.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        return !trimmedClue.isEmpty &&
        !trimmedHint1.isEmpty &&
        !trimmedISRC.isEmpty &&
        !correctAnswers.isEmpty &&
        multipleChoiceOptions.count == 4 &&
        multipleChoiceOptions.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } &&
        !trimmedAnswerText.isEmpty &&
        !trimmedSongStartInfo.isEmpty &&
        hasRequiredTrivia &&
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
        case answerText
        case songStartInfo
        case triviaItems
        case albumArtData
        // Old keys for backward compatibility
        case hint
        case correctArtist
        case songInfoText     // Old name for answerText
        case triviaText1      // Old trivia format
        case triviaText2
        case triviaText3
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

        // Migration: songInfoText → answerText
        if let newAnswerText = try? container.decodeIfPresent(String.self, forKey: .answerText) {
            answerText = newAnswerText
        } else {
            answerText = try container.decodeIfPresent(String.self, forKey: .songInfoText)
        }

        songStartInfo = try container.decodeIfPresent(String.self, forKey: .songStartInfo)

        // Migration: triviaText1/2/3 → triviaItems array
        if let newTriviaItems = try? container.decode([String].self, forKey: .triviaItems) {
            triviaItems = newTriviaItems
        } else {
            var items: [String] = []
            if let t1 = (try? container.decodeIfPresent(String.self, forKey: .triviaText1)) ?? nil, !t1.isEmpty {
                items.append(t1)
            }
            if let t2 = (try? container.decodeIfPresent(String.self, forKey: .triviaText2)) ?? nil, !t2.isEmpty {
                items.append(t2)
            }
            if let t3 = (try? container.decodeIfPresent(String.self, forKey: .triviaText3)) ?? nil, !t3.isEmpty {
                items.append(t3)
            }
            triviaItems = items
        }
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
        try container.encodeIfPresent(answerText, forKey: .answerText)
        try container.encodeIfPresent(songStartInfo, forKey: .songStartInfo)
        try container.encode(triviaItems, forKey: .triviaItems)
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
        answerText: "Dark Side of the Moon spent 937 weeks on the Billboard 200 chart.",
        songStartInfo: "Now playing one of the most iconic songs from this legendary album.",
        triviaItems: [
            "The album's iconic prism artwork was designed by Storm Thorgerson.",
            "The heartbeat sound that opens the album was recorded at 100 BPM."
        ]
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
            answerText: nil,
            songStartInfo: nil,
            triviaItems: [],
            albumArtData: nil
        )
    }
}
