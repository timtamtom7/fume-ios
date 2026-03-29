import SwiftUI
import AppKit

// MARK: - Menu Bar Label (Icon for menu bar)

struct MenuBarLabel: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 12, weight: .semibold))
            Text("Fume")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(FumeColors.accent)
    }
}

// MARK: - Menu Bar Content View

struct MenuBarContent: View {
    let onOpenFume: () -> Void
    let onQuit: () -> Void

    @State private var quickNoteTitle = ""
    @State private var quickNoteContent = ""
    @State private var isAddingNote = false
    @State private var searchQuery = ""
    @State private var recentSources: [Source] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FumeColors.accent)
                Text("Fume")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button {
                    onOpenFume()
                } label: {
                    Text("Open")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.blue)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open Fume")
                .accessibilityHint("Opens the Fume main window")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(FumeColors.surface)

            Divider()

            if isAddingNote {
                quickAddForm
            } else {
                mainMenuContent
            }
        }
        .frame(width: 300)
        .background(FumeColors.background)
        .task {
            await loadRecentSources()
        }
    }

    // MARK: - Quick Add Form

    private var quickAddForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button {
                    isAddingNote = false
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(FumeColors.textSecondary)
                .accessibilityLabel("Go Back")
                .accessibilityHint("Returns to the main menu")

                Text("Quick Note")
                    .font(.system(size: 13, weight: .semibold))
            }

            TextField("Title", text: $quickNoteTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(8)
                .background(FumeColors.surfaceRaised)
                .cornerRadius(8)

            TextEditor(text: $quickNoteContent)
                .font(.system(size: 12))
                .scrollContentBackground(.hidden)
                .foregroundStyle(FumeColors.textPrimary)
                .frame(height: 80)
                .padding(6)
                .background(FumeColors.surfaceRaised)
                .cornerRadius(8)

            HStack {
                Button {
                    Task { await saveQuickNote() }
                } label: {
                    Text("Save Note")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent)
                .tint(FumeColors.accent)
                .disabled(quickNoteTitle.isEmpty || quickNoteContent.isEmpty)
                .accessibilityLabel("Save Note")
                .accessibilityHint("Saves the quick note")
            }
        }
        .padding(12)
    }

    // MARK: - Main Menu Content

    private var mainMenuContent: some View {
        VStack(spacing: 0) {
            // Quick add button
            Button {
                isAddingNote = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(FumeColors.accent)
                    Text("Quick Add Note")
                        .font(.system(size: 13))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .background(FumeColors.background)
            .accessibilityLabel("Quick Add Note")
            .accessibilityHint("Opens a form to quickly add a new note")

            Divider()
                .padding(.vertical, 4)

            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(FumeColors.textSecondary)

                TextField("Search notes...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))

                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(FumeColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                    .accessibilityHint("Clears the search query")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(FumeColors.surfaceRaised)
            .cornerRadius(8)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            // Recent sources
            if !recentSources.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("RECENT")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(FumeColors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    ForEach(recentSources.prefix(4)) { source in
                        HStack(spacing: 8) {
                            Image(systemName: source.type.icon)
                                .font(.system(size: 10))
                                .foregroundStyle(typeColor(for: source.type))
                                .frame(width: 12)

                            Text(source.title)
                                .font(.system(size: 12))
                                .lineLimit(1)

                            Spacer()

                            Text(source.formattedDate)
                                .font(.system(size: 9))
                                .foregroundStyle(FumeColors.textSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                }

                Divider()
                    .padding(.vertical, 4)
            }

            // Actions
            VStack(spacing: 0) {
                Button {
                    onOpenFume()
                } label: {
                    HStack {
                        Image(systemName: "app")
                            .font(.system(size: 12))
                        Text("Open Fume")
                            .font(.system(size: 13))
                        Spacer()
                        Text("⌘O")
                            .font(.system(size: 10))
                            .foregroundStyle(FumeColors.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .foregroundStyle(FumeColors.textPrimary)
                .accessibilityLabel("Open Fume")
                .accessibilityHint("Opens the Fume main window")

                Divider()

                Button {
                    onQuit()
                } label: {
                    HStack {
                        Image(systemName: "power")
                            .font(.system(size: 12))
                        Text("Quit Fume")
                            .font(.system(size: 13))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .foregroundStyle(FumeColors.textSecondary)
                .accessibilityLabel("Quit Fume")
                .accessibilityHint("Quits the Fume application")
            }
        }
    }

    // MARK: - Helpers

    private func loadRecentSources() async {
        do {
            let sources = try await DatabaseService.shared.fetchAllSources()
            await MainActor.run {
                recentSources = Array(sources.prefix(5))
            }
        } catch {
            print("Failed to load recent sources: \(error)")
        }
    }

    private func saveQuickNote() async {
        let source = Source(
            type: .note,
            title: quickNoteTitle,
            content: quickNoteContent
        )

        let embedding = await EmbeddingService.shared.generateEmbedding(for: source.content)
        var sourceWithEmbedding = source
        sourceWithEmbedding.embedding = embedding

        do {
            try await DatabaseService.shared.insertSource(sourceWithEmbedding)
            quickNoteTitle = ""
            quickNoteContent = ""
            isAddingNote = false
            await loadRecentSources()
        } catch {
            print("Failed to save quick note: \(error)")
        }
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
