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

    // Onboarding
    @Published var showingOnboarding: Bool = true
    @Published var onboardingPhase: Int = 0  // 0=welcome, 1=instructions, 2=done

    // Hint system - automatic progression
    @Published var hintLevel: HintLevel = .none
    @Published var secondsUntilAutoHint: Int = 45
    @Published var secondsUntilAutoMC: Int = 15  // Starts after hint1 for first song

    // Track if this is the first song (affects MC timing)
    @Published var isFirstSong: Bool = true

    // Track if we're waiting for queued song to start before showing next clue
    @Published var waitingForNextSong: Bool = false
    @Published var solvedCurrentClue: Bool = false

    // Fade transition
    @Published var showFadeToBlack: Bool = false

    // Hard mode - no multiple choice hints (moved to settings, kept for compatibility)
    @Published var hardMode: Bool = false

    // Playback progress for UI
    @Published var playbackProgress: Double = 0
    @Published var secondsUntilNextClue: Int = 0
    @Published var isNearEndOfSong: Bool = false

    // Song info display
    @Published var showingCorrectMessage: Bool = false  // "That is correct" text
    @Published var showingSongInfo: Bool = false        // Full info overlay
    @Published var showingSongStartInfo: Bool = false   // Shown when queued song starts playing
    @Published var transitionPause: Bool = false        // Hides clue during overlay transitions
    @Published var currentAlbumArtData: Data? = nil

    // Solved clue info (stored when answer is correct, shown in info overlay)
    @Published var solvedClueText: String = ""
    @Published var solvedAnswerText: String = ""

    // Song start info (shown when song starts after being queued)
    @Published var currentSongStartInfo: String = ""

    // Queued song info (waiting for current song to finish)
    private var queuedClueText: String = ""
    private var queuedAnswerText: String = ""
    private var queuedSongStartInfo: String = ""
    private var queuedAlbumArtData: Data? = nil

    // Trivia for display while waiting
    @Published var queuedTrivia: [String] = []
    @Published var currentTriviaIndex: Int = 0
    private var triviaTimer: Timer?

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
    let playlistService = PlaylistService()
    private var autoHintTimer: Timer?
    private var autoMCTimer: Timer?
    private var songAwareMCTimer: Timer?
    private var songObserver: Task<Void, Never>?
    private var onboardingTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    private var savedProgressToRestore: SavedProgress?

    // Hunt file ID for per-hunt progress storage
    private let huntFileId: String

    /// Check if the currently playing song has been added to the playlist
    var currentSongAddedToPlaylist: Bool {
        guard let nowPlaying = musicPlayer.nowPlaying else { return false }
        return playlistService.hasBeenAdded(nowPlaying)
    }

    /// Add the currently playing song to the playlist
    func addCurrentSongToPlaylist() async {
        guard let nowPlaying = musicPlayer.nowPlaying else { return }
        await playlistService.addSongToPlaylist(nowPlaying)
    }

    init(treasureHunt: TreasureHunt, savedProgress: SavedProgress? = nil, huntFileId: String? = nil, skipOnboarding: Bool = false) {
        self.gameState = GameState(treasureHunt: treasureHunt)
        self.savedProgressToRestore = savedProgress
        self.huntFileId = huntFileId ?? treasureHunt.name
        // Show onboarding unless explicitly skipped (when handled by ContentView)
        self.showingOnboarding = !skipOnboarding

        // Set hunt name for playlist service
        playlistService.setCurrentHunt(name: treasureHunt.name)

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

        // Restore saved progress if available
        if let savedProgress = savedProgressToRestore {
            restoreProgress(from: savedProgress)
            savedProgressToRestore = nil
        }

        // Run onboarding sequence (always shown on every launch)
        if showingOnboarding {
            onboardingTask = Task { @MainActor in
                await runOnboardingSequence()
            }
        } else {
            // Skip to first clue
            onboardingPhase = 2
            startAutoHintTimer()
        }
    }

    // MARK: - Onboarding

    private func runOnboardingSequence() async {
        // Phase 0: Welcome screen (5 seconds)
        onboardingPhase = 0
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        guard !Task.isCancelled else { return }

        // Phase 1: Instructions screen (5 seconds) - smooth transition via animation
        onboardingPhase = 1
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        guard !Task.isCancelled else { return }

        // Onboarding complete
        showingOnboarding = false

        // Phase 2: First clue
        onboardingPhase = 2
        startAutoHintTimer()
    }

    // MARK: - Automatic Hint System

    private func startAutoHintTimer() {
        // Reset hint state
        hintLevel = .none
        secondsUntilAutoHint = 45
        secondsUntilAutoMC = 15

        // Stop any existing timers
        stopAllHintTimers()

        print("⏱️ Starting auto hint timer - hint1 in 45 seconds")

        // Start countdown timer for hint1
        autoHintTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor in
                if self.secondsUntilAutoHint > 0 {
                    self.secondsUntilAutoHint -= 1
                } else {
                    print("⏱️ Auto hint triggered - showing hint1")
                    self.hintLevel = .hint1
                    self.autoHintTimer?.invalidate()
                    self.autoHintTimer = nil

                    // For first song, start MC timer (15s after hint1 = 30s total)
                    if self.isFirstSong {
                        self.startAutoMCTimerForFirstSong()
                    } else {
                        // For subsequent songs, MC is tied to song duration
                        self.startSongAwareMCTimer()
                    }
                }
            }
        }
    }

    private func startAutoMCTimerForFirstSong() {
        secondsUntilAutoMC = 15
        print("⏱️ Starting auto MC timer for first song - MC in 15 seconds")

        autoMCTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor in
                if self.secondsUntilAutoMC > 0 {
                    self.secondsUntilAutoMC -= 1
                } else {
                    print("⏱️ Auto MC triggered - showing multiple choice")
                    if !self.hardMode {
                        self.hintLevel = .multipleChoice
                    }
                    self.autoMCTimer?.invalidate()
                    self.autoMCTimer = nil
                }
            }
        }
    }

    private func startSongAwareMCTimer() {
        print("⏱️ Starting song-aware MC timer - MC when 10s remain")

        songAwareMCTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor in
                let duration = self.musicPlayer.duration
                let currentTime = self.musicPlayer.playbackTime
                let remaining = duration - currentTime

                // Trigger MC when 10 seconds or less remain
                if duration > 0 && remaining <= 10 && self.hintLevel == .hint1 {
                    print("⏱️ Song-aware MC triggered - \(Int(remaining))s remaining")
                    if !self.hardMode {
                        self.hintLevel = .multipleChoice
                    }
                    self.songAwareMCTimer?.invalidate()
                    self.songAwareMCTimer = nil
                }
            }
        }
    }

    private func stopAllHintTimers() {
        autoHintTimer?.invalidate()
        autoHintTimer = nil
        autoMCTimer?.invalidate()
        autoMCTimer = nil
        songAwareMCTimer?.invalidate()
        songAwareMCTimer = nil
    }

    func toggleHardMode() {
        hardMode.toggle()
        // If turning on hard mode while MC is showing, revert to hint1
        if hardMode && hintLevel == .multipleChoice {
            hintLevel = .hint1
        }
    }

    /// Skip onboarding and jump to first clue
    func skipOnboarding() {
        // Cancel the onboarding sequence task
        onboardingTask?.cancel()
        onboardingTask = nil

        // Jump to first clue
        showingOnboarding = false
        onboardingPhase = 2
        startAutoHintTimer()
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
            let answerText = currentLink.answerText ?? ""
            let songStartInfo = currentLink.songStartInfo ?? ""
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

            // STEP 5: Set up next state BEFORE hiding correct message (prevents flash of old clue)
            if songAlreadyPlaying {
                // STEP 4a: Wait 7 seconds for correct message
                try? await Task.sleep(nanoseconds: 7_000_000_000)

                // Song was queued - set up trivia state first
                print("🎮 Song queued - waiting for it to start playing")
                queuedClueText = clueText
                queuedAnswerText = answerText
                queuedSongStartInfo = songStartInfo
                queuedAlbumArtData = albumArtData

                // Populate trivia from the PREVIOUS song (currently playing), not the queued one
                populateTriviaFromCurrentlyPlayingSong()
                startTriviaTimer()

                // Now transition: hide correct message, show trivia (crossfade via animation)
                waitingForNextSong = true
                showingCorrectMessage = false

                startObservingQueuedSong()
            } else {
                // STEP 4b: Wait 7 seconds for first song correct message
                try? await Task.sleep(nanoseconds: 7_000_000_000)

                // First song - show song start info first
                print("🎮 First song - showing song start info")
                startPlaybackUITimer()

                // Hide correct message, pause 1 second (transitionPause keeps clue hidden)
                transitionPause = true
                showingCorrectMessage = false
                try? await Task.sleep(nanoseconds: 1_000_000_000)

                // Transition to song start info (if available)
                if !songStartInfo.isEmpty {
                    currentSongStartInfo = songStartInfo
                    showingSongStartInfo = true
                    transitionPause = false

                    // Wait 7 seconds for song start info
                    try? await Task.sleep(nanoseconds: 7_000_000_000)

                    // Hide song start info, pause 1 second before next clue
                    transitionPause = true
                    showingSongStartInfo = false
                    currentSongStartInfo = ""
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    transitionPause = false

                    // Transition to next clue
                    advanceToNextClue()
                } else {
                    // No song start info - go directly to next clue
                    transitionPause = false
                    advanceToNextClue()
                }
            }
        } else {
            // Show error overlay
            showingError = true
            currentAnswer = ""

            // Auto-dismiss after 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            showingError = false
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
                    print("🎮 Queued song started playing")

                    // Reset progress-related state
                    secondsUntilNextClue = 0
                    isNearEndOfSong = false

                    // Update album art to the new song
                    currentAlbumArtData = queuedAlbumArtData

                    // Stop trivia timer
                    stopTriviaTimer()

                    // Transition: Set next state BEFORE clearing previous (prevents clue flash)
                    if !queuedSongStartInfo.isEmpty {
                        // Show song start info - crossfade from trivia
                        print("🎮 Showing song start info for 7 seconds")
                        currentSongStartInfo = queuedSongStartInfo
                        showingSongStartInfo = true
                        waitingForNextSong = false

                        // Wait 7 seconds for display
                        try? await Task.sleep(nanoseconds: 7_000_000_000)
                        if Task.isCancelled { return }

                        // Hide song start info, pause 1 second before next clue
                        transitionPause = true
                        showingSongStartInfo = false
                        currentSongStartInfo = ""
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        if Task.isCancelled { return }
                        transitionPause = false
                    } else {
                        // No song start info - go directly to next clue
                        waitingForNextSong = false
                    }

                    // Clear queued info
                    queuedClueText = ""
                    queuedAnswerText = ""
                    queuedSongStartInfo = ""
                    queuedAlbumArtData = nil

                    // Advance to next clue
                    advanceToNextClue()
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

    // MARK: - Trivia Display

    /// Populates trivia from the currently playing song (the previous link)
    /// This is called when a new song is queued, so trivia shows for what's playing now
    private func populateTriviaFromCurrentlyPlayingSong() {
        // The currently playing song is from the previous link (currentLinkIndex - 1)
        // because currentLinkIndex points to the clue the user just solved (queued song)
        let previousIndex = gameState.currentLinkIndex - 1
        guard previousIndex >= 0 else {
            queuedTrivia = []
            currentTriviaIndex = 0
            return
        }

        let previousLink = gameState.treasureHunt.links[previousIndex]
        // Use the triviaItems array, filtering out empty items
        queuedTrivia = previousLink.triviaItems.filter { !$0.isEmpty }
        currentTriviaIndex = 0
        print("📖 Loaded \(queuedTrivia.count) trivia items for currently playing song (link \(previousIndex + 1))")
    }

    private func startTriviaTimer() {
        triviaTimer?.invalidate()
        guard !queuedTrivia.isEmpty else { return }

        // Cycle through trivia every 10 seconds
        triviaTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if !self.queuedTrivia.isEmpty {
                    self.currentTriviaIndex = (self.currentTriviaIndex + 1) % self.queuedTrivia.count
                    print("📖 Showing trivia \(self.currentTriviaIndex + 1) of \(self.queuedTrivia.count)")
                }
            }
        }
    }

    private func stopTriviaTimer() {
        triviaTimer?.invalidate()
        triviaTimer = nil
        queuedTrivia = []
        currentTriviaIndex = 0
    }

    private func advanceToNextClue() {
        gameState.solveCurrentLink()
        solvedCurrentClue = false
        isFirstSong = false  // After first song, subsequent songs use song-aware MC timing

        if gameState.isComplete {
            // Game completed - clear saved progress
            SavedProgress.clear(for: huntFileId)
            print("🏆 Game completed - progress cleared for '\(huntFileId)'")
        } else {
            // Save progress after solving each clue
            saveProgress()
            startAutoHintTimer()
        }
    }

    // MARK: - Progress Persistence

    /// Save current game progress to UserDefaults
    func saveProgress() {
        SavedProgress.save(from: gameState, huntFileId: huntFileId)
    }

    /// Restore game state from saved progress
    func restoreProgress(from savedProgress: SavedProgress) {
        gameState.currentLinkIndex = savedProgress.currentLinkIndex
        gameState.solvedLinks = Set(savedProgress.solvedLinks)
        gameState.startTime = savedProgress.startTime
        gameState.phase = .playing
        isFirstSong = savedProgress.currentLinkIndex == 0
        print("🔄 Restored progress to clue \(savedProgress.currentLinkIndex + 1)")
    }

    private func showSongInfoOverlayThenAdvance(skipShowingSongInfo: Bool = false) {
        // Cancel any existing dismiss task
        songInfoDismissTask?.cancel()

        if !skipShowingSongInfo {
            showingSongInfo = true
        }

        // Check if this is the last clue
        let isLastClue = gameState.currentLinkIndex == gameState.treasureHunt.links.count - 1

        // Show overlay for 7 seconds, then fade out and advance to next clue
        songInfoDismissTask = Task { @MainActor in
            // Show song info overlay for 7 seconds
            try? await Task.sleep(nanoseconds: 7_000_000_000)
            if Task.isCancelled { return }

            // Hide overlay and advance - animations handle the crossfade
            showingSongInfo = false
            solvedCurrentClue = false

            if isLastClue {
                // This was the last song - show completion screen
                advanceToNextClue() // Mark as complete
                showingCompletionScreen = true
            } else {
                // More clues to go - next clue will fade in via animation
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

    /// Skip to the next queued song immediately
    func skipToNextSong() async {
        guard waitingForNextSong else { return }

        print("⏭️ User requested skip to next song")

        // Skip the current song in the player
        await musicPlayer.skipToNext()
    }

    func endGame() {
        // Save progress before closing if game is not complete
        if !gameState.isComplete {
            saveProgress()
        }

        musicPlayer.stop()
        stopAllHintTimers()
        songObserver?.cancel()
        songObserver = nil
        stopPlaybackUITimer()
        stopTriviaTimer()
    }

    var progressText: String {
        "\(gameState.solvedLinks.count) / \(gameState.treasureHunt.links.count)"
    }

    var currentLinkNumber: Int {
        gameState.currentLinkIndex + 1
    }

    var currentTriviaText: String? {
        guard !queuedTrivia.isEmpty, currentTriviaIndex < queuedTrivia.count else { return nil }
        return queuedTrivia[currentTriviaIndex]
    }
}
