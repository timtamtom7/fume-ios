import SwiftUI

// MARK: - Mac AI Chat View

struct MacAIChatView: View {
    @ObservedObject var viewModel: HomeViewModel
    let contextSource: Source?

    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 14))
                            .foregroundStyle(FumeColors.accent)

                        Text("Fume AI")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(FumeColors.textPrimary)
                    }

                    Text("Ask questions about your knowledge base")
                        .font(.system(size: 11))
                        .foregroundStyle(FumeColors.textSecondary)
                }

                Spacer()

                if viewModel.isThinking {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(FumeColors.accent)
                            .frame(width: 6, height: 6)
                            .modifier(PulseGlow())

                        Text("Thinking...")
                            .font(.system(size: 11))
                            .foregroundStyle(FumeColors.textSecondary)
                    }
                }
            }
            .padding()
            .background(FumeColors.surface)

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if let context = contextSource {
                            contextBanner(context)
                        }

                        if !viewModel.queryText.isEmpty, viewModel.response == nil, !viewModel.isThinking {
                            // Show the query that was submitted
                            queryBubble(viewModel.queryText)
                        }

                        if viewModel.isThinking {
                            thinkingIndicator
                        }

                        if let response = viewModel.response {
                            answerBubble(response)
                        }

                        if viewModel.queryText.isEmpty && viewModel.response == nil {
                            welcomeState
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.response?.id) { _, _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .background(FumeColors.background)

            Divider()

            // Input
            inputBar
        }
        .background(FumeColors.background)
    }

    // MARK: - Context Banner

    private func contextBanner(_ source: Source) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 12))
                .foregroundStyle(FumeColors.accent)

            Text("Context: \(source.title)")
                .font(.system(size: 12))
                .foregroundStyle(FumeColors.textSecondary)
                .lineLimit(1)

            Spacer()

            Image(systemName: source.type.icon)
                .font(.system(size: 10))
                .foregroundStyle(typeColor(for: source.type))
        }
        .padding(10)
        .background(FumeColors.sourceHighlight)
        .cornerRadius(10)
    }

    // MARK: - Query Bubble

    private func queryBubble(_ text: String) -> some View {
        HStack {
            Spacer()
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(FumeColors.textPrimary)
                .padding(12)
                .background(FumeColors.accent.opacity(0.2))
                .cornerRadius(16, corners: [.topLeft, .topRight, .bottomLeft])
                .id("bottom")
        }
    }

    // MARK: - Answer Bubble

    private func answerBubble(_ response: QueryResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // AI answer
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 11))
                        .foregroundStyle(FumeColors.accent)
                    Text("Fume")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(FumeColors.accent)
                }

                Text(response.answer)
                    .font(.system(size: 14))
                    .lineSpacing(5)
                    .foregroundStyle(FumeColors.textPrimary)
                    .textSelection(.enabled)
            }
            .padding(14)
            .background(FumeColors.surfaceRaised)
            .cornerRadius(14, corners: [.topLeft, .topRight, .bottomRight])

            // Source citations
            if !response.sources.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CITATIONS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(FumeColors.textSecondary)

                    ForEach(response.sources.prefix(3)) { match in
                        citationRow(match)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .id("bottom")
    }

    private func citationRow(_ match: SourceMatch) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(typeColor(for: match.source.type).opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: match.source.type.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(typeColor(for: match.source.type))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(match.source.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FumeColors.textPrimary)
                    .lineLimit(1)

                Text(match.excerpt)
                    .font(.system(size: 11))
                    .foregroundStyle(FumeColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Text("\(Int(match.relevanceScore * 100))%")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(relevanceColor(match.relevanceScore))
        }
        .padding(10)
        .background(FumeColors.surface)
        .cornerRadius(10)
    }

    // MARK: - Thinking Indicator

    private var thinkingIndicator: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 11))
                        .foregroundStyle(FumeColors.accent)
                    Text("Fume")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(FumeColors.accent)
                }

                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(FumeColors.accent.opacity(0.5 + Double(i) * 0.2))
                            .frame(width: 6, height: 6)
                            .modifier(DotBounce(delay: Double(i) * 0.15))
                    }
                }

                Text("Searching your knowledge base...")
                    .font(.system(size: 12))
                    .foregroundStyle(FumeColors.textSecondary)
            }
            .padding(14)
            .background(FumeColors.surfaceRaised)
            .cornerRadius(14, corners: [.topLeft, .topRight, .bottomRight])
            .modifier(AmberGlowModifier(isActive: true))

            Spacer()
        }
        .id("bottom")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Fume is thinking. Searching your knowledge base.")
    }

    // MARK: - Welcome State

    private var welcomeState: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 36))
                .foregroundStyle(FumeColors.accent.opacity(0.4))

            Text("Ask Fume anything")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(FumeColors.textPrimary)

            Text("Your notes, articles, and voice memos\nare your knowledge base. Ask anything.")
                .font(.system(size: 13))
                .foregroundStyle(FumeColors.textSecondary)
                .multilineTextAlignment(.center)

            // Example queries
            VStack(spacing: 8) {
                ForEach(exampleQueries, id: \.self) { query in
                    Button {
                        inputText = query
                        Task { await submitQuery() }
                    } label: {
                        Text("\"\(query)\"")
                            .font(.system(size: 12))
                            .foregroundStyle(FumeColors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(FumeColors.surfaceRaised)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Example query: \(query)")
                    .accessibilityHint("Click to submit this example question to Fume AI.")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask about your notes...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .lineLimit(1...4)
                .focused($isInputFocused)
                .padding(12)
                .background(FumeColors.surfaceRaised)
                .cornerRadius(12)
                .accessibilityLabel("Question input")
                .onSubmit {
                    Task { await submitQuery() }
                }

            Button {
                Task { await submitQuery() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(inputText.isEmpty ? FumeColors.textSecondary : FumeColors.accent)
            }
            .buttonStyle(.plain)
            .disabled(inputText.isEmpty || viewModel.isThinking)
            .accessibilityLabel("Send question")
            .accessibilityHint(inputText.isEmpty ? "Enter a question first." : "Submits your question to Fume AI.")
        }
        .padding()
        .background(FumeColors.surface)
    }

    // MARK: - Helpers

    private var exampleQueries: [String] {
        [
            "What are my main interests?",
            "Summarize my recent notes",
            "Find notes about work projects"
        ]
    }

    private func submitQuery() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        viewModel.queryText = text
        inputText = ""
        await viewModel.submitQuery()
    }

    private func typeColor(for type: SourceType) -> Color {
        switch type {
        case .note: return FumeColors.accent
        case .article: return Color.blue
        case .voiceMemo: return Color.purple
        case .image: return Color.green
        case .pdf: return Color.red
        }
    }

    private func relevanceColor(_ score: Double) -> Color {
        if score >= 0.7 { return .green }
        if score >= 0.4 { return FumeColors.accent }
        return FumeColors.textSecondary
    }
}

// MARK: - Animations

struct PulseGlow: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .opacity(isAnimating ? 0.4 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}

struct DotBounce: ViewModifier {
    let delay: Double
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .offset(y: isAnimating ? -4 : 4)
            .animation(
                .easeInOut(duration: 0.5)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}

struct AmberGlowModifier: ViewModifier {
    var isActive: Bool

    func body(content: Content) -> some View {
        content
            .shadow(color: FumeColors.accent.opacity(isActive ? 0.3 : 0), radius: isActive ? 12 : 0)
    }
}

// MARK: - Corner Radius Extension (macOS compatible)

extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

struct RectCorner: OptionSet {
    let rawValue: Int

    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomLeft = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)
    static let allCornners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

struct RoundedCornerShape: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner = .allCornners

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(radius, rect.width / 2, rect.height / 2)

        // Start at top-left (if not rounded) or top-left of corner arc
        if corners.contains(.topLeft) {
            path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        }

        // Top edge
        path.addLine(to: CGPoint(x: corners.contains(.topRight) ? rect.maxX - r : rect.maxX, y: rect.minY))

        // Top-right corner
        if corners.contains(.topRight) {
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r),
                              control: CGPoint(x: rect.maxX, y: rect.minY))
        }

        // Right edge
        path.addLine(to: CGPoint(x: rect.maxX, y: corners.contains(.bottomRight) ? rect.maxY - r : rect.maxY))

        // Bottom-right corner
        if corners.contains(.bottomRight) {
            path.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY),
                              control: CGPoint(x: rect.maxX, y: rect.maxY))
        }

        // Bottom edge
        path.addLine(to: CGPoint(x: corners.contains(.bottomLeft) ? rect.minX + r : rect.minX, y: rect.maxY))

        // Bottom-left corner
        if corners.contains(.bottomLeft) {
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r),
                              control: CGPoint(x: rect.minX, y: rect.maxY))
        }

        // Left edge
        path.addLine(to: CGPoint(x: rect.minX, y: corners.contains(.topLeft) ? rect.minY + r : rect.minY))

        if corners.contains(.topLeft) {
            path.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY),
                              control: CGPoint(x: rect.minX, y: rect.minY))
        }

        path.closeSubpath()
        return path
    }
}
