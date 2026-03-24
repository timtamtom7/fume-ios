import SwiftUI

struct SourceDetailView: View {
    let source: Source
    var allTags: [Tag] = []
    var onTagUpdate: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var isDeleted = false
    @State private var relatedSources: [Source] = []
    @State private var isLoadingRelated = false
    @State private var showTagEditor = false
    @State private var localAllTags: [Tag] = []
    @State private var showExportSheet = false
    @State private var showShareSheet = false
    @State private var isExporting = false
    @State private var exportResult: ExportResult?
    @State private var exportError: Error?
    @State private var showExportError = false

    var effectiveTags: [Tag] {
        allTags.isEmpty ? localAllTags : allTags
    }

    var sourceTags: [Tag] {
        effectiveTags.filter { source.tagIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FumeColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header Card
                        headerCard

                        // Tags Section
                        if !allTags.isEmpty {
                            tagsSection
                        }

                        // Content
                        contentSection

                        // AI Analysis
                        AIAnalysisView(source: source)

                        // URL if article
                        if let url = source.url, let articleURL = URL(string: url) {
                            urlSection(articleURL)
                        }

                        // Related Sources
                        relatedSourcesSection

                        // Metadata
                        metadataSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(source.type.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(FumeColors.accent)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showExportSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(FumeColors.accent)
                        }

                        Button {
                            showTagEditor = true
                        } label: {
                            Image(systemName: "tag")
                                .foregroundStyle(FumeColors.accent)
                        }

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .task {
                if allTags.isEmpty {
                    localAllTags = (try? await DatabaseService.shared.fetchAllTags()) ?? []
                }
                await loadRelatedSources()
            }
            .confirmationDialog(
                "Delete Source",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    Task {
                        try? await DatabaseService.shared.deleteSource(id: source.id)
                        isDeleted = true
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete this source from your knowledge base.")
            }
            .sheet(isPresented: $showTagEditor) {
                TagEditorSheet(
                    source: source,
                    allTags: effectiveTags,
                    onSave: { selectedTagIDs in
                        Task {
                            try? await DatabaseService.shared.updateSourceTags(sourceID: source.id, tagIDs: selectedTagIDs)
                            onTagUpdate()
                        }
                    }
                )
            }
            .sheet(isPresented: $showExportSheet) {
                SourceExportSheet(source: source)
            }
        }
    }

    // MARK: - Header Card
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(FumeColors.surfaceRaised)
                        .frame(width: 48, height: 48)

                    Image(systemName: source.type.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(FumeColors.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(source.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(FumeColors.textPrimary)
                        .lineLimit(2)

                    Text(source.formattedDate)
                        .font(.system(size: 13))
                        .foregroundStyle(FumeColors.textSecondary)
                }

                Spacer()
            }

            if let thumbnailData = source.thumbnailData,
               let uiImage = UIImage(data: thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 150)
                    .cornerRadius(12)
            }
        }
        .glassCard()
    }

    // MARK: - Tags Section
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "tag")
                    .foregroundStyle(FumeColors.accent)
                Text("Tags")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FumeColors.textSecondary)

                Spacer()

                Button {
                    showTagEditor = true
                } label: {
                    Text("Edit")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(FumeColors.accent)
                }
            }

            if sourceTags.isEmpty {
                Text("No tags added")
                    .font(.system(size: 13))
                    .foregroundStyle(FumeColors.textSecondary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(sourceTags) { tag in
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color(hex: tag.colorHex))
                                .frame(width: 8, height: 8)

                            Text(tag.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(FumeColors.textPrimary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color(hex: tag.colorHex).opacity(0.15))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color(hex: tag.colorHex).opacity(0.3), lineWidth: 0.5)
                        )
                    }
                }
            }
        }
        .glassCard()
    }

    // MARK: - Content Section
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(FumeColors.accent)
                Text("Content")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FumeColors.textSecondary)
            }

            Text(source.content)
                .font(.system(size: 15))
                .foregroundStyle(FumeColors.textPrimary)
                .lineSpacing(5)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    // MARK: - URL Section
    private func urlSection(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "link")
                    .foregroundStyle(FumeColors.accent)
                Text("Source URL")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FumeColors.textSecondary)
            }

            Link(destination: url) {
                Text(url.absoluteString)
                    .font(.system(size: 13))
                    .foregroundStyle(FumeColors.accent)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    // MARK: - Related Sources Section
    private var relatedSourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "link.circle")
                    .foregroundStyle(FumeColors.accent)
                Text("Related Sources")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FumeColors.textSecondary)

                Spacer()

                if isLoadingRelated {
                    ProgressView()
                        .tint(FumeColors.accent)
                        .scaleEffect(0.6)
                }
            }

            if !isLoadingRelated && relatedSources.isEmpty {
                Text("No related sources found")
                    .font(.system(size: 13))
                    .foregroundStyle(FumeColors.textSecondary)
            } else {
                // Connection visualization
                if !relatedSources.isEmpty {
                    SourceConnectionsView(
                        center: source,
                        related: Array(relatedSources.prefix(4))
                    )
                    .padding(.vertical, 4)
                }

                ForEach(relatedSources.prefix(4)) { related in
                    RelatedSourceRow(related: related, center: source)
                }
            }
        }
        .glassCard()
    }

    // MARK: - Metadata Section
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(FumeColors.accent)
                Text("Details")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FumeColors.textSecondary)
            }

            VStack(spacing: 8) {
                metadataRow(label: "Type", value: source.type.label)
                metadataRow(label: "Created", value: formattedDateTime(source.createdAt))
                metadataRow(label: "Characters", value: "\(source.content.count)")
                metadataRow(label: "Words", value: "\(source.content.split(separator: " ").count)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(FumeColors.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(FumeColors.textPrimary)
        }
    }

    private func formattedDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }

    private func loadRelatedSources() async {
        isLoadingRelated = true
        do {
            relatedSources = try await DatabaseService.shared.findRelatedSources(for: source, topK: 4)
        } catch {
            relatedSources = []
        }
        isLoadingRelated = false
    }
}

// MARK: - Related Source Row
struct RelatedSourceRow: View {
    let related: Source
    let center: Source

    var body: some View {
        HStack(spacing: 10) {
            // Connection line dot
            Circle()
                .fill(FumeColors.accent.opacity(0.4))
                .frame(width: 8, height: 8)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(FumeColors.surfaceRaised)
                    .frame(width: 32, height: 32)

                Image(systemName: related.type.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(FumeColors.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(related.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(FumeColors.textPrimary)
                    .lineLimit(1)

                Text(related.type.label)
                    .font(.system(size: 11))
                    .foregroundStyle(FumeColors.textSecondary)
            }

            Spacer()

            Image(systemName: "arrow.right")
                .font(.system(size: 10))
                .foregroundStyle(FumeColors.accent.opacity(0.6))
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(FumeColors.surfaceRaised.opacity(0.5))
        )
    }
}

// MARK: - Source Connections View (Visualization)
struct SourceConnectionsView: View {
    let center: Source
    let related: [Source]

    var body: some View {
        GeometryReader { geometry in
            let centerPoint = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2 - 20

            ZStack {
                // Connection lines
                ForEach(Array(related.enumerated()), id: \.element.id) { index, _ in
                    let angle = angleFor(index: index, total: related.count)
                    let endPoint = pointOnCircle(center: centerPoint, radius: radius, angle: angle)

                    ConnectionLineShape(start: centerPoint, end: endPoint)
                        .stroke(
                            FumeColors.accent.opacity(0.25),
                            style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                        )
                }

                // Center node
                Circle()
                    .fill(FumeColors.accent.opacity(0.2))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .stroke(FumeColors.accent, lineWidth: 1.5)
                    )
                    .overlay(
                        Image(systemName: center.type.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(FumeColors.accent)
                    )
                    .position(centerPoint)

                // Related nodes
                ForEach(Array(related.enumerated()), id: \.element.id) { index, source in
                    let angle = angleFor(index: index, total: related.count)
                    let point = pointOnCircle(center: centerPoint, radius: radius, angle: angle)

                    Circle()
                        .fill(FumeColors.surfaceRaised)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle()
                                .stroke(FumeColors.accent.opacity(0.5), lineWidth: 1)
                        )
                        .overlay(
                            Image(systemName: source.type.icon)
                                .font(.system(size: 10))
                                .foregroundStyle(FumeColors.accent)
                        )
                        .position(point)
                }
            }
        }
        .frame(height: 120)
    }

    private func angleFor(index: Int, total: Int) -> CGFloat {
        guard total > 0 else { return 0 }
        let baseAngle = -CGFloat.pi / 2 // Start from top
        let spread = CGFloat.pi * 2 / CGFloat(total)
        return baseAngle + CGFloat(index) * spread
    }

    private func pointOnCircle(center: CGPoint, radius: CGFloat, angle: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
    }
}

struct ConnectionLineShape: Shape {
    let start: CGPoint
    let end: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }
}

// MARK: - Flow Layout (for tags)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return (
            size: CGSize(width: maxWidth, height: currentY + lineHeight),
            frames: frames
        )
    }
}

// MARK: - Tag Editor Sheet
struct TagEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let source: Source
    let allTags: [Tag]
    let onSave: ([UUID]) -> Void

    @State private var selectedTagIDs: Set<UUID>

    init(source: Source, allTags: [Tag], onSave: @escaping ([UUID]) -> Void) {
        self.source = source
        self.allTags = allTags
        self.onSave = onSave
        _selectedTagIDs = State(initialValue: Set(source.tagIDs))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FumeColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        if allTags.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "tag.slash")
                                    .font(.system(size: 32))
                                    .foregroundStyle(FumeColors.textSecondary.opacity(0.4))

                                Text("No tags yet")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(FumeColors.textPrimary)

                                Text("Create tags in your Library to organize sources.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(FumeColors.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            ForEach(allTags) { tag in
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color(hex: tag.colorHex))
                                        .frame(width: 12, height: 12)

                                    Text(tag.name)
                                        .font(.system(size: 15))
                                        .foregroundStyle(FumeColors.textPrimary)

                                    Spacer()

                                    Image(systemName: selectedTagIDs.contains(tag.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedTagIDs.contains(tag.id) ? FumeColors.accent : FumeColors.textSecondary)
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedTagIDs.contains(tag.id) ? Color(hex: tag.colorHex).opacity(0.1) : FumeColors.surfaceRaised)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedTagIDs.contains(tag.id) ? Color(hex: tag.colorHex).opacity(0.3) : FumeColors.border, lineWidth: 0.5)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if selectedTagIDs.contains(tag.id) {
                                        selectedTagIDs.remove(tag.id)
                                    } else {
                                        selectedTagIDs.insert(tag.id)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Edit Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(FumeColors.textSecondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(Array(selectedTagIDs))
                        dismiss()
                    }
                    .foregroundStyle(FumeColors.accent)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Source Export Sheet

struct SourceExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let source: Source

    @State private var selectedFormat: ExportFormat = .obsidian
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportResult: ExportResult?
    @State private var error: Error?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ZStack {
                FumeColors.background
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("Export Source")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(FumeColors.textPrimary)

                    Text("Export \"\(source.title.prefix(40))\(source.title.count > 40 ? "..." : "")\"")
                        .font(.system(size: 14))
                        .foregroundStyle(FumeColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    VStack(spacing: 10) {
                        ForEach(ExportFormat.allCases) { format in
                            ExportFormatOption(
                                format: format,
                                isSelected: selectedFormat == format
                            ) {
                                selectedFormat = format
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    if isExporting {
                        ProgressView()
                            .tint(FumeColors.accent)
                        Text("Generating \(selectedFormat.rawValue)...")
                            .font(.system(size: 13))
                            .foregroundStyle(FumeColors.textSecondary)
                    }

                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(FumeColors.textSecondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Export") {
                        performExport()
                    }
                    .foregroundStyle(FumeColors.accent)
                    .fontWeight(.semibold)
                    .disabled(isExporting)
                }
            }
            .alert("Export Failed", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(error?.localizedDescription ?? "Unknown error")
            }
            .sheet(isPresented: $showShareSheet) {
                if let result = exportResult {
                    ShareSheet(items: [result.itemProvider])
                }
            }
        }
    }

    private func performExport() {
        isExporting = true
        Task {
            do {
                let result = try await ExportService.shared.exportSource(source, format: selectedFormat)
                exportResult = result
                isExporting = false
                showShareSheet = true
            } catch {
                self.error = error
                isExporting = false
                showError = true
            }
        }
    }
}
