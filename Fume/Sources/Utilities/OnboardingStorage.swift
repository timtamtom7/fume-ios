import Foundation

/// Manages onboarding state persistence via UserDefaults
@MainActor
final class OnboardingStorage {
    @MainActor
    static let shared = OnboardingStorage()

    private let defaults = UserDefaults.standard
    private let hasCompletedOnboardingKey = "fume_onboarding_completed"
    private let hasSeenOnboardingKey = "fume_has_seen_onboarding"

    private init() {}

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: hasCompletedOnboardingKey) }
        set { defaults.set(newValue, forKey: hasCompletedOnboardingKey) }
    }

    var hasSeenOnboarding: Bool {
        get { defaults.bool(forKey: hasSeenOnboardingKey) }
        set { defaults.set(newValue, forKey: hasSeenOnboardingKey) }
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        hasSeenOnboarding = true
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
        hasSeenOnboarding = false
    }
}
