import SwiftUI
import UIKit

struct ClueCardView: View {
    let clue: String
    let linkNumber: Int
    let albumArt: Data?

    var body: some View {
        VStack(spacing: 24) {
            linkNumberBadge

            if let artData = albumArt, let uiImage = UIImage(data: artData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 280, maxHeight: 280)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
            }

            clueText
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.1, green: 0.1, blue: 0.15),
                            Color(red: 0.15, green: 0.15, blue: 0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        )
        .padding(.horizontal, 20)
    }

    private var linkNumberBadge: some View {
        Text("Clue #\(linkNumber)")
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.15))
            )
    }

    private var clueText: some View {
        VStack(alignment: .leading, spacing: 12) {
            formattedClue
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }

    private var formattedClue: some View {
        let sentences = splitIntoSentences(clue)

        return VStack(alignment: .leading, spacing: 12) {
            if let firstSentence = sentences.first {
                Text(firstSentence)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if sentences.count > 1 {
                Text(sentences.dropFirst().joined(separator: " "))
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func splitIntoSentences(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        let sentenceEndings = CharacterSet(charactersIn: ".!?")
        var sentences: [String] = []
        var currentSentence = ""

        for char in trimmed {
            currentSentence.append(char)

            if sentenceEndings.contains(char.unicodeScalars.first!) {
                sentences.append(currentSentence.trimmingCharacters(in: .whitespaces))
                currentSentence = ""
            }
        }

        if !currentSentence.isEmpty {
            sentences.append(currentSentence.trimmingCharacters(in: .whitespaces))
        }

        return sentences.filter { !$0.isEmpty }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        ClueCardView(
            clue: "This Pink Floyd masterpiece took listeners to the dark side. Released in 1973, it became one of the best-selling albums of all time.",
            linkNumber: 1,
            albumArt: nil
        )
    }
}
