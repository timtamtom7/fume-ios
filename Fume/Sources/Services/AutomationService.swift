import Foundation

/// Automation Service — handles tag rules, daily digests, and scheduled tasks
actor AutomationService {
    static let shared = AutomationService()

    // MARK: - Tag Rules

    struct TagRule: Identifiable, Codable, Equatable {
        let id: UUID
        var triggerTagName: String  // Source has this tag → automatically add targetTagName
        var targetTagName: String    // Add this tag automatically
        var isEnabled: Bool
        var createdAt: Date

        init(id: UUID = UUID(), triggerTagName: String, targetTagName: String, isEnabled: Bool = true, createdAt: Date = Date()) {
            self.id = id
            self.triggerTagName = triggerTagName
            self.targetTagName = targetTagName
            self.isEnabled = isEnabled
            self.createdAt = createdAt
        }
    }

    // MARK: - Digest

    struct Digest: Identifiable {
        let id = UUID()
        let date: Date
        let sourcesCount: Int
        let topTags: [String]
        let topType: String?
        let message: String
    }

    // MARK: - Storage Keys

    private let tagRulesKey = "fume_tag_rules"
    private let lastDigestKey = "fume_last_digest"
    private let weeklyReviewDismissedKey = "fume_weekly_review_dismissed"

    private init() {}

    // MARK: - Tag Rules CRUD

    func fetchTagRules() -> [TagRule] {
        guard let data = UserDefaults.standard.data(forKey: tagRulesKey) else {
            return defaultRules()
        }

        do {
            let rules = try JSONDecoder().decode([TagRule].self, from: data)
            return rules.isEmpty ? defaultRules() : rules
        } catch {
            return defaultRules()
        }
    }

    func saveTagRules(_ rules: [TagRule]) {
        do {
            let data = try JSONEncoder().encode(rules)
            UserDefaults.standard.set(data, forKey: tagRulesKey)
        } catch {
            print("Failed to save tag rules: \(error)")
        }
    }

    func addTagRule(triggerTagName: String, targetTagName: String) -> TagRule {
        var rules = fetchTagRules()
        let newRule = TagRule(triggerTagName: triggerTagName, targetTagName: targetTagName)
        rules.append(newRule)
        saveTagRules(rules)
        return newRule
    }

    func updateTagRule(_ rule: TagRule) {
        var rules = fetchTagRules()
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
            saveTagRules(rules)
        }
    }

    func deleteTagRule(id: UUID) {
        var rules = fetchTagRules()
        rules.removeAll { $0.id == id }
        saveTagRules(rules)
    }

    func toggleTagRule(id: UUID) {
        var rules = fetchTagRules()
        if let index = rules.firstIndex(where: { $0.id == id }) {
            rules[index].isEnabled.toggle()
            saveTagRules(rules)
        }
    }

    /// Apply tag rules to a source and return any auto-added tag names
    func applyTagRules(to source: Source, allTags: [Tag]) async -> [String] {
        let rules = fetchTagRules().filter { $0.isEnabled }
        var autoAddedTagNames: [String] = []

        let sourceTagIDs = Set(source.tagIDs)

        for rule in rules {
            // Check if source has the trigger tag
            let hasTriggerTag = allTags.contains { tag in
                tag.name.lowercased() == rule.triggerTagName.lowercased() &&
                sourceTagIDs.contains(tag.id)
            }

            if hasTriggerTag {
                // Check if source doesn't already have the target tag
                let hasTargetTag = allTags.contains { tag in
                    tag.name.lowercased() == rule.targetTagName.lowercased() &&
                    sourceTagIDs.contains(tag.id)
                }

                if !hasTargetTag {
                    // Find the target tag or create it
                    if let existingTag = allTags.first(where: { $0.name.lowercased() == rule.targetTagName.lowercased() }) {
                        // Add to source
                        try? await DatabaseService.shared.updateSourceTags(
                            sourceID: source.id,
                            tagIDs: source.tagIDs + [existingTag.id]
                        )
                        autoAddedTagNames.append(existingTag.name)
                    } else {
                        // Create new tag
                        let newTag = Tag(name: rule.targetTagName, colorHex: TagColor.blue.rawValue)
                        try? await DatabaseService.shared.insertTag(newTag)
                        try? await DatabaseService.shared.updateSourceTags(
                            sourceID: source.id,
                            tagIDs: source.tagIDs + [newTag.id]
                        )
                        autoAddedTagNames.append(newTag.name)
                    }
                }
            }
        }

        return autoAddedTagNames
    }

    // MARK: - Default Rules

    private func defaultRules() -> [TagRule] {
        [
            TagRule(triggerTagName: "AI/ML", targetTagName: "Local AI", isEnabled: false),
            TagRule(triggerTagName: "Books", targetTagName: "Reading", isEnabled: false),
        ]
    }

    // MARK: - Digest

    func generateDailyDigest(sources: [Source]) async -> Digest? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            return nil
        }

        // Sources added today
        let todaySources = sources.filter { $0.createdAt >= today }
        let yesterdaySources = sources.filter { $0.createdAt >= yesterday && $0.createdAt < today }

        guard !todaySources.isEmpty else { return nil }

        // Top tags
        let allTagIDs = sources.flatMap { $0.tagIDs }
        var tagCounts: [UUID: Int] = [:]
        for tagID in allTagIDs {
            tagCounts[tagID, default: 0] += 1
        }

        // Top type
        var typeCounts: [SourceType: Int] = [:]
        for source in todaySources {
            typeCounts[source.type, default: 0] += 1
        }
        let topType = typeCounts.max { $0.value < $1.value }.map { $0.key.label }

        let message: String
        if todaySources.count == 1 {
            message = "You added 1 \(topType?.lowercased() ?? "source") today. Keep building!"
        } else {
            message = "You added \(todaySources.count) sources today. Great momentum!"
        }

        return Digest(
            date: today,
            sourcesCount: todaySources.count,
            topTags: [],
            topType: topType,
            message: message
        )
    }

    func generateWeeklyDigest(sources: [Source]) async -> Digest? {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
            return nil
        }
        let weekStartDay = calendar.startOfDay(for: weekStart)

        let weeklySources = sources.filter { $0.createdAt >= weekStartDay }

        guard !weeklySources.isEmpty else { return nil }

        // Count by type
        var typeCounts: [SourceType: Int] = [:]
        for source in weeklySources {
            typeCounts[source.type, default: 0] += 1
        }
        let topType = typeCounts.max { $0.value < $1.value }.map { $0.key.label }

        // Week-over-week comparison
        let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: weekStartDay) ?? calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let lastWeekSources = sources.filter {
            $0.createdAt >= lastWeekStart && $0.createdAt < weekStartDay
        }

        var message: String
        if weeklySources.count > lastWeekSources.count {
            let increase = weeklySources.count - lastWeekSources.count
            message = "\(weeklySources.count) sources this week (+ \(increase) vs last week). Your knowledge base is growing!"
        } else if weeklySources.count < lastWeekSources.count {
            let decrease = lastWeekSources.count - weeklySources.count
            message = "\(weeklySources.count) sources this week (- \(decrease) vs last week). Try adding a few more notes this week."
        } else {
            message = "\(weeklySources.count) sources this week — same as last week. Steady!"
        }

        if weeklySources.count >= 10 {
            message += " That's a solid week of building your second brain."
        }

        return Digest(
            date: weekStartDay,
            sourcesCount: weeklySources.count,
            topTags: [],
            topType: topType,
            message: message
        )
    }

    // MARK: - Weekly Review

    struct WeeklyReview {
        let weekStart: Date
        let weekEnd: Date
        let sourcesAdded: Int
        let topSources: [Source]
        let suggestedReviewQuestions: [String]
        let digest: String
    }

    func generateWeeklyReview(sources: [Source]) async -> WeeklyReview? {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
            return nil
        }
        let weekStartDay = calendar.startOfDay(for: weekStart)
        guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStartDay) else {
            return nil
        }

        let weeklySources = sources.filter { $0.createdAt >= weekStartDay && $0.createdAt <= weekEnd }

        guard !weeklySources.isEmpty else {
            return WeeklyReview(
                weekStart: weekStartDay,
                weekEnd: weekEnd,
                sourcesAdded: 0,
                topSources: [],
                suggestedReviewQuestions: [
                    "What was the most interesting thing you learned this week?",
                    "Did you capture any ideas worth revisiting?",
                    "What topics do you want to explore more next week?",
                ],
                digest: "No sources added this week. Start adding notes, articles, or voice memos to build your knowledge base!"
            )
        }

        // Sort by recency (most recent first) - take top 5
        let topSources = Array(weeklySources.sorted { $0.createdAt > $1.createdAt }.prefix(5))

        let suggestedQuestions = generateReviewQuestions(for: weeklySources)

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        let startStr = formatter.string(from: weekStartDay)
        let endStr = formatter.string(from: weekEnd)

        let digest = "Week of \(startStr) - \(endStr): You added \(weeklySources.count) source\(weeklySources.count == 1 ? "" : "s"). \(topSources.first?.title ?? "") was your most recent."

        return WeeklyReview(
            weekStart: weekStartDay,
            weekEnd: weekEnd,
            sourcesAdded: weeklySources.count,
            topSources: topSources,
            suggestedReviewQuestions: suggestedQuestions,
            digest: digest
        )
    }

    private func generateReviewQuestions(for sources: [Source]) -> [String] {
        var questions: [String] = []

        // Count types
        let hasVoiceMemos = sources.contains { $0.type == .voiceMemo }
        let hasArticles = sources.contains { $0.type == .article }
        let hasNotes = sources.contains { $0.type == .note }

        if hasVoiceMemos {
            questions.append("Any key insights from your voice memos this week worth revisiting?")
        }

        if hasArticles {
            questions.append("Which article had the biggest impact on your thinking this week?")
        }

        if hasNotes {
            questions.append("Did any of your written notes spark new ideas?")
        }

        if sources.count >= 5 {
            questions.append("You've been very active this week. What topic deserves more attention?")
        }

        // Always useful questions
        questions.append("What was the most surprising thing you learned this week?")
        questions.append("What's one thing you want to remember from this week?")
        questions.append("What topic should you explore more next week?")

        return Array(questions.prefix(4))
    }

    // MARK: - Rule Suggestion

    struct RuleSuggestion {
        let triggerTagName: String
        let targetTagName: String
        let reason: String
    }

    func suggestTagRules(basedOn sources: [Source], allTags: [Tag]) async -> [RuleSuggestion] {
        var suggestions: [RuleSuggestion] = []

        // Look for common co-occurrence patterns
        var tagCooccurrence: [UUID: Set<UUID>] = [:]

        for source in sources {
            for tagID1 in source.tagIDs {
                for tagID2 in source.tagIDs {
                    if tagID1 != tagID2 {
                        if tagCooccurrence[tagID1] == nil {
                            tagCooccurrence[tagID1] = Set()
                        }
                        tagCooccurrence[tagID1]?.insert(tagID2)
                    }
                }
            }
        }

        // Suggest rules for tags that frequently appear together
        let existingRules = fetchTagRules()
        let existingTriggerTargets = Set(existingRules.map { "\($0.triggerTagName.lowercased())|\($0.targetTagName.lowercased())" })

        for (tagID1, cooccurring) in tagCooccurrence {
            guard let tag1 = allTags.first(where: { $0.id == tagID1 }) else { continue }

            for tagID2 in cooccurring {
                guard let tag2 = allTags.first(where: { $0.id == tagID2 }) else { continue }

                // Check if rule doesn't already exist
                let pair = "\(tag1.name.lowercased())|\(tag2.name.lowercased())"
                if !existingTriggerTargets.contains(pair) {
                    suggestions.append(RuleSuggestion(
                        triggerTagName: tag1.name,
                        targetTagName: tag2.name,
                        reason: "'\(tag1.name)' and '\(tag2.name)' often appear together"
                    ))
                }
            }
        }

        return Array(suggestions.prefix(5))
    }

    // MARK: - Weekly Review Dismissal

    func dismissWeeklyReview() {
        UserDefaults.standard.set(Date(), forKey: weeklyReviewDismissedKey)
    }

    func weeklyReviewWasDismissedThisWeek() -> Bool {
        guard let lastDismissed = UserDefaults.standard.object(forKey: weeklyReviewDismissedKey) as? Date else {
            return false
        }

        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
            return false
        }
        let weekStartDay = calendar.startOfDay(for: weekStart)

        return lastDismissed >= weekStartDay
    }
}
