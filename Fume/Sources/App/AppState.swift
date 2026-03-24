import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: Tab = .home
    @Published var isLoading: Bool = false
    @Published var hasCompletedOnboarding: Bool = false
    @Published var showPricing: Bool = false

    enum Tab: Hashable {
        case home
        case library
    }

    init() {
        hasCompletedOnboarding = OnboardingStorage.shared.hasCompletedOnboarding
        Task {
            await DatabaseService.shared.initialize()
        }
    }

    func completeOnboarding() {
        OnboardingStorage.shared.completeOnboarding()
        hasCompletedOnboarding = true
    }

    func resetOnboarding() {
        OnboardingStorage.shared.resetOnboarding()
        hasCompletedOnboarding = false
    }
}
