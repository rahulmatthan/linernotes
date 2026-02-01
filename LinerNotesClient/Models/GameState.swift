import Foundation

enum GamePhase {
    case notStarted
    case playing
    case completed
    case paused
}

struct GameState {
    let treasureHunt: TreasureHunt
    var currentLinkIndex: Int
    var solvedLinks: Set<Int>
    var phase: GamePhase
    var startTime: Date?
    var completionTime: Date?

    var currentLink: ChainLink? {
        guard currentLinkIndex >= 0 && currentLinkIndex < treasureHunt.links.count else {
            return nil
        }
        return treasureHunt.links[currentLinkIndex]
    }

    var previousLink: ChainLink? {
        guard currentLinkIndex > 0 && currentLinkIndex <= treasureHunt.links.count else {
            return nil
        }
        return treasureHunt.links[currentLinkIndex - 1]
    }

    var progress: Double {
        guard !treasureHunt.links.isEmpty else { return 0 }
        return Double(solvedLinks.count) / Double(treasureHunt.links.count)
    }

    var isComplete: Bool {
        solvedLinks.count == treasureHunt.links.count
    }

    init(treasureHunt: TreasureHunt) {
        self.treasureHunt = treasureHunt
        self.currentLinkIndex = 0
        self.solvedLinks = []
        self.phase = .notStarted
    }

    mutating func startGame() {
        phase = .playing
        startTime = Date()
    }

    mutating func solveCurrentLink() {
        solvedLinks.insert(currentLinkIndex)

        if isComplete {
            phase = .completed
            completionTime = Date()
        } else {
            currentLinkIndex += 1
        }
    }

    var totalTime: TimeInterval? {
        guard let start = startTime else { return nil }
        let end = completionTime ?? Date()
        return end.timeIntervalSince(start)
    }
}
