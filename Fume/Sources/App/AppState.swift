import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: Tab = .home
    @Published var isLoading: Bool = false
    @Published var hasCompletedOnboarding: Bool = false
    @Published var showPricing: Bool = false
    @Published var isOffline: Bool = false
    @Published var syncStatus: SyncService.SyncStatus = .idle
    @Published var pendingChanges: Int = 0

    enum Tab: Hashable {
        case home
        case library
    }

    init() {
        hasCompletedOnboarding = OnboardingStorage.shared.hasCompletedOnboarding
        Task {
            await initialize()
        }
    }

    private func initialize() async {
        await DatabaseService.shared.initialize()

        // Initialize network monitor (starts automatically)
        let _ = NetworkMonitor.shared

        // Initialize sync service
        do {
            try await SyncService.shared.setupZone()
            try await SyncService.shared.syncAllSources()
        } catch {
            // Sync setup failed — offline mode still works
            print("Sync setup error (non-fatal): \(error)")
        }

        // Observe sync state changes
        observeSyncState()
    }

    private func observeSyncState() {
        Task {
            for await _ in AsyncTimerSequence(interval: 5) {
                let state = await SyncService.shared.syncState
                await MainActor.run {
                    self.syncStatus = state.status
                    self.pendingChanges = state.pendingChanges
                }
            }
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

// MARK: - Async Timer Sequence

struct AsyncTimerSequence: AsyncSequence {
    typealias Element = Date

    let interval: TimeInterval

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(interval: interval)
    }

    struct AsyncIterator: AsyncIteratorProtocol {
        let interval: TimeInterval

        mutating func next() async -> Date? {
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            return Date()
        }
    }
}
