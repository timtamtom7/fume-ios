import Foundation
import NaturalLanguage
import Accelerate

actor EmbeddingService {
    static let shared = EmbeddingService()

    private init() {}

    /// Generate a simple embedding vector using NLTagger and bag-of-words approach
    func generateEmbedding(for text: String) async -> [Float]? {
        let embeddingDimension = 256

        // Use NLTagger to extract words and their tags
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = text

        var wordScores: [String: Float] = [:]

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            let word = String(text[range]).lowercased()
            let score: Float
            switch tag {
            case .noun: score = 3.0
            case .verb: score = 2.0
            case .adjective: score = 2.5
            case .adverb: score = 1.5
            default: score = 1.0
            }
            wordScores[word, default: 0] += score
            return true
        }

        // Also extract named entities with higher weight
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            let word = String(text[range]).lowercased()
            if tag != nil {
                wordScores[word, default: 0] += 5.0
            }
            return true
        }

        // Create a simple hash-based embedding from word scores
        var embedding = [Float](repeating: 0, count: embeddingDimension)
        for (word, score) in wordScores {
            let hash = abs(word.hashValue)
            let indices = [
                hash % embeddingDimension,
                (hash >> 4) % embeddingDimension,
                (hash >> 8) % embeddingDimension
            ]
            for idx in indices {
                embedding[idx] += score * (1.0 / Float(indices.count))
            }
        }

        // Normalize
        let magnitude = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
        if magnitude > 0 {
            embedding = embedding.map { $0 / magnitude }
        }

        return embedding
    }

    /// Compute cosine similarity between two embedding vectors
    func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }
        var dotProduct: Float = 0
        vDSP_dotpr(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))
        return dotProduct
    }

    /// Find most similar sources to a query
    func findSimilarSources(query: String, sources: [Source], topK: Int = 5) async -> [SourceMatch] {
        guard let queryEmbedding = await generateEmbedding(for: query) else { return [] }

        var scoredSources: [(Source, Float)] = []

        for source in sources {
            if let embedding = source.embedding {
                let similarity = cosineSimilarity(queryEmbedding, embedding)
                if similarity > 0.1 {
                    scoredSources.append((source, similarity))
                }
            } else {
                // Fallback: simple keyword match
                let keywords = query.lowercased().split(separator: " ").map(String.init)
                var keywordScore: Float = 0
                for keyword in keywords {
                    if source.content.lowercased().contains(keyword) ||
                       source.title.lowercased().contains(keyword) {
                        keywordScore += 1
                    }
                }
                if keywordScore > 0 {
                    scoredSources.append((source, keywordScore / Float(keywords.count) * 0.5))
                }
            }
        }

        scoredSources.sort { $0.1 > $1.1 }

        return Array(scoredSources.prefix(topK)).map { source, score in
            let excerpt = extractExcerpt(from: source.content, matching: query)
            return SourceMatch(source: source, excerpt: excerpt, relevanceScore: Double(score))
        }
    }

    private func extractExcerpt(from content: String, matching query: String, maxLength: Int = 200) -> String {
        let lowercasedContent = content.lowercased()
        let keywords = query.lowercased().split(separator: " ").compactMap { word -> String? in
            let trimmed = String(word).trimmingCharacters(in: .punctuationCharacters)
            return trimmed.count > 2 ? trimmed : nil
        }

        for keyword in keywords {
            if let range = lowercasedContent.range(of: keyword) {
                let start = content.index(range.lowerBound, offsetBy: -min(60, content.distance(from: content.startIndex, to: range.lowerBound)), limitedBy: content.startIndex) ?? content.startIndex
                let end = content.index(range.upperBound, offsetBy: min(100, content.distance(from: range.upperBound, to: content.endIndex)), limitedBy: content.endIndex) ?? content.endIndex
                var excerpt = String(content[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                if start != content.startIndex { excerpt = "..." + excerpt }
                if end != content.endIndex { excerpt = excerpt + "..." }
                return excerpt
            }
        }

        if content.count <= maxLength {
            return content
        }
        let endIndex = content.index(content.startIndex, offsetBy: maxLength)
        return String(content[content.startIndex..<endIndex]) + "..."
    }
}
