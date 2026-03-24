import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var showAddSheet = false
    @State private var selectedSource: Source?
    @State private var showPricing = false

    var body: some View {
        NavigationStack {
            ZStack {
                FumeColors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Query Input
                    queryInputSection

                    Divider()
                        .background(FumeColors.divider)

                    // Error Banner
                    if let error = viewModel.currentError {
                        ErrorBanner(
                            error: error,
                            onDismiss: { viewModel.dismissError() },
                            onAction: {
                                if error == .storageLimitReached {
                                    showPricing = true
                                }
                            }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Response Area
                    if viewModel.isThinking {
                        thinkingSection
                    } else if let response = viewModel.response {
                        responseSection(response)
                    } else {
                        emptyStateSection
                    }

                    Spacer()
                }
            }
            .navigationTitle("Fume")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showAddSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(FumeColors.accent)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddContentSheet()
            }
            .sheet(item: $selectedSource) { source in
                SourceDetailView(source: source)
            }
            .sheet(isPresented: $showPricing) {
                PricingView()
            }
        }
    }

    // MARK: - Query Input
    private var queryInputSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                TextField(placeholderText, text: $viewModel.queryText, axis: .vertical)
                    .font(.system(size: 16))
                    .foregroundStyle(FumeColors.textPrimary)
                    .lineLimit(1...4)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(FumeColors.surfaceRaised)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(FumeColors.border, lineWidth: 0.5)
                            )
                    )
                    .onSubmit {
                        Task { await viewModel.submitQuery() }
                    }

                Button {
                    Task { await viewModel.submitQuery() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            viewModel.queryText.isEmpty ?
                            FumeColors.textSecondary :
                            FumeColors.accent
                        )
                }
                .disabled(viewModel.queryText.isEmpty || viewModel.isThinking)
            }

            if viewModel.response != nil {
                Button("Clear", systemImage: "xmark") {
                    viewModel.clearResponse()
                }
                .font(.system(size: 13))
                .foregroundStyle(FumeColors.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var placeholderText: String {
        // Rotate through real example queries
        let queries = RealContent.demoQueries
        let index = Int(Date().timeIntervalSince1970) % queries.count
        return queries[index]
    }

    // MARK: - Thinking Section
    private var thinkingSection: some View {
        VStack(spacing: 16) {
            ThinkingIndicator()

            Text("Searching your knowledge base...")
                .font(.system(size: 14))
                .foregroundStyle(FumeColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Response Section
    private func responseSection(_ response: QueryResponse) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Answer Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundStyle(FumeColors.accent)
                        Text("Answer")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(FumeColors.textSecondary)
                    }

                    Text(response.answer)
                        .font(.system(size: 15))
                        .foregroundStyle(FumeColors.textPrimary)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                }
                .glassCard()
                .amberGlow(isActive: false)

                // Sources Header
                if !response.sources.isEmpty {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(FumeColors.accent)
                        Text("From your notes:")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(FumeColors.textSecondary)
                    }
                    .padding(.horizontal, 4)

                    // Source Cards
                    ForEach(response.sources) { match in
                        SourceCard(match: match)
                            .onTapGesture {
                                selectedSource = match.source
                            }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Empty State
    private var emptyStateSection: some View {
        VStack(spacing: 20) {
            Spacer()

            // Custom brain illustration
            BrainIllustration()
                .frame(width: 180, height: 160)

            VStack(spacing: 8) {
                Text("Your second brain awaits")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(FumeColors.textPrimary)

                Text("Add notes, articles, voice memos,\nand images to build your knowledge base.")
                    .font(.system(size: 14))
                    .foregroundStyle(FumeColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showAddSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Add your first note")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(FumeColors.background)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(FumeColors.accent)
                )
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

// MARK: - Source Card
struct SourceCard: View {
    let match: SourceMatch

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SourceTypeIcon(type: match.source.type, size: 16)

                Text(match.source.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(FumeColors.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text(match.source.formattedDate)
                    .font(.system(size: 11))
                    .foregroundStyle(FumeColors.textSecondary)
            }

            Text(match.excerpt)
                .font(.system(size: 13))
                .foregroundStyle(FumeColors.textSecondary)
                .lineLimit(3)
                .lineSpacing(3)
        }
        .glassCard()
        .overlay(
            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(FumeColors.textSecondary)
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
            }
        )
    }
}

// MARK: - Thinking Indicator
struct ThinkingIndicator: View {
    @State private var animOffset: CGFloat = 0
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<5) { index in
                Circle()
                    .fill(FumeColors.accent)
                    .frame(width: 8, height: 8)
                    .offset(y: animOffset(for: index))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(FumeColors.glassOverlay)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(FumeColors.accent.opacity(0.3), lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }

    private func animOffset(for index: Int) -> CGFloat {
        guard isAnimating else { return 0 }
        let delay = Double(index) * 0.1
        return sin(CGFloat(delay) * .pi) * 6
    }
}
