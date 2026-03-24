import SwiftUI

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
                MacMainView()
            }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Source") {
                    // Would open add content sheet
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }

    private func configureAppearance() {
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
    }
}

// MARK: - macOS Main View (Desktop-adapted)

struct MacMainView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var showLibrary = false
    @State private var selectedSource: Source?

    var body: some View {
        NavigationSplitView {
            // Sidebar
            VStack(spacing: 0) {
                // Query section
                querySection
                    .padding()

                Divider()

                // Navigation
                List {
                    Button {
                        showLibrary = false
                    } label: {
                        Label("Query", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                    .padding(.vertical, 6)

                    Button {
                        showLibrary = true
                    } label: {
                        Label("Library", systemImage: "books.vertical")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                    .padding(.vertical, 6)

                    Divider()
                        .padding(.vertical, 8)

                    // Sync status
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.icloud")
                            .foregroundStyle(.green)
                        Text("iCloud synced")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
            .frame(minWidth: 200)
            .background(Color(nsColor: .controlBackgroundColor))
        } detail: {
            if showLibrary {
                MacLibraryView()
            } else {
                MacQueryDetailView(viewModel: viewModel)
            }
        }
        .frame(minWidth: 800, idealWidth: 1100, minHeight: 500)
    }

    // MARK: - Query Section

    private var querySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: "f59e0b"))

                Text("Fume")
                    .font(.system(size: 16, weight: .semibold))

                Spacer()
            }

            TextField("Ask Fume anything...", text: $viewModel.queryText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .lineLimit(1...3)
                .padding(10)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)
                .onSubmit {
                    Task { await viewModel.submitQuery() }
                }

            Button {
                Task { await viewModel.submitQuery() }
            } label: {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                    Text("Ask")
                }
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "f59e0b"))
            .disabled(viewModel.queryText.isEmpty || viewModel.isThinking)
        }
    }
}

// MARK: - Mac Query Detail View

struct MacQueryDetailView: View {
    @ObservedObject var viewModel: HomeViewModel
    @State private var selectedSource: Source?

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            if viewModel.isThinking {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(Color(hex: "f59e0b"))
                    Text("Searching your knowledge base...")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            } else if let response = viewModel.response {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Answer
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                    .foregroundStyle(Color(hex: "f59e0b"))
                                Text("Answer")
                                    .font(.system(size: 13, weight: .semibold))
                            }

                            Text(response.answer)
                                .font(.system(size: 15))
                                .lineSpacing(4)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(12)

                        // Sources
                        if !response.sources.isEmpty {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundStyle(Color(hex: "f59e0b"))
                                Text("From your notes:")
                                    .font(.system(size: 13, weight: .semibold))
                            }

                            ForEach(response.sources) { match in
                                MacSourceRow(source: match.source, excerpt: match.excerpt)
                                    .onTapGesture {
                                        selectedSource = match.source
                                    }
                            }
                        }
                    }
                    .padding()
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 60))
                        .foregroundStyle(Color(hex: "f59e0b").opacity(0.4))

                    Text("Ask Fume anything")
                        .font(.system(size: 17, weight: .semibold))

                    Text("Your second brain is ready to answer questions\nfrom your notes, articles, and voice memos.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .sheet(item: $selectedSource) { source in
            MacSourceDetailSheet(source: source)
        }
    }
}

// MARK: - Mac Source Row

struct MacSourceRow: View {
    let source: Source
    let excerpt: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(width: 40, height: 40)

                Image(systemName: source.type.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: "f59e0b"))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(source.title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)

                Text(excerpt)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(source.formattedDate)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
}

// MARK: - Mac Onboarding View

struct MacOnboardingView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundStyle(Color(hex: "f59e0b"))

            Text("Welcome to Fume")
                .font(.system(size: 24, weight: .bold))

            Text("Your AI-powered second brain for macOS.\nAdd notes, articles, and voice memos.\nAsk anything — Fume answers from your knowledge.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Get Started") {
                appState.completeOnboarding()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "f59e0b"))
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - NSApp Appearance Helper

extension NSApplication {
    static func makeThemedAppearance() {
        let appearance = NSAppearance(named: .darkAqua)
        NSApp.appearance = appearance
    }
}
