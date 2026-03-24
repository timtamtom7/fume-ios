import Foundation

actor AIQueryService {
    static let shared = AIQueryService()

    private init() {}

    /// Synthesize an answer from the matched sources
    /// Since we don't have a local LLM in this MVP, we generate a template-based response
    /// In production, this would integrate with Apple's on-device ML models
    func generateAnswer(for query: String, sources: [SourceMatch]) async -> String {
        guard !sources.isEmpty else {
            return "I couldn't find anything in your knowledge base that answers this question. Try adding more notes or articles about this topic."
        }

        if sources.count == 1 {
            let match = sources[0]
            return """
            Based on your notes, here's what I found:

            \(match.excerpt)

            This is from your \(match.source.formattedDate). Tap the source below to read more.
            """
        }

        var response = "I found \(sources.count) relevant sources in your knowledge base:\n\n"

        for (index, match) in sources.prefix(3).enumerated() {
            response += "[\(index + 1)] \(match.source.title)\n"
            response += "\"\(match.excerpt)\"\n\n"
        }

        response += "Tap any source below to explore it in full."

        return response
    }
}
