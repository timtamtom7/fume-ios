import Foundation

// MARK: - Knowledge Sharing Service
// R12: Share Knowledge Bases, Public Pages, Collaborative Research Spaces

final class KnowledgeSharingService: @unchecked Sendable {
    static let shared = KnowledgeSharingService()

    private init() {}

    // MARK: - Visibility

    enum Visibility: String, Codable, CaseIterable {
        case `private` = "private"
        case friends = "friends"
        case `public` = "public"

        var label: String {
            switch self {
            case .private: return "Private"
            case .friends: return "Friends"
            case .public: return "Public"
            }
        }

        var icon: String {
            switch self {
            case .private: return "lock.fill"
            case .friends: return "person.2.fill"
            case .public: return "globe"
            }
        }
    }

    // MARK: - Public Page

    struct PublicPage: Identifiable, Codable, Equatable {
        let id: UUID
        var pageId: UUID
        var authorID: String
        var authorName: String
        var title: String
        var summary: String
        var tags: [String]
        var visibility: Visibility
        var viewCount: Int
        var questionCount: Int
        var lastUpdatedAt: Date

        init(
            id: UUID = UUID(),
            pageId: UUID,
            authorID: String,
            authorName: String,
            title: String,
            summary: String = "",
            tags: [String] = [],
            visibility: Visibility = .public,
            viewCount: Int = 0,
            questionCount: Int = 0,
            lastUpdatedAt: Date = Date()
        ) {
            self.id = id
            self.pageId = pageId
            self.authorID = authorID
            self.authorName = authorName
            self.title = title
            self.summary = summary
            self.tags = tags
            self.visibility = visibility
            self.viewCount = viewCount
            self.questionCount = questionCount
            self.lastUpdatedAt = lastUpdatedAt
        }
    }

    // MARK: - AI Response

    struct AIResponse: Codable, Equatable {
        var answer: String
        var sources: [SourceReference]
        var confidence: Double
        var generatedAt: Date

        struct SourceReference: Codable, Equatable, Identifiable {
            let id: UUID
            var pageTitle: String
            var authorName: String
            var relevanceSnippet: String
        }

        init(answer: String = "", sources: [SourceReference] = [], confidence: Double = 0.0, generatedAt: Date = Date()) {
            self.answer = answer
            self.sources = sources
            self.confidence = confidence
            self.generatedAt = generatedAt
        }
    }

    // MARK: - Collaborative Space

    struct CollaborativeSpace: Identifiable, Codable, Equatable {
        let id: UUID
        var name: String
        var ownerID: String
        var ownerName: String
        var collaboratorIDs: [String]
        var noteIDs: [UUID]
        var noteContributions: [NoteContribution]
        var createdAt: Date
        var lastActivityAt: Date
        var isActive: Bool

        struct NoteContribution: Identifiable, Codable, Equatable {
            let id: UUID = UUID()
            var noteID: UUID
            var contributorID: String
            var contributorName: String
            var contributionSummary: String
            var contributedAt: Date
        }

        init(
            id: UUID = UUID(),
            name: String,
            ownerID: String,
            ownerName: String,
            collaboratorIDs: [String] = [],
            noteIDs: [UUID] = [],
            noteContributions: [NoteContribution] = [],
            createdAt: Date = Date(),
            lastActivityAt: Date = Date(),
            isActive: Bool = true
        ) {
            self.id = id
            self.name = name
            self.ownerID = ownerID
            self.ownerName = ownerName
            self.collaboratorIDs = collaboratorIDs
            self.noteIDs = noteIDs
            self.noteContributions = noteContributions
            self.createdAt = createdAt
            self.lastActivityAt = lastActivityAt
            self.isActive = isActive
        }
    }

    // MARK: - Most Asked Topics

    struct TrendingTopic: Identifiable, Codable, Equatable {
        let id: UUID = UUID()
        var topic: String
        var questionCount: Int
        var pageCount: Int
        var lastAskedAt: Date
    }

    // MARK: - Storage Keys

    private let publicPagesKey = "fume.publicPages"
    private let spacesKey = "fume.collaborativeSpaces"
    private let trendingKey = "fume.trendingTopics"

    // MARK: - Share a Page

    func sharePage(pageId: UUID, visibility: Visibility) async throws {
        var pages = loadPublicPages()

        if let existing = pages.firstIndex(where: { $0.pageId == pageId }) {
            pages[existing].visibility = visibility
            pages[existing].lastUpdatedAt = Date()
        } else {
            let newPage = PublicPage(
                pageId: pageId,
                authorID: currentUserID(),
                authorName: currentUserName(),
                title: "Shared Note",
                visibility: visibility
            )
            pages.append(newPage)
        }

        savePublicPages(pages)
    }

    // MARK: - Get Public Pages

    func getPublicPages() -> [PublicPage] {
        return loadPublicPages().filter { $0.visibility == .public }
    }

    // MARK: - Get Pages by Author

    func getPages(forAuthor authorID: String) -> [PublicPage] {
        return loadPublicPages().filter { $0.authorID == authorID }
    }

    // MARK: - Ask My Notes

    func askMyNotes(query: String) async throws -> AIResponse {
        let pages = loadPublicPages()
        let matchingPages = pages.filter { page in
            page.title.localizedCaseInsensitiveContains(query) ||
            page.summary.localizedCaseInsensitiveContains(query) ||
            page.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }

        var sources: [AIResponse.SourceReference] = []
        var answerText = ""

        if matchingPages.isEmpty {
            answerText = "No public pages found matching '\(query)'. Be the first to ask a question about this topic!"
        } else {
            let topPages = Array(matchingPages.prefix(3))
            sources = topPages.map { page in
                AIResponse.SourceReference(
                    id: page.id,
                    pageTitle: page.title,
                    authorName: page.authorName,
                    relevanceSnippet: page.summary.isEmpty ? "Tap to view full content" : page.summary
                )
            }
            answerText = "Found \(matchingPages.count) page(s) related to '\(query)'. People are asking Tommaso about \(query) — here are the top results."
        }

        return AIResponse(
            answer: answerText,
            sources: sources,
            confidence: matchingPages.isEmpty ? 0.0 : 0.85,
            generatedAt: Date()
        )
    }

    // MARK: - Trending Topics

    func getTrendingTopics() -> [TrendingTopic] {
        let pages = loadPublicPages()
        var topicCounts: [String: (count: Int, lastAsked: Date)] = [:]

        for page in pages {
            for tag in page.tags {
                let existing = topicCounts[tag] ?? (count: 0, lastAsked: Date.distantPast)
                topicCounts[tag] = (count: existing.count + page.questionCount, lastAsked: max(existing.lastAsked, page.lastUpdatedAt))
            }
        }

        return topicCounts
            .sorted { $0.value.count > $1.value.count }
            .prefix(10)
            .enumerated()
            .map { index, pair in
                TrendingTopic(
                    topic: pair.key,
                    questionCount: pair.value.count,
                    pageCount: pages.filter { $0.tags.contains(pair.key) }.count,
                    lastAskedAt: pair.value.lastAsked
                )
            }
    }

    // MARK: - Collaborative Spaces

    func createSpace(name: String) -> CollaborativeSpace {
        let space = CollaborativeSpace(
            name: name,
            ownerID: currentUserID(),
            ownerName: currentUserName()
        )

        var spaces = loadSpaces()
        spaces.append(space)
        saveSpaces(spaces)

        return space
    }

    func getSpaces() -> [CollaborativeSpace] {
        return loadSpaces()
    }

    func getSpaces(forUser userID: String) -> [CollaborativeSpace] {
        return loadSpaces().filter { $0.ownerID == userID || $0.collaboratorIDs.contains(userID) }
    }

    func inviteToSpace(spaceID: UUID, collaboratorID: String) throws {
        var spaces = loadSpaces()
        guard let index = spaces.firstIndex(where: { $0.id == spaceID }) else {
            throw KnowledgeSharingError.spaceNotFound
        }
        guard spaces[index].ownerID == currentUserID() else {
            throw KnowledgeSharingError.notAuthorized
        }
        if !spaces[index].collaboratorIDs.contains(collaboratorID) {
            spaces[index].collaboratorIDs.append(collaboratorID)
        }
        saveSpaces(spaces)
    }

    func addContribution(toSpace spaceID: UUID, noteID: UUID, summary: String) throws {
        var spaces = loadSpaces()
        guard let index = spaces.firstIndex(where: { $0.id == spaceID }) else {
            throw KnowledgeSharingError.spaceNotFound
        }

        let space = spaces[index]
        guard space.ownerID == currentUserID() || space.collaboratorIDs.contains(currentUserID()) else {
            throw KnowledgeSharingError.notAuthorized
        }

        spaces[index].noteIDs.append(noteID)
        spaces[index].noteContributions.append(
            CollaborativeSpace.NoteContribution(
                noteID: noteID,
                contributorID: currentUserID(),
                contributorName: currentUserName(),
                contributionSummary: summary,
                contributedAt: Date()
            )
        )
        spaces[index].lastActivityAt = Date()
        saveSpaces(spaces)
    }

    func synthesizeSpace(_ spaceID: UUID) async throws -> AIResponse {
        let spaces = loadSpaces()
        guard let space = spaces.first(where: { $0.id == spaceID }) else {
            throw KnowledgeSharingError.spaceNotFound
        }

        let contributions = space.noteContributions
        if contributions.isEmpty {
            return AIResponse(
                answer: "No contributions yet in '\(space.name)'. Add notes to get AI synthesis.",
                sources: [],
                confidence: 0.0
            )
        }

        let summary = contributions.map { $0.contributionSummary }.joined(separator: " | ")

        return AIResponse(
            answer: "Synthesis of '\(space.name)': \(contributions.count) contributions from \(space.collaboratorIDs.count + 1) collaborators — \(summary)",
            sources: [],
            confidence: 0.9,
            generatedAt: Date()
        )
    }

    // MARK: - Errors

    enum KnowledgeSharingError: Error, Identifiable {
        case spaceNotFound
        case notAuthorized
        case pageNotFound

        var id: String {
            switch self {
            case .spaceNotFound: return "spaceNotFound"
            case .notAuthorized: return "notAuthorized"
            case .pageNotFound: return "pageNotFound"
            }
        }
    }

    // MARK: - Private Helpers

    private func loadPublicPages() -> [PublicPage] {
        guard let data = UserDefaults.standard.data(forKey: publicPagesKey),
              let pages = try? JSONDecoder().decode([PublicPage].self, from: data) else {
            return []
        }
        return pages
    }

    private func savePublicPages(_ pages: [PublicPage]) {
        if let data = try? JSONEncoder().encode(pages) {
            UserDefaults.standard.set(data, forKey: publicPagesKey)
        }
    }

    private func loadSpaces() -> [CollaborativeSpace] {
        guard let data = UserDefaults.standard.data(forKey: spacesKey),
              let spaces = try? JSONDecoder().decode([CollaborativeSpace].self, from: data) else {
            return []
        }
        return spaces
    }

    private func saveSpaces(_ spaces: [CollaborativeSpace]) {
        if let data = try? JSONEncoder().encode(spaces) {
            UserDefaults.standard.set(data, forKey: spacesKey)
        }
    }

    private func currentUserID() -> String {
        return UserDefaults.standard.string(forKey: "fume.userID") ?? UUID().uuidString
    }

    private func currentUserName() -> String {
        return UserDefaults.standard.string(forKey: "fume.userName") ?? "You"
    }
}
