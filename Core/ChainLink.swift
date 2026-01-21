import Foundation

struct ChainLink: Identifiable, Codable {
    let id: UUID
    let clue: String
    let hint: String
    let correctArtist: [String]
    let isrc: String

    init(
        id: UUID = UUID(),
        clue: String,
        hint: String,
        correctArtist: [String],
        isrc: String
    ) {
        self.id = id
        self.clue = clue
        self.hint = hint
        self.correctArtist = correctArtist
        self.isrc = isrc
    }
}

extension ChainLink {
    static let example = ChainLink(
        clue: "This 1973 album took you to the dark side",
        hint: "Think lunar and progressive",
        correctArtist: ["Pink Floyd"],
        isrc: "GBAYE7300017"
    )
}
