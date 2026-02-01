import Foundation
import SwiftUI
import Combine

@available(iOS 15.0, *)
@MainActor
class GameViewModel: ObservableObject {
    @Published var gameState: GameState
    @Published var currentAnswer: String = ""
    @Published var showingError: Bool = false
    @Published var errorMessage: String = ""
    @Published var showingHint: Bool = false
    @Published var isCheckingAnswer: Bool = false

    // Hint system
    @Published var hintLevel: HintLevel = .none
    @Published var hintTimerActive: Bool = false
    @Published var secondsUntilHint: Int = 60

    // Track if we're waiting for queued song to start before showing next clue
    @Published var waitingForNextSong: Bool = false
    @Published var solvedCurrentClue: Bool = false

    // Hard mode - no multiple choice hints
    @Published var hardMode: Bool = false

    // Playback progress for UI
    @Published var playbackProgress: Double = 0
    @Published var secondsUntilNextClue: Int = 0
    @Published var isNearEndOfSong: Bool = false

    // Song info display
    @Published var showingCorrectMessage: Bool = false  // "That is correct" text
    @Published var showingSongInfo: Bool = false        // Full info overlay
    @Published var currentAlbumArtData: Data? = nil

    // Solved clue info (stored when answer is correct, shown in info overlay)
    @Published var solvedClueText: String = ""
    @Published var solvedSongInfoText: String = ""

    // Queued song info (waiting for current song to finish)
    private var queuedClueText: String = ""
    private var queuedSongInfoText: String = ""
    private var queuedAlbumArtData: Data? = nil

    // Completion state - only show after last song finishes
    @Published var showingCompletionScreen: Bool = false

    // MusicKit metadata (observed from player)
    @Published var currentArtworkURL: URL? = nil
    @Published var currentSongTitle: String = ""
    @Published var currentArtistName: String = ""
    @Published var isSongPlaying: Bool = false

    private var playbackUITimer: Timer?
    private var songInfoDismissTask: Task<Void, Never>?

    private let musicPlayer = MusicKitPlayerService()
    private var hintTimer: Timer?
    private var songObserver: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(treasureHunt: TreasureHunt) {
        self.gameState = GameState(treasureHunt: treasureHunt)
        setupMusicPlayerObservers()
    }

    private func setupMusicPlayerObservers() {
        // Observe artwork URL changes
        musicPlayer.$currentArtworkURL
            .receive(on: DispatchQueue.main)
            .sink { [weak self] url in
                self?.currentArtworkURL = url
            }
            .store(in: &cancellables)

        // Observe song title changes
        musicPlayer.$currentSongTitle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] title in
                self?.currentSongTitle = title
            }
            .store(in: &cancellables)

        // Observe artist name changes
        musicPlayer.$currentArtistName
            .receive(on: DispatchQueue.main)
            .sink { [weak self] artist in
                self?.currentArtistName = artist
            }
            .store(in: &cancellables)

        // Observe now playing changes
        musicPlayer.$nowPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] song in
                self?.isSongPlaying = song != nil
            }
            .store(in: &cancellables)
    }

    func startGame() async {
        gameState.startGame()

        let authorized = await musicPlayer.requestAuthorization()
        guard authorized else {
            errorMessage = "Apple Music access is required to play the game."
            showingError = true
            return
        }

        // NEW FLOW: No music plays at start, user sees first clue
        startHintTimer()
    }

    private func startHintTimer() {
        // Reset hint state
        hintLevel = .none
        hintTimerActive = false
        secondsUntilHint = 60

        // Stop any existing timer
        hintTimer?.invalidate()

        print("⏱️ Starting hint timer at \(secondsUntilHint) seconds")

        // Start countdown timer
        hintTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor in
                if self.secondsUntilHint > 0 {
                    self.secondsUntilHint -= 1
                    if self.secondsUntilHint % 10 == 0 {
                        print("⏱️ Hint timer: \(self.secondsUntilHint)s remaining")
                    }
                } else {
                    print("⏱️ Hint timer complete - hints now available!")
                    self.hintTimerActive = true
                    self.hintTimer?.invalidate()
                    self.hintTimer = nil
                }
            }
        }
    }

    func requestHint() {
        guard hintTimerActive else { return }

        switch hintLevel {
        case .none:
            hintLevel = .hint1
        case .hint1:
            if !hardMode {
                hintLevel = .multipleChoice  // Skip hint2, go straight to MC
            }
            // In hard mode, hint1 is the max level
        case .hint2, .multipleChoice:
            break // Already at max hint level
        }
    }

    func toggleHardMode() {
        hardMode.toggle()
        // If turning on hard mode while MC is showing, revert to hint1
        if hardMode && hintLevel == .multipleChoice {
            hintLevel = .hint1
        }
    }

    func selectMultipleChoiceOption(_ option: String) {
        currentAnswer = option
    }

    func submitAnswer() async {
        guard let currentLink = gameState.currentLink else { return }
        guard !solvedCurrentClue else { return } // Already solved, waiting for next song

        isCheckingAnswer = true
        defer { isCheckingAnswer = false }

        let isCorrect = FuzzyMatcher.matches(
            answer: currentAnswer,
            correctAnswers: currentLink.correctAnswers
        )

        if isCorrect {
            currentAnswer = ""
            solvedCurrentClue = true

            // Store the solved clue info
            let clueText = currentLink.clue
            let songInfoText = currentLink.songInfoText ?? ""
            let albumArtData = currentLink.albumArtData

            // Check if a song is already playing
            let songAlreadyPlaying = musicPlayer.nowPlaying != nil

            // STEP 1: Show album art IMMEDIATELY (for first song)
            if !songAlreadyPlaying {
                currentAlbumArtData = albumArtData
            }

            // STEP 2: Show "That is correct" immediately
            showingCorrectMessage = true

            // STEP 3: Play song as reward
            do {
                print("🎮 Attempting to play song with ISRC: \(currentLink.isrc), title: \(currentLink.songTitle ?? "nil"), artist: \(currentLink.artistName ?? "nil")")
                try await musicPlayer.playReward(
                    isrc: currentLink.isrc,
                    songTitle: currentLink.songTitle,
                    artistName: currentLink.artistName
                )
                print("🎮 playReward completed successfully")
            } catch {
                print("❌ Error playing song: \(error)")
            }

            // STEP 4: Wait 5 seconds then fade out "That is correct"
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            showingCorrectMessage = false

            // STEP 5: Show info overlay (or wait for queued song)
            if songAlreadyPlaying {
                // Song was queued - wait for it to start before showing info overlay
                print("🎮 Song queued - waiting for it to start playing")
                waitingForNextSong = true
                queuedClueText = clueText
                queuedSongInfoText = songInfoText
                queuedAlbumArtData = albumArtData
                startObservingQueuedSong()
                // Screen stays blank (just album art of current song) until queued song starts
            } else {
                // First song - show info overlay now
                print("🎮 First song - showing info overlay")
                solvedClueText = clueText
                solvedSongInfoText = songInfoText
                // Album art already set above
                // Start tracking playback progress for Now Playing bar
                startPlaybackUITimer()
                showSongInfoOverlayThenAdvance()
            }
        } else {
            errorMessage = "That's not quite right. Try again!"
            showingError = true

            try? await Task.sleep(nanoseconds: 500_000_000)
            currentAnswer = ""
        }
    }

    private func startObservingQueuedSong() {
        songObserver?.cancel()

        // Start UI update timer for progress bar
        startPlaybackUITimer()

        songObserver = Task { @MainActor in
            // Poll until the queued song becomes the now playing song
            while waitingForNextSong && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000) // Check every 0.5s

                // If queuedNext is nil and we were waiting, the song started
                if musicPlayer.queuedNext == nil && waitingForNextSong {
                    print("🎮 Queued song started playing - showing info overlay")
                    waitingForNextSong = false
                    // Don't stop the playback timer - keep tracking progress for Now Playing bar
                    // Reset progress-related state but keep timer running
                    secondsUntilNextClue = 0
                    isNearEndOfSong = false

                    // Update album art to the new song
                    currentAlbumArtData = queuedAlbumArtData

                    // Show info overlay for the song that just started
                    solvedClueText = queuedClueText
                    solvedSongInfoText = queuedSongInfoText

                    // Clear queued info
                    queuedClueText = ""
                    queuedSongInfoText = ""
                    queuedAlbumArtData = nil

                    showSongInfoOverlayThenAdvance()
                    break
                }
            }
        }
    }

    private func startPlaybackUITimer() {
        playbackUITimer?.invalidate()
        playbackUITimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updatePlaybackUI()
            }
        }
    }

    private func stopPlaybackUITimer() {
        playbackUITimer?.invalidate()
        playbackUITimer = nil
        playbackProgress = 0
        secondsUntilNextClue = 0
        isNearEndOfSong = false
    }

    private func updatePlaybackUI() {
        guard musicPlayer.duration > 0 else {
            playbackProgress = 0
            secondsUntilNextClue = 0
            isNearEndOfSong = false
            return
        }

        playbackProgress = musicPlayer.playbackTime / musicPlayer.duration
        let remaining = musicPlayer.duration - musicPlayer.playbackTime
        secondsUntilNextClue = max(0, Int(remaining))
        isNearEndOfSong = waitingForNextSong && secondsUntilNextClue <= 10 && secondsUntilNextClue > 0
    }

    private func advanceToNextClue() {
        gameState.solveCurrentLink()
        solvedCurrentClue = false

        if !gameState.isComplete {
            startHintTimer()
        }
    }

    private func showSongInfoOverlayThenAdvance() {
        // Cancel any existing dismiss task
        songInfoDismissTask?.cancel()

        showingSongInfo = true

        // Check if this is the last clue
        let isLastClue = gameState.currentLinkIndex == gameState.treasureHunt.links.count - 1

        // Show overlay for 30 seconds, then fade out, wait 5 seconds, then advance to next clue
        songInfoDismissTask = Task { @MainActor in
            // Show "That is correct" overlay for 30 seconds
            try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            if Task.isCancelled { return }

            // Fade out the overlay
            showingSongInfo = false

            // Wait 5 seconds before showing next clue or completion
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            if Task.isCancelled { return }

            solvedCurrentClue = false

            if isLastClue {
                // This was the last song - show completion screen
                advanceToNextClue() // Mark as complete
                showingCompletionScreen = true
            } else {
                // More clues to go
                advanceToNextClue()
            }
        }
    }

    func toggleHint() {
        showingHint.toggle()
    }

    func pauseGame() {
        musicPlayer.pause()
    }

    func resumeGame() async {
        try? await musicPlayer.resume()
    }

    func endGame() {
        musicPlayer.stop()
        hintTimer?.invalidate()
        hintTimer = nil
        songObserver?.cancel()
        songObserver = nil
        stopPlaybackUITimer()
    }

    var progressText: String {
        "\(gameState.solvedLinks.count) / \(gameState.treasureHunt.links.count)"
    }

    var currentLinkNumber: Int {
        gameState.currentLinkIndex + 1
    }
}
