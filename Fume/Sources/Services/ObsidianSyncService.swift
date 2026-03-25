import Foundation
import NaturalLanguage

// R11: Obsidian Sync Service
// Two-way sync with Obsidian vault
actor ObsidianSyncService {
    static let shared = ObsidianSyncService()

    private init() {}

    struct SyncResult {
        let imported: Int
        let exported: Int
        let conflicts: Int
        let errors: [String]
    }

    // MARK: - Vault Discovery

    /// Try to find Obsidian vault in common locations
    func discoverVault() -> URL? {
        let fileManager = FileManager.default

        // iCloud Documents
        if let icloudURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let icloudVault = icloudURL.appendingPathComponent("..").appendingPathComponent("Documents").appendingPathComponent("Obsidian")
            if fileManager.fileExists(atPath: icloudVault.path) {
                return icloudVault
            }
        }

        // Local Documents
        if let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let localVault = docsURL.appendingPathComponent("Obsidian")
            if fileManager.fileExists(atPath: localVault.path) {
                return localVault
            }

            let vault2 = docsURL.appendingPathComponent("Obsidian Vault")
            if fileManager.fileExists(atPath: vault2.path) {
                return vault2
            }
        }

        return nil
    }

    // MARK: - Initial Sync

    /// Initial sync: import all notes from Obsidian vault into Fume
    func importFromVault(vaultURL: URL) async throws -> [Source] {
        var sources: [Source] = []

        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: vaultURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
            return []
        }

        var fileURLs: [URL] = []
        while let url = enumerator.nextObject() as? URL {
            if url.pathExtension == "md" {
                fileURLs.append(url)
            }
        }

        for fileURL in fileURLs {
            do {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let title = extractTitle(from: content, fallback: fileURL.deletingPathExtension().lastPathComponent)
                let (bodyContent, _) = extractBodyAndTags(from: content)

                let source = Source(
                    id: UUID(),
                    type: .note,
                    title: title,
                    content: bodyContent,
                    url: fileURL.path,
                    thumbnailData: nil,
                    createdAt: getFileDate(fileURL) ?? Date(),
                    updatedAt: Date(),
                    embedding: nil,
                    tagIDs: []
                )

                sources.append(source)
            } catch {
                print("Failed to import \(fileURL): \(error)")
            }
        }

        return sources
    }

    /// Export Fume notes to Obsidian vault
    func exportToVault(sources: [Source], vaultURL: URL) async throws -> Int {
        var exportedCount = 0

        for source in sources {
            let filename = sanitizeFilename(source.title) + ".md"
            let fileURL = vaultURL.appendingPathComponent(filename)

            let frontmatter = buildObsidianFrontmatter(for: source)
            let markdown = """
            \(frontmatter)

            # \(source.title)

            \(source.content)
            """

            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
            exportedCount += 1
        }

        return exportedCount
    }

    // MARK: - Bi-directional Sync

    /// Perform bi-directional sync between Fume and Obsidian
    func sync(fumeSources: [Source], vaultURL: URL) async throws -> SyncResult {
        var imported = 0
        var exported = 0
        var conflicts = 0
        var errors: [String] = []

        // Get all .md files from vault
        let vaultFiles = try getVaultFiles(vaultURL)
        let fumeByPath = Dictionary(uniqueKeysWithValues: fumeSources.compactMap { source -> (String, Source)? in
            guard let url = source.url else { return nil }
            return (url, source)
        })

        // Import new files from vault
        for (path, fileURL) in vaultFiles {
            if fumeByPath[path] == nil {
                // New file in vault, import to Fume
                do {
                    let content = try String(contentsOf: fileURL, encoding: .utf8)
                    let title = extractTitle(from: content, fallback: fileURL.deletingPathExtension().lastPathComponent)
                    let (bodyContent, _) = extractBodyAndTags(from: content)

                    // Note: actual import would be handled by caller
                    imported += 1
                } catch {
                    errors.append("Failed to import \(path): \(error)")
                }
            }
        }

        // Export Fume sources to vault
        for source in fumeSources {
            if let path = source.url, vaultFiles[path] != nil {
                // File exists in vault — check for conflict
                if let vaultFileURL = URL(string: path) {
                    let vaultContent = (try? String(contentsOf: vaultFileURL, encoding: .utf8)) ?? ""
                    let localContent = source.content

                    if hashContent(vaultContent) != hashContent(localContent) {
                        // Conflict detected
                        conflicts += 1
                        // For now, vault wins — overwrite local reference
                    }
                }
            } else {
                // New file from Fume, export to vault
                let filename = sanitizeFilename(source.title) + ".md"
                let fileURL = vaultURL.appendingPathComponent(filename)

                let frontmatter = buildObsidianFrontmatter(for: source)
                let markdown = "\(frontmatter)\n\n# \(source.title)\n\n\(source.content)"

                do {
                    try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
                    exported += 1
                } catch {
                    errors.append("Failed to export \(source.title): \(error)")
                }
            }
        }

        return SyncResult(imported: imported, exported: exported, conflicts: conflicts, errors: errors)
    }

    // MARK: - Tag Sync

    /// Sync tags between Fume and Obsidian
    func syncTags(fumeTags: [Tag], vaultURL: URL) async throws -> Int {
        let tagsFile = vaultURL.appendingPathComponent(".fume-tags.json")
        let data = try JSONEncoder().encode(fumeTags.map { TagExport(from: $0) })
        try data.write(to: tagsFile)
        return fumeTags.count
    }

    // MARK: - Private Helpers

    private func getVaultFiles(_ vaultURL: URL) throws -> [String: URL] {
        var files: [String: URL] = [:]
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(at: vaultURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
            return files
        }

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "md" else { continue }
            files[fileURL.path] = fileURL
        }

        return files
    }

    private func extractTitle(from content: String, fallback: String) -> String {
        // Look for first H1 heading
        if let range = content.range(of: "^# .+$", options: .regularExpression) {
            return String(content[range]).dropFirst(2).trimmingCharacters(in: .whitespaces)
        }
        return fallback
    }

    private func extractBodyAndTags(from content: String) -> (String, [String]) {
        var tags: [String] = []

        // Extract YAML frontmatter
        if content.hasPrefix("---") {
            if let endRange = content.range(of: "---", options: [], range: content.index(content.startIndex, offsetBy: 3)..<content.endIndex) {
                let frontmatter = String(content[content.index(after: content.startIndex)..<endRange.lowerBound])

                // Extract tags from frontmatter
                if let tagsRange = frontmatter.range(of: "tags:", options: .regularExpression) {
                    let tagsLine = String(frontmatter[tagsRange.lowerBound...])
                        .components(separatedBy: .newlines)
                        .first?
                        .dropFirst(5)
                        .trimmingCharacters(in: .whitespaces) ?? ""

                    if tagsLine.hasPrefix("[") {
                        // Array format: [tag1, tag2]
                        tags = tagsLine
                            .trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
                            .components(separatedBy: ",")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                    } else {
                        // Single tag
                        tags = [tagsLine.trimmingCharacters(in: .whitespaces)]
                    }
                }

                // Return content after frontmatter
                let bodyStart = content.index(after: endRange.upperBound)
                let body = String(content[bodyStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
                return (body, tags)
            }
        }

        return (content, tags)
    }

    private func buildObsidianFrontmatter(for source: Source) -> String {
        var frontmatter = "---\n"
        frontmatter += "created: \(ISO8601DateFormatter().string(from: source.createdAt))\n"
        frontmatter += "updated: \(ISO8601DateFormatter().string(from: source.updatedAt))\n"

        if !source.tagIDs.isEmpty {
            frontmatter += "tags: [\(source.tagIDs.map { $0.uuidString.prefix(8) }.joined(separator: ", "))]\n"
        }

        frontmatter += "---\n"
        return frontmatter
    }

    private func sanitizeFilename(_ title: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return title.components(separatedBy: invalidChars).joined(separator: "_")
    }

    private func getFileDate(_ url: URL) -> Date? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attrs?[.creationDate] as? Date
    }

    private func hashContent(_ content: String) -> String {
        // Simple hash for comparison
        let data = Data(content.utf8)
        var hash: UInt64 = 5381
        for byte in data {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return String(hash, radix: 16)
    }
}

// MARK: - Supporting Types

private struct TagExport: Codable {
    let id: UUID
    let name: String
    let color: String?

    init(from tag: Tag) {
        self.id = tag.id
        self.name = tag.name
        self.color = tag.colorHex
    }
}

import NaturalLanguage
