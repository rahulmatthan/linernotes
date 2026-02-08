import SwiftUI

// MARK: - Design Constants
private enum Design {
    enum Font {
        static let caption = SwiftUI.Font.system(size: 13)
        static let captionMedium = SwiftUI.Font.system(size: 13, weight: .medium)
        static let body = SwiftUI.Font.system(size: 16)
        static let bodyMedium = SwiftUI.Font.system(size: 16, weight: .medium)
        static let title1 = SwiftUI.Font.system(size: 24, weight: .bold)
    }

    enum Spacing {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    enum Colors {
        static let accent = Color(red: 1.0, green: 0.84, blue: 0.0)
        static let secondaryText = Color.white.opacity(0.7)
    }
}

struct ContentView: View {
    // Navigation state
    enum NavigationState {
        case splash
        case onboardingWelcome
        case onboardingInstructions
        case huntSelection
        case game
    }

    @State private var navigationState: NavigationState = .splash
    @State private var selectedHunt: TreasureHunt?
    @State private var savedProgress: SavedProgress?
    @State private var selectedHuntFileId: String?

    // Check if user has seen onboarding before
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        ZStack {
            backgroundGradient

            switch navigationState {
            case .splash:
                splashScreen
            case .onboardingWelcome:
                onboardingWelcomeScreen
            case .onboardingInstructions:
                onboardingInstructionsScreen
            case .huntSelection:
                HuntSelectionView(
                    onHuntSelected: { hunt, progress, huntFileId in
                        selectedHunt = hunt
                        savedProgress = progress
                        selectedHuntFileId = huntFileId
                        navigationState = .game
                    },
                    onClose: {
                        navigationState = .splash
                    }
                )
                .transition(.opacity)
            case .game:
                if let hunt = selectedHunt {
                    GameView(
                        treasureHunt: hunt,
                        savedProgress: savedProgress,
                        huntFileId: selectedHuntFileId ?? hunt.name,
                        skipOnboarding: true
                    )
                    .transition(.opacity)
                    .onDisappear {
                        // Return to hunt selection when game is dismissed
                        selectedHunt = nil
                        savedProgress = nil
                        selectedHuntFileId = nil
                        navigationState = .huntSelection
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: navigationState)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.1),
                Color(red: 0.1, green: 0.05, blue: 0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Splash Screen

    private var splashScreen: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 80))
                    .foregroundColor(Design.Colors.accent)

                Text("LinerNotes")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.white)

                Text("Musical Treasure Hunt")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            Button {
                if hasSeenOnboarding {
                    navigationState = .huntSelection
                } else {
                    navigationState = .onboardingWelcome
                }
            } label: {
                Label("Start", systemImage: "play.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Design.Colors.accent,
                                        Color(red: 0.9, green: 0.75, blue: 0.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
    }

    // MARK: - Onboarding Screens

    private var skipButton: some View {
        Button {
            hasSeenOnboarding = true
            navigationState = .huntSelection
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
                    Image(systemName: "music.note.list")
                        .font(.system(size: 64, weight: .light))
                        .foregroundColor(Design.Colors.accent)

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

                // Next button
                Button {
                    navigationState = .onboardingInstructions
                } label: {
                    Text("Next")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Design.Colors.accent)
                        )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
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
        .transition(.opacity)
    }

    private var onboardingInstructionsScreen: some View {
        ZStack {
            VStack(spacing: Design.Spacing.xxxl) {
                Spacer()

                VStack(spacing: Design.Spacing.xl) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 56, weight: .light))
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

                // Let's Go button
                Button {
                    hasSeenOnboarding = true
                    navigationState = .huntSelection
                } label: {
                    Text("Let's Go")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Design.Colors.accent)
                        )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
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
        .transition(.opacity)
    }
}

#Preview {
    ContentView()
}
