import SwiftUI

struct UsernameSetupView: View {
    let onComplete: (String) -> Void

    @State private var nameText: String = ""
    @FocusState private var isFieldFocused: Bool

    private var canContinue: Bool {
        !nameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Welcome to LinkUp")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text("What should we call you?")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                }

                TextField(
                    "",
                    text: $nameText,
                    prompt: Text("Your name").foregroundColor(.white.opacity(0.4))
                )
                .focused($isFieldFocused)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(true)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Button {
                    let trimmed = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onComplete(trimmed)
                } label: {
                    Text("Continue")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(canContinue ? Theme.primaryBlue : Theme.primaryBlue.opacity(0.4))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(!canContinue)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .onAppear {
            isFieldFocused = true
        }
    }
}
