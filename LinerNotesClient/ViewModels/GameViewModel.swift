import Foundation
import SwiftUI
import Combine

@available(iOS 15.0, *)
@MainActor
class GameViewModel: ObservableObject {
    private enum HintConfig {
        static let autoHintSeconds = 45
        static let mcDelayAfterHintSeconds = 60
        static let nearSongEndMCSeconds = 10
        static let queuedTextFadeWindowSeconds = 10
    }

    private enum Timing {
        static let onboardingPhase: UInt64 = 5_000_000_000
        static let correctMessage: UInt64 = 10_000_000_000
        static let finalCelebration: UInt64 = 5_000_000_000
        static let transitionPause: UInt64 = 1_000_000_000
        static let errorDismiss: UInt64 = 2_000_000_000
        static let observerPoll: UInt64 = 500_000_000
        static let playbackUITick: TimeInterval = 0.5
        static let hintTick: TimeInterval = 1.0
        static let songAwareMCTick: TimeInterval = 0.5
        static let triviaTick: TimeInterval = 10.0
        static let songStartInfoInitialDelay: UInt64 = 2_000_000_000
        static let fadeOutDuration: UInt64 = 800_000_000
    }

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
    @Published var secondsUntilAutoHint: Int = HintConfig.autoHintSeconds
    @Published var secondsUntilAutoMC: Int = HintConfig.mcDelayAfterHintSeconds  // Starts after hint1

    // Track if this is the first song (affects MC timing)
    @Published var isFirstSong: Bool = true

    // Track if we're waiting for queued song to start before showing next clue
    @Published var waitingForNextSong: Bool = false
    @Published var solvedCurrentClue: Bool = false

    // Fade transition
    @Published var showFadeToBlack: Bool = false

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
    private var isFinalQueuedTransition: Bool = false

    // Trivia for display while waiting
    @Published var queuedTrivia: [String] = []
    @Published var currentTriviaIndex: Int = 0
    private var triviaTimer: Timer?

    // Completion state - only show after last song finishes
    @Published var showingCompletionScreen: Bool = false
    @Published var completionMessage: String = "Congratulations! You've completed this hunt."
    @Published var showingPostQuestTrivia: Bool = false
    @Published var shouldAutoClose: Bool = false
    @Published var showingFinalCelebration: Bool = false

    // MusicKit metadata (observed from player)
    @Published var currentArtworkURL: URL? = nil
    @Published var currentSongTitle: String = ""
    @Published var currentArtistName: String = ""
    @Published var isSongPlaying: Bool = false

    private var playbackUITimer: Timer?

    private let musicPlayer = MusicKitPlayerService()
    let playlistService = PlaylistService()
    private var autoHintTimer: Timer?
    private var autoMCTimer: Timer?
    private var songAwareMCTimer: Timer?
    private var songObserver: Task<Void, Never>?
    private var onboardingTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var hintShownAt: Date?

    private var savedProgressToRestore: SavedProgress?

    // Hunt file ID for per-hunt progress storage
    private let huntFileId: String

    private func sleep(_ nanoseconds: UInt64) async {
        try? await Task.sleep(nanoseconds: nanoseconds)
    }

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

    /// Track if the entire hunt has been added to playlist
    @Published var huntAddedToPlaylist: Bool = false

    /// Add all songs from the hunt to the playlist
    func addEntireHuntToPlaylist() async {
        let links = gameState.treasureHunt.links
        let songInfos = links.map { link in
            (isrc: link.isrc, songTitle: link.songTitle, artistName: link.artistName)
        }

        let addedCount = await playlistService.addSongsToPlaylist(songInfos)
        if addedCount == links.count {
            huntAddedToPlaylist = true
        }
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

        // Observe actual playback state
        musicPlayer.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                self?.isSongPlaying = isPlaying
            }
            .store(in: &cancellables)
    }

    func startGame() async {
        gameState.startGame()
        completionMessage = "Congratulations! You've completed this hunt."
        showingPostQuestTrivia = false
        showingFinalCelebration = false
        isFinalQueuedTransition = false
        shouldAutoClose = false
        showFadeToBlack = false

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
        await sleep(Timing.onboardingPhase)
        guard !Task.isCancelled else { return }

        // Phase 1: Instructions screen (5 seconds) - smooth transition via animation
        onboardingPhase = 1
        await sleep(Timing.onboardingPhase)
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
        secondsUntilAutoHint = HintConfig.autoHintSeconds
        secondsUntilAutoMC = HintConfig.mcDelayAfterHintSeconds
        hintShownAt = nil

        // Stop any existing timers
        stopAllHintTimers()

        print("⏱️ Starting auto hint timer - hint1 in 45 seconds")

        // Start countdown timer for hint1
        autoHintTimer = Timer.scheduledTimer(withTimeInterval: Timing.hintTick, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor in
                if self.secondsUntilAutoHint > 0 {
                    self.secondsUntilAutoHint -= 1
                } else {
                    print("⏱️ Auto hint triggered - showing hint1")
                    self.hintLevel = .hint1
                    self.hintShownAt = Date()
                    self.autoHintTimer?.invalidate()
                    self.autoHintTimer = nil

                    // For first song, MC appears 60 seconds after hint.
                    if self.isFirstSong {
                        self.startAutoMCTimerForFirstSong()
                    } else {
                        // For subsequent songs, MC appears 60s after hint but no later than
                        // 10s before the current song ends.
                        self.startSongAwareMCTimer()
                    }
                }
            }
        }
    }

    private func startAutoMCTimerForFirstSong() {
        secondsUntilAutoMC = HintConfig.mcDelayAfterHintSeconds
        print("⏱️ Starting auto MC timer for first song - MC in 60 seconds")

        autoMCTimer = Timer.scheduledTimer(withTimeInterval: Timing.hintTick, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor in
                if self.secondsUntilAutoMC > 0 {
                    self.secondsUntilAutoMC -= 1
                } else {
                    print("⏱️ Auto MC triggered - showing multiple choice")
                    self.hintLevel = .multipleChoice
                    self.autoMCTimer?.invalidate()
                    self.autoMCTimer = nil
                }
            }
        }
    }

    private func startSongAwareMCTimer() {
        print("⏱️ Starting song-aware MC timer - MC in 60s after hint or by 10s before song end")
        if hintShownAt == nil {
            hintShownAt = Date()
        }

        songAwareMCTimer = Timer.scheduledTimer(withTimeInterval: Timing.songAwareMCTick, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor in
                let elapsed = Date().timeIntervalSince(self.hintShownAt ?? Date())
                let secondsUntilDelayTarget = Double(HintConfig.mcDelayAfterHintSeconds) - elapsed
                let duration = self.musicPlayer.duration
                let currentTime = self.musicPlayer.playbackTime
                let remaining = duration - currentTime
                let secondsUntilSongCap = remaining - Double(HintConfig.nearSongEndMCSeconds)

                let secondsUntilTrigger: Double
                if duration > 0 {
                    secondsUntilTrigger = min(secondsUntilDelayTarget, secondsUntilSongCap)
                } else {
                    // Fallback if duration is unavailable.
                    secondsUntilTrigger = secondsUntilDelayTarget
                }

                self.secondsUntilAutoMC = max(0, Int(ceil(secondsUntilTrigger)))

                // Trigger at +60s from hint, or earlier if needed to avoid passing the
                // "10 seconds before song end" deadline.
                if secondsUntilTrigger <= 0 && self.hintLevel == .hint1 {
                    print("⏱️ Song-aware MC triggered")
                    self.hintLevel = .multipleChoice
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

    func revealNextHintStage() {
        switch hintLevel {
        case .none:
            hintLevel = .hint1
            hintShownAt = Date()
            autoHintTimer?.invalidate()
            autoHintTimer = nil

            if isFirstSong {
                startAutoMCTimerForFirstSong()
            } else {
                startSongAwareMCTimer()
            }
        case .hint1, .hint2:
            hintLevel = .multipleChoice
            autoMCTimer?.invalidate()
            autoMCTimer = nil
            songAwareMCTimer?.invalidate()
            songAwareMCTimer = nil
            secondsUntilAutoMC = 0
        case .multipleChoice:
            break
        }
    }

    var canRevealNextHintStage: Bool {
        hintLevel != .multipleChoice && !gameState.isComplete && !waitingForNextSong
    }

    var hintButtonTitle: String {
        switch hintLevel {
        case .none:
            return "Hint"
        case .hint1, .hint2:
            return "Choices"
        case .multipleChoice:
            return "Shown"
        }
    }

    var hintButtonIconName: String {
        switch hintLevel {
        case .none:
            return "lightbulb"
        case .hint1, .hint2:
            return "list.bullet.circle"
        case .multipleChoice:
            return "checkmark.circle"
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
            await handleCorrectAnswer(for: currentLink)
            return
        }

        await handleIncorrectAnswer()
    }

    private func handleCorrectAnswer(for currentLink: ChainLink) async {
        currentAnswer = ""
        solvedCurrentClue = true

        let clueText = currentLink.clue
        let answerText = currentLink.answerText ?? ""
        let songStartInfo = currentLink.songStartInfo ?? ""
        let albumArtData = currentLink.albumArtData
        let isLastSong = gameState.currentLinkIndex == gameState.treasureHunt.links.count - 1
        let songAlreadyPlaying = musicPlayer.nowPlaying != nil

        if !songAlreadyPlaying {
            currentAlbumArtData = albumArtData
        }

        showingCorrectMessage = true
        await playReward(for: currentLink)

        if isLastSong {
            if songAlreadyPlaying {
                await handleQueuedSongTransition(
                    clueText: clueText,
                    answerText: answerText,
                    songStartInfo: songStartInfo,
                    albumArtData: albumArtData,
                    isFinalTransition: true
                )
            } else {
                await handleLastSongStartTransition(songStartInfo: songStartInfo)
            }
            return
        }

        if songAlreadyPlaying {
            await handleQueuedSongTransition(
                clueText: clueText,
                answerText: answerText,
                songStartInfo: songStartInfo,
                albumArtData: albumArtData,
                isFinalTransition: false
            )
        } else {
            await handleFirstSongTransition(songStartInfo: songStartInfo)
        }
    }

    private func playReward(for link: ChainLink) async {
        do {
            print("🎮 Attempting to play song with ISRC: \(link.isrc), title: \(link.songTitle ?? "nil"), artist: \(link.artistName ?? "nil")")
            try await musicPlayer.playReward(
                isrc: link.isrc,
                songTitle: link.songTitle,
                artistName: link.artistName
            )
            print("🎮 playReward completed successfully")
        } catch {
            print("❌ Error playing song: \(error)")
        }
    }

    private func handleLastSongStartTransition(songStartInfo: String) async {
        await sleep(Timing.correctMessage)

        showingCorrectMessage = false
        transitionPause = true
        await sleep(Timing.songStartInfoInitialDelay)

        if !songStartInfo.isEmpty {
            currentSongStartInfo = songStartInfo
            showingSongStartInfo = true
            transitionPause = false
            await sleep(Timing.correctMessage)
            transitionPause = true
            showingSongStartInfo = false
            currentSongStartInfo = ""
            await sleep(Timing.transitionPause)
        }

        transitionPause = false
        let completedLinkIndex = gameState.currentLinkIndex
        advanceToNextClue()
        await showFinalCelebration()
        enterPostQuestTriviaMode(songIndex: completedLinkIndex)
    }

    private func handleQueuedSongTransition(
        clueText: String,
        answerText: String,
        songStartInfo: String,
        albumArtData: Data?,
        isFinalTransition: Bool
    ) async {
        await sleep(Timing.correctMessage)

        print("🎮 Song queued - waiting for it to start playing")
        queuedClueText = clueText
        queuedAnswerText = answerText
        queuedSongStartInfo = songStartInfo
        queuedAlbumArtData = albumArtData
        isFinalQueuedTransition = isFinalTransition

        populateTriviaFromCurrentlyPlayingSong()
        startTriviaTimer()
        waitingForNextSong = true
        showingPostQuestTrivia = false
        showingCorrectMessage = false
        startObservingQueuedSong()
    }

    private func handleFirstSongTransition(songStartInfo: String) async {
        await sleep(Timing.correctMessage)

        print("🎮 First song - showing song start info")
        startPlaybackUITimer()

        transitionPause = true
        showingCorrectMessage = false
        await sleep(Timing.transitionPause)

        if !songStartInfo.isEmpty {
            currentSongStartInfo = songStartInfo
            showingSongStartInfo = true
            transitionPause = false

            await sleep(Timing.correctMessage)

            transitionPause = true
            showingSongStartInfo = false
            currentSongStartInfo = ""
            await sleep(Timing.transitionPause)
            transitionPause = false
            advanceToNextClue()
            return
        }

        transitionPause = false
        advanceToNextClue()
    }

    private func handleIncorrectAnswer() async {
        showingError = true
        currentAnswer = ""
        await sleep(Timing.errorDismiss)
        showingError = false
    }

    private func startObservingQueuedSong() {
        songObserver?.cancel()

        // Start UI update timer for progress bar
        startPlaybackUITimer()

        songObserver = Task { @MainActor in
            // Poll until the queued song becomes the now playing song
            while waitingForNextSong && !Task.isCancelled {
                await sleep(Timing.observerPoll) // Check every 0.5s

                // Song has started only when queue is cleared and player is active.
                if musicPlayer.queuedNext == nil && musicPlayer.isPlaying && waitingForNextSong {
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
                        // Hide text during handoff, then wait 2s before showing song info.
                        transitionPause = true
                        waitingForNextSong = false
                        await sleep(Timing.songStartInfoInitialDelay)
                        if Task.isCancelled { return }

                        print("🎮 Showing song start info for 7 seconds")
                        currentSongStartInfo = queuedSongStartInfo
                        showingSongStartInfo = true
                        transitionPause = false

                        // Wait 7 seconds for display
                        await sleep(Timing.correctMessage)
                        if Task.isCancelled { return }

                        // Hide song start info, pause 1 second before next clue
                        transitionPause = true
                        showingSongStartInfo = false
                        currentSongStartInfo = ""
                        await sleep(Timing.transitionPause)
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

                    if self.isFinalQueuedTransition {
                        let completedLinkIndex = self.gameState.currentLinkIndex
                        self.advanceToNextClue()
                        await self.showFinalCelebration()
                        self.enterPostQuestTriviaMode(songIndex: completedLinkIndex)
                        self.isFinalQueuedTransition = false
                    } else {
                        // Advance to next clue
                        advanceToNextClue()
                    }
                    break
                }
            }
        }
    }

    private func startPlaybackUITimer() {
        playbackUITimer?.invalidate()
        playbackUITimer = Timer.scheduledTimer(withTimeInterval: Timing.playbackUITick, repeats: true) { [weak self] _ in
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
        isNearEndOfSong = waitingForNextSong && secondsUntilNextClue <= HintConfig.nearSongEndMCSeconds && secondsUntilNextClue > 0
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

    private func populateTriviaForLink(at index: Int) {
        guard gameState.treasureHunt.links.indices.contains(index) else {
            queuedTrivia = []
            currentTriviaIndex = 0
            return
        }

        let link = gameState.treasureHunt.links[index]
        queuedTrivia = link.triviaItems.filter { !$0.isEmpty }
        currentTriviaIndex = 0
        print("📖 Loaded \(queuedTrivia.count) trivia items for link \(index + 1)")
    }

    private func enterPostQuestTriviaMode(songIndex: Int) {
        completionMessage = "Congratulations. You have now reached the end of your quest"
        showingCompletionScreen = false
        waitingForNextSong = false
        showingFinalCelebration = false
        showingPostQuestTrivia = true
        shouldAutoClose = false
        showFadeToBlack = false
        populateTriviaForLink(at: songIndex)
        startTriviaTimer()
        startPlaybackUITimer()
        startObservingPostQuestSongEnd()
    }

    private func showFinalCelebration() async {
        showingFinalCelebration = true
        await sleep(Timing.finalCelebration)
        showingFinalCelebration = false
    }

    private func startObservingPostQuestSongEnd() {
        songObserver?.cancel()

        songObserver = Task { @MainActor in
            var hasSeenPlayback = musicPlayer.isPlaying

            while showingPostQuestTrivia && !Task.isCancelled {
                await sleep(Timing.observerPoll)

                if musicPlayer.isPlaying {
                    hasSeenPlayback = true
                }

                if hasSeenPlayback && !musicPlayer.isPlaying {
                    showingPostQuestTrivia = false
                    stopTriviaTimer()
                    stopPlaybackUITimer()

                    // Wait 2 seconds after song end, then fade and return to hunt selection.
                    await sleep(Timing.songStartInfoInitialDelay)
                    if Task.isCancelled { return }

                    showFadeToBlack = true
                    await sleep(Timing.fadeOutDuration)
                    if Task.isCancelled { return }

                    shouldAutoClose = true
                    break
                }
            }
        }
    }

    private func startTriviaTimer() {
        triviaTimer?.invalidate()
        guard !queuedTrivia.isEmpty else { return }

        // Cycle through trivia every 10 seconds
        triviaTimer = Timer.scheduledTimer(withTimeInterval: Timing.triviaTick, repeats: true) { [weak self] _ in
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
            // Game completed - save as complete so it shows in hunt selection
            saveProgress()
            print("🏆 Game completed - progress saved as complete for '\(huntFileId)'")
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
        showingPostQuestTrivia = false
        showingFinalCelebration = false
        isFinalQueuedTransition = false
        shouldAutoClose = false
        showFadeToBlack = false
        print("🔄 Restored progress to clue \(savedProgress.currentLinkIndex + 1)")
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
        showingPostQuestTrivia = false
        showingFinalCelebration = false
        isFinalQueuedTransition = false
        shouldAutoClose = false
        showFadeToBlack = false
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

    var queuedTextOpacity: Double {
        guard waitingForNextSong else { return 1.0 }

        if isFinalQueuedTransition {
            let fadeStart = 10
            let fadeEnd = 2
            if secondsUntilNextClue >= fadeStart { return 1.0 }
            if secondsUntilNextClue <= fadeEnd { return 0.0 }
            return Double(secondsUntilNextClue - fadeEnd) / Double(fadeStart - fadeEnd)
        }

        let fadeStart = HintConfig.queuedTextFadeWindowSeconds
        if secondsUntilNextClue >= fadeStart { return 1.0 }
        if secondsUntilNextClue <= 0 { return 0.0 }
        return Double(secondsUntilNextClue) / Double(fadeStart)
    }

    var displayedClueText: String {
        return gameState.currentLink?.clue ?? ""
    }

    var displayedHint1: String {
        return gameState.currentLink?.hint1 ?? ""
    }

    var displayedHint2: String? {
        return gameState.currentLink?.hint2
    }

    var displayedMultipleChoiceOptions: [String] {
        return gameState.currentLink?.multipleChoiceOptions ?? ["", "", "", ""]
    }

    var shouldShowPlayableClue: Bool {
        !gameState.isComplete && gameState.currentLink != nil
    }
}
