import SwiftUI

// MARK: - Mac Source Library View

struct MacSourceLibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @State private var selectedSource: Source?
    @State private var sortOrder: SortOrder = .dateDesc
    @State private var filterType: SourceType?
    @State private var searchQuery = ""

    enum SortOrder: String, CaseIterable {
        case dateDesc = "Newest first"
        case dateAsc = "Oldest first"
        case titleAsc = "A → Z"
        case titleDesc = "Z → A"
    }

    var sortedSources: [Source] {
        var sources = viewModel.sources

        if let type = filterType {
            sources = sources.filter { $0.type == type }
        }

        if !searchQuery.isEmpty {
            let lower = searchQuery.lowercased()
            sources = sources.filter {
                $0.title.lowercased().contains(lower) ||
                $0.content.lowercased().contains(lower)
            }
        }

        switch sortOrder {
        case .dateDesc: sources.sort { $0.createdAt > $1.createdAt }
        case .dateAsc: sources.sort { $0.createdAt < $1.createdAt }
        case .titleAsc: sources.sort { $0.title.lowercased() < $1.title.lowercased() }
        case .titleDesc: sources.sort { $0.title.lowercased() > $1.title.lowercased() }
        }

        return sources
    }

    var sourceCounts: [SourceType: Int] {
        var counts: [SourceType: Int] = [:]
        for type in SourceType.allCases {
            counts[type] = viewModel.sources.filter { $0.type == type }.count
        }
        return counts
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                // Search
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(FumeColors.textSecondary)

                    TextField("Filter sources...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .accessibilityLabel("Filter sources")
                }
                .padding(8)
                .background(FumeColors.surfaceRaised)
                .cornerRadius(8)

                Spacer()

                // Sort picker
                Menu {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Button {
                            sortOrder = order
                        } label: {
                            HStack {
                                Text(order.rawValue)
                                if sortOrder == order {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 11))
                        Text(sortOrder.rawValue)
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(FumeColors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(FumeColors.surfaceRaised)
                    .cornerRadius(8)
                }
                .menuStyle(.automatic)
                .accessibilityLabel("Sort order")
                .accessibilityValue(sortOrder.rawValue)
            }
            .padding()

            Divider()

            HStack(spacing: 0) {
                // Type filter sidebar
                VStack(spacing: 2) {
                    filterButton(nil, label: "All", count: viewModel.sources.count)

                    Divider()
                        .padding(.vertical, 4)

                    ForEach(SourceType.allCases, id: \.self) { type in
                        filterButton(type, label: type.label, count: sourceCounts[type] ?? 0, icon: type.icon)
                    }
                }
                .padding(.vertical, 8)
                .frame(width: 140)
                .background(FumeColors.surface)

                Divider()

                // Main content
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .tint(FumeColors.accent)
                    Spacer()
                } else if sortedSources.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
                            ForEach(sortedSources) { source in
                                LibraryCard(source: source, isSelected: selectedSource?.id == source.id)
                                    .onTapGesture {
                                        selectedSource = source
                                    }
                            }
                        }
                        .padding()
                    }
                    .background(FumeColors.background)
                }
            }
        }
        .background(FumeColors.background)
        .task {
            await viewModel.loadSources()
        }
    }

    private func filterButton(_ type: SourceType?, label: String, count: Int, icon: String? = nil) -> some View {
        let isSelected = filterType == type

        return Button {
            filterType = type
        } label: {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .frame(width: 14)
                }

                Text(label)
                    .font(.system(size: 12))

                Spacer()

                Text("\(count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? FumeColors.accent : FumeColors.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? FumeColors.accent.opacity(0.2) : Color.clear)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? FumeColors.accent : FumeColors.textPrimary)
            .background(isSelected ? FumeColors.sourceHighlight : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) filter")
        .accessibilityValue("\(count) sources")
        .accessibilityHint(isSelected ? "Currently selected. Click to show all sources." : "Click to filter by \(label).")
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "books.vertical")
                .font(.system(size: 40))
                .foregroundStyle(FumeColors.textSecondary.opacity(0.4))

            Text("No sources found")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(FumeColors.textSecondary)

            if !searchQuery.isEmpty || filterType != nil {
                Button {
                    searchQuery = ""
                    filterType = nil
                } label: {
                    Text("Clear filters")
                        .font(.system(size: 13))
                        .foregroundStyle(FumeColors.accent)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Library Card

struct LibraryCard: View {
    let source: Source
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(typeColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: source.type.icon)
                        .font(.system(size: 13))
                        .foregroundStyle(typeColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(source.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FumeColors.textPrimary)
                        .lineLimit(1)

                    Text(source.formattedDate)
                        .font(.system(size: 10))
                        .foregroundStyle(FumeColors.textSecondary)
                }

                Spacer()
            }

            Text(source.content.prefix(120) + (source.content.count > 120 ? "..." : ""))
                .font(.system(size: 12))
                .foregroundStyle(FumeColors.textSecondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Tags
            if !source.tagIDs.isEmpty {
                HStack(spacing: 4) {
                    ForEach(source.tagIDs.prefix(3), id: \.self) { tagID in
                        Circle()
                            .fill(FumeColors.accent.opacity(0.6))
                            .frame(width: 4, height: 4)
                    }
                    if source.tagIDs.count > 3 {
                        Text("+\(source.tagIDs.count - 3)")
                            .font(.system(size: 9))
                            .foregroundStyle(FumeColors.textSecondary)
                    }
                }
            }

            HStack {
                Label("\(source.content.count) chars", systemImage: "textformat.size")
                    .font(.system(size: 10))
                    .foregroundStyle(FumeColors.textSecondary.opacity(0.7))

                Spacer()

                if source.embedding != nil {
                    HStack(spacing: 2) {
                        Image(systemName: "brain")
                            .font(.system(size: 8))
                        Text("indexed")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(FumeColors.accent.opacity(0.6))
                }
            }
        }
        .padding(14)
        .background(isSelected ? FumeColors.surfaceRaised : FumeColors.surface)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? FumeColors.accent.opacity(0.4) : FumeColors.border.opacity(0.5), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(source.type.label): \(source.title). \(source.content.prefix(100))")
        .accessibilityHint("Click to select this source.")
    }

    private var typeColor: Color {
        switch source.type {
        case .note: return FumeColors.accent
        case .article: return Color.blue
        case .voiceMemo: return Color.purple
        case .image: return Color.green
        case .pdf: return Color.red
        }
    }
}
