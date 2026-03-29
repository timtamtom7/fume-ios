import SwiftUI

// MARK: - Mac Shared Pages View
// Browse public knowledge pages from the community

struct MacSharedPagesView: View {
    @State private var publicPages: [KnowledgeSharingService.PublicPage] = []
    @State private var trendingTopics: [KnowledgeSharingService.TrendingTopic] = []
    @State private var searchQuery = ""
    @State private var isLoading = false
    @State private var selectedPage: KnowledgeSharingService.PublicPage?
    @State private var questionText = ""
    @State private var aiResponse: KnowledgeSharingService.AIResponse?
    @State private var isAsking = false

    private let service = KnowledgeSharingService.shared

    var filteredPages: [KnowledgeSharingService.PublicPage] {
        if searchQuery.isEmpty {
            return publicPages
        }
        let lower = searchQuery.lowercased()
        return publicPages.filter {
            $0.title.lowercased().contains(lower) ||
            $0.authorName.lowercased().contains(lower) ||
            $0.tags.contains { $0.lowercased().contains(lower) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Trending topics banner
            if !trendingTopics.isEmpty {
                trendingBanner
                Divider()
            }

            // Search
            searchBar

            Divider()

            // Content
            if isLoading {
                Spacer()
                ProgressView("Loading public pages...")
                    .tint(FumeColors.accent)
                Spacer()
            } else if filteredPages.isEmpty {
                emptyState
            } else {
                pagesList
            }
        }
        .background(FumeColors.background)
        .task {
            await loadData()
        }
        .sheet(item: $selectedPage) { page in
            pageDetailSheet(page)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.system(size: 14))
                        .foregroundStyle(FumeColors.accent)

                    Text("Public Pages")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FumeColors.textPrimary)
                }

                Text("Browse what people are sharing and asking about")
                    .font(.system(size: 11))
                    .foregroundStyle(FumeColors.textSecondary)
            }

            Spacer()

            Button {
                Task { await loadData() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help("Refresh")
        }
        .padding()
        .background(FumeColors.surface)
    }

    // MARK: - Trending Banner

    private var trendingBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 11))
                    .foregroundStyle(FumeColors.accent)

                Text("Trending Topics")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FumeColors.textSecondary)

                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(trendingTopics) { topic in
                        trendingTag(topic)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(FumeColors.surface.opacity(0.5))
    }

    private func trendingTag(_ topic: KnowledgeSharingService.TrendingTopic) -> some View {
        Button {
            searchQuery = topic.topic
        } label: {
            HStack(spacing: 4) {
                Text(topic.topic)
                    .font(.system(size: 11, weight: .medium))

                Text("\(topic.questionCount)")
                    .font(.system(size: 10))
                    .foregroundStyle(FumeColors.textSecondary)
            }
            .foregroundStyle(FumeColors.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(FumeColors.accent.opacity(0.15))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(FumeColors.textSecondary)

            TextField("Search public pages...", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13))

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
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
    }

    // MARK: - Pages List

    private var pagesList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredPages) { page in
                    publicPageRow(page)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func publicPageRow(_ page: KnowledgeSharingService.PublicPage) -> some View {
        Button {
            selectedPage = page
        } label: {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(FumeColors.accent.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Text(String(page.authorName.prefix(1)).uppercased())
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FumeColors.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(page.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FumeColors.textPrimary)
                        .lineLimit(1)

                    Text("by \(page.authorName)")
                        .font(.system(size: 11))
                        .foregroundStyle(FumeColors.textSecondary)

                    if !page.tags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(page.tags.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(FumeColors.accent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(FumeColors.accent.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "eye")
                            .font(.system(size: 10))
                        Text("\(page.viewCount)")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(FumeColors.textSecondary)

                    HStack(spacing: 4) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 10))
                        Text("\(page.questionCount)")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(FumeColors.textSecondary)
                }
            }
            .padding(12)
            .background(FumeColors.surfaceRaised)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "globe")
                .font(.system(size: 36))
                .foregroundStyle(FumeColors.textSecondary.opacity(0.4))

            Text("No public pages yet")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(FumeColors.textSecondary)

            Text("Share your notes publicly to appear here")
                .font(.system(size: 12))
                .foregroundStyle(FumeColors.textSecondary.opacity(0.7))
            Spacer()
        }
    }

    // MARK: - Page Detail Sheet

    private func pageDetailSheet(_ page: KnowledgeSharingService.PublicPage) -> some View {
        VStack(spacing: 0) {
            // Sheet header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(page.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FumeColors.textPrimary)

                    Text("by \(page.authorName)")
                        .font(.system(size: 11))
                        .foregroundStyle(FumeColors.textSecondary)
                }

                Spacer()

                Button {
                    selectedPage = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(FumeColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(FumeColors.surface)

            Divider()

            // Summary
            if !page.summary.isEmpty {
                Text(page.summary)
                    .font(.system(size: 13))
                    .foregroundStyle(FumeColors.textPrimary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FumeColors.surfaceRaised)
            }

            Divider()

            // Ask about this page
            VStack(alignment: .leading, spacing: 8) {
                Text("Ask about this page")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FumeColors.textSecondary)

                HStack(spacing: 8) {
                    TextField("e.g. What is this about?", text: $questionText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(10)
                        .background(FumeColors.surfaceRaised)
                        .cornerRadius(8)

                    Button {
                        Task { await askQuestionAbout(page) }
                    } label: {
                        if isAsking {
                            ProgressView()
                                .tint(FumeColors.accent)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FumeColors.accent)
                    .disabled(questionText.isEmpty || isAsking)
                }

                // AI Response
                if let response = aiResponse {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 11))
                                .foregroundStyle(FumeColors.accent)

                            Text("Fume AI")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(FumeColors.textSecondary)

                            Spacer()

                            Text(String(format: "%.0f%% confident", response.confidence * 100))
                                .font(.system(size: 9))
                                .foregroundStyle(FumeColors.textSecondary)
                        }

                        Text(response.answer)
                            .font(.system(size: 12))
                            .foregroundStyle(FumeColors.textPrimary)
                            .textSelection(.enabled)

                        if !response.sources.isEmpty {
                            Divider()
                            Text("Sources:")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(FumeColors.textSecondary)

                            ForEach(response.sources) { source in
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 10))
                                        .foregroundStyle(FumeColors.accent)

                                    Text("\(source.pageTitle) — \(source.authorName)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(FumeColors.textSecondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(FumeColors.surfaceRaised)
                    .cornerRadius(10)
                }
            }
            .padding()
            .background(FumeColors.background)

            Spacer()
        }
        .frame(width: 480, height: 400)
        .background(FumeColors.background)
    }

    // MARK: - Actions

    private func loadData() async {
        isLoading = true
        publicPages = service.getPublicPages()
        trendingTopics = service.getTrendingTopics()
        isLoading = false
    }

    private func askQuestionAbout(_ page: KnowledgeSharingService.PublicPage) async {
        isAsking = true
        aiResponse = nil

        do {
            aiResponse = try await service.askMyNotes(query: questionText.isEmpty ? page.title : questionText)
        } catch {
            aiResponse = KnowledgeSharingService.AIResponse(
                answer: "Failed to get an answer. Please try again.",
                sources: [],
                confidence: 0.0
            )
        }

        isAsking = false
    }
}
