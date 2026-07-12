import SwiftUI

/// Passive countdown display showing when hints will appear automatically
struct HintButton: View {
    let secondsUntilHint: Int
    let hintLevel: HintLevel

    // Design constants
    private let accentColor = Color(red: 1.0, green: 0.42, blue: 0.42)
    private let secondaryText = Color.white.opacity(0.5)

    private var displayText: String {
        switch hintLevel {
        case .none:
            if secondsUntilHint > 0 {
                return "Hint in \(secondsUntilHint)s"
            } else {
                return "Hint soon..."
            }
        case .hint1:
            return "Hint shown"
        case .hint2, .multipleChoice:
            return "Options shown"
        }
    }

    private var icon: String {
        switch hintLevel {
        case .none:
            return "clock"
        case .hint1:
            return "lightbulb.fill"
        case .hint2, .multipleChoice:
            return "checkmark"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium, design: .rounded))
            Text(displayText)
                .font(.system(size: 12, weight: .medium, design: .rounded))
        }
        .foregroundColor(hintLevel == .none ? secondaryText : accentColor.opacity(0.8))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
        )
        .animation(.easeOut(duration: 0.2), value: hintLevel)
        .animation(.easeOut(duration: 0.2), value: secondsUntilHint)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 16) {
            Text("Automatic Hints")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.5))

            HintButton(secondsUntilHint: 12, hintLevel: HintLevel.none)
            HintButton(secondsUntilHint: 5, hintLevel: HintLevel.none)
            HintButton(secondsUntilHint: 0, hintLevel: HintLevel.hint1)
            HintButton(secondsUntilHint: 0, hintLevel: HintLevel.multipleChoice)
        }
    }
}
