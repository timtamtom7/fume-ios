import SwiftUI

struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @State private var selectedSource: Source?
    @State private var sourceToDelete: Source?
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                FumeColors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search Bar
                    searchBar

                    // Filter Chips
                    filterChips

                    Divider()
                        .background(FumeColors.divider)

                    // Source Grid
                    if viewModel.isLoading {
                        loadingView
                    } else if viewModel.filteredSources.isEmpty {
                        emptyView
                    } else {
                        sourceGrid
                    }
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.loadSources()
            }
            .refreshable {
                await viewModel.loadSources()
            }
            .sheet(item: $selectedSource) { source in
                SourceDetailView(source: source)
            }
            .confirmationDialog(
                "Delete Source",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let source = sourceToDelete {
                        Task {
                            await viewModel.deleteSource(source)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete this source from your knowledge base.")
            }
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(FumeColors.textSecondary)

            TextField("Search your library...", text: $viewModel.searchText)
                .font(.system(size: 15))
                .foregroundStyle(FumeColors.textPrimary)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(FumeColors.textSecondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(FumeColors.surfaceRaised)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Filter Chips
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterChip(
                    label: "All",
                    isSelected: viewModel.selectedFilter == nil
                ) {
                    viewModel.setFilter(nil)
                }

                ForEach(SourceType.allCases, id: \.self) { type in
                    FilterChip(
                        label: type.label,
                        icon: type.icon,
                        isSelected: viewModel.selectedFilter == type
                    ) {
                        viewModel.setFilter(type)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Source Grid
    private var sourceGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(viewModel.filteredSources) { source in
                    SourceGridCard(source: source)
                        .onTapGesture {
                            selectedSource = source
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                sourceToDelete = source
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Empty View
    private var emptyView: some View {
        Group {
            if !viewModel.searchText.isEmpty {
                NoSearchResultsView(query: viewModel.searchText)
            } else {
                EmptyLibraryView()
            }
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(FumeColors.accent)
            Spacer()
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let label: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                }
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? FumeColors.accent : FumeColors.surfaceRaised)
            )
            .foregroundStyle(isSelected ? FumeColors.background : FumeColors.textSecondary)
        }
    }
}

// MARK: - Source Grid Card
struct SourceGridCard: View {
    let source: Source

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Thumbnail or Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(FumeColors.surfaceRaised)

                if let thumbnailData = source.thumbnailData,
                   let uiImage = UIImage(data: thumbnailData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 80)
                        .clipped()
                        .cornerRadius(12)
                } else {
                    Image(systemName: source.type.icon)
                        .font(.system(size: 28))
                        .foregroundStyle(FumeColors.accent)
                }
            }
            .frame(height: 80)

            VStack(alignment: .leading, spacing: 4) {
                Text(source.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FumeColors.textPrimary)
                    .lineLimit(2)

                Text(source.formattedDate)
                    .font(.system(size: 11))
                    .foregroundStyle(FumeColors.textSecondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(FumeColors.glassOverlay)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(FumeColors.border, lineWidth: 0.5)
                )
        )
    }
}
