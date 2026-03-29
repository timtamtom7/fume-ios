import SwiftUI
import AppKit

@main
struct FumeMacApp: App {
    @StateObject private var appState = AppState()

    init() {
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            if !appState.hasCompletedOnboarding {
                MacOnboardingView(appState: appState)
            } else {
                MacContentView()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Source") {
                    NotificationCenter.default.post(name: .openAddSource, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
                .accessibilityLabel("Add Source")
            }
        }
    }

    private func configureAppearance() {
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        NSApp.setActivationPolicy(.accessory)
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let openAddSource = Notification.Name("openAddSource")
}

// MARK: - macOS Main View (Three-Column Layout)

struct MacOnboardingView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // Logo
            ZStack {
                Circle()
                    .fill(FumeColors.accent.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 44))
                    .foregroundStyle(FumeColors.accent)
            }

            VStack(spacing: 8) {
                Text("Welcome to Fume")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(FumeColors.textPrimary)

                Text("Your AI-powered second brain for macOS")
                    .font(.system(size: 15))
                    .foregroundStyle(FumeColors.textSecondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                featureRow(icon: "note.text", text: "Capture notes, articles, and voice memos")
                featureRow(icon: "brain", text: "Powered by on-device AI (Apple Neural Engine)")
                featureRow(icon: "moon.fill", text: "Dark intelligence terminal aesthetic")
                featureRow(icon: "lock.shield", text: "Your data stays local, always private")
            }
            .padding(.horizontal, 40)

            Button {
                appState.completeOnboarding()
            } label: {
                Text("Get Started")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(minWidth: 160)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(FumeColors.accent)
            .controlSize(.large)
            .accessibilityLabel("Get Started")
            .accessibilityHint("Completes onboarding and starts using Fume")

            Spacer()

            Text("Fume v1.0.0")
                .font(.system(size: 11))
                .foregroundStyle(FumeColors.textSecondary.opacity(0.6))
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FumeColors.background)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(FumeColors.accent)
                .frame(width: 24)

            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(FumeColors.textPrimary)
        }
    }
}
