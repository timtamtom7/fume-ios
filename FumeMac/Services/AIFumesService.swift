import Foundation
import NaturalLanguage

/// AIFumesService — AI-powered question answering for FumeMac
/// Uses semantic search with NaturalLanguage embeddings and generates answers with citations
final class AIFumesService {
    static let shared = AIFumesService()

    private let embeddingService = EmbeddingService.shared

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

    struct SearchResult: Identifiable {
        let id: UUID
        let source: Source
        let relevanceScore: Double
        let matchedExcerpt: String

        init(id: UUID = UUID(), source: Source, relevanceScore: Double, matchedExcerpt: String) {
            self.id = id
            self.source = source
            self.relevanceScore = relevanceScore
            self.matchedExcerpt = matchedExcerpt
        }
    }

    // MARK: - Answer Generation

    /// Answer a natural language question using the provided sources as context
    func answer(query: String, sources: [Source]) -> AIResponse {
        guard !sources.isEmpty else {
            return AIResponse(
                answer: noSourcesFoundMessage(for: query),
                citedSources: [],
                confidence: 0.0,
                query: query
            )
        }

        // Use semantic search to find most relevant sources
        let rankedResults = semanticSearch(query: query, sources: sources)
        let topSources = rankedResults.prefix(5).map { $0.source }

        // Calculate confidence based on match quality
        let confidence = calculateConfidence(rankedResults: Array(rankedResults), query: query)

        // Generate answer using template-based synthesis
        let answer = synthesizeAnswer(query: query, rankedResults: Array(rankedResults))

        return AIResponse(
            answer: answer,
            citedSources: topSources,
            confidence: confidence,
            query: query
        )
    }

    // MARK: - Semantic Search

    /// Find semantically similar sources using NaturalLanguage embeddings + keyword fallback
    func semanticSearch(query: String, sources: [Source]) -> [SearchResult] {
        let queryLower = query.lowercased()

        // Score all sources using embedding similarity + keyword matching
        var scored: [(Source, Double, String)] = []

        for source in sources {
            let score: Double
            let excerpt: String

            if let embedding = source.embedding {
                // Use stored embedding similarity
                let embeddingScore = computeEmbeddingSimilarity(query: query, embedding: embedding)
                let keywordScore = computeKeywordScore(query: queryLower, source: source)
                score = embeddingScore * 0.6 + keywordScore * 0.4
            } else {
                // Fallback to NaturalLanguage embedding + keyword matching
                let nlScore = embeddingService.computeSimilarity(query: query, text: source.content)
                let keywordScore = computeKeywordScore(query: queryLower, source: source)
                score = nlScore * 0.6 + keywordScore * 0.4
            }

            if score > 0.05 {
                excerpt = extractExcerpt(from: source.content, query: query)
                scored.append((source, score, excerpt))
            }
        }

        // Sort by score descending
        scored.sort { $0.1 > $1.1 }

        return scored.prefix(10).map { source, score, excerpt in
            SearchResult(
                id: source.id,
                source: source,
                relevanceScore: score,
                matchedExcerpt: excerpt
            )
        }
    }

    // MARK: - Auto-Tagging

    /// Extract tags from source content using NLTagger entity extraction
    func extractTags(from source: Source) -> [String] {
        return embeddingService.extractEntities(from: source.content)
    }

    /// Auto-tag a source with relevant tags based on its content
    func autoTag(source: Source) -> [UUID] {
        let extractedTags = extractTags(from: source)
        // Tag matching would be done against existing tags in the database
        // This returns tag strings that should be matched/created
        return [] // Placeholder - actual implementation would query existing tags
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

    private func calculateConfidence(rankedResults: [SearchResult], query: String) -> Double {
        guard !rankedResults.isEmpty else { return 0.0 }
        let topScore = rankedResults[0].relevanceScore

        // Boost if multiple sources agree
        let agreementBonus = rankedResults.count > 1 ? 0.1 : 0.0

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

    private func synthesizeAnswer(query: String, rankedResults: [SearchResult]) -> String {
        let queryLower = query.lowercased()

        // Handle specific query types with targeted responses
        if queryLower.hasPrefix("what is") || queryLower.hasPrefix("what are") {
            return synthesizeWhatIs(query: query, rankedResults: rankedResults)
        }
        if queryLower.hasPrefix("who") {
            return synthesizeWho(query: query, rankedResults: rankedResults)
        }
        if queryLower.hasPrefix("how") {
            return synthesizeHow(query: query, rankedResults: rankedResults)
        }
        if queryLower.hasPrefix("why") {
            return synthesizeWhy(query: query, rankedResults: rankedResults)
        }
        if queryLower.hasPrefix("summarize") || queryLower.contains("summary of") {
            return synthesizeSummary(query: query, rankedResults: rankedResults)
        }

        // Generic synthesis
        return synthesizeGeneric(query: query, rankedResults: rankedResults)
    }

    private func synthesizeWhatIs(query: String, rankedResults: [SearchResult]) -> String {
        guard let top = rankedResults.first else {
            return "I couldn't find information about that in your knowledge base."
        }

        let topic = extractTopic(from: query)
        let firstSentence = extractFirstSentence(from: top.matchedExcerpt)

        var answer = "Based on your notes"
        if !topic.isEmpty {
            answer += ", \(topic)"
        }
        answer += ":\n\n\"\(firstSentence)\""

        if rankedResults.count > 1 {
            answer += "\n\nI also found \(rankedResults.count - 1) other source\(rankedResults.count == 2 ? "" : "s") with related information."
        }

        return answer
    }

    private func synthesizeWho(query: String, rankedResults: [SearchResult]) -> String {
        guard let top = rankedResults.first else {
            return "I couldn't find information about that in your knowledge base."
        }

        let person = extractTopic(from: query)
        return "Here's what your notes say about \(person.isEmpty ? "this person" : person):\n\n\"\(extractFirstSentence(from: top.matchedExcerpt))\""
    }

    private func synthesizeHow(query: String, rankedResults: [SearchResult]) -> String {
        guard !rankedResults.isEmpty else {
            return "I couldn't find how-to information about that in your knowledge base."
        }

        var answer = "Here's what I found in your notes:\n\n"
        for (index, result) in rankedResults.prefix(3).enumerated() {
            if index > 0 { answer += "\n\n---\n\n" }
            answer += "From **\(result.source.title)**:\n"
            answer += "\"\(result.matchedExcerpt)\""
        }

        return answer
    }

    private func synthesizeWhy(query: String, rankedResults: [SearchResult]) -> String {
        guard !rankedResults.isEmpty else {
            return "I couldn't find reasoning for that in your knowledge base."
        }

        return "Here's what your notes suggest about why:\n\n\"\(rankedResults[0].matchedExcerpt)\""
    }

    private func synthesizeSummary(query: String, rankedResults: [SearchResult]) -> String {
        guard !rankedResults.isEmpty else {
            return "I couldn't find anything to summarize in your knowledge base."
        }

        var summaries: [String] = []
        for result in rankedResults.prefix(4) {
            let summary = extractFirstSentence(from: result.matchedExcerpt)
            summaries.append("• \(result.source.title): \(summary)")
        }

        return "Here's a summary from your knowledge base:\n\n" + summaries.joined(separator: "\n")
    }

    private func synthesizeGeneric(query: String, rankedResults: [SearchResult]) -> String {
        guard !rankedResults.isEmpty else {
            return "I couldn't find anything in your knowledge base that answers this question."
        }

        if rankedResults.count == 1 {
            return "\(rankedResults[0].matchedExcerpt)\n\n— from your \(rankedResults[0].source.formattedDate)"
        }

        var answer = "I found \(rankedResults.count) relevant sources in your knowledge base:\n\n"
        for (index, result) in rankedResults.prefix(3).enumerated() {
            answer += "**\(index + 1). \(result.source.title)**\n"
            answer += "\"\(result.matchedExcerpt)\"\n\n"
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
