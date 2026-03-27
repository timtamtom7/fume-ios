import SwiftUI

struct AIAnalysisView: View {
    let source: Source
    @State private var analysis: IntelligenceService.AnalysisResult?
    @State private var suggestedTags: [IntelligenceService.SuggestedTag] = []
    @State private var isLoading = true
    @State private var showFullAnalysis = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(FumeColors.accent)
                Text("AI Analysis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FumeColors.textPrimary)

                Spacer()

                if isLoading {
                    ProgressView()
                        .tint(FumeColors.accent)
                        .scaleEffect(0.7)
                } else {
                    Button {
                        showFullAnalysis = true
                    } label: {
                        Text("Full Analysis")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(FumeColors.accent)
                    }
                }
            }

            if isLoading {
                loadingPlaceholder
            } else if let analysis = analysis {
                // Summary
                if !analysis.summary.isEmpty {
                    summarySection(analysis.summary)
                }

                // Key Facts Preview
                if !analysis.keyFacts.isEmpty {
                    keyFactsPreview(analysis.keyFacts)
                }

                // Suggested Tags
                if !suggestedTags.isEmpty {
                    suggestedTagsSection
                }

                // Action Items Preview
                if !analysis.actionItems.isEmpty {
                    actionItemsPreview(analysis.actionItems)
                }
            }
        }
        .glassCard()
        .task {
            await loadAnalysis()
        }
        .sheet(isPresented: $showFullAnalysis) {
            if let analysis = analysis {
                FullAnalysisSheet(
                    source: source,
                    analysis: analysis,
                    suggestedTags: suggestedTags
                )
            }
        }
    }

    // MARK: - Summary Section

    private func summarySection(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 11))
                    .foregroundStyle(FumeColors.accent)
                Text("Summary")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FumeColors.textSecondary)
            }

            Text(summary)
                .font(.system(size: 14))
                .foregroundStyle(FumeColors.textPrimary)
                .lineSpacing(3)
                .lineLimit(showFullAnalysis ? nil : 3)
        }
    }

    // MARK: - Key Facts Preview

    private func keyFactsPreview(_ facts: [IntelligenceService.KeyFact]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "number.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(FumeColors.accent)
                Text("Key Facts")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FumeColors.textSecondary)

                Spacer()

                Text("\(facts.prefix(5).count) found")
                    .font(.system(size: FumeTokens.fontSizeCaption))
                    .foregroundStyle(FumeColors.textSecondary.opacity(0.7))
            }

            FlowLayout(spacing: 6) {
                ForEach(facts.prefix(5)) { fact in
                    KeyFactChip(fact: fact)
                }
            }
        }
    }

    // MARK: - Suggested Tags

    private var suggestedTagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "tag")
                    .font(.system(size: 11))
                    .foregroundStyle(FumeColors.accent)
                Text("Suggested Tags")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FumeColors.textSecondary)
            }

            FlowLayout(spacing: 6) {
                ForEach(suggestedTags.prefix(4)) { suggestion in
                    SuggestedTagChip(suggestion: suggestion)
                }
            }
        }
    }

    // MARK: - Action Items Preview

    private func actionItemsPreview(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "checklist")
                    .font(.system(size: 11))
                    .foregroundStyle(FumeColors.accent)
                Text("Action Items")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FumeColors.textSecondary)

                Spacer()

                Text("\(items.count) found")
                    .font(.system(size: FumeTokens.fontSizeCaption))
                    .foregroundStyle(FumeColors.textSecondary.opacity(0.7))
            }

            ForEach(items.prefix(2), id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: FumeTokens.fontSizeCaption))
                        .foregroundStyle(FumeColors.accent.opacity(0.7))
                        .padding(.top, 2)

                    Text(item)
                        .font(.system(size: 13))
                        .foregroundStyle(FumeColors.textPrimary)
                        .lineLimit(2)
                }
            }
        }
    }

    // MARK: - Loading Placeholder

    private var loadingPlaceholder: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: FumeTokens.cornerRadiusSmall)
                    .fill(FumeColors.surfaceRaised.opacity(0.5))
                    .frame(width: 100, height: 12)

                RoundedRectangle(cornerRadius: FumeTokens.cornerRadiusSmall)
                    .fill(FumeColors.surfaceRaised.opacity(0.5))
                    .frame(width: 60, height: 12)
            }

            RoundedRectangle(cornerRadius: FumeTokens.cornerRadiusSmall)
                .fill(FumeColors.surfaceRaised.opacity(0.3))
                .frame(height: 11)
                .padding(.trailing, 40)

            RoundedRectangle(cornerRadius: FumeTokens.cornerRadiusSmall)
                .fill(FumeColors.surfaceRaised.opacity(0.3))
                .frame(height: 11)
                .padding(.trailing, 20)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Load Analysis

    private func loadAnalysis() async {
        isLoading = true
        analysis = await IntelligenceService.shared.analyzeSource(source)
        suggestedTags = await IntelligenceService.shared.suggestTags(for: source)
        isLoading = false
    }
}

// MARK: - Key Fact Chip

struct KeyFactChip: View {
    let fact: IntelligenceService.KeyFact

    var icon: String {
        switch fact.type {
        case .date: return "calendar"
        case .name: return "person"
        case .number: return "number"
        case .url: return "link"
        case .email: return "envelope"
        case .location: return "mappin"
        case .technology: return "cpu"
        case .concept: return "lightbulb"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))

            Text(fact.value)
                .font(.system(size: FumeTokens.fontSizeCaption, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(FumeColors.textPrimary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(FumeColors.surfaceRaised)
        )
        .overlay(
            Capsule()
                .stroke(FumeColors.border.opacity(0.5), lineWidth: 0.5)
        )
        .accessibilityLabel("\(icon.replacingOccurrences(of: ".", with: " ")): \(fact.value)")
    }
}

// MARK: - Suggested Tag Chip

struct SuggestedTagChip: View {
    let suggestion: IntelligenceService.SuggestedTag
    @State private var isAdded = false

    var body: some View {
        HStack(spacing: 4) {
            if isAdded {
                Image(systemName: "checkmark")
                    .font(.system(size: FumeTokens.fontSizeCaption2))
                    .foregroundStyle(.green)
            }

            Text("#\(suggestion.tagName)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isAdded ? .green : FumeColors.textPrimary)

            if !isAdded {
                Text("+\(Int(suggestion.confidence * 100))%")
                    .font(.system(size: FumeTokens.fontSizeCaption2))
                    .foregroundStyle(FumeColors.accent.opacity(0.7))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(isAdded ? Color.green.opacity(0.1) : FumeColors.accent.opacity(0.1))
        )
        .overlay(
            Capsule()
                .stroke(isAdded ? Color.green.opacity(0.3) : FumeColors.accent.opacity(0.3), lineWidth: 0.5)
        )
        .accessibilityLabel("Suggested tag: \(suggestion.tagName), \(Int(suggestion.confidence * 100))% confidence")
    }
}

// MARK: - Full Analysis Sheet

struct FullAnalysisSheet: View {
    @Environment(\.dismiss) private var dismiss
    let source: Source
    let analysis: IntelligenceService.AnalysisResult
    let suggestedTags: [IntelligenceService.SuggestedTag]

    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            ZStack {
                FumeColors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Tab Picker
                    Picker("Analysis", selection: $selectedTab) {
                        Text("Summary").tag(0)
                        Text("Facts").tag(1)
                        Text("Actions").tag(2)
                        Text("Questions").tag(3)
                        Text("Tags").tag(4)
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            switch selectedTab {
                            case 0:
                                summaryTab
                            case 1:
                                factsTab
                            case 2:
                                actionsTab
                            case 3:
                                questionsTab
                            case 4:
                                tagsTab
                            default:
                                EmptyView()
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Full Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(FumeColors.accent)
                }
            }
        }
    }

    // MARK: - Summary Tab

    private var summaryTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Summary Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "text.alignleft")
                        .foregroundStyle(FumeColors.accent)
                    Text("Summary")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FumeColors.textPrimary)
                }

                Text(analysis.summary)
                    .font(.system(size: 15))
                    .foregroundStyle(FumeColors.textPrimary)
                    .lineSpacing(5)
            }
            .glassCard()

            // Sentiment
            HStack(spacing: 12) {
                Image(systemName: sentimentIcon)
                    .font(.system(size: 20))
                    .foregroundStyle(sentimentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Sentiment")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FumeColors.textPrimary)
                    Text(analysis.sentiment)
                        .font(.system(size: 12))
                        .foregroundStyle(FumeColors.textSecondary)
                }

                Spacer()
            }
            .glassCard()
        }
    }

    private var sentimentIcon: String {
        switch analysis.sentiment {
        case "Positive": return "face.smiling"
        case "Critical": return "exclamationmark.triangle"
        case "Informative": return "lightbulb"
        default: return "minus.circle"
        }
    }

    private var sentimentColor: Color {
        switch analysis.sentiment {
        case "Positive": return .green
        case "Critical": return .orange
        case "Informative": return .blue
        default: return FumeColors.accent
        }
    }

    // MARK: - Facts Tab

    private var factsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            if analysis.keyFacts.isEmpty {
                emptyState(message: "No key facts extracted from this source.")
            } else {
                // Group by type
                ForEach(groupedFacts.keys.sorted { $0.rawValue < $1.rawValue }, id: \.self) { type in
                    if let facts = groupedFacts[type] {
                        factGroup(type: type, facts: facts)
                    }
                }
            }
        }
    }

    private func factGroup(type: IntelligenceService.KeyFact.FactType, facts: [IntelligenceService.KeyFact]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: iconForFactType(type))
                    .foregroundStyle(FumeColors.accent)
                Text(type.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FumeColors.textSecondary)

                Spacer()

                Text("\(facts.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(FumeColors.textSecondary.opacity(0.7))
            }

            ForEach(facts) { fact in
                VStack(alignment: .leading, spacing: 4) {
                    Text(fact.value)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(FumeColors.textPrimary)

                    if !fact.context.isEmpty {
                        Text(fact.context)
                            .font(.system(size: 12))
                            .foregroundStyle(FumeColors.textSecondary)
                            .lineLimit(2)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .glassCard()
    }

    private func iconForFactType(_ type: IntelligenceService.KeyFact.FactType) -> String {
        switch type {
        case .date: return "calendar"
        case .name: return "person"
        case .number: return "number"
        case .url: return "link"
        case .email: return "envelope"
        case .location: return "mappin"
        case .technology: return "cpu"
        case .concept: return "lightbulb"
        }
    }

    private var groupedFacts: [IntelligenceService.KeyFact.FactType: [IntelligenceService.KeyFact]] {
        Dictionary(grouping: analysis.keyFacts, by: { $0.type })
    }

    // MARK: - Actions Tab

    private var actionsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            if analysis.actionItems.isEmpty {
                emptyState(message: "No action items found in this source.")
            } else {
                ForEach(Array(analysis.actionItems.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(FumeColors.accent.opacity(0.15))
                                .frame(width: 28, height: 28)

                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(FumeColors.accent)
                        }

                        Text(item)
                            .font(.system(size: 14))
                            .foregroundStyle(FumeColors.textPrimary)
                            .lineSpacing(3)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - Questions Tab

    private var questionsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            if analysis.questionsRaised.isEmpty {
                emptyState(message: "No questions raised by this source.")
            } else {
                ForEach(analysis.questionsRaised, id: \.self) { question in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundStyle(FumeColors.accent.opacity(0.7))

                        Text(question)
                            .font(.system(size: 14))
                            .foregroundStyle(FumeColors.textPrimary)
                            .lineSpacing(3)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - Tags Tab

    private var tagsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            if suggestedTags.isEmpty {
                emptyState(message: "No tag suggestions for this source.")
            } else {
                ForEach(suggestedTags) { suggestion in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(FumeColors.accent.opacity(0.15))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text("#")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(FumeColors.accent)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(suggestion.tagName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(FumeColors.textPrimary)

                            Text(suggestion.reason)
                                .font(.system(size: 12))
                                .foregroundStyle(FumeColors.textSecondary)
                        }

                        Spacer()

                        Text("\(Int(suggestion.confidence * 100))%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(FumeColors.accent)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - Empty State

    private func emptyState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(FumeColors.textSecondary.opacity(0.4))

            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(FumeColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Digest View

struct DigestView: View {
    let digest: AutomationService.Digest
    @State private var showDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "bell.badge")
                    .foregroundStyle(FumeColors.accent)
                Text("Digest")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FumeColors.textSecondary)

                Spacer()

                Text(formattedDate(digest.date))
                    .font(.system(size: 11))
                    .foregroundStyle(FumeColors.textSecondary.opacity(0.7))
            }

            Text(digest.message)
                .font(.system(size: 14))
                .foregroundStyle(FumeColors.textPrimary)
                .lineSpacing(3)

            HStack(spacing: 12) {
                Label("\(digest.sourcesCount)", systemImage: "doc.text")
                    .font(.system(size: 12))
                    .foregroundStyle(FumeColors.textSecondary)

                if let topType = digest.topType {
                    Label(topType, systemImage: "tag")
                        .font(.system(size: 12))
                        .foregroundStyle(FumeColors.textSecondary)
                }
            }
        }
        .glassCard()
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Weekly Review View

struct WeeklyReviewView: View {
    let review: AutomationService.WeeklyReview
    @State private var currentQuestionIndex = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(FumeColors.accent)
                Text("Weekly Review")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FumeColors.textPrimary)

                Spacer()

                Text(weekRangeText)
                    .font(.system(size: 11))
                    .foregroundStyle(FumeColors.textSecondary.opacity(0.7))
            }

            // Stats
            HStack(spacing: 16) {
                StatCard(value: "\(review.sourcesAdded)", label: "Sources", icon: "doc.text")
                StatCard(value: "\(review.topSources.count)", label: "Added", icon: "plus.circle")
            }

            // Current question
            if !review.suggestedReviewQuestions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Reflect")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FumeColors.textSecondary)

                    Text(review.suggestedReviewQuestions[currentQuestionIndex])
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(FumeColors.textPrimary)
                        .lineSpacing(4)

                    HStack(spacing: 8) {
                        ForEach(0..<review.suggestedReviewQuestions.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentQuestionIndex ? FumeColors.accent : FumeColors.textSecondary.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }

                        Spacer()

                        Button {
                            withAnimation {
                                currentQuestionIndex = (currentQuestionIndex + 1) % review.suggestedReviewQuestions.count
                            }
                        } label: {
                            Label("Next", systemImage: "arrow.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(FumeColors.accent)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            // Top sources
            if !review.topSources.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("This Week")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FumeColors.textSecondary)

                    ForEach(review.topSources.prefix(3)) { source in
                        HStack(spacing: 8) {
                            Image(systemName: source.type.icon)
                                .font(.system(size: 12))
                                .foregroundStyle(FumeColors.accent.opacity(0.7))
                                .frame(width: 16)

                            Text(source.title)
                                .font(.system(size: 13))
                                .foregroundStyle(FumeColors.textPrimary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .glassCard()
    }

    private var weekRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: review.weekStart)) - \(formatter.string(from: review.weekEnd))"
    }
}

struct StatCard: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(FumeColors.accent.opacity(0.7))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(FumeColors.textPrimary)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(FumeColors.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: FumeTokens.cornerRadiusSmall)
                .fill(FumeColors.surfaceRaised)
        )
    }
}
