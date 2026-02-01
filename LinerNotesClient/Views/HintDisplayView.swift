import SwiftUI

struct HintDisplayView: View {
    let hintLevel: HintLevel
    let hint1: String
    let hint2: String?
    let multipleChoiceOptions: [String]
    let onSelectOption: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Hint (text)
            if hintLevel.rawValue >= HintLevel.hint1.rawValue && !hint1.isEmpty {
                hintCard(title: "Hint", text: hint1, icon: "lightbulb.fill")
            }

            // Multiple Choice Options
            if hintLevel == .multipleChoice && !multipleChoiceOptions.isEmpty {
                multipleChoiceCard
            }
        }
        .animation(.easeInOut(duration: 0.3), value: hintLevel)
    }

    private func hintCard(title: String, text: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
            }

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.3), lineWidth: 1)
                )
        )
        .transition(.scale.combined(with: .opacity))
    }

    private var multipleChoiceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                Text("Choose an answer:")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
            }

            VStack(spacing: 8) {
                ForEach(Array(multipleChoiceOptions.enumerated()), id: \.offset) { index, option in
                    if !option.isEmpty {
                        Button {
                            onSelectOption(option)
                        } label: {
                            HStack {
                                Text(optionLetter(index))
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                                    .frame(width: 24)

                                Text(option)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.1))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.2, green: 0.2, blue: 0.3).opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.3), lineWidth: 1)
                )
        )
        .transition(.scale.combined(with: .opacity))
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
                hint2: "He can't feel his face when he's with you",
                multipleChoiceOptions: ["The Weeknd", "Drake", "Post Malone", "Justin Bieber"],
                onSelectOption: { print($0) }
            )
            .padding()
        }
    }
}
