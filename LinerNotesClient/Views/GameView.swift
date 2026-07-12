import SwiftUI

// MARK: - Design Constants
private enum Design {
    enum Mode {
        static let useRefinedTheme = true
    }

    // Typography scale - SF Pro Rounded
    enum Font {
        static let caption = SwiftUI.Font.system(size: 13, weight: .regular, design: .rounded)
        static let captionMedium = SwiftUI.Font.system(size: 13, weight: .medium, design: .rounded)
        static let body = SwiftUI.Font.system(size: 17, weight: .regular, design: .default)
        static let bodyMedium = SwiftUI.Font.system(size: 17, weight: .medium, design: .default)
        static let title3 = SwiftUI.Font.system(size: 19, weight: .regular, design: .default)
        static let title3Medium = SwiftUI.Font.system(size: 20, weight: .semibold, design: .serif)
        static let title2 = SwiftUI.Font.system(size: 22, weight: .semibold, design: .serif)
        static let title1 = SwiftUI.Font.system(size: 30, weight: .bold, design: .serif)
    }

    // Spacing scale
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    // Colors
    enum Colors {
        static let accent = Mode.useRefinedTheme
            ? Color(red: 0.94, green: 0.67, blue: 0.32)
            : Color(red: 1.0, green: 0.42, blue: 0.42)
        static let cardBackground = Mode.useRefinedTheme ? Color.black.opacity(0.62) : Color.black.opacity(0.8)
        static let inputBackground = Mode.useRefinedTheme ? Color.black.opacity(0.50) : Color.black.opacity(0.6)
        static let secondaryText = Mode.useRefinedTheme ? Color.white.opacity(0.82) : Color.white.opacity(0.7)
        static let tertiaryText = Mode.useRefinedTheme ? Color.white.opacity(0.62) : Color.white.opacity(0.5)
        static let border = Mode.useRefinedTheme ? Color.white.opacity(0.14) : Color.white.opacity(0.2)
    }

    // Radii
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
    }
}

struct GameView: View {
    let treasureHunt: TreasureHunt
    let savedProgress: SavedProgress?
    let huntFileId: String
    let skipOnboarding: Bool
    let onClose: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: GameViewModel

    init(treasureHunt: TreasureHunt, savedProgress: SavedProgress? = nil, huntFileId: String? = nil, skipOnboarding: Bool = false, onClose: (() -> Void)? = nil) {
        self.treasureHunt = treasureHunt
        self.savedProgress = savedProgress
        self.huntFileId = huntFileId ?? treasureHunt.name
        self.skipOnboarding = skipOnboarding
        self.onClose = onClose
        self._viewModel = StateObject(wrappedValue: GameViewModel(
            treasureHunt: treasureHunt,
            savedProgress: savedProgress,
            huntFileId: huntFileId ?? treasureHunt.name,
            skipOnboarding: skipOnboarding
        ))
    }

    private var brandMark: some View {
        Image("BrandRecord")
            .resizable()
            .scaledToFill()
            .frame(width: 52, height: 52)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 7, y: 3)
    }

    private func closeGame() {
        viewModel.endGame()
        if let onClose = onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    var body: some View {
        ZStack {
            // Background layers
            backgroundLayers

            // Onboarding screens
            if viewModel.showingOnboarding {
                onboardingScreen
            } else if viewModel.showingCompletionScreen {
                completionScreen
            } else if viewModel.shouldShowPlayableClue {
                gameScreen
            }

            // Overlays with smooth fade transitions
            if (viewModel.waitingForNextSong || viewModel.showingPostQuestTrivia) && !viewModel.showingOnboarding {
                queuedSongIndicator
                    .transition(.opacity.animation(.easeInOut(duration: 1.5)))
            }

            if viewModel.showingCorrectMessage && !viewModel.showingOnboarding {
                correctMessageOverlay
                    .transition(.opacity.animation(.easeInOut(duration: 1.5)))
            }

            if viewModel.showingSongStartInfo && !viewModel.showingOnboarding {
                songStartInfoOverlay
                    .transition(.opacity.animation(.easeInOut(duration: 1.5)))
            }

            if viewModel.showingFinalCelebration && !viewModel.showingOnboarding {
                finalCelebrationOverlay
                    .transition(.opacity.animation(.easeInOut(duration: 0.6)))
            }

            // Fade to black transition overlay
            if viewModel.showFadeToBlack {
                fadeToBlackOverlay
            }

            // Error overlay
            if viewModel.showingError {
                errorOverlay
                    .transition(.opacity.animation(.easeInOut(duration: 0.5)))
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .task {
            await viewModel.startGame()
        }
        .onChange(of: viewModel.shouldAutoClose) { shouldClose in
            if shouldClose {
                closeGame()
            }
        }
        .onAppear {
            updateIdleTimerState()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: viewModel.isSongPlaying) { _ in
            updateIdleTimerState()
        }
        .onChange(of: viewModel.waitingForNextSong) { _ in
            updateIdleTimerState()
        }
        .onChange(of: viewModel.queuedTrivia) { _ in
            updateIdleTimerState()
        }
    }

    private var shouldKeepScreenAwake: Bool {
        let isShowingTrivia = (viewModel.waitingForNextSong || viewModel.showingPostQuestTrivia) && !viewModel.queuedTrivia.isEmpty
        return viewModel.isSongPlaying && isShowingTrivia
    }

    private func updateIdleTimerState() {
        UIApplication.shared.isIdleTimerDisabled = shouldKeepScreenAwake
    }

    // MARK: - Background

    private var backgroundLayers: some View {
        GeometryReader { geometry in
            ZStack {
                // Consistent vinyl groove texture background
                VinylGrooveBackground()

                // Letterboxed album art (no blurred background)
                if let albumArtData = viewModel.currentAlbumArtData,
                   let uiImage = UIImage(data: albumArtData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: geometry.size.width - Design.Spacing.xxxl * 2, maxHeight: geometry.size.height * 0.45)
                        .cornerRadius(Design.Radius.sm)
                        .shadow(color: .black.opacity(0.6), radius: 24, y: 8)
                        .id(albumArtData.hashValue)
                } else if viewModel.isSongPlaying, let artworkURL = viewModel.currentArtworkURL {
                    AsyncImage(url: artworkURL) { phase in
                        if case .success(let image) = phase {
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: geometry.size.width - Design.Spacing.xxxl * 2, maxHeight: geometry.size.height * 0.45)
                                .cornerRadius(Design.Radius.sm)
                                .shadow(color: .black.opacity(0.6), radius: 24, y: 8)
                        }
                    }
                    .id(artworkURL)
                }
            }
            .animation(.easeOut(duration: 0.8), value: viewModel.currentAlbumArtData)
            .animation(.easeOut(duration: 0.8), value: viewModel.currentArtworkURL)
        }
        .ignoresSafeArea()
    }

    // MARK: - Onboarding Screens

    private var onboardingScreen: some View {
        Group {
            switch viewModel.onboardingPhase {
            case 0:
                onboardingWelcomeScreen
            case 1:
                onboardingInstructionsScreen
            default:
                EmptyView()
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.5), value: viewModel.onboardingPhase)
    }

    private var skipButton: some View {
        Button {
            viewModel.skipOnboarding()
        } label: {
            Text("Skip")
                .font(Design.Font.bodyMedium)
                .foregroundColor(Design.Colors.accent)
                .padding(.horizontal, Design.Spacing.lg)
                .padding(.vertical, Design.Spacing.sm)
                .background(Capsule().fill(Design.Colors.accent.opacity(0.15)))
        }
    }

    private var onboardingWelcomeScreen: some View {
        ZStack {
            VStack(spacing: Design.Spacing.xxxl) {
                Spacer()

                VStack(spacing: Design.Spacing.xl) {
                    if Design.Mode.useRefinedTheme {
                        brandMark
                    } else {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 64, weight: .light, design: .rounded))
                            .foregroundColor(Design.Colors.accent)
                    }

                    Text("Welcome")
                        .font(Design.Font.title1)
                        .foregroundColor(.white)
                }

                Text("This is Liner Notes, a curated musical journey where you discover the music trivia that connects songs and artists to each other in unexpected ways")
                    .font(Design.Font.body)
                    .foregroundColor(Design.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, Design.Spacing.xxxl)

                Spacer()
            }

            // Skip button in top-right corner
            VStack {
                HStack {
                    Spacer()
                    skipButton
                }
                .padding(.horizontal, Design.Spacing.xl)
                .padding(.top, Design.Spacing.md)
                Spacer()
            }
        }
    }

    private var addToPlaylistButton: some View {
        let isAdded = viewModel.currentSongAddedToPlaylist
        let isAdding = viewModel.playlistService.isAddingCurrentSong
        let hasFailed = viewModel.playlistService.playlistCreationFailed

        return Button {
            Task {
                await viewModel.addCurrentSongToPlaylist()
            }
        } label: {
            HStack(spacing: Design.Spacing.sm) {
                if isAdding {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(Design.Colors.accent)
                } else {
                    Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 18, weight: .regular, design: .rounded))
                        .foregroundColor(isAdded ? Design.Colors.accent : .white)
                }

                Text(isAdded ? "Added to Playlist" : "Add to Playlist")
                    .font(Design.Font.caption)
                    .foregroundColor(isAdded ? Design.Colors.accent : .white)
            }
            .padding(.horizontal, Design.Spacing.md)
            .padding(.vertical, Design.Spacing.sm)
            .background(
                Capsule()
                    .fill(isAdded ? Design.Colors.accent.opacity(0.15) : Design.Colors.accent.opacity(0.3))
            )
        }
        .disabled(isAdded || isAdding || hasFailed)
        .opacity(hasFailed ? 0.5 : 1.0)
    }

    private var onboardingInstructionsScreen: some View {
        ZStack {
            VStack(spacing: Design.Spacing.xxxl) {
                Spacer()

                VStack(spacing: Design.Spacing.xl) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 56, weight: .light, design: .rounded))
                        .foregroundColor(Design.Colors.accent)

                    Text("How to Play")
                        .font(Design.Font.title1)
                        .foregroundColor(.white)
                }

                Text("To start with you will get a clue that you need to solve to unlock the first song. Read the clue and type the answer in the text box to submit it. If you can't solve it you will get hints that will give you more information")
                    .font(Design.Font.body)
                    .foregroundColor(Design.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, Design.Spacing.xxxl)

                Spacer()
            }

            // Skip button in top-right corner
            VStack {
                HStack {
                    Spacer()
                    skipButton
                }
                .padding(.horizontal, Design.Spacing.xl)
                .padding(.top, Design.Spacing.md)
                Spacer()
            }
        }
    }

    // MARK: - Fade to Black Overlay

    private var fadeToBlackOverlay: some View {
        Color.black
            .ignoresSafeArea()
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.5), value: viewModel.showFadeToBlack)
    }

    // MARK: - Completion Screen

    private var completionScreen: some View {
        VStack(spacing: Design.Spacing.xxxl) {
            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 56, weight: .light, design: .rounded))
                .foregroundColor(Design.Colors.accent)

            VStack(spacing: Design.Spacing.md) {
                Text("You've reached the end")
                    .font(Design.Font.title1)
                    .foregroundColor(.white)

                Text(viewModel.completionMessage)
                    .font(Design.Font.body)
                    .foregroundColor(Design.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, Design.Spacing.xxxl)

            Spacer()

            VStack(spacing: Design.Spacing.lg) {
                // Add Hunt to Playlist button
                addHuntToPlaylistButton

                Button {
                    closeGame()
                } label: {
                    Text("Close")
                        .font(Design.Font.bodyMedium)
                        .foregroundColor(.black)
                        .frame(width: 200)
                        .padding(.vertical, Design.Spacing.lg)
                        .background(Design.Colors.accent)
                        .cornerRadius(Design.Radius.md)
                }
            }
            .padding(.bottom, 60)
        }
    }

    private var addHuntToPlaylistButton: some View {
        let isAdded = viewModel.huntAddedToPlaylist
        let isAdding = viewModel.playlistService.isAddingMultipleSongs
        let hasFailed = viewModel.playlistService.playlistCreationFailed
        let progress = viewModel.playlistService.addMultipleSongsProgress

        return Button {
            Task {
                await viewModel.addEntireHuntToPlaylist()
            }
        } label: {
            HStack(spacing: 8) {
                if isAdding {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Design.Colors.accent))
                        .scaleEffect(0.8)
                    Text("Adding \(progress.current)/\(progress.total)...")
                        .font(Design.Font.bodyMedium)
                        .foregroundColor(Design.Colors.accent)
                } else {
                    Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 16, weight: .medium))
                    Text(isAdded ? "Hunt Added to Playlist" : "Add Hunt to Playlist")
                        .font(Design.Font.captionMedium)
                }
            }
            .foregroundColor(isAdded ? .green : Design.Colors.accent)
            .frame(width: 200)
            .padding(.vertical, Design.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Design.Radius.md)
                    .stroke(isAdded ? Color.green : Design.Colors.accent, lineWidth: 2)
            )
        }
        .disabled(isAdded || isAdding || hasFailed)
        .opacity(hasFailed ? 0 : 1)
    }

    // MARK: - Game Screen

    private var gameScreen: some View {
        GeometryReader { geometry in
            ZStack {
                if viewModel.showingSongInfo {
                    songInfoOverlay(geometry: geometry)
                } else if viewModel.waitingForNextSong || viewModel.showingCorrectMessage || viewModel.showingSongStartInfo || viewModel.transitionPause {
                    // Just show close button while overlays are visible or during transition pauses
                    closeButtonHeader
                } else {
                    clueScreen(geometry: geometry)
                }
            }
            .animation(.easeInOut(duration: 1.5), value: viewModel.showingCorrectMessage)
            .animation(.easeInOut(duration: 1.5), value: viewModel.showingSongInfo)
            .animation(.easeInOut(duration: 1.5), value: viewModel.waitingForNextSong)
            .animation(.easeInOut(duration: 1.5), value: viewModel.showingSongStartInfo)
            .animation(.easeInOut(duration: 1.5), value: viewModel.transitionPause)
        }
    }

    // MARK: - Close Button Header

    private var closeButtonHeader: some View {
        VStack {
            HStack {
                closeButton
                Spacer()
            }
            .padding(.horizontal, Design.Spacing.xl)
            .padding(.top, Design.Spacing.md)
            Spacer()
        }
    }

    // MARK: - Dynamic Text

    private var clueHeaderText: String {
        return viewModel.isFirstSong ? "HERE IS YOUR FIRST CLUE" : "HERE IS THE CLUE TO UNLOCK THE NEXT SONG"
    }

    private var closeButton: some View {
        Button {
            closeGame()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.15))
                .clipShape(Circle())
        }
    }

    private var hintRevealButton: some View {
        Button {
            Task { @MainActor in
                viewModel.revealNextHintStage()
            }
        } label: {
            HStack(spacing: Design.Spacing.xs) {
                Image(systemName: viewModel.hintButtonIconName)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                Text(viewModel.hintButtonTitle)
                    .font(Design.Font.captionMedium)
            }
            .padding(.horizontal, Design.Spacing.md)
            .padding(.vertical, Design.Spacing.sm)
            .background(
                Capsule()
                    .fill(viewModel.canRevealNextHintStage ? Design.Colors.accent.opacity(0.22) : Color.white.opacity(0.1))
            )
            .foregroundColor(viewModel.canRevealNextHintStage ? Design.Colors.accent : .white.opacity(0.7))
        }
        .disabled(!viewModel.canRevealNextHintStage)
    }

    // MARK: - Song Info Overlay

    private func songInfoOverlay(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            HStack {
                closeButton
                Spacer()
            }
            .padding(.horizontal, Design.Spacing.xl)
            .padding(.top, Design.Spacing.md)
            .padding(.bottom, Design.Spacing.md)

            // Song info card (at top)
            VStack(spacing: Design.Spacing.lg) {
                // Song title and artist
                VStack(spacing: Design.Spacing.xs) {
                    Text(viewModel.currentSongTitle)
                        .font(Design.Font.title2)
                        .foregroundColor(Design.Colors.accent)
                        .multilineTextAlignment(.center)

                    Text(viewModel.currentArtistName)
                        .font(Design.Font.body)
                        .foregroundColor(Design.Colors.secondaryText)
                }

                // Answer text
                if !viewModel.solvedAnswerText.isEmpty {
                    Rectangle()
                        .fill(Design.Colors.border)
                        .frame(height: 1)

                    Text(viewModel.solvedAnswerText)
                        .font(Design.Font.body)
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(Design.Spacing.xxl)
            .frame(maxWidth: geometry.size.width - Design.Spacing.xxxl)
            .background(
                RoundedRectangle(cornerRadius: Design.Radius.lg)
                    .fill(Design.Colors.cardBackground)
            )

            Spacer()
        }
        .transition(.opacity)
    }

    // MARK: - Clue Screen

    private func clueScreen(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Header - close + hint reveal button
            HStack(alignment: .center) {
                closeButton
                Spacer()
                hintRevealButton
            }
            .padding(.horizontal, Design.Spacing.xl)
            .padding(.top, Design.Spacing.md)
            .padding(.bottom, Design.Spacing.md)

            // Clue card (at top)
            VStack(spacing: Design.Spacing.lg) {
                // Clue label and text
                VStack(spacing: Design.Spacing.sm) {
                    Text(clueHeaderText)
                        .font(Design.Font.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Design.Colors.accent)
                        .tracking(1.2)
                        .multilineTextAlignment(.center)

                    Text(viewModel.displayedClueText)
                        .font(Design.Font.title3)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                // Hints
                if viewModel.hintLevel != .none {
                    Rectangle()
                        .fill(Design.Colors.border)
                        .frame(height: 1)

                    HintDisplayView(
                        hintLevel: viewModel.hintLevel,
                        hint1: viewModel.displayedHint1,
                        hint2: viewModel.displayedHint2,
                        multipleChoiceOptions: viewModel.displayedMultipleChoiceOptions,
                        onSelectOption: { viewModel.selectMultipleChoiceOption($0) }
                    )

                    // Add to Playlist button - appears when hints are showing
                    if viewModel.isSongPlaying {
                        Rectangle()
                            .fill(Design.Colors.border)
                            .frame(height: 1)

                        addToPlaylistButton
                    }
                }
            }
            .padding(Design.Spacing.xxl)
            .frame(maxWidth: geometry.size.width - Design.Spacing.xxxl)
            .background(
                RoundedRectangle(cornerRadius: Design.Radius.lg)
                    .fill(Design.Colors.cardBackground)
            )
            .animation(.easeOut(duration: 0.3), value: viewModel.hintLevel)

            // Spacer - album art shows through here
            Spacer()

            // Answer input (fixed at bottom)
            VStack(spacing: Design.Spacing.md) {
                TextField("Type your answer...", text: $viewModel.currentAnswer)
                    .font(Design.Font.body)
                    .padding(Design.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: Design.Radius.md)
                            .fill(Design.Colors.inputBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: Design.Radius.md)
                                    .stroke(Design.Colors.border, lineWidth: 1)
                            )
                    )
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .onChange(of: viewModel.hintLevel) { newLevel in
                        if newLevel == .multipleChoice {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    }

                Button {
                    Task {
                        await viewModel.submitAnswer()
                    }
                } label: {
                    Text("Submit")
                        .font(Design.Font.bodyMedium)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Design.Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: Design.Radius.md)
                                .fill(viewModel.currentAnswer.isEmpty ? Design.Colors.accent.opacity(0.4) : Design.Colors.accent)
                        )
                }
                .disabled(viewModel.currentAnswer.isEmpty || viewModel.isCheckingAnswer)
            }
            .padding(.horizontal, Design.Spacing.xl)
            .padding(.bottom, Design.Spacing.xxl)
        }
        .transition(.opacity)
    }

    // MARK: - Queued Song Indicator

    private var queuedSongIndicator: some View {
        GeometryReader { geometry in
            VStack {
                // Close button at top
                HStack {
                    closeButton
                    Spacer()
                }
                .padding(.horizontal, Design.Spacing.xl)
                .padding(.top, Design.Spacing.md)

                // Trivia card - shows queued message + trivia about currently playing song
                VStack(spacing: Design.Spacing.lg) {
                    // Queued message header
                    Text(viewModel.showingPostQuestTrivia
                         ? "You have completed your quest. As you bask in your success here is some information you might find interesting:"
                         : "Your next song has been queued. While you wait for it to play here is some information you might find interesting:")
                        .font(Design.Font.caption)
                        .foregroundColor(Design.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)

                    // Song title and artist (currently playing)
                    VStack(spacing: Design.Spacing.xs) {
                        Text(viewModel.currentSongTitle)
                            .font(Design.Font.title3Medium)
                            .foregroundColor(Design.Colors.accent)
                            .multilineTextAlignment(.center)

                        Text(viewModel.currentArtistName)
                            .font(Design.Font.body)
                            .foregroundColor(Design.Colors.secondaryText)
                    }

                    // Trivia text
                    if let triviaText = viewModel.currentTriviaText {
                        Rectangle()
                            .fill(Design.Colors.border)
                            .frame(height: 1)

                        Text(triviaText)
                            .font(Design.Font.body)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)

                        // Trivia progress dots
                        if viewModel.queuedTrivia.count > 1 {
                            HStack(spacing: Design.Spacing.sm) {
                                ForEach(0..<viewModel.queuedTrivia.count, id: \.self) { index in
                                    Circle()
                                        .fill(index == viewModel.currentTriviaIndex ? Design.Colors.accent : Color.white.opacity(0.3))
                                        .frame(width: 6, height: 6)
                                }
                            }
                        }
                    }

                    // Add to Playlist button
                    Rectangle()
                        .fill(Design.Colors.border)
                        .frame(height: 1)

                    if viewModel.showingPostQuestTrivia {
                        addHuntToPlaylistButton
                    } else {
                        addToPlaylistButton
                    }
                }
                .padding(Design.Spacing.xxl)
                .frame(maxWidth: geometry.size.width - Design.Spacing.xxxl)
                .background(
                    RoundedRectangle(cornerRadius: Design.Radius.lg)
                        .fill(Design.Colors.cardBackground)
                )
                .padding(.top, Design.Spacing.md)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .animation(.easeOut(duration: 0.4), value: viewModel.currentTriviaIndex)
                .opacity(viewModel.queuedTextOpacity)
                .id(viewModel.currentTriviaIndex)

                Spacer()

                // Progress card at bottom with skip control
                VStack(spacing: Design.Spacing.md) {
                    // Progress bar
                    GeometryReader { barGeometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.2))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Design.Colors.accent)
                                .frame(width: barGeometry.size.width * viewModel.playbackProgress)
                        }
                    }
                    .frame(height: 4)

                    // Status text and skip button
                    HStack {
                        if viewModel.secondsUntilNextClue > 0 {
                            Text(viewModel.showingPostQuestTrivia
                                 ? "Song ends in \(viewModel.secondsUntilNextClue)s"
                                 : "Next song in \(viewModel.secondsUntilNextClue)s")
                                .font(Design.Font.caption)
                                .foregroundColor(Design.Colors.secondaryText)
                        }

                        Spacer()

                        if !viewModel.showingPostQuestTrivia {
                            // Skip to next song button
                            Button {
                                Task {
                                    await viewModel.skipToNextSong()
                                }
                            } label: {
                                HStack(spacing: Design.Spacing.xs) {
                                    Text("Skip")
                                        .font(Design.Font.captionMedium)
                                    Image(systemName: "forward.fill")
                                        .font(.system(size: 12, weight: .regular, design: .rounded))
                                }
                                .foregroundColor(Design.Colors.accent)
                                .padding(.horizontal, Design.Spacing.md)
                                .padding(.vertical, Design.Spacing.sm)
                                .background(
                                    Capsule()
                                        .fill(Design.Colors.accent.opacity(0.15))
                                )
                            }
                        }
                    }
                    .opacity(viewModel.queuedTextOpacity)
                }
                .padding(.horizontal, Design.Spacing.xl)
                .padding(.vertical, Design.Spacing.lg)
                .frame(maxWidth: geometry.size.width - Design.Spacing.xxxl)
                .background(
                    RoundedRectangle(cornerRadius: Design.Radius.md)
                        .fill(Design.Colors.cardBackground)
                )
                .padding(.bottom, 100)
            }
            .frame(maxWidth: .infinity)
        }
        .animation(.easeOut, value: viewModel.secondsUntilNextClue)
    }

    // MARK: - Correct Message Overlay

    private var correctMessageOverlay: some View {
        let answerText = viewModel.gameState.currentLink?.answerText ?? ""

        return VStack {
            VStack(spacing: Design.Spacing.lg) {
                Text("Correct")
                    .font(Design.Font.title1)
                    .foregroundColor(Design.Colors.accent)

                // Answer text on the next line
                if !answerText.isEmpty {
                    Text(answerText)
                        .font(Design.Font.body)
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, Design.Spacing.xxl)
            .padding(.vertical, Design.Spacing.xl)
            .frame(maxWidth: UIScreen.main.bounds.width - Design.Spacing.xxxl)
            .background(
                RoundedRectangle(cornerRadius: Design.Radius.lg)
                    .fill(Design.Colors.cardBackground)
            )
            .shadow(color: .black.opacity(0.3), radius: 16)
            .padding(.top, 60)

            Spacer()
        }
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Error Overlay

    private var errorOverlay: some View {
        ZStack {
            // Full screen dark background
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: Design.Spacing.md) {
                Text("I am sorry")
                    .font(Design.Font.title1)
                    .foregroundColor(Design.Colors.accent)

                Text("That is not the correct answer.")
                    .font(Design.Font.body)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Design.Spacing.xxl)
            .padding(.vertical, Design.Spacing.xl)
            .frame(maxWidth: UIScreen.main.bounds.width - Design.Spacing.xxxl)
            .background(
                RoundedRectangle(cornerRadius: Design.Radius.lg)
                    .fill(Design.Colors.cardBackground)
            )
        }
        .onTapGesture {
            viewModel.showingError = false
        }
    }

    private var finalCelebrationOverlay: some View {
        ZStack {
            CelebrationConfettiView()
                .ignoresSafeArea()

            TimelineView(.animation) { timeline in
                let flashPhase = (sin(timeline.date.timeIntervalSinceReferenceDate * 7.0) + 1.0) / 2.0

                VStack {
                    Spacer()

                    Text("Congratulations - you have solved the hunt")
                        .font(Design.Font.title1)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Design.Spacing.xxl)
                        .padding(.vertical, Design.Spacing.xl)
                        .background(
                            RoundedRectangle(cornerRadius: Design.Radius.lg)
                                .fill(Design.Colors.cardBackground.opacity(0.9))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Design.Radius.lg)
                                .stroke(Design.Colors.accent.opacity(0.55), lineWidth: 1.5)
                        )
                        .shadow(color: .black.opacity(0.35), radius: 18)
                        .opacity(0.4 + (flashPhase * 0.6))

                    Spacer()
                }
                .padding(.horizontal, Design.Spacing.xl)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Song Start Info Overlay

    private var songStartInfoOverlay: some View {
        VStack {
            VStack(spacing: Design.Spacing.lg) {
                // "Now Playing" label
                Text("NOW PLAYING")
                    .font(Design.Font.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Design.Colors.accent)
                    .tracking(1.2)

                // Song title and artist
                VStack(spacing: Design.Spacing.xs) {
                    Text(viewModel.currentSongTitle)
                        .font(Design.Font.title2)
                        .foregroundColor(Design.Colors.accent)
                        .multilineTextAlignment(.center)

                    Text(viewModel.currentArtistName)
                        .font(Design.Font.body)
                        .foregroundColor(Design.Colors.secondaryText)
                }

                // Song start info text
                if !viewModel.currentSongStartInfo.isEmpty {
                    Rectangle()
                        .fill(Design.Colors.border)
                        .frame(height: 1)

                    Text(viewModel.currentSongStartInfo)
                        .font(Design.Font.body)
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(Design.Spacing.xxl)
            .frame(maxWidth: UIScreen.main.bounds.width - Design.Spacing.xxxl)
            .background(
                RoundedRectangle(cornerRadius: Design.Radius.lg)
                    .fill(Design.Colors.cardBackground)
            )
            .shadow(color: .black.opacity(0.3), radius: 16)
            .padding(.top, 60)

            Spacer()
        }
    }
}

private struct CelebrationConfettiView: View {
    private struct Piece: Identifiable {
        let id: Int
        let x: CGFloat
        let delay: Double
        let size: CGFloat
        let rotation: Double
        let color: Color
    }

    private let pieces: [Piece] = [
        .init(id: 0, x: 0.08, delay: 0.0, size: 10, rotation: 12, color: .red),
        .init(id: 1, x: 0.15, delay: 0.3, size: 12, rotation: -18, color: .yellow),
        .init(id: 2, x: 0.23, delay: 0.6, size: 9, rotation: 30, color: .green),
        .init(id: 3, x: 0.31, delay: 0.1, size: 11, rotation: -22, color: .blue),
        .init(id: 4, x: 0.39, delay: 0.5, size: 8, rotation: 15, color: .orange),
        .init(id: 5, x: 0.47, delay: 0.2, size: 13, rotation: -12, color: .pink),
        .init(id: 6, x: 0.55, delay: 0.4, size: 10, rotation: 28, color: .mint),
        .init(id: 7, x: 0.63, delay: 0.7, size: 12, rotation: -26, color: .cyan),
        .init(id: 8, x: 0.71, delay: 0.15, size: 9, rotation: 20, color: .purple),
        .init(id: 9, x: 0.79, delay: 0.55, size: 11, rotation: -16, color: .teal),
        .init(id: 10, x: 0.87, delay: 0.25, size: 10, rotation: 35, color: .white),
        .init(id: 11, x: 0.94, delay: 0.65, size: 8, rotation: -30, color: .indigo)
    ]

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate

                ZStack {
                    Color.black.opacity(0.18)

                    ForEach(pieces) { piece in
                        let cycle = (time + piece.delay).truncatingRemainder(dividingBy: 2.8)
                        let progress = cycle / 2.8
                        let y = (-0.12 + progress * 1.28) * geometry.size.height
                        let wobble = sin((progress * .pi * 4) + piece.delay * 3) * 18

                        RoundedRectangle(cornerRadius: 2)
                            .fill(piece.color)
                            .frame(width: piece.size, height: piece.size * 1.5)
                            .rotationEffect(.degrees(piece.rotation + progress * 360))
                            .position(
                                x: piece.x * geometry.size.width + wobble,
                                y: y
                            )
                            .opacity(progress < 0.95 ? 0.95 : (1.0 - progress) * 12)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}
