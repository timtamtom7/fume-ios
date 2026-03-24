import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @State private var selectedSource: Source?
    @State private var sourceToDelete: Source?
    @State private var showDeleteConfirmation = false
    @State private var showTagSheet = false
    @State private var showImportOptions = false
    @State private var showExportOptions = false
    @State private var isExporting = false
    @State private var exportError: Error?
    @State private var showExportError = false
    @State private var tagToEdit: Tag?

    var body: some View {
        NavigationStack {
            ZStack {
                FumeColors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search Bar
                    searchBar

                    // Filter section
                    filterSection

                    Divider()
                        .background(FumeColors.divider)

                    // Content
                    if viewModel.isLoading {
                        loadingView
                    } else if !viewModel.searchText.isEmpty {
                        searchResultsView
                    } else if viewModel.filteredSources.isEmpty {
                        if viewModel.selectedTagID != nil {
                            emptyTagFilterView
                        } else {
                            emptyView
                        }
                    } else {
                        sourceGrid
                    }
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Menu {
                            Button {
                                showImportOptions = true
                            } label: {
                                Label("Import Files", systemImage: "square.and.arrow.down")
                            }

                            Button {
                                showExportOptions = true
                            } label: {
                                Label("Export Library", systemImage: "square.and.arrow.up")
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.down.on.square")
                                .foregroundStyle(FumeColors.accent)
                        }

                        Button {
                            showTagSheet = true
                        } label: {
                            Image(systemName: "tag")
                                .foregroundStyle(viewModel.selectedTagID != nil ? FumeColors.accent : FumeColors.textSecondary)
                        }
                    }
                }
            }
            .task {
                await viewModel.loadSources()
            }
            .refreshable {
                await viewModel.loadSources()
            }
            .sheet(item: $selectedSource) { source in
                SourceDetailView(source: source, allTags: viewModel.allTags) {
                    Task { await viewModel.refreshAfterTagUpdate() }
                }
            }
            .sheet(isPresented: $showTagSheet) {
                TagManagementSheet(
                    tags: viewModel.allTags,
                    selectedTagID: viewModel.selectedTagID,
                    onSelectTag: { tagID in
                        viewModel.setTagFilter(tagID)
                        showTagSheet = false
                    },
                    onCreateTag: { name, colorHex in
                        Task {
                            await viewModel.createTag(name: name, colorHex: colorHex)
                        }
                    },
                    onDeleteTag: { tag in
                        Task {
                            await viewModel.deleteTag(tag)
                        }
                    }
                )
            }
            .sheet(isPresented: $showImportOptions) {
                ImportOptionsSheet(
                    onImport: { urls in
                        Task {
                            await viewModel.importFiles(urls)
                        }
                    }
                )
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showExportOptions) {
                ExportOptionsSheet(
                    sources: viewModel.filteredSources.isEmpty ? viewModel.sources : viewModel.filteredSources,
                    isExporting: $isExporting,
                    onExport: { result in
                        shareExport(result)
                    }
                )
                .presentationDetents([.medium])
            }
            .alert("Export Failed", isPresented: $showExportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportError?.localizedDescription ?? "Unknown error")
            }
            .alert("Import Failed", isPresented: $viewModel.showImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.importError?.localizedDescription ?? "Unknown error")
            }
            .overlay {
                if viewModel.isImporting {
                    importProgressOverlay
                }
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
                .foregroundStyle(viewModel.isSearching ? FumeColors.accent : FumeColors.textSecondary)

            TextField("Search your library...", text: $viewModel.searchText)
                .font(.system(size: 15))
                .foregroundStyle(FumeColors.textPrimary)
                .autocorrectionDisabled()
                .onChange(of: viewModel.searchText) { _, newValue in
                    Task {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        if viewModel.searchText == newValue {
                            await viewModel.performSearch(newValue)
                        }
                    }
                }

            if viewModel.isSearching {
                ProgressView()
                    .tint(FumeColors.accent)
                    .scaleEffect(0.8)
            } else if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.clearSearch()
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

    // MARK: - Filter Section
    private var filterSection: some View {
        VStack(spacing: 8) {
            // Type filters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    FilterChip(
                        label: "All",
                        isSelected: viewModel.selectedFilter == nil && viewModel.selectedTagID == nil
                    ) {
                        viewModel.setFilter(nil)
                        viewModel.setTagFilter(nil)
                    }

                    ForEach(SourceType.allCases, id: \.self) { type in
                        FilterChip(
                            label: type.label,
                            icon: type.icon,
                            isSelected: viewModel.selectedFilter == type && viewModel.selectedTagID == nil
                        ) {
                            viewModel.setFilter(type)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            // Tag filters
            if !viewModel.allTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.allTags) { tag in
                            TagChip(
                                tag: tag,
                                isSelected: viewModel.selectedTagID == tag.id
                            ) {
                                if viewModel.selectedTagID == tag.id {
                                    viewModel.setTagFilter(nil)
                                } else {
                                    viewModel.setTagFilter(tag.id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Search Results
    private var searchResultsView: some View {
        Group {
            if viewModel.searchResults.isEmpty && !viewModel.isSearching {
                NoSearchResultsView(query: viewModel.searchText)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.searchResults) { result in
                            SearchResultCard(result: result, searchQuery: viewModel.searchText)
                                .onTapGesture {
                                    selectedSource = result.source
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Source Grid
    private var sourceGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(viewModel.filteredSources) { source in
                    SourceGridCard(source: source, tags: viewModel.allTags.filter { source.tagIDs.contains($0.id) })
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
        EmptyLibraryView()
    }

    private var emptyTagFilterView: some View {
        EmptyTagFilterView()
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

    // MARK: - Import Progress Overlay
    private var importProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .tint(FumeColors.accent)
                    .scaleEffect(1.2)

                Text(viewModel.importProgress)
                    .font(.system(size: 14))
                    .foregroundStyle(FumeColors.textPrimary)
            }
            .padding(32)
            .glassCard()
        }
    }
}

// MARK: - Tag Chip
struct TagChip: View {
    let tag: Tag
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: tag.colorHex))
                    .frame(width: 8, height: 8)

                Text(tag.name)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? Color(hex: tag.colorHex).opacity(0.2) : FumeColors.surfaceRaised)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color(hex: tag.colorHex).opacity(0.5) : FumeColors.border, lineWidth: 0.5)
            )
            .foregroundStyle(isSelected ? Color(hex: tag.colorHex) : FumeColors.textSecondary)
        }
    }
}

// MARK: - Search Result Card
struct SearchResultCard: View {
    let result: SearchResult
    let searchQuery: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(FumeColors.surfaceRaised)
                        .frame(width: 40, height: 40)

                    Image(systemName: result.source.type.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(FumeColors.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.source.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FumeColors.textPrimary)
                        .lineLimit(1)

                    Text(result.source.formattedDate)
                        .font(.system(size: 11))
                        .foregroundStyle(FumeColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(FumeColors.textSecondary)
            }

            HighlightedText(text: result.chunk, highlight: searchQuery)
                .font(.system(size: 13))
                .foregroundStyle(FumeColors.textSecondary)
                .lineLimit(3)
        }
        .padding(14)
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

// MARK: - Highlighted Text
struct HighlightedText: View {
    let text: String
    let highlight: String

    var body: some View {
        highlightedAttributedText
    }

    private var highlightedAttributedText: Text {
        guard !highlight.isEmpty else {
            return Text(text).foregroundColor(FumeColors.textSecondary)
        }

        let lowercasedText = text.lowercased()
        let lowercasedHighlight = highlight.lowercased()
        let words = lowercasedHighlight.split(separator: " ").map(String.init).filter { $0.count > 2 }

        var result = Text("")
        var currentIndex = text.startIndex

        // Find all highlight ranges
        var ranges: [(Range<String.Index>, Range<String.Index>)] = []
        for word in words {
            var searchStart = lowercasedText.startIndex
            while let foundRange = lowercasedText.range(of: word, range: searchStart..<lowercasedText.endIndex) {
                let textRange = Range(uncheckedBounds: (
                    lower: text.index(text.startIndex, offsetBy: lowercasedText.distance(from: lowercasedText.startIndex, to: foundRange.lowerBound)),
                    upper: text.index(text.startIndex, offsetBy: lowercasedText.distance(from: lowercasedText.startIndex, to: foundRange.upperBound))
                ))
                ranges.append((textRange, foundRange))
                searchStart = foundRange.upperBound
            }
        }

        ranges.sort { $0.1.lowerBound < $1.1.lowerBound }

        for (textRange, _) in ranges {
            // Add non-highlighted portion
            if currentIndex < textRange.lowerBound {
                result = result + Text(String(text[currentIndex..<textRange.lowerBound])).foregroundColor(FumeColors.textSecondary)
            }
            // Add highlighted portion
            if currentIndex <= textRange.lowerBound {
                result = result + Text(String(text[textRange.lowerBound..<textRange.upperBound]))
                    .foregroundColor(FumeColors.accent)
                    .fontWeight(.semibold)
                currentIndex = textRange.upperBound
            }
        }

        // Add remaining text
        if currentIndex < text.endIndex {
            result = result + Text(String(text[currentIndex...])).foregroundColor(FumeColors.textSecondary)
        }

        return result
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
    let tags: [Tag]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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

                // Tags
                if !tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(tags.prefix(2)) { tag in
                            Circle()
                                .fill(Color(hex: tag.colorHex))
                                .frame(width: 6, height: 6)
                        }
                        if tags.count > 2 {
                            Text("+\(tags.count - 2)")
                                .font(.system(size: 10))
                                .foregroundStyle(FumeColors.textSecondary)
                        }
                    }
                }
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

// MARK: - Empty Tag Filter View
struct EmptyTagFilterView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(FumeColors.accent.opacity(0.08))
                    .frame(width: 100, height: 100)

                Image(systemName: "tag.slash")
                    .font(.system(size: 36))
                    .foregroundStyle(FumeColors.textSecondary.opacity(0.4))
            }

            VStack(spacing: 6) {
                Text("No sources with this tag")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FumeColors.textPrimary)

                Text("Add this tag to sources in your library to see them here.")
                    .font(.system(size: 13))
                    .foregroundStyle(FumeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }
}

// MARK: - Tag Management Sheet
struct TagManagementSheet: View {
    @Environment(\.dismiss) private var dismiss
    let tags: [Tag]
    let selectedTagID: UUID?
    let onSelectTag: (UUID?) -> Void
    let onCreateTag: (String, String) -> Void
    let onDeleteTag: (Tag) -> Void

    @State private var showCreateTag = false
    @State private var newTagName = ""
    @State private var newTagColor: TagColor = .amber

    var body: some View {
        NavigationStack {
            ZStack {
                FumeColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        // Clear filter option
                        Button {
                            onSelectTag(nil)
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle")
                                    .foregroundStyle(FumeColors.textSecondary)
                                Text("Clear tag filter")
                                    .foregroundStyle(FumeColors.textSecondary)
                                Spacer()
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(FumeColors.surfaceRaised)
                            )
                        }

                        ForEach(tags) { tag in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(hex: tag.colorHex))
                                    .frame(width: 12, height: 12)

                                Text(tag.name)
                                    .font(.system(size: 15))
                                    .foregroundStyle(FumeColors.textPrimary)

                                Spacer()

                                if selectedTagID == tag.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(FumeColors.accent)
                                }

                                Button {
                                    onDeleteTag(tag)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 13))
                                        .foregroundStyle(FumeColors.textSecondary)
                                }
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedTagID == tag.id ? Color(hex: tag.colorHex).opacity(0.1) : FumeColors.surfaceRaised)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedTagID == tag.id ? Color(hex: tag.colorHex).opacity(0.3) : FumeColors.border, lineWidth: 0.5)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelectTag(tag.id)
                            }
                        }

                        // Create new tag button
                        Button {
                            showCreateTag = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(FumeColors.accent)
                                Text("Create new tag")
                                    .foregroundStyle(FumeColors.accent)
                                Spacer()
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(FumeColors.accent.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(FumeColors.accent)
                }
            }
            .alert("Create Tag", isPresented: $showCreateTag) {
                TextField("Tag name", text: $newTagName)
                Button("Cancel", role: .cancel) {
                    newTagName = ""
                }
                Button("Create") {
                    if !newTagName.trimmingCharacters(in: .whitespaces).isEmpty {
                        onCreateTag(newTagName.trimmingCharacters(in: .whitespaces), newTagColor.rawValue)
                        newTagName = ""
                    }
                }
            } message: {
                Text("Enter a name for the new tag.")
            }
        }
    }
}

// MARK: - Import Options Sheet
struct ImportOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onImport: ([URL]) -> Void

    @State private var showFilePicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                FumeColors.background
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("Import from Files")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(FumeColors.textPrimary)

                    Text("Select markdown or text files from Obsidian, Notion exports, or Apple Notes.")
                        .font(.system(size: 14))
                        .foregroundStyle(FumeColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 16)

                    VStack(spacing: 12) {
                        ForEach(ImportSourceType.allCases) { sourceType in
                            ImportSourceOption(type: sourceType) {
                                showFilePicker = true
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(FumeColors.textSecondary)
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.plainText, .text, .content],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    dismiss()
                    onImport(urls)
                case .failure:
                    break
                }
            }
        }
    }
}

struct ImportSourceOption: View {
    let type: ImportSourceType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(FumeColors.surfaceRaised)
                        .frame(width: 44, height: 44)

                    Image(systemName: type.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(Color(hex: type.color))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(type.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FumeColors.textPrimary)

                    Text(type.description)
                        .font(.system(size: 12))
                        .foregroundStyle(FumeColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(FumeColors.textSecondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(FumeColors.glassOverlay)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(FumeColors.border, lineWidth: 0.5)
                    )
            )
        }
    }
}

// MARK: - Export Options Sheet

struct ExportOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let sources: [Source]
    @Binding var isExporting: Bool
    let onExport: (ExportResult) -> Void

    @State private var selectedFormat: ExportFormat = .obsidian
    @State private var exportResult: ExportResult?
    @State private var showShareSheet = false
    @State private var error: Error?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ZStack {
                FumeColors.background
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("Export Library")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(FumeColors.textPrimary)

                    Text("\(sources.count) source\(sources.count == 1 ? "" : "s") will be exported.")
                        .font(.system(size: 14))
                        .foregroundStyle(FumeColors.textSecondary)

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
                    .disabled(isExporting || sources.isEmpty)
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
        guard !sources.isEmpty else { return }

        isExporting = true

        Task {
            do {
                let result = try await ExportService.shared.export(sources: sources, format: selectedFormat)
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

// MARK: - Export Format Option

struct ExportFormatOption: View {
    let format: ExportFormat
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(FumeColors.surfaceRaised)
                        .frame(width: 44, height: 44)

                    Image(systemName: format.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(FumeColors.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(format.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FumeColors.textPrimary)

                    Text(formatDescription)
                        .font(.system(size: 12))
                        .foregroundStyle(FumeColors.textSecondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? FumeColors.accent : FumeColors.textSecondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? FumeColors.accent.opacity(0.08) : FumeColors.glassOverlay)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? FumeColors.accent.opacity(0.3) : FumeColors.border, lineWidth: 0.5)
            )
        }
    }

    private var formatDescription: String {
        switch format {
        case .obsidian: return "Markdown files with frontmatter for Obsidian"
        case .pdf: return "Printable PDF document"
        case .json: return "Raw data export for backup"
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - LibraryView Share Export Extension

extension LibraryView {
    func shareExport(_ result: ExportResult) {
        // Handled via sheet presentation
    }
}
