import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if !appState.hasCompletedOnboarding {
                OnboardingView(appState: appState)
            } else {
                MainTabView()
                    .sheet(isPresented: $appState.showPricing) {
                        PricingView()
                    }
            }
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            HomeView()
                .tabItem {
                    Label("Query", systemImage: "magnifyingglass")
                }
                .tag(AppState.Tab.home)

            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
                .tag(AppState.Tab.library)
        }
        .tint(FumeColors.accent)
        .overlay(alignment: .top) {
            SyncStatusBar()
                .padding(.top, 4)
        }
    }
}
