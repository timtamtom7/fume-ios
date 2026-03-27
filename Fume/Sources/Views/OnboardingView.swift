import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @ObservedObject private var appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    var body: some View {
        ZStack {
            FumeColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    OnboardingScreen1()
                        .tag(0)

                    OnboardingScreen2()
                        .tag(1)

                    OnboardingScreen3()
                        .tag(2)

                    OnboardingScreen4(appState: appState)
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Page indicator + skip
                VStack(spacing: 20) {
                    HStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? FumeColors.accent : FumeColors.textSecondary.opacity(0.3))
                                .frame(width: index == currentPage ? 10 : 8, height: index == currentPage ? 10 : 8)
                                .animation(.easeInOut(duration: 0.2), value: currentPage)
                        }
                    }

                    if currentPage < 3 {
                        Button {
                            completeOnboarding()
                        } label: {
                            Text("Skip")
                                .font(.system(size: FumeTokens.fontSizeBodySmall))
                                .foregroundStyle(FumeColors.textSecondary)
                        }
                        .accessibilityLabel("Skip onboarding")
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }

    private func completeOnboarding() {
        OnboardingStorage.shared.completeOnboarding()
        appState.hasCompletedOnboarding = true
    }
}

// MARK: - Screen 1: Your Second Brain
struct OnboardingScreen1: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero graphic
            BrainIllustration()
                .frame(width: 220, height: 200)

            VStack(spacing: 16) {
                Text("Your second brain")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(FumeColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Fume stores everything you care about — notes, articles, voice memos, images — and lets you ask it anything.")
                    .font(.system(size: 16))
                    .foregroundStyle(FumeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 8)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Screen 2: Add Anything
struct OnboardingScreen2: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Content type grid illustration
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    ContentTypeCard(icon: "note.text", label: "Notes", color: FumeColors.accent)
                        .accessibilityLabel("Content type: Notes")
                    ContentTypeCard(icon: "link", label: "Articles", color: Color(hex: "3b82f6"))
                        .accessibilityLabel("Content type: Articles")
                }

                HStack(spacing: 16) {
                    ContentTypeCard(icon: "waveform", label: "Voice", color: Color(hex: "8b5cf6"))
                        .accessibilityLabel("Content type: Voice memos")
                    ContentTypeCard(icon: "photo", label: "Images", color: Color(hex: "10b981"))
                        .accessibilityLabel("Content type: Images")
                }
            }
            .padding(.horizontal, 32)

            VStack(spacing: 16) {
                Text("Add anything")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(FumeColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Type a quick note. Paste an article URL. Record a voice memo. Photograph a document. Fume handles it all.")
                    .font(.system(size: 16))
                    .foregroundStyle(FumeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 24)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Screen 3: Ask Anything
struct OnboardingScreen3: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Query illustration
            QueryIllustration()
                .frame(width: 260, height: 200)

            VStack(spacing: 16) {
                Text("Ask anything")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(FumeColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("\"What did I read about local AI last month?\" Fume searches your entire knowledge base and answers from your own notes.")
                    .font(.system(size: 16))
                    .foregroundStyle(FumeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 8)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Screen 4: Your Mind, Amplified
struct OnboardingScreen4: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Final illustration - amplified mind
            AmplifiedMindIllustration()
                .frame(width: 220, height: 200)

            VStack(spacing: 16) {
                Text("Your mind, amplified")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(FumeColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Everything runs on your device. Your data never leaves your phone. Start building your second brain.")
                    .font(.system(size: 16))
                    .foregroundStyle(FumeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 8)

            Spacer()

            // Start button
            Button {
                FumeHaptic.success()
                OnboardingStorage.shared.completeOnboarding()
                appState.hasCompletedOnboarding = true
            } label: {
                Text("Start using Fume")
                    .font(.system(size: FumeTokens.fontSizeTitle, weight: .semibold))
                    .foregroundStyle(FumeColors.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(FumeColors.accent)
                    )
            }
            .padding(.horizontal, 32)
            .accessibilityLabel("Start using Fume")
            .padding(.bottom, 60)
        }
    }
}

// MARK: - Supporting Views

struct ContentTypeCard: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: FumeTokens.cornerRadiusLarge)
                    .fill(color.opacity(0.15))
                    .frame(height: 70)

                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(color)
            }

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(FumeColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}


