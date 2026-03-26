import Foundation

/// Intelligence Service — handles AI analysis, auto-tagging, and knowledge extraction
/// Uses on-device templates + keyword detection to provide useful insights
actor IntelligenceService {
    static let shared = IntelligenceService()

    private init() {}

    // MARK: - AI Analysis

    struct AnalysisResult {
        let summary: String
        let actionItems: [String]
        let questionsRaised: [String]
        let keyFacts: [KeyFact]
        let sentiment: String
        // R7: Extended AI Analysis
        var topic: String?
        var readingDifficulty: String?
        var freshnessWarning: String?
        var relatedTopics: [String]
        var keyTakeaways: [String]
        var analyzedAt: Date
    }

    struct KeyFact: Identifiable {
        let id = UUID()
        let type: FactType
        let value: String
        let context: String

        enum FactType: String {
            case date = "Date"
            case name = "Name"
            case number = "Number"
            case url = "URL"
            case email = "Email"
            case location = "Location"
            case technology = "Technology"
            case concept = "Concept"
        }
    }

    /// Analyze a source and return structured insights
    func analyzeSource(_ source: Source) async -> AnalysisResult {
        let content = source.content + " " + source.title

        // Extract key facts
        let keyFacts = extractKeyFacts(from: content)

        // Generate summary
        let summary = generateSummary(from: content)

        // Extract action items
        let actionItems = extractActionItems(from: content)

        // Extract questions
        let questions = extractQuestions(from: content)

        // Sentiment (simple keyword-based)
        let sentiment = analyzeSentiment(content)

        // R7: Extended AI Analysis
        let topic = classifyTopic(content)
        let readingDifficulty = assessReadingDifficulty(content)
        let freshnessWarning = assessFreshness(content, sourceDate: source.createdAt)
        let relatedTopics = findRelatedTopics(content)
        let keyTakeaways = extractKeyTakeaways(from: content)

        return AnalysisResult(
            summary: summary,
            actionItems: actionItems,
            questionsRaised: questions,
            keyFacts: keyFacts,
            sentiment: sentiment,
            topic: topic,
            readingDifficulty: readingDifficulty,
            freshnessWarning: freshnessWarning,
            relatedTopics: relatedTopics,
            keyTakeaways: keyTakeaways,
            analyzedAt: Date()
        )
    }

    // MARK: - Summary Generation

    private func generateSummary(from content: String, maxSentences: Int = 3) -> String {
        let sentences = splitIntoSentences(content)
        guard !sentences.isEmpty else { return "" }

        // Score sentences by importance (keyword density + position)
        let importantWords = extractImportantWords(from: content)
        var scoredSentences: [(String, Double)] = []

        for (index, sentence) in sentences.enumerated() {
            let words = sentence.lowercased().components(separatedBy: .whitespacesAndNewlines)
            let wordCount = words.count
            guard wordCount > 3 else { continue }

            var score = 0.0
            for word in words {
                if importantWords.contains(word) {
                    score += 1.0
                }
            }

            // Boost first sentences (usually contain thesis)
            if index < 2 {
                score *= 1.3
            }

            // Boost sentences with capital letters (proper nouns, acronyms)
            let capitals = sentence.filter { $0.isUppercase && $0.isLetter }
            score += Double(capitals.count) * 0.1

            // Penalize very short or very long sentences
            if wordCount < 8 || wordCount > 40 {
                score *= 0.7
            }

            scoredSentences.append((sentence, score))
        }

        // Sort by score and take top N
        scoredSentences.sort { $0.1 > $1.1 }
        let topSentences = scoredSentences.prefix(maxSentences).map { $0.0 }

        // Return in original order
        let orderedTop = topSentences.sorted { s1, s2 in
            guard let idx1 = sentences.firstIndex(of: s1),
                  let idx2 = sentences.firstIndex(of: s2) else { return false }
            return idx1 < idx2
        }

        return orderedTop.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Key Facts Extraction

    private func extractKeyFacts(from content: String) -> [KeyFact] {
        var facts: [KeyFact] = []
        var seen = Set<String>()

        // Extract dates
        let datePatterns = [
            "\\b(\\d{1,2}[\\/\\-]\\d{1,2}[\\/\\-]\\d{2,4})\\b",
            "\\b((?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\\s+\\d{1,2}(?:,?\\s+\\d{4})?)\\b",
            "\\b(\\d{4}-\\d{2}-\\d{2})\\b",
            "\\b((?:yesterday|today|tomorrow|last\\s+week|next\\s+week|last\\s+month|next\\s+month)\\b)",
        ]

        for pattern in datePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(content.startIndex..., in: content)
                let matches = regex.matches(in: content, range: range)
                for match in matches {
                    if let matchRange = Range(match.range(at: 1), in: content) {
                        let dateStr = String(content[matchRange]).trimmingCharacters(in: .whitespaces)
                        if !seen.contains(dateStr.lowercased()) {
                            seen.insert(dateStr.lowercased())
                            facts.append(KeyFact(type: .date, value: dateStr, context: extractContext(around: matchRange, in: content)))
                        }
                    }
                }
            }
        }

        // Extract URLs
        let urlPattern = "https?://[^\\s]+"
        if let regex = try? NSRegularExpression(pattern: urlPattern) {
            let range = NSRange(content.startIndex..., in: content)
            let matches = regex.matches(in: content, range: range)
            for match in matches {
                if let matchRange = Range(match.range, in: content) {
                    let urlStr = String(content[matchRange])
                    if !seen.contains(urlStr) {
                        seen.insert(urlStr)
                        facts.append(KeyFact(type: .url, value: urlStr, context: extractContext(around: matchRange, in: content)))
                    }
                }
            }
        }

        // Extract emails
        let emailPattern = "[\\w.+-]+@[\\w-]+\\.[\\w.]+"
        if let regex = try? NSRegularExpression(pattern: emailPattern) {
            let range = NSRange(content.startIndex..., in: content)
            let matches = regex.matches(in: content, range: range)
            for match in matches {
                if let matchRange = Range(match.range, in: content) {
                    let emailStr = String(content[matchRange])
                    if !seen.contains(emailStr.lowercased()) {
                        seen.insert(emailStr.lowercased())
                        facts.append(KeyFact(type: .email, value: emailStr, context: extractContext(around: matchRange, in: content)))
                    }
                }
            }
        }

        // Extract numbers with context (years, percentages, money)
        let numberPatterns = [
            ("\\b\\d{4}\\b", "Year"), // 4-digit years like 2024
            ("\\b\\d+%\\b", "Percentage"), // Percentages
            ("\\b\\$?[\\d,]+(?:\\.\\d{2})?\\b", "Money"), // Money
            ("\\b\\d+(?:\\.\\d+)?\\s*(?:GB|MB|KB|TB|Hz|GHz|MHz|ms)\\b", "Measurement"), // Tech measurements
        ]

        for (pattern, type) in numberPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(content.startIndex..., in: content)
                let matches = regex.matches(in: content, range: range)
                for match in matches {
                    if let matchRange = Range(match.range, in: content) {
                        let numStr = String(content[matchRange])
                        if !seen.contains(numStr) {
                            seen.insert(numStr)
                            facts.append(KeyFact(type: .number, value: numStr, context: extractContext(around: matchRange, in: content)))
                        }
                    }
                }
            }
        }

        // Extract technology keywords
        let techKeywords = [
            "Swift", "Python", "JavaScript", "TypeScript", "Rust", "Go", "Kotlin", "Java",
            "React", "Vue", "Angular", "Node.js", "Django", "Flask", "Rails",
            "Apple Silicon", "M1", "M2", "M3", "Neural Engine", "CoreML",
            "OpenAI", "Claude", "GPT", "Llama", "Ollama", "Mistral",
            "SQLite", "PostgreSQL", "MongoDB", "Redis",
            "Docker", "Kubernetes", "AWS", "GCP", "Azure",
            "HTTP", "API", "REST", "GraphQL", "WebSocket",
            "Git", "GitHub", "CI/CD", "Xcode", "VS Code",
            "iOS", "macOS", "Android", "Windows", "Linux",
            "LLVM", "SwiftUI", "UIKit", "React Native", "Flutter",
        ]

        let contentLower = content.lowercased()
        for tech in techKeywords {
            if contentLower.contains(tech.lowercased()) && !seen.contains(tech.lowercased()) {
                // Find the actual match range
                if let range = content.range(of: tech, options: .caseInsensitive) {
                    seen.insert(tech.lowercased())
                    facts.append(KeyFact(type: .technology, value: tech, context: extractContext(around: range, in: content)))
                }
            }
        }

        // Extract capitalized names (potential people/orgs)
        let namePattern = "\\b([A-Z][a-z]+(?:\\s+[A-Z][a-z]+)+)\\b"
        if let regex = try? NSRegularExpression(pattern: namePattern) {
            let range = NSRange(content.startIndex..., in: content)
            let matches = regex.matches(in: content, range: range)
            for match in matches {
                if let matchRange = Range(match.range(at: 1), in: content) {
                    let nameStr = String(content[matchRange])
                    if !seen.contains(nameStr.lowercased()) && nameStr.split(separator: " ").count <= 4 {
                        seen.insert(nameStr.lowercased())
                        facts.append(KeyFact(type: .name, value: nameStr, context: extractContext(around: matchRange, in: content)))
                    }
                }
            }
        }

        // Extract concepts (capitalized single words that might be important terms)
        let conceptPattern = "\\b([A-Z][a-z]+(?:[A-Z][a-z]+)+)\\b"
        if let regex = try? NSRegularExpression(pattern: conceptPattern) {
            let range = NSRange(content.startIndex..., in: content)
            let matches = regex.matches(in: content, range: range)
            for match in matches {
                if let matchRange = Range(match.range(at: 1), in: content) {
                    let conceptStr = String(content[matchRange])
                    if !seen.contains(conceptStr.lowercased()) {
                        seen.insert(conceptStr.lowercased())
                        facts.append(KeyFact(type: .concept, value: conceptStr, context: extractContext(around: matchRange, in: content)))
                    }
                }
            }
        }

        return Array(facts.prefix(15)) // Limit to 15 facts
    }

    private func extractContext(around range: Range<String.Index>, in content: String, window: Int = 40) -> String {
        let start = content.index(range.lowerBound, offsetBy: -min(window, content.distance(from: content.startIndex, to: range.lowerBound)), limitedBy: content.startIndex) ?? content.startIndex
        let end = content.index(range.upperBound, offsetBy: min(window, content.distance(from: range.upperBound, to: content.endIndex)), limitedBy: content.endIndex) ?? content.endIndex
        var context = String(content[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
        if start != content.startIndex { context = "..." + context }
        if end != content.endIndex { context = context + "..." }
        return context
    }

    // MARK: - Action Items Extraction

    private func extractActionItems(from content: String) -> [String] {
        var actionItems: [String] = []
        let sentences = splitIntoSentences(content)

        let actionPatterns = [
            "should", "need to", "must", "have to", "ought to",
            "will", "going to", "plan to", "want to", "try to",
            "remember to", "don't forget", "next step", "action item",
            "todo", "to-do", "TODO", "FIXME", "HACK", "XXX",
        ]

        let imperativeVerbs = [
            "add", "create", "build", "make", "write", "update", "fix", "check",
            "review", "explore", "try", "look into", "research", "investigate",
            "download", "install", "configure", "set up", "run", "test",
            "implement", "design", "plan", "organize", "clean", "remove",
        ]

        for sentence in sentences {
            let lower = sentence.lowercased()

            // Check for action patterns
            let hasPattern = actionPatterns.contains { lower.contains($0) }
            let hasImperative = imperativeVerbs.contains { word in
                lower.hasPrefix(word) || lower.contains(" \(word) ")
            }

            // Check for bullet points or numbered items
            let isBulletPoint = sentence.hasPrefix("-") || sentence.hasPrefix("•") ||
                               sentence.range(of: "^\\d+[\\.)]", options: .regularExpression) != nil

            // Must have a verb and reasonable length
            let hasVerb = containsVerb(in: sentence)
            let reasonableLength = sentence.count > 15 && sentence.count < 200

            if (hasPattern || hasImperative || isBulletPoint) && hasVerb && reasonableLength {
                // Clean up the sentence
                var cleaned = sentence
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "^[-•]\\s*", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "^\\d+[\\.)]\\s*", with: "", options: .regularExpression)

                if !cleaned.isEmpty && !actionItems.contains(where: { $0.lowercased() == cleaned.lowercased() }) {
                    actionItems.append(cleaned)
                }
            }
        }

        return Array(actionItems.prefix(5))
    }

    private func containsVerb(in sentence: String) -> Bool {
        let commonVerbs = [
            "is", "are", "was", "were", "be", "been", "being",
            "have", "has", "had", "do", "does", "did", "will", "would",
            "could", "should", "may", "might", "must", "can",
            "add", "create", "build", "make", "write", "update", "fix", "check",
            "review", "explore", "try", "look", "research", "find", "see",
            "download", "install", "configure", "set", "run", "test",
            "implement", "design", "plan", "organize", "remove", "delete",
            "think", "know", "want", "need", "use", "see", "get", "got",
            "learn", "understand", "remember", "forget", "consider",
        ]

        let words = sentence.lowercased().components(separatedBy: .whitespacesAndNewlines)
        return words.contains { commonVerbs.contains($0) }
    }

    // MARK: - Questions Extraction

    private func extractQuestions(from content: String) -> [String] {
        var questions: [String] = []
        let sentences = splitIntoSentences(content)

        for sentence in sentences {
            // Must end with question mark or be a question pattern
            let isQuestion = sentence.contains("?") ||
                            sentence.lowercased().hasPrefix("what") ||
                            sentence.lowercased().hasPrefix("how") ||
                            sentence.lowercased().hasPrefix("why") ||
                            sentence.lowercased().hasPrefix("when") ||
                            sentence.lowercased().hasPrefix("where") ||
                            sentence.lowercased().hasPrefix("who") ||
                            sentence.lowercased().hasPrefix("which") ||
                            sentence.lowercased().hasPrefix("can ") ||
                            sentence.lowercased().hasPrefix("could ") ||
                            sentence.lowercased().hasPrefix("should ") ||
                            sentence.lowercased().hasPrefix("would ") ||
                            sentence.lowercased().hasPrefix("is ") ||
                            sentence.lowercased().hasPrefix("are ") ||
                            sentence.lowercased().hasPrefix("does ") ||
                            sentence.lowercased().hasPrefix("do ")

            if isQuestion {
                let cleaned = sentence
                    .trimmingCharacters(in: CharacterSet(charactersIn: "?"))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

                if !cleaned.isEmpty && cleaned.count > 10 && cleaned.count < 200 {
                    if !questions.contains(where: { $0.lowercased() == cleaned.lowercased() }) {
                        questions.append(cleaned)
                    }
                }
            }
        }

        return Array(questions.prefix(5))
    }

    // MARK: - Sentiment Analysis (simple keyword-based)

    private func analyzeSentiment(_ content: String) -> String {
        let positive = ["great", "excellent", "amazing", "love", "best", "awesome", "fantastic", "wonderful", "brilliant", "outstanding", "impressive", "helpful", "useful", "valuable", "powerful", "fast", "easy", "simple", "clean", "beautiful"]
        let negative = ["bad", "terrible", "awful", "hate", "worst", "horrible", "disappointing", "frustrating", "confusing", "broken", "slow", "difficult", "complex", "painful", "annoying", "problem", "issue", "bug", "error", "fail"]
        let neutral = ["interesting", "notable", "worth", "noted", "saved", "remember", "thought", "idea"]

        let words = content.lowercased().components(separatedBy: .whitespacesAndNewlines)
        var posCount = 0
        var negCount = 0
        var neuCount = 0

        for word in words {
            let clean = word.trimmingCharacters(in: .punctuationCharacters)
            if positive.contains(clean) { posCount += 1 }
            else if negative.contains(clean) { negCount += 1 }
            else if neutral.contains(clean) { neuCount += 1 }
        }

        if posCount > negCount + 1 { return "Positive" }
        else if negCount > posCount + 1 { return "Critical" }
        else if neuCount > posCount && neuCount > negCount { return "Informative" }
        return "Neutral"
    }

    // MARK: - Auto-Tagging

    struct SuggestedTag: Identifiable {
        let id = UUID()
        let tagName: String
        let confidence: Double
        let reason: String
    }

    func suggestTags(for source: Source) async -> [SuggestedTag] {
        var suggestions: [SuggestedTag] = []
        let content = (source.content + " " + source.title).lowercased()

        // Topic-based tags
        let topicMappings: [(keywords: [String], tagName: String, reason: String)] = [
            // Technology
            (["swift", "swiftui", "uikit", "xcode", "apple", "ios", "macos", "watchos"], "Apple Dev", "mentions Apple development"),
            (["python", "django", "flask", "pip", "pypi"], "Python", "mentions Python"),
            (["javascript", "typescript", "node", "npm", "react", "vue", "webpack"], "Web Dev", "mentions web development"),
            (["machine learning", "deep learning", "neural network", "ai", "llm", "gpt", "transformer", "ml model", "training data", "corpus"], "AI/ML", "mentions AI or machine learning"),
            (["local ai", "on-device", "ollama", "llama.cpp", "quantization", "coreml"], "Local AI", "mentions local AI"),
            (["docker", "kubernetes", "container", "k8s", "dockerfile"], "DevOps", "mentions containers/DevOps"),
            (["api", "rest", "graphql", "endpoint", "http", "request", "response"], "APIs", "mentions APIs"),
            (["database", "sql", "sqlite", "postgresql", "mongodb", "redis", "query"], "Databases", "mentions databases"),
            (["git", "github", "ci/cd", "pipeline", "workflow", "action"], "Git/CI", "mentions version control"),
            (["security", "auth", "oauth", "jwt", "encryption", "ssl", "tls", "vulnerability"], "Security", "mentions security"),
            (["performance", "speed", "optimize", "benchmark", "profiling", "latency", "throughput"], "Performance", "mentions performance"),
            (["testing", "unit test", "integration test", "tdd", "test coverage"], "Testing", "mentions testing"),
            (["design", "ux", "ui", "figma", "interface", "user experience"], "Design", "mentions design"),

            // Content Type Hints
            (["article", "blog", "post", "tweet", "thread"], "Articles", "content type hint"),
            (["book", "chapter", "reading", "page"], "Books", "content type hint"),
            (["meeting", "standup", "retro", "sprint", "planning"], "Meetings", "content type hint"),
            (["project", "kickoff", "roadmap", "milestone"], "Projects", "content type hint"),
            (["idea", "thought", "brainstorm", "concept"], "Ideas", "content type hint"),

            // Domain
            (["startup", "founder", "vc", "funding", "investor", "revenue", "saas", "pricing"], "Business", "mentions business/startup"),
            (["research", "study", "paper", "academic", "arxiv", "doi"], "Research", "mentions research"),
            (["personal", "life", "family", "health", "fitness", "travel", "trip"], "Personal", "personal content"),
        ]

        for mapping in topicMappings {
            var matchCount = 0
            for keyword in mapping.keywords {
                if content.contains(keyword) {
                    matchCount += 1
                }
            }

            if matchCount > 0 {
                let confidence = min(Double(matchCount) / Double(mapping.keywords.count), 1.0)
                if confidence >= 0.15 {
                    suggestions.append(SuggestedTag(
                        tagName: mapping.tagName,
                        confidence: confidence,
                        reason: mapping.reason
                    ))
                }
            }
        }

        // Sort by confidence
        suggestions.sort { $0.confidence > $1.confidence }

        // Take top 5
        return Array(suggestions.prefix(5))
    }

    // MARK: - Weekly Digest

    struct WeeklyDigest {
        let weekStartDate: Date
        let weekEndDate: Date
        let sourcesAdded: Int
        let topTopics: [String]
        let newTags: [String]
        let weeklyInsight: String
    }

    func generateWeeklyDigest(sources: [Source]) async -> WeeklyDigest {
        let calendar = Calendar.current
        let now = Date()
        let weekEnd = calendar.startOfDay(for: now)
        let weekStart = calendar.date(byAdding: .day, value: -7, to: weekEnd) ?? calendar.date(byAdding: .day, value: -7, to: now) ?? now

        // Filter sources from this week
        let weeklySources = sources.filter { $0.createdAt >= weekStart && $0.createdAt <= weekEnd }

        // Count by type
        var typeCounts: [SourceType: Int] = [:]
        for source in weeklySources {
            typeCounts[source.type, default: 0] += 1
        }

        // Extract top topics from content
        let allContent = weeklySources.map { "\($0.title) \($0.content)" }.joined(separator: " ")
        let topTopics = extractTopTopics(from: allContent, count: 5)

        // Find new tags (sources added this week with tags)
        let newTags = Set(weeklySources.flatMap { $0.tagIDs.map { String($0.uuidString.prefix(8)) } })

        // Generate insight
        let weeklyInsight = generateWeeklyInsight(
            sourcesCount: weeklySources.count,
            topTopics: topTopics,
            typeCounts: typeCounts,
            weekStart: weekStart
        )

        return WeeklyDigest(
            weekStartDate: weekStart,
            weekEndDate: weekEnd,
            sourcesAdded: weeklySources.count,
            topTopics: topTopics,
            newTags: Array(newTags),
            weeklyInsight: weeklyInsight
        )
    }

    private func extractTopTopics(from content: String, count: Int) -> [String] {
        let importantKeywords = [
            "apple", "swift", "python", "javascript", "typescript", "ai", "ml", "machine learning",
            "api", "database", "cloud", "aws", "performance", "security", "design", "ux",
            "startup", "business", "research", "product", "code", "programming",
            "ios", "macos", "web", "mobile", "server", "client", "architecture",
            "llm", "local", "on-device", "neural", "transformer", "language model",
            "git", "testing", "deployment", "devops", "container", "docker",
        ]

        var topicCounts: [String: Int] = [:]
        let contentLower = content.lowercased()

        for topic in importantKeywords {
            let occurrences = contentLower.components(separatedBy: topic).count - 1
            if occurrences > 0 {
                topicCounts[topic] = occurrences
            }
        }

        return topicCounts
            .sorted { $0.value > $1.value }
            .prefix(count)
            .map { $0.key.capitalized }
    }

    private func generateWeeklyInsight(sourcesCount: Int, topTopics: [String], typeCounts: [SourceType: Int], weekStart: Date) -> String {
        var insight = ""

        if sourcesCount == 0 {
            insight = "No new sources added this week. Start adding notes, articles, or voice memos to build your knowledge base!"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d"
            let weekStr = formatter.string(from: weekStart)

            insight = "This week (\(weekStr)): you added \(sourcesCount) new \(sourcesCount == 1 ? "source" : "sources")."

            if !topTopics.isEmpty {
                insight += " Top topics: \(topTopics.joined(separator: ", "))."
            }

            if let voiceCount = typeCounts[.voiceMemo], voiceCount > 0 {
                insight += " \(voiceCount) voice memo\(voiceCount == 1 ? "" : "s") captured."
            }

            if sourcesCount >= 5 {
                insight += " Great momentum building your knowledge base!"
            } else if sourcesCount >= 2 {
                insight += " Steady progress — keep it up!"
            }
        }

        return insight
    }

    // MARK: - Change Detection

    struct ChangeDiff {
        let sourceID: UUID
        let title: String
        let oldContent: String
        let newContent: String
        let changedAt: Date
        let changes: [Change]
    }

    struct Change {
        let type: ChangeType
        let excerpt: String

        enum ChangeType {
            case added
            case removed
            case modified
        }
    }

    func detectChanges(for sources: [Source], since days: Int = 7) async -> [ChangeDiff] {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        // This would compare current content with previously stored versions
        // For now, we detect changes by looking at recently updated sources
        let recentlyUpdated = sources.filter { $0.updatedAt > cutoffDate && $0.updatedAt != $0.createdAt }

        var diffs: [ChangeDiff] = []

        for source in recentlyUpdated {
            // In a real implementation, we'd compare with stored previous versions
            // Here we're simulating by extracting what's different
            let changes = extractChanges(source.content)
            if !changes.isEmpty {
                diffs.append(ChangeDiff(
                    sourceID: source.id,
                    title: source.title,
                    oldContent: "", // Would be stored previous version
                    newContent: source.content,
                    changedAt: source.updatedAt,
                    changes: changes
                ))
            }
        }

        return diffs
    }

    private func extractChanges(_ content: String) -> [Change] {
        // Simple change detection: find recent additions (sentences with recent dates or "new")
        var changes: [Change] = []
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let lower = line.lowercased()
            if lower.contains("updated") || lower.contains("new") || lower.contains("added") {
                if line.count > 10 && line.count < 300 {
                    changes.append(Change(type: .modified, excerpt: line.trimmingCharacters(in: .whitespaces)))
                }
            }
        }

        return changes
    }

    // MARK: - Helpers

    private func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { substring, _, _, _ in
            if let s = substring?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                sentences.append(s)
            }
        }
        return sentences
    }

    private func extractImportantWords(from content: String, topN: Int = 20) -> Set<String> {
        let stopWords: Set<String> = ["the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by", "is", "are", "was", "were", "be", "been", "being", "have", "has", "had", "do", "does", "did", "will", "would", "could", "should", "may", "might", "must", "can", "this", "that", "these", "those", "i", "you", "he", "she", "it", "we", "they", "what", "which", "who", "when", "where", "why", "how", "all", "each", "every", "both", "few", "more", "most", "other", "some", "such", "no", "nor", "not", "only", "own", "same", "so", "than", "too", "very", "just", "about", "into", "over", "after", "before", "between", "under", "again", "further", "then", "once", "here", "there", "any", "from", "up", "down", "out", "off", "above", "below", "your", "my", "his", "her", "their", "our", "its", "one", "two", "three", "first", "second", "new", "old", "also", "like", "use", "using", "used", "way", "make", "made", "get", "got"]

        let words = content.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 && !stopWords.contains($0) }

        var wordCounts: [String: Int] = [:]
        for word in words {
            wordCounts[word, default: 0] += 1
        }

        let sorted = wordCounts.sorted { $0.value > $1.value }
        let topWords = Set(sorted.prefix(topN).map { $0.key })

        return topWords
    }

    // MARK: - R7: Extended AI Analysis

    private func classifyTopic(_ content: String) -> String? {
        let lowercased = content.lowercased()
        let topicKeywords: [String: [String]] = [
            "Technology": ["software", "hardware", "computer", "ai", "machine learning", "app", "code", "programming", "developer", "api", "cloud", "data", "algorithm"],
            "Science": ["research", "study", "experiment", "scientist", "hypothesis", "discovery", "physics", "biology", "chemistry"],
            "Business": ["revenue", "company", "market", "startup", "investment", "founding", "ceo", "growth", "strategy", "customer", "sales", "product"],
            "Health": ["health", "medical", "doctor", "treatment", "patient", "disease", "therapy", "wellness", "exercise", "nutrition"],
            "Politics": ["government", "policy", "election", "vote", "congress", "senate", "law", "regulation"],
            "Entertainment": ["movie", "film", "music", "game", "show", "series", "actor", "director", "streaming"],
            "Sports": ["team", "player", "game", "match", "championship", "league", "score", "coach"],
            "Finance": ["stock", "market", "investment", "trading", "finance", "banking", "interest", "inflation", "economy"],
            "Education": ["school", "university", "student", "teacher", "course", "learning", "education", "degree"],
            "Lifestyle": ["travel", "food", "fashion", "recipe", "restaurant", "vacation", "hobby", "fitness"]
        ]
        var bestTopic: String?
        var bestScore = 0
        for (topic, keywords) in topicKeywords {
            let score = keywords.filter { lowercased.contains($0) }.count
            if score > bestScore { bestScore = score; bestTopic = topic }
        }
        return bestScore > 0 ? bestTopic : nil
    }

    private func assessReadingDifficulty(_ content: String) -> String? {
        let words = content.lowercased().components(separatedBy: .whitespacesAndNewlines)
        guard words.count > 50 else { return nil }
        let pattern = "\\b[a-z]{8,}\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, range: range)
        let ratio = Double(matches.count) / Double(words.count)
        if ratio > 0.15 { return "Hard" }
        if ratio > 0.08 { return "Medium" }
        return "Easy"
    }

    private func assessFreshness(_ content: String, sourceDate: Date?) -> String? {
        guard let date = sourceDate else { return "Unknown publication date — verify information freshness" }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days > 730 { return "This content is over 2 years old and may contain outdated information." }
        if days > 365 { return "This content is over 1 year old. Check for more recent sources." }
        if days > 180 { return "This content is 6+ months old. Verify if the information is still current." }
        return nil
    }

    private func findRelatedTopics(_ content: String) -> [String] {
        let lowercased = content.lowercased()
        let signatures: [String: [String]] = [
            "AI & Machine Learning": ["artificial intelligence", "machine learning", "neural network", "deep learning", "llm", "gpt"],
            "Climate Change": ["climate", "carbon", "emissions", "global warming", "sustainability", "renewable energy"],
            "Cryptocurrency": ["bitcoin", "ethereum", "blockchain", "crypto", "defi", "nft"],
            "Space": ["spacex", "nasa", "rocket", "satellite", "mars", "moon", "astronaut"],
            "Privacy": ["privacy", "surveillance", "gdpr", "data collection", "encryption"]
        ]
        var related: [String] = []
        for (topic, keywords) in signatures {
            if keywords.contains(where: { lowercased.contains($0) }) { related.append(topic) }
        }
        return Array(related.prefix(3))
    }

    private func extractKeyTakeaways(from content: String) -> [String] {
        let sentences = splitIntoSentences(content)
        guard sentences.count >= 2 else { return [] }
        var takeaways: [String] = []
        if let first = sentences.first {
            takeaways.append(first.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let importantWords = extractImportantWords(from: content)
        let scored = sentences.dropFirst().map { (s: $0, score: scoreTakeawaySentence($0, importantWords: importantWords)) }
            .sorted { $0.score > $1.score }
            .prefix(2)
        for item in scored {
            let cleaned = item.s.trimmingCharacters(in: .whitespacesAndNewlines)
            if !takeaways.contains(cleaned) { takeaways.append(cleaned) }
        }
        return Array(takeaways.prefix(3))
    }

    private func scoreTakeawaySentence(_ sentence: String, importantWords: Set<String>) -> Double {
        let words = sentence.lowercased().components(separatedBy: .whitespacesAndNewlines)
        var score = 0.0
        for word in words where importantWords.contains(word) { score += 1.0 }
        return score / max(1, Double(words.count))
    }
}

// MARK: - String Extension for Regex Matching

extension String {
    func matches(_ regex: NSRegularExpression) -> Bool {
        let range = NSRange(startIndex..., in: self)
        return regex.firstMatch(in: self, range: range) != nil
    }
}
