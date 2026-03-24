import SwiftUI
import Combine

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var sources: [Source] = []
    @Published var isLoading: Bool = false
    @Published var selectedFilter: SourceType?
    @Published var searchText: String = ""

    var filteredSources: [Source] {
        var result = sources

        if let filter = selectedFilter {
            result = result.filter { $0.type == filter }
        }

        if !searchText.isEmpty {
            let lowercased = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(lowercased) ||
                $0.content.lowercased().contains(lowercased)
            }
        }

        return result
    }

    func loadSources() async {
        isLoading = true
        do {
            sources = try await DatabaseService.shared.fetchAllSources()
        } catch {
            print("Failed to load sources: \(error)")
        }
        isLoading = false
    }

    func deleteSource(_ source: Source) async {
        do {
            try await DatabaseService.shared.deleteSource(id: source.id)
            sources.removeAll { $0.id == source.id }
        } catch {
            print("Failed to delete source: \(error)")
        }
    }

    func setFilter(_ type: SourceType?) {
        selectedFilter = type
    }
}
