import SwiftUI
import AppKit
import AVFoundation

// MARK: - Mac Content View (Three-Column Layout)

struct MacContentView: View {
    @StateObject private var libraryViewModel = LibraryViewModel()
    @StateObject private var homeViewModel = HomeViewModel()
    @State private var selectedSourceType: SourceType? = nil
    @State private var selectedSource: Source? = nil
    @State private var showEditor = false
    @State private var showSettings = false
    @State private var showAIChat = false
    @State private var searchQuery = ""

    var body: some View {
        NavigationSplitView {
            // Left sidebar — Source types
            VStack(spacing: 0) {
                List(selection: $selectedSourceType) {
                    Section {
                        ForEach(SourceType.allCases, id: \.self) { type in
                            Button {
                                selectedSourceType = selectedSourceType == type ? nil : type
                                showAIChat = false
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: type.icon)
                                        .font(.system(size: 13))
                                        .frame(width: 18)
                                        .foregroundStyle(typeColor(for: type))
                                    Text(type.label)
                                        .font(.system(size: 13))
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(selectedSourceType == type ? FumeColors.sourceHighlight : Color.clear)
                            .cornerRadius(8)
                        }
                    } header: {
                        Text("Sources")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(FumeColors.textSecondary)
                            .textCase(.uppercase)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .background(FumeColors.surface)

                Divider()

                // Bottom actions
                VStack(spacing: 0) {
                    Button {
                        showEditor = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FumeColors.accent)
                    .padding(12)

                    Divider()

                    HStack(spacing: 12) {
                        Button {
                            showAIChat = true
                            selectedSource = nil
                        } label: {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 13))
                        }
                        .buttonStyle(.plain)
                        .help("Ask AI")

                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 13))
                        }
                        .buttonStyle(.plain)
                        .help("Settings")
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                }
                .background(FumeColors.surface)
            }
            .frame(minWidth: 180, idealWidth: 200)
            .background(FumeColors.surface)

        } content: {
            // Center — Note list / search results
            MacNoteListView(
                viewModel: libraryViewModel,
                selectedSourceType: selectedSourceType,
                searchQuery: $searchQuery,
                selectedSource: $selectedSource,
                onAskAI: { source in
                    selectedSource = source
                    showAIChat = true
                }
            )
            .frame(minWidth: 260, idealWidth: 320)

        } detail: {
            // Right — Detail / AI Chat
            if showAIChat {
                MacAIChatView(
                    viewModel: homeViewModel,
                    contextSource: selectedSource
                )
                .frame(minWidth: 400)
            } else if let source = selectedSource {
                MacSourceDetailView(source: source)
                    .frame(minWidth: 400)
            } else {
                emptyDetailView
                    .frame(minWidth: 400)
            }
        }
        .frame(minWidth: 900, minHeight: 500)
        .background(FumeColors.background)
        .task {
            await libraryViewModel.loadSources()
        }
        .sheet(isPresented: $showEditor) {
            MacNoteEditorView(viewModel: libraryViewModel)
        }
        .sheet(isPresented: $showSettings) {
            MacSettingsView()
        }
    }

    private var emptyDetailView: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(FumeColors.accent.opacity(0.3))
            Text("Select a source or ask Fume")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(FumeColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FumeColors.background)
    }

    private func typeColor(for type: SourceType) -> Color {
        switch type {
        case .note: return FumeColors.accent
        case .article: return Color.blue
        case .voiceMemo: return Color.purple
        case .image: return Color.green
        case .pdf: return Color.red
        }
    }
}

// MARK: - Note List View

struct MacNoteListView: View {
    @ObservedObject var viewModel: LibraryViewModel
    let selectedSourceType: SourceType?
    @Binding var searchQuery: String
    @Binding var selectedSource: Source?
    let onAskAI: (Source) -> Void

    var displayedSources: [Source] {
        var result = viewModel.sources

        if let type = selectedSourceType {
            result = result.filter { $0.type == type }
        }

        if !searchQuery.isEmpty {
            let lower = searchQuery.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(lower) ||
                $0.content.lowercased().contains(lower)
            }
        }

        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(FumeColors.textSecondary)

                TextField("Search notes...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit {
                        Task {
                            await viewModel.performSearch(searchQuery)
                        }
                    }

                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                        viewModel.clearSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(FumeColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(FumeColors.surfaceRaised)
            .cornerRadius(10)
            .padding()

            Divider()

            // List
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                    .tint(FumeColors.accent)
                Spacer()
            } else if displayedSources.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(displayedSources) { source in
                            MacNoteRow(
                                source: source,
                                isSelected: selectedSource?.id == source.id
                            )
                            .onTapGesture {
                                selectedSource = source
                            }
                            .contextMenu {
                                Button {
                                    selectedSource = source
                                    onAskAI(source)
                                } label: {
                                    Label("Ask about this", systemImage: "brain")
                                }

                                Divider()

                                Button(role: .destructive) {
                                    Task { await viewModel.deleteSource(source) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(FumeColors.background)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 36))
                .foregroundStyle(FumeColors.textSecondary.opacity(0.4))
            Text("No sources yet")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(FumeColors.textSecondary)
            Text("Add notes, articles, or voice memos")
                .font(.system(size: 12))
                .foregroundStyle(FumeColors.textSecondary.opacity(0.7))
            Spacer()
        }
    }
}

// MARK: - Note Row

struct MacNoteRow: View {
    let source: Source
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(typeColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: source.type.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(typeColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(source.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(FumeColors.textPrimary)

                Text(source.content.prefix(60) + (source.content.count > 60 ? "..." : ""))
                    .font(.system(size: 11))
                    .foregroundStyle(FumeColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(source.formattedDate)
                .font(.system(size: 10))
                .foregroundStyle(FumeColors.textSecondary.opacity(0.7))
        }
        .padding(10)
        .background(isSelected ? FumeColors.sourceHighlight : FumeColors.surfaceRaised)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? FumeColors.accent.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private var typeColor: Color {
        switch source.type {
        case .note: return FumeColors.accent
        case .article: return Color.blue
        case .voiceMemo: return Color.purple
        case .image: return Color.green
        case .pdf: return Color.red
        }
    }
}

// MARK: - Source Detail View

struct MacSourceDetailView: View {
    let source: Source

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(source.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(FumeColors.textPrimary)
                    Spacer()
                }

                HStack(spacing: 8) {
                    Label(source.type.label, systemImage: source.type.icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(typeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(typeColor.opacity(0.15))
                        .cornerRadius(12)

                    Text(source.formattedDate)
                        .font(.system(size: 11))
                        .foregroundStyle(FumeColors.textSecondary)
                }
            }
            .padding()
            .background(FumeColors.surface)

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(source.content)
                        .font(.system(size: 14))
                        .lineSpacing(5)
                        .foregroundStyle(FumeColors.textPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let url = source.url, let parsedURL = URL(string: url) {
                        Divider()
                        Link(destination: parsedURL) {
                            HStack {
                                Image(systemName: "link")
                                Text(url)
                                    .lineLimit(1)
                            }
                            .font(.system(size: 12))
                            .foregroundStyle(Color.blue)
                        }
                    }

                    Divider()

                    HStack {
                        Label("\(source.content.count) chars", systemImage: "textformat.size")
                        Spacer()
                        Label("\(source.content.split(separator: " ").count) words", systemImage: "text.word.spacing")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(FumeColors.textSecondary)
                    .padding()
                    .background(FumeColors.surfaceRaised)
                    .cornerRadius(10)
                }
                .padding()
            }
            .background(FumeColors.background)
        }
        .background(FumeColors.background)
    }

    private var typeColor: Color {
        switch source.type {
        case .note: return FumeColors.accent
        case .article: return Color.blue
        case .voiceMemo: return Color.purple
        case .image: return Color.green
        case .pdf: return Color.red
        }
    }
}
