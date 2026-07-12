import SwiftUI

struct HintDisplayView: View {
    let hintLevel: HintLevel
    let hint1: String
    let hint2: String?
    let multipleChoiceOptions: [String]
    let onSelectOption: (String) -> Void

    // Design constants (matching GameView)
    private let accentColor = Color(red: 1.0, green: 0.42, blue: 0.42)
    private let secondaryText = Color.white.opacity(0.7)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Hint text
            if hintLevel.rawValue >= HintLevel.hint1.rawValue && !hint1.isEmpty {
                hintCard
            }

            // Multiple Choice Options
            if hintLevel == .multipleChoice && !multipleChoiceOptions.isEmpty {
                multipleChoiceCard
            }
        }
        .animation(.easeOut(duration: 0.3), value: hintLevel)
    }

    private var hintCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(accentColor)
                Text("HINT")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(accentColor)
                    .tracking(1)
            }

            Text(hint1)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(accentColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(accentColor.opacity(0.2), lineWidth: 1)
                )
        )
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private var multipleChoiceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(secondaryText)
                Text("OR CHOOSE")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(secondaryText)
                    .tracking(1)
            }

            VStack(spacing: 8) {
                ForEach(Array(multipleChoiceOptions.enumerated()), id: \.offset) { index, option in
                    if !option.isEmpty {
                        Button {
                            onSelectOption(option)
                        } label: {
                            HStack(spacing: 12) {
                                Text(optionLetter(index))
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(accentColor)
                                    .frame(width: 20)

                                Text(option)
                                    .font(.system(size: 16, weight: .regular, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private func optionLetter(_ index: Int) -> String {
        ["A", "B", "C", "D"][safe: index] ?? "\(index + 1)"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            HintDisplayView(
                hintLevel: .multipleChoice,
                hint1: "Think about what blinds you at night",
                hint2: nil,
                multipleChoiceOptions: ["The Weeknd", "Drake", "Post Malone", "Justin Bieber"],
                onSelectOption: { print($0) }
            )
            .padding(24)
        }
    }
}
