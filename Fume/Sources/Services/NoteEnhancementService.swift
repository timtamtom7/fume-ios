import Foundation
import NaturalLanguage

// R11: Note Enhancement Service
// Auto-linking backlinks, orphan note detection, Zettelkasten IDs, merge tool
actor NoteEnhancementService {
    static let shared = NoteEnhancementService()

    private init() {}

    // MARK: - Auto-linking / Backlinks

    /// Find potential links between notes based on content similarity and keyword matching
    func findPotentialLinks(in notes: [Source]) -> [NoteLink] {
        var links: [NoteLink] = []

        for i in 0..<notes.count {
            for j in (i + 1)..<notes.count {
                let noteA = notes[i]
                let noteB = notes[j]

                // Check if noteA mentions noteB's title
                if noteA.content.localizedCaseInsensitiveContains(noteB.title) {
                    links.append(NoteLink(
                        sourceId: noteA.id,
                        targetId: noteB.id,
                        type: .mentions,
                        anchor: noteB.title
                    ))
                }

                // Check if noteB mentions noteA's title
                if noteB.content.localizedCaseInsensitiveContains(noteA.title) {
                    links.append(NoteLink(
                        sourceId: noteB.id,
                        targetId: noteA.id,
                        type: .mentions,
                        anchor: noteA.title
                    ))
                }

                // Check keyword overlap
                let keywordsA = extractKeywords(from: noteA.content)
                let keywordsB = extractKeywords(from: noteB.content)
                let overlap = keywordsA.intersection(keywordsB)

                if overlap.count >= 3 {
                    links.append(NoteLink(
                        sourceId: noteA.id,
                        targetId: noteB.id,
                        type: .keywordRelated,
                        anchor: nil
                    ))
                }
            }
        }

        return links
    }

    /// Generate backlinks for a specific note
    func backlinks(for noteId: UUID, in links: [NoteLink]) -> [NoteLink] {
        links.filter { $0.targetId == noteId }
    }

    // MARK: - Orphan Detection

    /// Find notes with no incoming or outgoing links
    func findOrphanNotes(notes: [Source], links: [NoteLink]) -> [Source] {
        let linkedNoteIds = Set(links.flatMap { [$0.sourceId, $0.targetId] })
        return notes.filter { !linkedNoteIds.contains($0.id) }
    }

    /// Find notes with most links (hub notes)
    func findHubNotes(notes: [Source], links: [NoteLink], limit: Int = 10) -> [(Source, Int)] {
        var linkCounts: [UUID: Int] = [:]

        for link in links {
            linkCounts[link.sourceId, default: 0] += 1
            linkCounts[link.targetId, default: 0] += 1
        }

        return notes
            .compactMap { note -> (Source, Int)? in
                guard let count = linkCounts[note.id] else { return nil }
                return (note, count)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { ($0.0, $0.1) }
    }

    // MARK: - Zettelkasten IDs

    /// Generate a unique Zettelkasten-style ID (YYYYMMDDHHMMSS format)
    func generateZettelId() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter.string(from: Date())
    }

    /// Assign Zettel IDs to notes (stored separately from Source)
    func assignZettelIds(to notes: [Source]) -> [UUID: String] {
        var result: [UUID: String] = [:]
        for note in notes {
            result[note.id] = generateZettelId()
        }
        return result
    }

    // MARK: - Merge Tool

    /// Find potential duplicate notes based on title and content similarity
    func findDuplicates(in notes: [Source], threshold: Double = 0.8) -> [[Source]] {
        var duplicateGroups: [[Source]] = []
        var processed: Set<UUID> = []

        for i in 0..<notes.count {
            guard !processed.contains(notes[i].id) else { continue }

            var group: [Source] = [notes[i]]

            for j in (i + 1)..<notes.count {
                guard !processed.contains(notes[j].id) else { continue }

                let similarity = computeSimilarity(notes[i], notes[j])
                if similarity >= threshold {
                    group.append(notes[j])
                    processed.insert(notes[j].id)
                }
            }

            if group.count > 1 {
                processed.insert(notes[i].id)
                duplicateGroups.append(group)
            }
        }

        return duplicateGroups
    }

    /// Merge multiple notes into one
    func mergeNotes(_ notes: [Source], newTitle: String?) -> Source {
        let sorted = notes.sorted { $0.createdAt < $1.createdAt }
        let combinedContent = sorted.map { "## \($0.title)\n\n\($0.content)" }.joined(separator: "\n\n---\n\n")

        let mergedNote = Source(
            id: UUID(),
            type: .note,
            title: newTitle ?? "Merged Note (\(sorted.count) notes)",
            content: combinedContent,
            url: nil,
            thumbnailData: nil,
            createdAt: sorted.first?.createdAt ?? Date(),
            updatedAt: Date(),
            embedding: nil,
            tagIDs: Array(Set(sorted.flatMap { $0.tagIDs }))
        )

        return mergedNote
    }

    // MARK: - Private Helpers

    private func extractKeywords(from text: String) -> Set<String> {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text

        var keywords: Set<String> = []

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            if tag == .noun || tag == .verb {
                let word = String(text[range]).lowercased()
                if word.count > 3 {
                    keywords.insert(word)
                }
            }
            return true
        }

        return keywords
    }

    private func computeSimilarity(_ a: Source, _ b: Source) -> Double {
        let wordsA = Set(a.content.lowercased().split(separator: " ").map(String.init))
        let wordsB = Set(b.content.lowercased().split(separator: " ").map(String.init))

        let intersection = wordsA.intersection(wordsB).count
        let union = wordsA.union(wordsB).count

        guard union > 0 else { return 0 }

        // Also check title similarity
        let titleSimilarity = a.title.lowercased() == b.title.lowercased() ? 1.0 : 0.0

        return (Double(intersection) / Double(union)) * 0.5 + titleSimilarity * 0.5
    }
}

// MARK: - Supporting Types

struct NoteLink: Identifiable, Hashable {
    let id = UUID()
    let sourceId: UUID
    let targetId: UUID
    let type: LinkType
    let anchor: String?

    enum LinkType {
        case mentions
        case keywordRelated
        case bidirectional
    }
}
