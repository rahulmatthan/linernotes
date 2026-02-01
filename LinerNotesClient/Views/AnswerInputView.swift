import SwiftUI

struct AnswerInputView: View {
    @Binding var answer: String
    @Binding var showingHint: Bool
    let hint: String
    let isCheckingAnswer: Bool
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            if showingHint && !hint.isEmpty {
                hintView
            }

            HStack(spacing: 12) {
                TextField("Who's the artist?", text: $answer)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            )
                    )
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        if !answer.isEmpty {
                            onSubmit()
                        }
                    }
                    .disabled(isCheckingAnswer)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)

                Button {
                    showingHint.toggle()
                } label: {
                    Image(systemName: showingHint ? "lightbulb.fill" : "lightbulb")
                        .font(.system(size: 20))
                        .foregroundColor(hint.isEmpty ? .gray : Color(red: 1.0, green: 0.84, blue: 0.0))
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.1))
                        )
                }
                .disabled(hint.isEmpty)
            }

            if isCheckingAnswer {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
            } else {
                Button {
                    onSubmit()
                } label: {
                    Text("Submit Answer")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.84, blue: 0.0),
                                            Color(red: 0.9, green: 0.75, blue: 0.0)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                }
                .disabled(answer.isEmpty)
                .opacity(answer.isEmpty ? 0.5 : 1.0)
            }
        }
        .padding(.horizontal, 20)
        .onAppear {
            isFocused = true
        }
    }

    private var hintView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                Text("Hint")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
            }

            Text(hint)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.3), lineWidth: 1)
                )
        )
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .scale.combined(with: .opacity)
        ))
        .animation(.spring(response: 0.3), value: showingHint)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        AnswerInputView(
            answer: .constant(""),
            showingHint: .constant(false),
            hint: "Think lunar and progressive",
            isCheckingAnswer: false,
            onSubmit: {}
        )
        .padding()
    }
}
