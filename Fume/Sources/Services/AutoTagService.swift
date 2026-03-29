import Foundation
import NaturalLanguage

/// AutoTagService — Uses NLP to automatically suggest tags for notes
/// Extracts entities, topics, and keywords to suggest 2-5 relevant tags
actor AutoTagService {
    static let shared = AutoTagService()

    private init() {}

    // MARK: - Types

    struct SuggestedTag: Identifiable, Equatable {
        let id = UUID()
        let name: String
        let confidence: Double
        let reason: String
        let category: TagCategory

        enum TagCategory: String {
            case technology = "Technology"
            case business = "Business"
            case personal = "Personal"
            case research = "Research"
            case health = "Health"
            case learning = "Learning"
            case project = "Project"
            case idea = "Idea"
            case article = "Article"
            case meeting = "Meeting"
            case other = "Other"
        }
    }

    // MARK: - Tag Suggestion

    /// Suggest 2-5 tags for a given source (note, article, etc.)
    func suggestTags(for source: Source) async -> [SuggestedTag] {
        let combinedText = (source.title + " " + source.content).lowercased()

        // Use NLP tagger for entity extraction
        let entities = extractNamedEntities(from: combinedText)
        let topics = classifyTopics(from: combinedText)
        let keywords = extractKeywords(from: source.content, title: source.title)

        var suggestions: [SuggestedTag] = []

        // Add entity-based tags (high confidence for strong matches)
        for entity in entities.prefix(2) {
            suggestions.append(SuggestedTag(
                name: entity.name,
                confidence: entity.confidence,
                reason: entity.reason,
                category: entity.category
            ))
        }

        // Add topic-based tags
        for topic in topics.prefix(2) {
            // Don't duplicate
            if !suggestions.contains(where: { $0.name.lowercased() == topic.name.lowercased() }) {
                suggestions.append(SuggestedTag(
                    name: topic.name,
                    confidence: topic.confidence,
                    reason: topic.reason,
                    category: topic.category
                ))
            }
        }

        // Add keyword-based tags if we still need more
        if suggestions.count < 3 {
            for keyword in keywords.prefix(3) {
                if !suggestions.contains(where: { $0.name.lowercased() == keyword.name.lowercased() }) {
                    suggestions.append(keyword)
                }
                if suggestions.count >= 5 { break }
            }
        }

        // Sort by confidence
        suggestions.sort { $0.confidence > $1.confidence }

        // Return top 5
        return Array(suggestions.prefix(5))
    }

    // MARK: - Named Entity Extraction

    private struct ExtractedEntity {
        let name: String
        let confidence: Double
        let reason: String
        let category: SuggestedTag.TagCategory
    }

    private func extractNamedEntities(from text: String) -> [ExtractedEntity] {
        var entities: [ExtractedEntity] = []
        var seen = Set<String>()

        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        var currentEntity = ""
        var currentType: NLTag?
        var entityRanges: [Range<String.Index>] = []

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            if let tag = tag {
                let word = String(text[range])

                // Collect multi-word entities
                if currentType == tag {
                    currentEntity += " " + word
                    entityRanges.append(range)
                } else {
                    // Finalize previous entity
                    if !currentEntity.isEmpty && currentEntity.count > 2 {
                        let normalized = currentEntity.trimmingCharacters(in: .whitespaces)
                        if !seen.contains(normalized.lowercased()) {
                            seen.insert(normalized.lowercased())

                            let confidence = min(0.5 + Double(entityRanges.count) * 0.1, 0.9)
                            let category = categoryForTag(currentType)

                            if normalized.split(separator: " ").count <= 4 {
                                entities.append(ExtractedEntity(
                                    name: normalized.capitalized,
                                    confidence: confidence,
                                    reason: "Named \(currentType?.rawValue ?? "entity") detected",
                                    category: category
                                ))
                            }
                        }
                    }

                    currentEntity = word
                    currentType = tag
                    entityRanges = [range]
                }
            }
            return true
        }

        // Finalize last entity
        if !currentEntity.isEmpty && currentEntity.count > 2 {
            let normalized = currentEntity.trimmingCharacters(in: .whitespaces)
            if !seen.contains(normalized.lowercased()) {
                seen.insert(normalized.lowercased())

                if normalized.split(separator: " ").count <= 4 {
                    entities.append(ExtractedEntity(
                        name: normalized.capitalized,
                        confidence: 0.6,
                        reason: "Named \(currentType?.rawValue ?? "entity") detected",
                        category: categoryForTag(currentType)
                    ))
                }
            }
        }

        return entities
    }

    private func categoryForTag(_ tag: NLTag?) -> SuggestedTag.TagCategory {
        switch tag {
        case .personalName: return .personal
        case .organizationName: return .business
        case .placeName: return .personal
        default: return .other
        }
    }

    // MARK: - Topic Classification

    private struct ClassifiedTopic {
        let name: String
        let confidence: Double
        let reason: String
        let category: SuggestedTag.TagCategory
    }

    private func classifyTopics(from text: String) -> [ClassifiedTopic] {
        var topics: [ClassifiedTopic] = []
        let lower = text

        let topicMappings: [(keywords: [String], tagName: String, reason: String, category: SuggestedTag.TagCategory)] = [
            // Technology
            (["swift ", "swiftui", "uikit", "xcode", "apple silicon", "m1", "m2", "m3"], "Apple Dev", "mentions Apple development", .technology),
            (["python", "django", "flask", "pip", "pypi"], "Python", "mentions Python", .technology),
            (["javascript", "typescript", "node", "npm", "react", "vue", "webpack"], "Web Dev", "mentions web development", .technology),
            (["machine learning", "deep learning", "neural network", " ai ", "llm", "gpt-", "transformer model"], "AI/ML", "mentions AI or machine learning", .technology),
            (["local ai", "on-device", "ollama", "llama.cpp", "quantization", "coreml"], "Local AI", "mentions local/on-device AI", .technology),
            (["docker", "kubernetes", "container", "k8s", "dockerfile", "helm"], "DevOps", "mentions container/DevOps", .technology),
            (["api", "rest ", "graphql", "endpoint", "http/", "request/", "webhook"], "APIs", "mentions APIs", .technology),
            (["database", "sqlite", "postgresql", "mongodb", "redis", "sql query"], "Databases", "mentions databases", .technology),
            (["git ", "github", "ci/cd", "pipeline", "github action"], "Git/CI", "mentions version control", .technology),
            (["security", "auth", "oauth", "jwt", "encryption", "ssl", "tls", "vulnerability", "exploit"], "Security", "mentions security", .technology),
            (["performance", "speed", "optimize", "benchmark", "profiling", "latency", "throughput"], "Performance", "mentions performance", .technology),
            (["unit test", "integration test", "tdd", "test coverage", "testing"], "Testing", "mentions testing", .technology),
            (["design", "ux", "ui ", "figma", "user experience"], "Design", "mentions design", .technology),
            (["swift package", "spm", "cocoapods", "carthage"], "Swift Package", "mentions Swift dependencies", .technology),

            // Business
            (["startup", "founder", "vc ", "funding", "investor", "revenue", "saas", "pricing", "burn rate"], "Business", "mentions business/startup", .business),
            (["product", "roadmap", "feature", "launch", "release", "version"], "Product", "mentions product", .business),
            (["meeting", "standup", "retro", "sprint", "planning", "scrum"], "Meetings", "mentions meetings", .meeting),
            (["project", "kickoff", "milestone", "deliverable"], "Projects", "mentions projects", .project),

            // Learning
            (["learning", "course", "tutorial", "learn", "study", "book", "chapter", "reading"], "Learning", "mentions learning resources", .learning),
            (["research", "paper", "academic", "arxiv", "doi", "study", "experiment"], "Research", "mentions research", .research),
            (["idea", "brainstorm", "concept", "thought", "thinking about"], "Ideas", "mentions ideas", .idea),

            // Content type
            (["article", "blog post", "tweet", "twitter thread", "newsletter"], "Articles", "content type: article", .article),
            (["personal", "life", "family", "health", "fitness", "travel", "trip"], "Personal", "personal content", .personal),
        ]

        for mapping in topicMappings {
            var matchCount = 0
            for keyword in mapping.keywords {
                if lower.contains(keyword) {
                    matchCount += 1
                }
            }

            if matchCount > 0 {
                let confidence = min(Double(matchCount) / Double(mapping.keywords.count) + 0.2, 0.95)
                if confidence >= 0.2 {
                    topics.append(ClassifiedTopic(
                        name: mapping.tagName,
                        confidence: confidence,
                        reason: mapping.reason,
                        category: mapping.category
                    ))
                }
            }
        }

        return topics
    }

    // MARK: - Keyword Extraction

    private func extractKeywords(from content: String, title: String) -> [SuggestedTag] {
        var suggestions: [SuggestedTag] = []
        var seen = Set<String>()

        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = content

        var wordScores: [String: (score: Double, reason: String)] = [:]

        // Score words by lexical class
        tagger.enumerateTags(in: content.startIndex..<content.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            let word = String(content[range]).lowercased()

            guard word.count > 3 else { return true }
            guard !stopWords.contains(word) else { return true }

            let score: Double
            let reason: String

            switch tag {
            case .noun:
                score = 2.0
                reason = "noun"
            case .verb:
                score = 1.0
                reason = "verb"
            case .adjective:
                score = 1.5
                reason = "adjective"
            default:
                score = 0.5
                reason = "word"
            }

            if let existing = wordScores[word] {
                wordScores[word] = (existing.score + score, existing.reason)
            } else {
                wordScores[word] = (score, reason)
            }

            return true
        }

        // Also check title for higher weights
        let titleWords = title.lowercased().components(separatedBy: .whitespacesAndNewlines)
        for word in titleWords {
            let clean = word.trimmingCharacters(in: .punctuationCharacters)
            if clean.count > 3 && !stopWords.contains(clean) {
                if let existing = wordScores[clean] {
                    wordScores[clean] = (existing.score + 2.0, "in title + \(existing.reason)")
                }
            }
        }

        // Sort by score and take top keywords
        let sorted = wordScores.sorted { $0.value.score > $1.value.score }

        for (word, data) in sorted.prefix(10) {
            guard !seen.contains(word) else { continue }
            seen.insert(word)

            let confidence = min(data.score / 5.0, 0.8)
            if confidence >= 0.15 {
                suggestions.append(SuggestedTag(
                    name: word.capitalized,
                    confidence: confidence,
                    reason: "Keyword: \(data.reason)",
                    category: .other
                ))
            }

            if suggestions.count >= 3 { break }
        }

        return suggestions
    }

    // MARK: - Batch Tagging

    /// Suggest tags for multiple sources at once
    func suggestTagsForBatch(_ sources: [Source]) async -> [UUID: [SuggestedTag]] {
        var results: [UUID: [SuggestedTag]] = [:]

        for source in sources {
            results[source.id] = await suggestTags(for: source)
        }

        return results
    }

    // MARK: - Tag Merging

    /// Merge suggested tags from multiple sources to find common themes
    func findCommonTags(in sources: [Source]) async -> [SuggestedTag] {
        let allTags = await suggestTagsForBatch(sources)

        var tagCounts: [String: (count: Int, confidence: Double, reason: String, category: SuggestedTag.TagCategory)] = [:]

        for (_, tags) in allTags {
            var seenInThisSource = Set<String>()
            for tag in tags {
                if !seenInThisSource.contains(tag.name.lowercased()) {
                    seenInThisSource.insert(tag.name.lowercased())

                    let key = tag.name.lowercased()
                    if let existing = tagCounts[key] {
                        tagCounts[key] = (existing.count + 1, max(existing.confidence, tag.confidence), tag.reason, tag.category)
                    } else {
                        tagCounts[key] = (1, tag.confidence, tag.reason, tag.category)
                    }
                }
            }
        }

        return tagCounts
            .sorted { $0.value.count > $1.value.count }
            .prefix(5)
            .map { name, data in
                SuggestedTag(
                    name: name.capitalized,
                    confidence: data.confidence * Double(data.count) / Double(sources.count),
                    reason: "Appears in \(data.count) of \(sources.count) sources",
                    category: data.category
                )
            }
    }

    // MARK: - Stop Words

    private let stopWords: Set<String> = [
        "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by",
        "is", "are", "was", "were", "be", "been", "being", "have", "has", "had", "do", "does", "did",
        "will", "would", "could", "should", "may", "might", "must", "can", "this", "that", "these",
        "those", "what", "which", "who", "when", "where", "why", "how", "all", "each", "every",
        "both", "few", "more", "most", "other", "some", "such", "no", "nor", "not", "only", "own",
        "same", "so", "than", "too", "very", "just", "about", "into", "over", "after", "before",
        "between", "under", "again", "further", "then", "once", "here", "there", "from", "up",
        "down", "out", "off", "above", "below", "your", "their", "our", "its", "also", "like",
        "use", "using", "used", "way", "make", "made", "get", "got", "one", "two", "three",
        "first", "second", "new", "old", "last", "next", "now", "then", "back", "even", "still",
        "well", "much", "many", "very", "really", "quite", "right", "left", "come", "came",
        "take", "took", "know", "knew", "think", "thought", "see", "saw", "look", "looked",
        "want", "need", "going", "say", "said", "tell", "told", "give", "gave", "find", "found"
    ]
}
