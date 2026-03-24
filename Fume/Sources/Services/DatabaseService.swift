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
        })
    }

    func insertSource(_ source: Source) async throws {
        guard let db = db else { return }

        let embeddingStr = source.embedding.map { embed in
            embed.map { String($0) }.joined(separator: ",")
        }

        let insert = sourcesTable.insert(
            idCol <- source.id.uuidString,
            typeCol <- source.type.rawValue,
            titleCol <- source.title,
            contentCol <- source.content,
            urlCol <- source.url,
            thumbnailCol <- source.thumbnailData,
            createdAtCol <- source.createdAt.timeIntervalSince1970,
            updatedAtCol <- source.updatedAt.timeIntervalSince1970,
            embeddingCol <- embeddingStr
        )

        try db.run(insert)
    }

    func fetchAllSources() async throws -> [Source] {
        guard let db = db else { return [] }

        var sources: [Source] = []
        for row in try db.prepare(sourcesTable.order(createdAtCol.desc)) {
            let embedding: [Float]? = row[embeddingCol]?.split(separator: ",").compactMap {
                Float(String($0))
            }

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
                embedding: embedding
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
            embedding: embedding
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

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
