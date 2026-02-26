import SwiftUI

struct OnboardingHeaderBar: View {
    let showBack: Bool
    let showSkip: Bool
    let onBack: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack {
            if showBack {
                Button(action: onBack) {
                    Label("Back", systemImage: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(hex: "525252"))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("onboarding.backButton")
            } else {
                Color.clear
                    .frame(width: 56, height: 24)
            }

            Spacer()

            Text("Lexical Onboarding")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: "4A5565"))
                .accessibilityIdentifier("onboarding.title")

            Spacer()

            if showSkip {
                Button("Skip") {
                    onSkip()
                }
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color(hex: "8E8E93"))
                .buttonStyle(.plain)
                .accessibilityIdentifier("onboarding.skipButton")
            } else {
                Color.clear
                    .frame(width: 56, height: 24)
            }
        }
        .frame(height: 32)
    }
}

struct OnboardingProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    private var progress: CGFloat {
        guard totalSteps > 0 else { return 0 }
        return CGFloat(currentStep + 1) / CGFloat(totalSteps)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color(hex: OnboardingFlowModel.progressTrackHex))
                .frame(height: 4)

            Capsule()
                .fill(Color(hex: OnboardingFlowModel.accentHex))
                .frame(maxWidth: .infinity)
                .frame(height: 4)
                .scaleEffect(x: max(0, min(1, progress)), y: 1, anchor: .leading)
                .animation(.easeInOut(duration: 0.40), value: progress)
        }
        .accessibilityElement()
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue("Step \(currentStep + 1) of \(totalSteps)")
        .accessibilityIdentifier("onboarding.progressBar")
    }
}

struct OnboardingPrimaryButton: View {
    let title: String
    let isEnabled: Bool
    let accessibilityID: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(.white)
                .background(isEnabled ? Color(hex: OnboardingFlowModel.accentHex) : Color(hex: OnboardingFlowModel.accentHex).opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .pressScaleEffect(enabled: isEnabled)
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier(accessibilityID)
    }
}

struct OnboardingStepContainer<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }
}

private struct PressScaleModifier: ViewModifier {
    let enabled: Bool
    @GestureState private var pressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed && enabled ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: pressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($pressed) { _, state, _ in
                        state = true
                    }
            )
    }
}

private extension View {
    func pressScaleEffect(enabled: Bool) -> some View {
        modifier(PressScaleModifier(enabled: enabled))
    }
}

private struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.8), lineWidth: 1)
            )
    }
}

extension View {
    func onboardingGlassCard() -> some View {
        modifier(GlassCardModifier())
    }

    @ViewBuilder
    func lexicalWordsAutocapitalization() -> some View {
#if os(iOS)
        textInputAutocapitalization(.words)
#else
        self
#endif
    }
}

struct ForgettingCurvePreview: View {
    let isStabilized: Bool

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let baseY = height * 0.15
            let floorY = height * 0.88

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "F7F8F9"), Color(hex: "EFF2F5")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Path { path in
                    path.move(to: CGPoint(x: 14, y: baseY))
                    path.addCurve(
                        to: CGPoint(x: width - 14, y: floorY),
                        control1: CGPoint(x: width * 0.35, y: height * 0.30),
                        control2: CGPoint(x: width * 0.72, y: height * 0.82)
                    )
                }
                .stroke(Color(hex: OnboardingFlowModel.accentHex).opacity(0.9), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                if isStabilized {
                    Path { path in
                        let pivotX = width * 0.56
                        path.move(to: CGPoint(x: pivotX, y: height * 0.68))
                        path.addLine(to: CGPoint(x: pivotX, y: baseY))
                    }
                    .stroke(Color(hex: "D97706"), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))

                    Path { path in
                        let pivotX = width * 0.56
                        path.move(to: CGPoint(x: pivotX, y: baseY))
                        path.addCurve(
                            to: CGPoint(x: width - 14, y: height * 0.24),
                            control1: CGPoint(x: width * 0.72, y: height * 0.18),
                            control2: CGPoint(x: width * 0.88, y: height * 0.26)
                        )
                    }
                    .stroke(Color(hex: "16A34A"), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
