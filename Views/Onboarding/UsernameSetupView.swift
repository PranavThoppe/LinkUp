import SwiftUI

struct UsernameSetupView: View {
    let onComplete: (String, String) -> Void

    @State private var nameText: String
    @State private var selectedColorHex: String = Participant.palette.first ?? "#FF6B9D"
    @State private var hasAssignedColor: Bool = false
    @State private var isRollingColor: Bool = false
    @FocusState private var isFieldFocused: Bool

    private var avatarFill: Color {
        if hasAssignedColor || isRollingColor {
            Color(hex: selectedColorHex)
        } else {
            Theme.cellDefault
        }
    }

    private var canContinue: Bool {
        let trimmed = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && hasAssignedColor && !isRollingColor
    }

    init(
        initialName: String = "",
        lockedColorHex: String? = nil,
        onComplete: @escaping (String, String) -> Void
    ) {
        self.onComplete = onComplete
        _nameText = State(initialValue: initialName)
        let paletteFirst = Participant.palette.first ?? "#FF6B9D"
        let restored = lockedColorHex?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let hex = restored, !hex.isEmpty {
            _selectedColorHex = State(initialValue: hex)
            _hasAssignedColor = State(initialValue: true)
        } else {
            _selectedColorHex = State(initialValue: paletteFirst)
            _hasAssignedColor = State(initialValue: false)
        }
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

                ZStack {
                    Circle()
                        .fill(avatarFill)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Text(String(nameText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased())
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white.opacity(0.92))
                        )
                        .scaleEffect(isRollingColor ? 1.08 : 1.0)
                        .opacity(isRollingColor ? 0.92 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: isRollingColor)
                }
                .frame(height: 76)

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

                Text(hasAssignedColor ? "Your color is set" : "Tap once for your color")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)

                Button {
                    rollToRandomColor()
                } label: {
                    HStack(spacing: 8) {
                        if hasAssignedColor {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Assigned")
                        } else {
                            Text("Assign my color")
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(hasAssignedColor ? Theme.textSecondary : .white)
                    .padding(.horizontal, 16)
                    .frame(height: 40)
                    .padding(.horizontal, 16)
                    .background(Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                hasAssignedColor ? Theme.cardDivider : Color(hex: selectedColorHex),
                                lineWidth: hasAssignedColor ? 1 : 2
                            )
                    )
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(hasAssignedColor || isRollingColor)

                Button {
                    let trimmed = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onComplete(trimmed, selectedColorHex)
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

    private func rollToRandomColor() {
        guard !hasAssignedColor, !isRollingColor, !Participant.palette.isEmpty else { return }
        isRollingColor = true

        let colors = Participant.palette
        let targetIndex = Int.random(in: 0..<colors.count)
        let minimumCycles = colors.count * 2
        let startIndex = colors.firstIndex(of: selectedColorHex) ?? 0
        let totalSteps = minimumCycles + ((targetIndex - startIndex + colors.count) % colors.count)
        let steps = max(totalSteps, colors.count)

        Task {
            for step in 1...steps {
                let idx = (startIndex + step) % colors.count
                await MainActor.run {
                    selectedColorHex = colors[idx]
                }
                let progress = Double(step) / Double(steps)
                let delayNs = UInt64((0.07 + progress * 0.22) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delayNs)
            }
            await MainActor.run {
                isRollingColor = false
                hasAssignedColor = true
                UserProfileLocalState.onboardingDraftColorHex = selectedColorHex
            }
        }
    }
}
