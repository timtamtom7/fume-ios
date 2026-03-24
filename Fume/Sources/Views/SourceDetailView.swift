import SwiftUI

struct SourceDetailView: View {
    let source: Source
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var isDeleted = false

    var body: some View {
        NavigationStack {
            ZStack {
                FumeColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header Card
                        headerCard

                        // Content
                        contentSection

                        // URL if article
                        if let url = source.url, let articleURL = URL(string: url) {
                            urlSection(articleURL)
                        }

                        // Metadata
                        metadataSection
                    }
                    .padding(16)
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
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
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
}
