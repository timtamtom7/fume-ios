import Foundation
import SQLite

actor DatabaseService {
    static let shared = DatabaseService()

    private var db: Connection?
    private let sourcesTable = Table("sources")

    // Columns
    private let idCol = Expression<String>("id")
    private let typeCol = Expression<String>("type")
    private let titleCol = Expression<String>("title")
    private let contentCol = Expression<String>("content")
    private let urlCol = Expression<String?>("url")
    private let thumbnailCol = Expression<Data?>("thumbnail")
    private let createdAtCol = Expression<Double>("created_at")
    private let updatedAtCol = Expression<Double>("updated_at")
    private let embeddingCol = Expression<String?>("embedding")
    private let tagIDsCol = Expression<String>("tag_ids")

    // Tags table
    private let tagsTable = Table("tags")
    private let tagIdCol = Expression<String>("id")
    private let tagNameCol = Expression<String>("name")
    private let tagColorCol = Expression<String>("color")
    private let tagCreatedAtCol = Expression<Double>("created_at")

    // Source-Tag junction table
    private let sourceTagsTable = Table("source_tags")
    private let stSourceIdCol = Expression<String>("source_id")
    private let stTagIdCol = Expression<String>("tag_id")

    private init() {}

    func initialize() async {
        do {
            let path = getDocumentsDirectory().appendingPathComponent("fume.sqlite3").path
            db = try Connection(path)
            try createTables()
        } catch {
            print("Database initialization error: \(error)")
        }
    }

    private func createTables() throws {
        guard let db = db else { return }

        try db.run(sourcesTable.create(ifNotExists: true) { t in
            t.column(idCol, primaryKey: true)
            t.column(typeCol)
            t.column(titleCol)
            t.column(contentCol)
            t.column(urlCol)
            t.column(thumbnailCol)
            t.column(createdAtCol)
            t.column(updatedAtCol)
            t.column(embeddingCol)
            t.column(tagIDsCol, defaultValue: "")
        })

        try db.run(tagsTable.create(ifNotExists: true) { t in
            t.column(tagIdCol, primaryKey: true)
            t.column(tagNameCol)
            t.column(tagColorCol)
            t.column(tagCreatedAtCol)
        })

        try db.run(sourceTagsTable.create(ifNotExists: true) { t in
            t.column(stSourceIdCol)
            t.column(stTagIdCol)
            t.primaryKey(stSourceIdCol, stTagIdCol)
        })
    }

    func insertSource(_ source: Source) async throws {
        guard let db = db else { return }

        let embeddingStr = source.embedding.map { embed in
            embed.map { String($0) }.joined(separator: ",")
        }

        let tagIDsStr = source.tagIDs.map { $0.uuidString }.joined(separator: ",")

        let insert = sourcesTable.insert(
            idCol <- source.id.uuidString,
            typeCol <- source.type.rawValue,
            titleCol <- source.title,
            contentCol <- source.content,
            urlCol <- source.url,
            thumbnailCol <- source.thumbnailData,
            createdAtCol <- source.createdAt.timeIntervalSince1970,
            updatedAtCol <- source.updatedAt.timeIntervalSince1970,
            embeddingCol <- embeddingStr,
            tagIDsCol <- tagIDsStr
        )

        try db.run(insert)

        // Insert source-tag relationships
        for tagID in source.tagIDs {
            try db.run(sourceTagsTable.insert(or: .ignore,
                stSourceIdCol <- source.id.uuidString,
                stTagIdCol <- tagID.uuidString
            ))
        }
    }

    func fetchAllSources() async throws -> [Source] {
        guard let db = db else { return [] }

        var sources: [Source] = []
        for row in try db.prepare(sourcesTable.order(createdAtCol.desc)) {
            let embedding: [Float]? = row[embeddingCol]?.split(separator: ",").compactMap {
                Float(String($0))
            }

            let tagIDs: [UUID] = (row[tagIDsCol] ?? "")
                .split(separator: ",")
                .compactMap { UUID(uuidString: String($0)) }

            guard let uuid = UUID(uuidString: row[idCol]),
                  let type = SourceType(rawValue: row[typeCol]) else { continue }

            let source = Source(
                id: uuid,
                type: type,
                title: row[titleCol],
                content: row[contentCol],
                url: row[urlCol],
                thumbnailData: row[thumbnailCol],
                createdAt: Date(timeIntervalSince1970: row[createdAtCol]),
                updatedAt: Date(timeIntervalSince1970: row[updatedAtCol]),
                embedding: embedding,
                tagIDs: tagIDs
            )
            sources.append(source)
        }
        return sources
    }

    func fetchSource(id: UUID) async throws -> Source? {
        guard let db = db else { return nil }

        let query = sourcesTable.filter(idCol == id.uuidString)
        guard let row = try db.pluck(query) else { return nil }

        let embedding: [Float]? = row[embeddingCol]?.split(separator: ",").compactMap {
            Float(String($0))
        }

        let tagIDs: [UUID] = (row[tagIDsCol] ?? "")
            .split(separator: ",")
            .compactMap { UUID(uuidString: String($0)) }

        guard let type = SourceType(rawValue: row[typeCol]) else { return nil }

        return Source(
            id: id,
            type: type,
            title: row[titleCol],
            content: row[contentCol],
            url: row[urlCol],
            thumbnailData: row[thumbnailCol],
            createdAt: Date(timeIntervalSince1970: row[createdAtCol]),
            updatedAt: Date(timeIntervalSince1970: row[updatedAtCol]),
            embedding: embedding,
            tagIDs: tagIDs
        )
    }

    func deleteSource(id: UUID) async throws {
        guard let db = db else { return }
        let source = sourcesTable.filter(idCol == id.uuidString)
        try db.run(source.delete())
    }

    func searchSources(query: String) async throws -> [Source] {
        let allSources = try await fetchAllSources()
        let lowercasedQuery = query.lowercased()
        return allSources.filter {
            $0.title.lowercased().contains(lowercasedQuery) ||
            $0.content.lowercased().contains(lowercasedQuery)
        }
    }

    func updateSourceEmbedding(id: UUID, embedding: [Float]) async throws {
        guard let db = db else { return }

        let embeddingStr = embedding.map { String($0) }.joined(separator: ",")
        let source = sourcesTable.filter(idCol == id.uuidString)
        try db.run(source.update(embeddingCol <- embeddingStr))
    }

    // MARK: - Tag Operations

    func fetchAllTags() async throws -> [Tag] {
        guard let db = db else { return [] }

        var tags: [Tag] = []
        for row in try db.prepare(tagsTable.order(tagNameCol.asc)) {
            guard let uuid = UUID(uuidString: row[tagIdCol]) else { continue }
            let tag = Tag(
                id: uuid,
                name: row[tagNameCol],
                colorHex: row[tagColorCol],
                createdAt: Date(timeIntervalSince1970: row[tagCreatedAtCol])
            )
            tags.append(tag)
        }
        return tags
    }

    func insertTag(_ tag: Tag) async throws {
        guard let db = db else { return }
        let insert = tagsTable.insert(
            tagIdCol <- tag.id.uuidString,
            tagNameCol <- tag.name,
            tagColorCol <- tag.colorHex,
            tagCreatedAtCol <- tag.createdAt.timeIntervalSince1970
        )
        try db.run(insert)
    }

    func deleteTag(id: UUID) async throws {
        guard let db = db else { return }
        // Remove tag from all sources
        let junctions = sourceTagsTable.filter(stTagIdCol == id.uuidString)
        try db.run(junctions.delete())
        // Remove tag itself
        let tagRow = tagsTable.filter(tagIdCol == id.uuidString)
        try db.run(tagRow.delete())
    }

    func updateSourceTags(sourceID: UUID, tagIDs: [UUID]) async throws {
        guard let db = db else { return }

        // Remove existing relationships
        let existing = sourceTagsTable.filter(stSourceIdCol == sourceID.uuidString)
        try db.run(existing.delete())

        // Add new relationships
        for tagID in tagIDs {
            try db.run(sourceTagsTable.insert(or: .ignore,
                stSourceIdCol <- sourceID.uuidString,
                stTagIdCol <- tagID.uuidString
            ))
        }

        // Update source's tagIDs column
        let tagIDsStr = tagIDs.map { $0.uuidString }.joined(separator: ",")
        let source = sourcesTable.filter(idCol == sourceID.uuidString)
        try db.run(source.update(tagIDsCol <- tagIDsStr))
    }

    func findRelatedSources(for source: Source, topK: Int = 5) async throws -> [Source] {
        guard let db = db else { return [] }

        let allSources = try await fetchAllSources()
        let keywords = extractKeywords(from: source.content + " " + source.title)

        var scored: [(Source, Double)] = []

        for other in allSources where other.id != source.id {
            let otherKeywords = extractKeywords(from: other.content + " " + other.title)
            let overlap = keywords.filter { otherKeywords.contains($0) }
            if !overlap.isEmpty {
                let score = Double(overlap.count) / Double(max(keywords.count, otherKeywords.count))
                scored.append((other, score))
            }
        }

        scored.sort { $0.1 > $1.1 }
        return Array(scored.prefix(topK)).map { $0.0 }
    }

    private func extractKeywords(from text: String) -> Set<String> {
        let stopWords: Set<String> = ["the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by", "is", "are", "was", "were", "be", "been", "being", "have", "has", "had", "do", "does", "did", "will", "would", "could", "should", "may", "might", "must", "can", "this", "that", "these", "those", "i", "you", "he", "she", "it", "we", "they", "what", "which", "who", "when", "where", "why", "how", "all", "each", "every", "both", "few", "more", "most", "other", "some", "such", "no", "nor", "not", "only", "own", "same", "so", "than", "too", "very", "just", "about", "into", "over", "after", "before", "between", "under", "again", "further", "then", "once", "here", "there", "any", "from", "up", "down", "out", "off", "above", "below"]
        let words = text.lowercased().components(separatedBy: .punctuationCharacters).joined().split(separator: " ").map(String.init)
        return Set(words.filter { $0.count > 3 && !stopWords.contains($0) })
    }

    func searchSources(query: String) async throws -> [SearchResult] {
        let allSources = try await fetchAllSources()
        let lowercasedQuery = query.lowercased()
        let queryKeywords = extractKeywords(from: query)

        var results: [SearchResult] = []

        for source in allSources {
            let titleMatch = source.title.lowercased().contains(lowercasedQuery)
            let contentMatch = source.content.lowercased().contains(lowercasedQuery)

            guard titleMatch || contentMatch else { continue }

            let contentKeywords = extractKeywords(from: source.content)
            let keywordOverlap = queryKeywords.filter { contentKeywords.contains($0) }
            let keywordScore = Double(keywordOverlap.count) / Double(max(queryKeywords.count, 1))

            var score = 0.0
            if titleMatch { score += 0.5 }
            if contentMatch { score += 0.3 }
            score += keywordScore * 0.2

            // Find the matching chunk
            let chunk = findMatchingChunk(in: source.content, query: query)

            results.append(SearchResult(id: source.id, source: source, score: score, chunk: chunk))
        }

        results.sort { $0.score > $1.score }
        return results
    }

    private func findMatchingChunk(in content: String, query: String, maxLength: Int = 200) -> String {
        let lowercasedContent = content.lowercased()
        let words = query.lowercased().split(separator: " ").filter { $0.count > 2 }.map(String.init)

        for word in words {
            if let range = lowercasedContent.range(of: word) {
                let start = content.index(range.lowerBound, offsetBy: -min(60, content.distance(from: content.startIndex, to: range.lowerBound)), limitedBy: content.startIndex) ?? content.startIndex
                let end = content.index(range.upperBound, offsetBy: min(100, content.distance(from: range.upperBound, to: content.endIndex)), limitedBy: content.endIndex) ?? content.endIndex
                var excerpt = String(content[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                if start != content.startIndex { excerpt = "..." + excerpt }
                if end != content.endIndex { excerpt = excerpt + "..." }
                return excerpt
            }
        }

        if content.count <= maxLength { return content }
        return String(content.prefix(maxLength)) + "..."
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
