import Foundation
import NaturalLanguage

/// EmbeddingService — On-device semantic search using NaturalLanguage framework
/// Provides embedding-based similarity search and entity extraction for notes
final class EmbeddingService {
    static let shared = EmbeddingService()

    private let tagger: NLTagger
    private let embedder: NLEmbedder?

    private init() {
        self.tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass, .lemma])
        self.embedder = NLEmbedder.sentenceEmbedding(for: .english)
    }

    // MARK: - Embedding Similarity

    /// Compute semantic similarity between a query and text using NaturalLanguage embeddings
    /// Returns a score between 0.0 and 1.0
    func computeSimilarity(query: String, text: String) -> Double {
        guard let embedder = embedder else {
            // Fallback to keyword-based similarity if embedder unavailable
            return computeKeywordSimilarity(query: query, text: text)
        }

        // Use NaturalLanguage sentence embeddings
        guard let queryEmbedding = embedder.embedding(for: query),
              let textEmbedding = embedder.embedding(for: text) else {
            return computeKeywordSimilarity(query: query, text: text)
        }

        return cosineSimilarity(queryEmbedding, textEmbedding)
    }

    /// Compute embedding vector for a piece of text
    func computeEmbedding(for text: String) -> [Float]? {
        guard let embedder = embedder,
              let embedding = embedder.embedding(for: text) else {
            return nil
        }

        // Convert NLEmbedding to [Float]
        var floats: [Float] = []
        for i in 0..<embedding.dimensionCount {
            floats.append(embedding[i])
        }
        return floats
    }

    /// Find semantically similar text chunks within a document
    func findSimilarChunks(query: String, in text: String, maxChunks: Int = 5) -> [(String, Double)] {
        let chunks = splitIntoChunks(text: text, maxChunkSize: 200)

        var scored: [(String, Double)] = []
        for chunk in chunks {
            let score = computeSimilarity(query: query, text: chunk)
            if score > 0.1 {
                scored.append((chunk, score))
            }
        }

        // Sort by score descending
        scored.sort { $0.1 > $1.1 }
        return Array(scored.prefix(maxChunks))
    }

    // MARK: - Entity Extraction (Auto-Tagging)

    /// Extract named entities from text using NLTagger
    /// Returns an array of entity strings suitable for tagging
    func extractEntities(from text: String) -> [String] {
        var entities: [String] = []

        tagger.string = text
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)

        // Extract named entities (people, places, organizations)
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        let range = text.startIndex..<text.endIndex

        tagger.enumerateTags(in: range, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            if let tag = tag {
                let entity = String(text[tokenRange])
                // Filter out very short entities and common words
                if entity.count >= 3 && !isCommonWord(entity) {
                    entities.append(entity)
                }
            }
            return true
        }

        // Also extract key nouns and topics
        let nouns = extractKeyNouns(from: text)
        entities.append(contentsOf: nouns)

        // Deduplicate and return top entities
        return Array(Set(entities)).prefix(10).map { $0 }
    }

    /// Extract key nouns from text using lexical class tagging
    func extractKeyNouns(from text: String) -> [String] {
        var nouns: [String] = []

        tagger.string = text
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)

        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]
        let range = text.startIndex..<text.endIndex

        tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass, options: options) { tag, tokenRange in
            if tag == .noun {
                let noun = String(text[tokenRange])
                // Filter: at least 3 chars, not a common word
                if noun.count >= 3 && !isCommonWord(noun) {
                    nouns.append(noun.lowercased())
                }
            }
            return true
        }

        // Return most common nouns (simple frequency-based)
        let nounCounts = Dictionary(grouping: nouns, by: { $0 }).mapValues { $0.count }
        let sortedNouns = nounCounts.sorted { $0.value > $1.value }
        return Array(sortedNouns.prefix(5).map { $0.key })
    }

    /// Extract lemmatized keywords for better matching
    func extractLemmas(from text: String) -> [String] {
        var lemmas: [String] = []

        tagger.string = text
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)

        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]
        let range = text.startIndex..<text.endIndex

        tagger.enumerateTags(in: range, unit: .word, scheme: .lemma, options: options) { tag, tokenRange in
            if let lemma = tag?.rawValue {
                let lemmaStr = String(lemma)
                if lemmaStr.count >= 3 && !isCommonWord(lemmaStr) {
                    lemmas.append(lemmaStr.lowercased())
                }
            }
            return true
        }

        return Array(Set(lemmas))
    }

    // MARK: - Private Helpers

    private func cosineSimilarity(_ a: NLEmbedding, _ b: NLEmbedding) -> Double {
        guard a.dimensionCount == b.dimensionCount else { return 0.0 }

        var dotProduct: Double = 0.0
        var normA: Double = 0.0
        var normB: Double = 0.0

        for i in 0..<a.dimensionCount {
            let aVal = Double(a[i])
            let bVal = Double(b[i])
            dotProduct += aVal * bVal
            normA += aVal * aVal
            normB += bVal * bVal
        }

        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0.0 }

        return (dotProduct + 1.0) / 2.0 // Normalize to 0-1 range
    }

    private func computeKeywordSimilarity(query: String, text: String) -> Double {
        let queryWords = Set(query.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 2 })

        let textWords = Set(text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 2 })

        let intersection = queryWords.intersection(textWords)
        let union = queryWords.union(textWords)

        guard !union.isEmpty else { return 0.0 }
        return Double(intersection.count) / Double(union.count)
    }

    private func splitIntoChunks(text: String, maxChunkSize: Int) -> [String] {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var chunks: [String] = []
        var currentChunk = ""

        for sentence in sentences {
            if currentChunk.count + sentence.count < maxChunkSize {
                currentChunk += (currentChunk.isEmpty ? "" : ". ") + sentence
            } else {
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk)
                }
                currentChunk = sentence
            }
        }

        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }

        return chunks
    }

    private func isCommonWord(_ word: String) -> Bool {
        let commonWords: Set<String> = [
            "the", "be", "to", "of", "and", "a", "in", "that", "have", "i",
            "it", "for", "not", "on", "with", "he", "as", "you", "do", "at",
            "this", "but", "his", "by", "from", "they", "we", "say", "her", "she",
            "or", "an", "will", "my", "one", "all", "would", "there", "their", "what",
            "so", "up", "out", "if", "about", "who", "get", "which", "go", "me",
            "when", "make", "can", "like", "time", "no", "just", "him", "know", "take",
            "people", "into", "year", "your", "good", "some", "could", "them", "see", "other",
            "than", "then", "now", "look", "only", "come", "its", "over", "think", "also",
            "back", "after", "use", "two", "how", "our", "work", "first", "well", "way",
            "even", "new", "want", "because", "any", "these", "give", "day", "most", "us",
            "is", "are", "was", "were", "been", "being", "has", "had", "does", "did",
            "very", "many", "much", "more", "such", "each", "every", "both", "few", "between"
        ]
        return commonWords.contains(word.lowercased())
    }
}
