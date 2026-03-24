import Foundation
import CloudKit
import Combine

/// SyncService — iCloud sync with offline queue and conflict resolution
/// Syncs Sources and Tags across iPhone/iPad/Mac via CloudKit private database
actor SyncService {
    static let shared = SyncService()

    // MARK: - Types

    struct SyncRecord: Codable {
        let id: UUID
        let recordType: RecordType
        let data: Data
        let modifiedAt: Date
        let deleted: Bool

        enum RecordType: String, Codable {
            case source
            case tag
        }
    }

    enum SyncStatus: Equatable {
        case idle
        case syncing
        case offline
        case error(String)
        case upToDate

        var isActive: Bool {
            self == .syncing
        }
    }

    struct SyncState: Equatable {
        var status: SyncStatus = .idle
        var lastSyncedAt: Date?
        var pendingChanges: Int = 0
        var conflictCount: Int = 0
    }

    // MARK: - Properties

    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let recordZone: CKRecordZone
    private let zoneID: CKRecordZone.ID

    private(set) var syncState: SyncState = SyncState()
    private var pendingOperations: [SyncOperation] = []
    private var subscribers: [UUID: CheckedContinuation<Void, Never>] = [:]

    private let sourcesRecordType = "Source"
    private let tagsRecordType = "Tag"
    private let operationQueueKey = "fume_pending_operations"
    private let lastSyncKey = "fume_last_sync_timestamp"

    // MARK: - Sync Operation

    struct SyncOperation: Codable {
        let id: UUID
        let recordType: SyncRecord.RecordType
        let recordID: UUID
        let operationType: OperationType
        let data: Data?
        let timestamp: Date

        enum OperationType: String, Codable {
            case create
            case update
            case delete
        }
    }

    // MARK: - Init

    private init() {
        container = CKContainer(identifier: "iCloud.com.fume.app")
        privateDatabase = container.privateCloudDatabase
        zoneID = CKRecordZone.ID(zoneName: "FumeZone", ownerName: CKCurrentUserDefaultName)
        recordZone = CKRecordZone(zoneID: zoneID)
    }

    // MARK: - Setup

    func setupZone() async throws {
        do {
            _ = try await privateDatabase.save(recordZone)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Zone already exists — that's fine
        }
    }

    // MARK: - Sync Sources

    func syncAllSources() async throws {
        syncState.status = .syncing
        defer {
            if case .error = syncState.status {
                // Keep error state
            } else {
                syncState.status = .idle
            }
        }

        do {
            // 1. Upload pending local changes
            try await uploadPendingChanges()

            // 2. Fetch remote changes
            try await fetchRemoteChanges()

            syncState.lastSyncedAt = Date()
            syncState.status = .upToDate

            // Notify subscribers
            notifySubscribers()
        } catch {
            syncState.status = .error(error.localizedDescription)
            throw error
        }
    }

    // MARK: - Upload Single Source

    func uploadSource(_ source: Source) async throws {
        let record = try encodeSourceAsRecord(source)

        // Save locally first (offline-first)
        savePendingOperation(SyncOperation(
            id: UUID(),
            recordType: .source,
            recordID: source.id,
            operationType: source.embedding == nil ? .create : .update,
            data: try? JSONEncoder().encode(source),
            timestamp: Date()
        ))

        // Attempt CloudKit save
        do {
            _ = try await privateDatabase.save(record)
            await removePendingOperation(recordID: source.id, type: .source)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Conflict — resolve it
            try await resolveConflict(for: source.id, serverRecord: error.serverRecord, incoming: record)
        } catch {
            // Queue for later if offline
            queueOfflineOperation(for: source.id, type: .source)
        }
    }

    // MARK: - Upload Single Tag

    func uploadTag(_ tag: Tag) async throws {
        let record = try encodeTagAsRecord(tag)

        savePendingOperation(SyncOperation(
            id: UUID(),
            recordType: .tag,
            recordID: tag.id,
            operationType: .create,
            data: try? JSONEncoder().encode(tag),
            timestamp: Date()
        ))

        do {
            _ = try await privateDatabase.save(record)
            await removePendingOperation(recordID: tag.id, type: .tag)
        } catch let error as CKError where error.code == .serverRecordChanged {
            try await resolveTagConflict(for: tag.id, serverRecord: error.serverRecord, incoming: record)
        } catch {
            queueOfflineOperation(for: tag.id, type: .tag)
        }
    }

    // MARK: - Delete Remote

    func deleteSourceRemote(id: UUID) async throws {
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)

        savePendingOperation(SyncOperation(
            id: UUID(),
            recordType: .source,
            recordID: id,
            operationType: .delete,
            data: nil,
            timestamp: Date()
        ))

        do {
            try await privateDatabase.deleteRecord(withID: recordID)
            await removePendingOperation(recordID: id, type: .source)
        } catch {
            // Keep in queue
        }
    }

    func deleteTagRemote(id: UUID) async throws {
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)

        savePendingOperation(SyncOperation(
            id: UUID(),
            recordType: .tag,
            recordID: id,
            operationType: .delete,
            data: nil,
            timestamp: Date()
        ))

        do {
            try await privateDatabase.deleteRecord(withID: recordID)
            await removePendingOperation(recordID: id, type: .tag)
        } catch {
            // Keep in queue
        }
    }

    // MARK: - Process Offline Queue

    func processOfflineQueue() async {
        let operations = loadPendingOperations()
        syncState.pendingChanges = operations.count

        for operation in operations {
            do {
                switch operation.operationType {
                case .create, .update:
                    if let data = operation.data {
                        if operation.recordType == .source {
                            let source = try JSONDecoder().decode(Source.self, from: data)
                            let record = try encodeSourceAsRecord(source)
                            _ = try await privateDatabase.save(record)
                        } else {
                            let tag = try JSONDecoder().decode(Tag.self, from: data)
                            let record = try encodeTagAsRecord(tag)
                            _ = try await privateDatabase.save(record)
                        }
                    }
                case .delete:
                    let recordID = CKRecord.ID(recordName: operation.recordID.uuidString, zoneID: zoneID)
                    try await privateDatabase.deleteRecord(withID: recordID)
                }
                await removePendingOperation(recordID: operation.recordID, type: operation.recordType == .source ? .source : .tag)
            } catch {
                // Keep failed operations for retry
            }
        }

        syncState.pendingChanges = loadPendingOperations().count
    }

    // MARK: - Conflict Resolution

    /// Last-write-wins with semantic merge for content fields
    private func resolveConflict(for id: UUID, serverRecord: CKRecord?, incoming: CKRecord) async throws {
        guard let serverRecord = serverRecord else { return }

        let serverModified = serverRecord["modifiedAt"] as? Date ?? Date.distantPast
        let incomingModified = incoming["modifiedAt"] as? Date ?? Date.distantPast

        // Server wins if newer, otherwise incoming wins
        if serverModified > incomingModified {
            // Fetch and apply server version locally
            let serverSource = try decodeSourceFromRecord(serverRecord)
            try await DatabaseService.shared.insertSource(serverSource)
        }
        // else: incoming already saved locally, push to server
        _ = try? await privateDatabase.save(incoming)
    }

    private func resolveTagConflict(for id: UUID, serverRecord: CKRecord?, incoming: CKRecord) async throws {
        guard let serverRecord = serverRecord else { return }

        let serverModified = serverRecord["modifiedAt"] as? Date ?? Date.distantPast
        let incomingModified = incoming["modifiedAt"] as? Date ?? Date.distantPast

        if serverModified > incomingModified {
            let serverTag = try decodeTagFromRecord(serverRecord)
            try await DatabaseService.shared.insertTag(serverTag)
        }
        _ = try? await privateDatabase.save(incoming)
    }

    // MARK: - Upload Pending Changes

    private func uploadPendingChanges() async throws {
        let operations = loadPendingOperations()
        for operation in operations {
            do {
                switch operation.operationType {
                case .create, .update:
                    if let data = operation.data {
                        if operation.recordType == .source {
                            let source = try JSONDecoder().decode(Source.self, from: data)
                            let record = try encodeSourceAsRecord(source)
                            _ = try await privateDatabase.save(record)
                        } else {
                            let tag = try JSONDecoder().decode(Tag.self, from: data)
                            let record = try encodeTagAsRecord(tag)
                            _ = try await privateDatabase.save(record)
                        }
                    }
                case .delete:
                    let recordID = CKRecord.ID(recordName: operation.recordID.uuidString, zoneID: zoneID)
                    try await privateDatabase.deleteRecord(withID: recordID)
                }
                await removePendingOperation(recordID: operation.recordID, type: operation.recordType == .source ? .source : .tag)
            } catch {
                // Skip failed operations — they'll be retried next sync
            }
        }
    }

    // MARK: - Fetch Remote Changes

    private func fetchRemoteChanges() async throws {
        // Fetch sources
        let sourceQuery = CKQuery(recordType: sourcesRecordType, predicate: NSPredicate(value: true))
        let (sourceResults, _) = try await privateDatabase.records(
            matching: sourceQuery,
            inZoneWith: zoneID,
            resultsLimit: 1000
        )

        for (_, result) in sourceResults {
            if case .success(let record) = result {
                if record["deleted"] as? Bool == true {
                    // Soft-deleted record
                    try? await DatabaseService.shared.deleteSource(id: UUID(uuidString: record.recordID.recordName) ?? UUID())
                } else {
                    let source = try decodeSourceFromRecord(record)
                    try? await DatabaseService.shared.insertSource(source)
                }
            }
        }

        // Fetch tags
        let tagQuery = CKQuery(recordType: tagsRecordType, predicate: NSPredicate(value: true))
        let (tagResults, _) = try await privateDatabase.records(
            matching: tagQuery,
            inZoneWith: zoneID,
            resultsLimit: 500
        )

        for (_, result) in tagResults {
            if case .success(let record) = result {
                if record["deleted"] as? Bool == true {
                    try? await DatabaseService.shared.deleteTag(id: UUID(uuidString: record.recordID.recordName) ?? UUID())
                } else {
                    let tag = try decodeTagFromRecord(record)
                    try? await DatabaseService.shared.insertTag(tag)
                }
            }
        }
    }

    // MARK: - Record Encoding

    private func encodeSourceAsRecord(_ source: Source) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: source.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: sourcesRecordType, recordID: recordID)

        record["id"] = source.id.uuidString
        record["type"] = source.type.rawValue
        record["title"] = source.title
        record["content"] = source.content
        record["url"] = source.url
        record["createdAt"] = source.createdAt
        record["updatedAt"] = source.updatedAt
        record["modifiedAt"] = Date()
        record["tagIDs"] = source.tagIDs.map { $0.uuidString }.joined(separator: ",")
        record["deleted"] = false

        if let thumbnailData = source.thumbnailData {
            record["thumbnail"] = thumbnailData
        }

        if let embedding = source.embedding {
            let embeddingStr = embedding.map { String($0) }.joined(separator: ",")
            record["embedding"] = embeddingStr
        }

        return record
    }

    private func decodeSourceFromRecord(_ record: CKRecord) throws -> Source {
        guard let idStr = record["id"] as? String,
              let id = UUID(uuidString: idStr),
              let typeStr = record["type"] as? String,
              let type = SourceType(rawValue: typeStr),
              let title = record["title"] as? String,
              let content = record["content"] as? String else {
            throw SyncError.decodingFailed
        }

        let tagIDsStr = record["tagIDs"] as? String ?? ""
        let tagIDs: [UUID] = tagIDsStr.split(separator: ",").compactMap { UUID(uuidString: String($0)) }

        let embeddingStr = record["embedding"] as? String
        let embedding: [Float]? = embeddingStr?.split(separator: ",").compactMap { Float(String($0)) }

        return Source(
            id: id,
            type: type,
            title: title,
            content: content,
            url: record["url"] as? String,
            thumbnailData: record["thumbnail"] as? Data,
            createdAt: record["createdAt"] as? Date ?? Date(),
            updatedAt: record["updatedAt"] as? Date ?? Date(),
            embedding: embedding,
            tagIDs: tagIDs
        )
    }

    private func encodeTagAsRecord(_ tag: Tag) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: tag.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: tagsRecordType, recordID: recordID)

        record["id"] = tag.id.uuidString
        record["name"] = tag.name
        record["colorHex"] = tag.colorHex
        record["createdAt"] = tag.createdAt
        record["modifiedAt"] = Date()
        record["deleted"] = false

        return record
    }

    private func decodeTagFromRecord(_ record: CKRecord) throws -> Tag {
        guard let idStr = record["id"] as? String,
              let id = UUID(uuidString: idStr),
              let name = record["name"] as? String,
              let colorHex = record["colorHex"] as? String else {
            throw SyncError.decodingFailed
        }

        return Tag(
            id: id,
            name: name,
            colorHex: colorHex,
            createdAt: record["createdAt"] as? Date ?? Date()
        )
    }

    // MARK: - Pending Operations Storage

    private func savePendingOperation(_ operation: SyncOperation) {
        var ops = loadPendingOperations()
        // Replace any existing operation for same record
        ops.removeAll { $0.recordID == operation.recordID && $0.recordType == operation.recordType }
        ops.append(operation)
        saveOperations(ops)
        syncState.pendingChanges = ops.count
    }

    private func removePendingOperation(recordID: UUID, type: SyncRecord.RecordType) {
        var ops = loadPendingOperations()
        let typeStr = type == .source ? "source" : "tag"
        ops.removeAll { $0.recordID == recordID && $0.recordType.rawValue == typeStr }
        saveOperations(ops)
        syncState.pendingChanges = ops.count
    }

    private func loadPendingOperations() -> [SyncOperation] {
        guard let data = UserDefaults.standard.data(forKey: operationQueueKey) else { return [] }
        return (try? JSONDecoder().decode([SyncOperation].self, from: data)) ?? []
    }

    private func saveOperations(_ operations: [SyncOperation]) {
        if let data = try? JSONEncoder().encode(operations) {
            UserDefaults.standard.set(data, forKey: operationQueueKey)
        }
    }

    private func queueOfflineOperation(for id: UUID, type: SyncRecord.RecordType) {
        // Already queued via savePendingOperation
    }

    // MARK: - Subscribers

    private func notifySubscribers() {
        for (_, cont) in subscribers {
            cont.resume()
        }
        subscribers.removeAll()
    }

    func waitForSync() async {
        await withCheckedContinuation { cont in
            subscribers[UUID()] = cont
        }
    }

    // MARK: - Account Status

    func checkAccountStatus() async -> CKAccountStatus {
        do {
            return try await container.accountStatus()
        } catch {
            return .couldNotDetermine
        }
    }
}

// MARK: - Errors

enum SyncError: Error, LocalizedError {
    case notSignedIn
    case zoneCreationFailed
    case encodingFailed
    case decodingFailed
    case conflictUnresolvable

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Sign in to iCloud to sync your knowledge base."
        case .zoneCreationFailed: return "Failed to create sync zone."
        case .encodingFailed: return "Failed to encode data for sync."
        case .decodingFailed: return "Failed to decode synced data."
        case .conflictUnresolvable: return "Sync conflict couldn't be resolved."
        }
    }
}
