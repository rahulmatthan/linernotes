import SwiftUI

struct HintButton: View {
    let isEnabled: Bool
    let secondsRemaining: Int
    let hintLevel: HintLevel
    let hardMode: Bool
    let onTap: () -> Void

    private var buttonText: String {
        switch hintLevel {
        case .none:
            return "Hint"
        case .hint1:
            return hardMode ? "All Hints Used" : "Show Options"
        case .hint2, .multipleChoice:
            return "All Hints Used"
        }
    }

    private var isFullyUsed: Bool {
        hintLevel == .multipleChoice || (hardMode && hintLevel == .hint1)
    }

    private var buttonIcon: String {
        switch hintLevel {
        case .none, .hint1, .hint2:
            return "lightbulb.fill"
        case .multipleChoice:
            return "checkmark.circle"
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: buttonIcon)
                    .font(.system(size: 16, weight: .semibold))
                Text(buttonText)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(isEnabled && !isFullyUsed ? .black : .white.opacity(0.5))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isEnabled && !isFullyUsed
                          ? Color(red: 1.0, green: 0.84, blue: 0.0)
                          : Color.white.opacity(0.15))
            )
        }
        .disabled(!isEnabled || isFullyUsed)
        .animation(.easeInOut(duration: 0.3), value: isEnabled)
        .animation(.easeInOut(duration: 0.3), value: hintLevel)
        .animation(.easeInOut(duration: 0.3), value: hardMode)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 20) {
            Text("Normal Mode").foregroundColor(.white)
            HintButton(isEnabled: false, secondsRemaining: 45, hintLevel: .none, hardMode: false, onTap: {})
            HintButton(isEnabled: true, secondsRemaining: 0, hintLevel: .none, hardMode: false, onTap: {})
            HintButton(isEnabled: true, secondsRemaining: 0, hintLevel: .hint1, hardMode: false, onTap: {})

            Text("Hard Mode").foregroundColor(.white).padding(.top)
            HintButton(isEnabled: true, secondsRemaining: 0, hintLevel: .hint1, hardMode: true, onTap: {})
        }
    }
}
