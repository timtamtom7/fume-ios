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

// MARK: - Tag
struct Tag: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, colorHex: String = "f59e0b", createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
    }

    var color: TagColor {
        TagColor(rawValue: colorHex) ?? .amber
    }
}

enum TagColor: String, CaseIterable {
    case amber = "f59e0b"
    case blue = "3b82f6"
    case green = "10b981"
    case purple = "8b5cf6"
    case red = "ef4444"
    case pink = "ec4899"
    case teal = "14b8a6"
    case orange = "f97316"

    var swatch: String {
        switch self {
        case .amber: return "amber.fill"
        case .blue: return "blue.fill"
        case .green: return "green.fill"
        case .purple: return "purple.fill"
        case .red: return "red.fill"
        case .pink: return "pink.fill"
        case .teal: return "teal.fill"
        case .orange: return "orange.fill"
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
    var tagIDs: [UUID]

    init(
        id: UUID = UUID(),
        type: SourceType,
        title: String,
        content: String,
        url: String? = nil,
        thumbnailData: Data? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        embedding: [Float]? = nil,
        tagIDs: [UUID] = []
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
        self.tagIDs = tagIDs
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
