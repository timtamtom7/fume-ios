import Foundation

// MARK: - Source Type
enum SourceType: String, Codable, CaseIterable {
    case note
    case article
    case voiceMemo = "voice_memo"
    case image
    case pdf

    var icon: String {
        switch self {
        case .note: return "note.text"
        case .article: return "link"
        case .voiceMemo: return "waveform"
        case .image: return "photo"
        case .pdf: return "doc.text"
        }
    }

    var label: String {
        switch self {
        case .note: return "Note"
        case .article: return "Article"
        case .voiceMemo: return "Voice Memo"
        case .image: return "Image"
        case .pdf: return "PDF"
        }
    }
}

// MARK: - Source Model
struct Source: Identifiable, Codable, Equatable {
    let id: UUID
    var type: SourceType
    var title: String
    var content: String
    var url: String?
    var thumbnailData: Data?
    var createdAt: Date
    var updatedAt: Date
    var embedding: [Float]?

    init(
        id: UUID = UUID(),
        type: SourceType,
        title: String,
        content: String,
        url: String? = nil,
        thumbnailData: Data? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        embedding: [Float]? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.content = content
        self.url = url
        self.thumbnailData = thumbnailData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.embedding = embedding
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let prefix = type == .article ? "Article from " : ""
        return prefix + formatter.string(from: createdAt)
    }
}

// MARK: - Query Response
struct QueryResponse: Identifiable {
    let id: UUID = UUID()
    let answer: String
    let sources: [SourceMatch]
    let query: String
    let timestamp: Date = Date()
}

struct SourceMatch: Identifiable, Equatable {
    let id: UUID = UUID()
    let source: Source
    let excerpt: String
    let relevanceScore: Double
}

// MARK: - Search Result
struct SearchResult: Identifiable {
    let id: UUID
    let source: Source
    let score: Double
    let chunk: String
}
