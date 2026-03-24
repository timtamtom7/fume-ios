import Foundation
import UniformTypeIdentifiers

// MARK: - Import Source Type
enum ImportSourceType: String, CaseIterable, Identifiable {
    case obsidian = "Obsidian"
    case notion = "Notion"
    case appleNotes = "Apple Notes"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .obsidian: return "folder.fill"
        case .notion: return "doc.richtext"
        case .appleNotes: return "note.text"
        }
    }

    var color: String {
        switch self {
        case .obsidian: return "8b5cf6"
        case .notion: return "ffffff"
        case .appleNotes: return "f59e0b"
        }
    }

    var supportedExtensions: [String] {
        switch self {
        case .obsidian: return ["md", "txt"]
        case .notion: return ["md", "txt"]
        case .appleNotes: return ["txt", "md"]
        }
    }

    var description: String {
        switch self {
        case .obsidian: return "Import from your Obsidian vault"
        case .notion: return "Import from Notion markdown export"
        case .appleNotes: return "Import from Apple Notes text"
        }
    }
}

// MARK: - Imported File
struct ImportedFile: Identifiable {
    let id: UUID = UUID()
    let name: String
    let content: String
    let type: ImportSourceType
    let url: String?
    let createdAt: Date
}

// MARK: - File Import Service
actor FileImportService {
    static let shared = FileImportService()

    private init() {}

    func importFiles(urls: [URL]) async throws -> [ImportedFile] {
        var imported: [ImportedFile] = []

        for url in urls {
            guard url.startAccessingSecurityScopedResource() else {
                throw ImportError.accessDenied
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let data = try Data(contentsOf: url)
            guard let content = String(data: data, encoding: .utf8) else {
                throw ImportError.encodingError
            }

            let detectedType = detectSourceType(from: url, content: content)
            let name = url.deletingPathExtension().lastPathComponent
            let fileCreatedAt: Date = {
                let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
                return (attrs?[.creationDate] as? Date) ?? Date()
            }()

            let file = ImportedFile(
                name: name,
                content: content,
                type: detectedType,
                url: nil,
                createdAt: fileCreatedAt
            )
            imported.append(file)
        }

        return imported
    }

    func parseObsidianFile(_ content: String, name: String) -> (title: String, content: String) {
        var title = name
        var body = content

        // Check for YAML frontmatter
        if content.hasPrefix("---") {
            let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
            var frontmatterEnd = 0
            for (i, line) in lines.enumerated() {
                if i > 0 && line.trimmingCharacters(in: .whitespaces) == "---" {
                    frontmatterEnd = i
                    break
                }
            }

            if frontmatterEnd > 0 {
                let frontmatter = lines[1..<frontmatterEnd].joined(separator: "\n")
                // Extract title from frontmatter
                if let titleLine = frontmatter.split(separator: "\n").first(where: { $0.hasPrefix("title:") }) {
                    title = String(titleLine.dropFirst("title:".count)).trimmingCharacters(in: .whitespaces)
                    if title.hasPrefix("\"") && title.hasSuffix("\"") {
                        title = String(title.dropFirst().dropLast())
                    }
                }
                body = lines[(frontmatterEnd + 1)...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Fall back to first H1 heading as title
        if title == name {
            let lines = body.split(separator: "\n")
            if let h1 = lines.first(where: { $0.hasPrefix("# ") }) {
                title = String(h1.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
        }

        return (title, body)
    }

    func parseNotionMarkdown(_ content: String, name: String) -> (title: String, content: String) {
        var title = name
        var body = content

        // Notion exports often have title as first line or in properties block
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        // Look for title in first non-empty line
        if let firstLine = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            if firstLine.hasPrefix("# ") {
                title = String(firstLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                body = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Strip Notion-specific blocks
        body = stripNotionBlocks(body)

        return (title, body)
    }

    func parseAppleNotesText(_ content: String, name: String) -> (title: String, content: String) {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var title = name
        var body = content

        // First non-empty line might be the title
        if let firstLine = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
            if trimmed.count < 100 && !trimmed.contains(".") {
                title = trimmed
                body = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return (title, body)
    }

    private func detectSourceType(from url: URL, content: String) -> ImportSourceType {
        let ext = url.pathExtension.lowercased()

        // Check content characteristics
        if content.hasPrefix("---") && content.contains("tags:") {
            return .obsidian
        }
        if content.contains("## ") && content.contains("**") && !content.hasPrefix("---") {
            return .notion
        }
        if ext == "txt" && !content.contains("---") && !content.contains("**") {
            return .appleNotes
        }

        return ext == "md" ? .obsidian : .appleNotes
    }

    private func stripNotionBlocks(_ content: String) -> String {
        var result = content

        // Remove callout blocks
        let calloutPattern = try? NSRegularExpression(pattern: "> \\[!\\w+\\].*?(\\n>.*?)*", options: [.dotMatchesLineSeparators])
        result = calloutPattern?.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "") ?? result

        // Remove database table blocks
        let tablePattern = try? NSRegularExpression(pattern: "\\|.*?\\|\n\\|[-: ]+\\|\n((?:\\|.*?\\|\n?)*)", options: [])
        result = tablePattern?.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "") ?? result

        return result
    }

    func convertToSource(_ file: ImportedFile) -> Source {
        let (title, content): (String, String)

        switch file.type {
        case .obsidian:
            let parsed = parseObsidianFile(file.content, name: file.name)
            title = parsed.title
            content = parsed.content
        case .notion:
            let parsed = parseNotionMarkdown(file.content, name: file.name)
            title = parsed.title
            content = parsed.content
        case .appleNotes:
            let parsed = parseAppleNotesText(file.content, name: file.name)
            title = parsed.title
            content = parsed.content
        }

        return Source(
            type: .note,
            title: title,
            content: content,
            url: file.url,
            createdAt: file.createdAt,
            updatedAt: file.createdAt
        )
    }
}

// MARK: - Import Errors
enum ImportError: Error, LocalizedError {
    case accessDenied
    case encodingError
    case parseError
    case unsupportedFormat
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .accessDenied: return "Could not access the selected file."
        case .encodingError: return "The file encoding is not supported."
        case .parseError: return "Could not parse the file content."
        case .unsupportedFormat: return "This file format is not supported."
        case .emptyContent: return "The file appears to be empty."
        }
    }
}
