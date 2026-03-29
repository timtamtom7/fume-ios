import Foundation
import NaturalLanguage

/// AIFumesService — AI-powered question answering over your knowledge base
/// Uses semantic search to find relevant passages and generates answers with citations
actor AIFumesService {
    static let shared = AIFumesService()

    private init() {}

    // MARK: - Types

    struct AIResponse {
        let answer: String
        let citedSources: [Source]
        let confidence: Double
        let query: String
        let timestamp: Date

        init(answer: String, citedSources: [Source], confidence: Double, query: String) {
            self.answer = answer
            self.citedSources = citedSources
            self.confidence = confidence
            self.query = query
            self.timestamp = Date()
        }
    }

    // MARK: - Answer Generation

    /// Answer a natural language question using the provided sources as context
    func answer(query: String, sources: [Source]) async -> AIResponse {
        guard !sources.isEmpty else {
            return AIResponse(
                answer: noSourcesFoundMessage(for: query),
                citedSources: [],
                confidence: 0.0,
                query: query
            )
        }

        // Use semantic search to find most relevant sources
        let rankedSources = await semanticSearch(query: query, sources: sources, topK: 5)
        let topSources = rankedSources.map { $0.source }

        // Calculate confidence based on match quality
        let confidence = calculateConfidence(rankedSources: rankedSources, query: query)

        // Generate answer using template-based synthesis
        let answer = await synthesizeAnswer(query: query, rankedSources: rankedSources)

        return AIResponse(
            answer: answer,
            citedSources: topSources,
            confidence: confidence,
            query: query
        )
    }

    // MARK: - Semantic Search

    struct RankedSource: Identifiable {
        let id: UUID
        let source: Source
        let relevanceScore: Double
        let matchedExcerpt: String
    }

    /// Find semantically similar sources using embeddings + keyword fallback
    func semanticSearch(query: String, sources: [Source], topK: Int = 5) async -> [RankedSource] {
        let queryLower = query.lowercased()

        // Score all sources
        var scored: [(Source, Double, String)] = []

        for source in sources {
            let score: Double
            let excerpt: String

            if let embedding = source.embedding {
                // Use embedding similarity
                let embeddingScore = computeEmbeddingSimilarity(query: query, embedding: embedding)
                let keywordScore = computeKeywordScore(query: queryLower, source: source)
                score = embeddingScore * 0.6 + keywordScore * 0.4
            } else {
                // Fallback to keyword matching
                score = computeKeywordScore(query: queryLower, source: source)
            }

            if score > 0.05 {
                excerpt = extractExcerpt(from: source.content, query: query)
                scored.append((source, score, excerpt))
            }
        }

        // Sort by score descending
        scored.sort { $0.1 > $1.1 }

        return scored.prefix(topK).map { source, score, excerpt in
            RankedSource(
                id: source.id,
                source: source,
                relevanceScore: score,
                matchedExcerpt: excerpt
            )
        }
    }

    // MARK: - Private Helpers

    private func noSourcesFoundMessage(for query: String) -> String {
        let lower = query.lowercased()
        if lower.contains("help") || lower.contains("what can") {
            return "I can answer questions about anything in your knowledge base — your notes, articles, voice memos, and more. Just ask me anything!"
        }
        if lower.contains("who am i") || lower.contains("about me") {
            return "I don't have personal information about you. I'm here to answer questions about the content you've saved in Fume."
        }
        return "I couldn't find anything in your knowledge base that directly answers this question. Try rephrasing or adding more content about this topic."
    }

    private func calculateConfidence(rankedSources: [RankedSource], query: String) -> Double {
        guard !rankedSources.isEmpty else { return 0.0 }
        let topScore = rankedSources[0].relevanceScore

        // Boost if multiple sources agree
        let agreementBonus = rankedSources.count > 1 ? 0.1 : 0.0

        // Boost for specific question types
        let queryLower = query.lowercased()
        let specificityBonus: Double
        if queryLower.contains("what") || queryLower.contains("how") || queryLower.contains("why") {
            specificityBonus = topScore > 0.5 ? 0.1 : 0.0
        } else {
            specificityBonus = 0.0
        }

        return min(topScore + agreementBonus + specificityBonus, 1.0)
    }

    private func computeEmbeddingSimilarity(query: String, embedding: [Float]) -> Double {
        // Generate a simple query embedding using word scoring
        let queryWords = query.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 2 }

        guard !queryWords.isEmpty else { return 0.0 }

        var score: Float = 0.0
        for word in queryWords {
            let wordHash = abs(word.hashValue)
            let idx = wordHash % embedding.count
            score += embedding[idx]
        }

        return Double(score / Float(queryWords.count) + 0.5) / 1.5
    }

    private func computeKeywordScore(query: String, source: Source) -> Double {
        let queryWords = query.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 2 }

        guard !queryWords.isEmpty else { return 0.0 }

        let contentLower = source.content.lowercased()
        let titleLower = source.title.lowercased()

        var matches = 0
        var titleMatches = 0

        for word in queryWords {
            if contentLower.contains(word) { matches += 1 }
            if titleLower.contains(word) { titleMatches += 1 }
        }

        let contentScore = Double(matches) / Double(queryWords.count)
        let titleBonus = titleMatches > 0 ? Double(titleMatches) / Double(queryWords.count) * 0.3 : 0.0

        return min(contentScore * 0.7 + titleBonus, 1.0)
    }

    private func extractExcerpt(from content: String, query: String, maxLength: Int = 200) -> String {
        let lowercasedContent = content.lowercased()
        let queryKeywords = query.lowercased()
            .split(separator: " ")
            .compactMap { word -> String? in
                let trimmed = String(word).trimmingCharacters(in: .punctuationCharacters)
                return trimmed.count > 2 ? trimmed : nil
            }

        for keyword in queryKeywords {
            if let range = lowercasedContent.range(of: keyword) {
                let startDist = content.distance(from: content.startIndex, to: range.lowerBound)
                let startOffset = min(60, startDist)
                let start = content.index(range.lowerBound, offsetBy: -startOffset, limitedBy: content.startIndex) ?? content.startIndex

                let endDist = content.distance(from: range.upperBound, to: content.endIndex)
                let endOffset = min(100, endDist)
                let end = content.index(range.upperBound, offsetBy: endOffset, limitedBy: content.endIndex) ?? content.endIndex

                var excerpt = String(content[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                if start != content.startIndex { excerpt = "..." + excerpt }
                if end != content.endIndex { excerpt = excerpt + "..." }
                return excerpt
            }
        }

        // Fallback: first maxLength characters
        if content.count <= maxLength {
            return content
        }
        let endIndex = content.index(content.startIndex, offsetBy: maxLength)
        return String(content[content.startIndex..<endIndex]) + "..."
    }

    private func synthesizeAnswer(query: String, rankedSources: [RankedSource]) async -> String {
        let queryLower = query.lowercased()

        // Handle specific query types with targeted responses
        if queryLower.hasPrefix("what is") || queryLower.hasPrefix("what are") {
            return synthesizeWhatIs(query: query, rankedSources: rankedSources)
        }
        if queryLower.hasPrefix("who") {
            return synthesizeWho(query: query, rankedSources: rankedSources)
        }
        if queryLower.hasPrefix("how") {
            return synthesizeHow(query: query, rankedSources: rankedSources)
        }
        if queryLower.hasPrefix("why") {
            return synthesizeWhy(query: query, rankedSources: rankedSources)
        }
        if queryLower.hasPrefix("summarize") || queryLower.contains("summary of") {
            return synthesizeSummary(query: query, rankedSources: rankedSources)
        }

        // Generic synthesis
        return synthesizeGeneric(query: query, rankedSources: rankedSources)
    }

    private func synthesizeWhatIs(query: String, rankedSources: [RankedSource]) -> String {
        guard let top = rankedSources.first else {
            return "I couldn't find information about that in your knowledge base."
        }

        let topic = extractTopic(from: query)
        let firstSentence = extractFirstSentence(from: top.matchedExcerpt)

        var answer = "Based on your notes"
        if !topic.isEmpty {
            answer += ", \(topic)"
        }
        answer += ":\n\n\"\(firstSentence)\""

        if rankedSources.count > 1 {
            answer += "\n\nI also found \(rankedSources.count - 1) other source\(rankedSources.count == 2 ? "" : "s") with related information."
        }

        return answer
    }

    private func synthesizeWho(query: String, rankedSources: [RankedSource]) -> String {
        guard let top = rankedSources.first else {
            return "I couldn't find information about that in your knowledge base."
        }

        let person = extractTopic(from: query)
        return "Here's what your notes say about \(person.isEmpty ? "this person" : person):\n\n\"\(extractFirstSentence(from: top.matchedExcerpt))\""
    }

    private func synthesizeHow(query: String, rankedSources: [RankedSource]) -> String {
        guard !rankedSources.isEmpty else {
            return "I couldn't find how-to information about that in your knowledge base."
        }

        var answer = "Here's what I found in your notes:\n\n"
        for (index, source) in rankedSources.prefix(3).enumerated() {
            if index > 0 { answer += "\n\n---\n\n" }
            answer += "From **\(source.source.title)**:\n"
            answer += "\"\(source.matchedExcerpt)\""
        }

        return answer
    }

    private func synthesizeWhy(query: String, rankedSources: [RankedSource]) -> String {
        guard !rankedSources.isEmpty else {
            return "I couldn't find reasoning for that in your knowledge base."
        }

        return "Here's what your notes suggest about why:\n\n\"\(rankedSources[0].matchedExcerpt)\""
    }

    private func synthesizeSummary(query: String, rankedSources: [RankedSource]) -> String {
        guard !rankedSources.isEmpty else {
            return "I couldn't find anything to summarize in your knowledge base."
        }

        var summaries: [String] = []
        for source in rankedSources.prefix(4) {
            let summary = extractFirstSentence(from: source.matchedExcerpt)
            summaries.append("• \(source.source.title): \(summary)")
        }

        return "Here's a summary from your knowledge base:\n\n" + summaries.joined(separator: "\n")
    }

    private func synthesizeGeneric(query: String, rankedSources: [RankedSource]) -> String {
        guard !rankedSources.isEmpty else {
            return "I couldn't find anything in your knowledge base that answers this question."
        }

        if rankedSources.count == 1 {
            return "\(rankedSources[0].matchedExcerpt)\n\n— from your \(rankedSources[0].source.formattedDate)"
        }

        var answer = "I found \(rankedSources.count) relevant sources in your knowledge base:\n\n"
        for (index, source) in rankedSources.prefix(3).enumerated() {
            answer += "**\(index + 1). \(source.source.title)**\n"
            answer += "\"\(source.matchedExcerpt)\"\n\n"
        }

        answer += "Tap any source below to explore it in full."
        return answer
    }

    private func extractTopic(from query: String) -> String {
        let words = query.components(separatedBy: .whitespacesAndNewlines)
        // Skip "what is", "what are", "who is", etc.
        let skipWords = Set(["what", "is", "are", "was", "were", "who", "how", "why", "when", "where", "the", "a", "an", "this", "that", "these", "those", "i", "me", "my"])
        let topicWords = words.filter { !skipWords.contains($0.lowercased()) && $0.count > 2 }
        return topicWords.joined(separator: " ")
    }

    private func extractFirstSentence(from text: String) -> String {
        var sentenceEnd = text.startIndex
        for char in text {
            if char == "." || char == "!" || char == "?" {
                break
            }
            sentenceEnd = text.index(after: sentenceEnd)
        }

        let firstSentence = String(text[text.startIndex..<sentenceEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        if firstSentence.isEmpty {
            return String(text.prefix(150)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
        }
        return firstSentence
    }
}

// MARK: - Source Extension for Semantic Search

extension Source {
    /// Perform semantic search across this source's content
    func matches(query: String) async -> Double {
        let queryLower = query.lowercased()

        if let embedding = self.embedding {
            // Use embedding similarity
            let embeddingScore = computeSimpleEmbeddingSimilarity(query: query, embedding: embedding)
            let keywordScore = computeSimpleKeywordScore(query: queryLower)
            return embeddingScore * 0.6 + keywordScore * 0.4
        }

        return computeSimpleKeywordScore(query: queryLower)
    }

    private func computeSimpleEmbeddingSimilarity(query: String, embedding: [Float]) -> Double {
        let queryWords = query.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 2 }

        guard !queryWords.isEmpty else { return 0.0 }

        var score: Float = 0.0
        for word in queryWords {
            let wordHash = abs(word.hashValue)
            let idx = wordHash % embedding.count
            score += embedding[idx]
        }

        return Double(score / Float(queryWords.count) + 0.5) / 1.5
    }

    private func computeSimpleKeywordScore(query: String) -> Double {
        let queryWords = query.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 2 }

        guard !queryWords.isEmpty else { return 0.0 }

        let contentLower = content.lowercased()
        let titleLower = title.lowercased()

        var matches = 0
        var titleMatches = 0

        for word in queryWords {
            if contentLower.contains(word) { matches += 1 }
            if titleLower.contains(word) { titleMatches += 1 }
        }

        let contentScore = Double(matches) / Double(queryWords.count)
        let titleBonus = titleMatches > 0 ? Double(titleMatches) / Double(queryWords.count) * 0.3 : 0.0

        return min(contentScore * 0.7 + titleBonus, 1.0)
    }
}
