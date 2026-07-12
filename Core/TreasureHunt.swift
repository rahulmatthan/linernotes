import Foundation

struct TreasureHunt: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var createdDate: Date
    var modifiedDate: Date
    var links: [ChainLink]
    var loopbackClue: LoopbackClue?
    var version: String

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        createdDate: Date = Date(),
        modifiedDate: Date = Date(),
        links: [ChainLink]? = nil,
        loopbackClue: LoopbackClue? = nil,
        version: String = "2.0"
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
        self.loopbackClue = loopbackClue
        self.version = version

        if let links = links {
            self.links = links
        } else {
            // Start with 1 empty link - table editor allows adding more
            self.links = [ChainLink.empty]
        }
    }

    /// A hunt is considered complete from an authoring perspective only when
    /// all links have their full content filled (clue, hints, answer text,
    /// song start info, trivia, etc.).
    var isComplete: Bool {
        !links.isEmpty && links.allSatisfy { $0.isAuthoringComplete }
    }

    var completionPercentage: Double {
        let total = links.count
        guard total > 0 else { return 0 }

        let completeLinks = links.filter { $0.isAuthoringComplete }.count
        return Double(completeLinks) / Double(total) * 100.0
    }
}

extension TreasureHunt {
    static var empty: TreasureHunt {
        TreasureHunt(
            name: "New Treasure Hunt",
            description: ""
        )
    }
}

struct LoopbackClue: Codable, Equatable {
    var clue: String
    var hint1: String
    var hint2: String?
    var multipleChoiceOptions: [String]
    var correctAnswers: [String]
    var answerText: String?
    var completionText: String?

    static let maxClueLength = 300
    static let maxHint1Length = 150
    static let maxHint2Length = 150
    static let maxMCOptionLength = 50
    static let maxAnswerTextLength = 300
    static let maxCompletionTextLength = 300

    var isValid: Bool {
        let trimmedClue = clue.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHint1 = hint1.trimmingCharacters(in: .whitespacesAndNewlines)

        return !trimmedClue.isEmpty &&
        !trimmedHint1.isEmpty &&
        !correctAnswers.isEmpty &&
        multipleChoiceOptions.count == 4 &&
        multipleChoiceOptions.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } &&
        clue.count <= Self.maxClueLength &&
        hint1.count <= Self.maxHint1Length &&
        (hint2 == nil || hint2!.count <= Self.maxHint2Length) &&
        multipleChoiceOptions.allSatisfy { $0.count <= Self.maxMCOptionLength } &&
        (answerText == nil || answerText!.count <= Self.maxAnswerTextLength) &&
        (completionText == nil || completionText!.count <= Self.maxCompletionTextLength)
    }

    static var empty: LoopbackClue {
        LoopbackClue(
            clue: "",
            hint1: "",
            hint2: nil,
            multipleChoiceOptions: ["", "", "", ""],
            correctAnswers: [],
            answerText: nil,
            completionText: nil
        )
    }
}
