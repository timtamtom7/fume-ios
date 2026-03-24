import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var queryText: String = ""
    @Published var isThinking: Bool = false
    @Published var response: QueryResponse?
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var currentError: FumeError?

    private let embeddingService = EmbeddingService.shared
    private let aiQueryService = AIQueryService.shared

    func submitQuery() async {
        guard !queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isThinking = true
        response = nil
        errorMessage = nil
        currentError = nil

        do {
            let sources = try await DatabaseService.shared.fetchAllSources()

            // Check free tier limit
            if sources.count >= 50 {
                currentError = .storageLimitReached
                isThinking = false
                return
            }

            let matches = await embeddingService.findSimilarSources(query: queryText, sources: sources, topK: 5)
            let answer = await aiQueryService.generateAnswer(for: queryText, sources: matches)

            response = QueryResponse(answer: answer, sources: matches, query: queryText)
        } catch {
            currentError = .aiQueryFailed
        }

        isThinking = false
    }

    func clearResponse() {
        response = nil
        queryText = ""
    }

    func dismissError() {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentError = nil
        }
    }
}
