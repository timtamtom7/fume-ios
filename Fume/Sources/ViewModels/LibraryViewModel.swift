import SwiftUI
import Combine
import UniformTypeIdentifiers

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var sources: [Source] = []
    @Published var isLoading: Bool = false
    @Published var selectedFilter: SourceType?
    @Published var searchText: String = ""
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching: Bool = false
    @Published var allTags: [Tag] = []
    @Published var selectedTagID: UUID?
    @Published var showImportPicker: Bool = false
    @Published var isImporting: Bool = false
    @Published var importProgress: String = ""
    @Published var importError: ImportError?
    @Published var showImportError: Bool = false

    var filteredSources: [Source] {
        var result = sources

        // Filter by type
        if let filter = selectedFilter {
            result = result.filter { $0.type == filter }
        }

        // Filter by tag
        if let tagID = selectedTagID {
            result = result.filter { $0.tagIDs.contains(tagID) }
        }

        // Filter by search text (local fallback)
        if !searchText.isEmpty && searchResults.isEmpty {
            let lowercased = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(lowercased) ||
                $0.content.lowercased().contains(lowercased)
            }
        } else if searchResults.isEmpty {
            // Use filtered sources for display when not searching
            return result
        }

        return result
    }

    func loadSources() async {
        isLoading = true
        do {
            sources = try await DatabaseService.shared.fetchAllSources()
            allTags = try await DatabaseService.shared.fetchAllTags()
        } catch {
            print("Failed to load sources: \(error)")
        }
        isLoading = false
    }

    func performSearch(_ query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        do {
            searchResults = try await DatabaseService.shared.searchSources(query: query)
        } catch {
            searchResults = []
        }
        isSearching = false
    }

    func clearSearch() {
        searchText = ""
        searchResults = []
        isSearching = false
    }

    func deleteSource(_ source: Source) async {
        do {
            try await DatabaseService.shared.deleteSource(id: source.id)
            sources.removeAll { $0.id == source.id }
            searchResults.removeAll { $0.source.id == source.id }
        } catch {
            print("Failed to delete source: \(error)")
        }
    }

    func setFilter(_ type: SourceType?) {
        selectedFilter = type
    }

    func setTagFilter(_ tagID: UUID?) {
        selectedTagID = tagID
    }

    func createTag(name: String, colorHex: String) async {
        let tag = Tag(name: name, colorHex: colorHex)
        do {
            try await DatabaseService.shared.insertTag(tag)
            allTags.append(tag)
        } catch {
            print("Failed to create tag: \(error)")
        }
    }

    func deleteTag(_ tag: Tag) async {
        do {
            try await DatabaseService.shared.deleteTag(id: tag.id)
            allTags.removeAll { $0.id == tag.id }
            sources = sources.map { source in
                var updated = source
                updated.tagIDs.removeAll { $0 == tag.id }
                return updated
            }
            if selectedTagID == tag.id {
                selectedTagID = nil
            }
        } catch {
            print("Failed to delete tag: \(error)")
        }
    }

    func updateSourceTags(sourceID: UUID, tagIDs: [UUID]) async {
        do {
            try await DatabaseService.shared.updateSourceTags(sourceID: sourceID, tagIDs: tagIDs)
            if let idx = sources.firstIndex(where: { $0.id == sourceID }) {
                sources[idx].tagIDs = tagIDs
            }
        } catch {
            print("Failed to update source tags: \(error)")
        }
    }

    func importFiles(_ urls: [URL]) async {
        isImporting = true
        importProgress = "Reading files..."

        do {
            let importedFiles = try await FileImportService.shared.importFiles(urls: urls)

            guard !importedFiles.isEmpty else {
                importError = .emptyContent
                showImportError = true
                isImporting = false
                return
            }

            for (index, file) in importedFiles.enumerated() {
                importProgress = "Importing \(index + 1) of \(importedFiles.count)..."

                let source = await FileImportService.shared.convertToSource(file)

                // Generate embedding
                importProgress = "Embedding \(file.name)..."
                let embedding = await EmbeddingService.shared.generateEmbedding(for: source.content)

                var sourceWithEmbedding = source
                sourceWithEmbedding.embedding = embedding

                try await DatabaseService.shared.insertSource(sourceWithEmbedding)
                sources.insert(sourceWithEmbedding, at: 0)
            }

            importProgress = ""
        } catch let error as ImportError {
            importError = error
            showImportError = true
        } catch {
            importError = .parseError
            showImportError = true
        }

        isImporting = false
    }

    func refreshAfterTagUpdate() async {
        do {
            allTags = try await DatabaseService.shared.fetchAllTags()
            sources = try await DatabaseService.shared.fetchAllSources()
        } catch {
            print("Failed to refresh: \(error)")
        }
    }
}
