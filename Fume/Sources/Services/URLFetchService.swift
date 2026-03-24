import Foundation

actor URLFetchService {
    static let shared = URLFetchService()

    private init() {}

    struct FetchedArticle {
        let title: String
        let content: String
        let url: URL
    }

    func fetchArticle(from urlString: String) async throws -> FetchedArticle {
        guard let url = URL(string: urlString) else {
            throw URLFetchError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLFetchError.httpError
        }

        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw URLFetchError.encodingError
        }

        let title = extractTitle(from: html) ?? url.host ?? "Untitled Article"
        let content = extractContent(from: html)

        return FetchedArticle(title: title, content: content, url: url)
    }

    private func extractTitle(from html: String) -> String? {
        if let titleRange = html.range(of: "<title[^>]*>(.*?)</title>", options: .regularExpression) {
            var title = String(html[titleRange])
            title = title.replacingOccurrences(of: "<title[^>]*>", with: "", options: .regularExpression)
            title = title.replacingOccurrences(of: "</title>", with: "")
            return decodeHTMLEntities(title).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let ogTitleRange = html.range(of: "og:title[^>]*content=\"([^\"]+)\"", options: .regularExpression) {
            var title = String(html[ogTitleRange])
            title = title.replacingOccurrences(of: "og:title[^>]*content=\"", with: "", options: .regularExpression)
            title = title.replacingOccurrences(of: "\"", with: "")
            return decodeHTMLEntities(title).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    private func extractContent(from html: String) -> String {
        var content = html

        // Remove script and style tags
        content = content.replacingOccurrences(of: "<script[^>]*>[\\s\\S]*?</script>", with: "", options: .regularExpression)
        content = content.replacingOccurrences(of: "<style[^>]*>[\\s\\S]*?</style>", with: "", options: .regularExpression)
        content = content.replacingOccurrences(of: "<nav[^>]*>[\\s\\S]*?</nav>", with: "", options: .regularExpression)
        content = content.replacingOccurrences(of: "<footer[^>]*>[\\s\\S]*?</footer>", with: "", options: .regularExpression)
        content = content.replacingOccurrences(of: "<header[^>]*>[\\s\\S]*?</header>", with: "", options: .regularExpression)

        // Replace common block elements with newlines
        content = content.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: .regularExpression)
        content = content.replacingOccurrences(of: "</p>", with: "\n\n", options: .regularExpression)
        content = content.replacingOccurrences(of: "</div>", with: "\n", options: .regularExpression)
        content = content.replacingOccurrences(of: "</h[1-6]>", with: "\n\n", options: .regularExpression)
        content = content.replacingOccurrences(of: "</li>", with: "\n", options: .regularExpression)

        // Strip remaining tags
        content = content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // Decode HTML entities
        content = decodeHTMLEntities(content)

        // Clean up whitespace
        content = content.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        content = content.replacingOccurrences(of: "\n\\s+", with: "\n", options: .regularExpression)
        content = content.replacingOccurrences(of: "\\s+\n", with: "\n", options: .regularExpression)
        content = content.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        let entities: [String: String] = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&#39;": "'",
            "&nbsp;": " ",
            "&mdash;": "—",
            "&ndash;": "–",
            "&hellip;": "…",
            "&copy;": "©",
            "&reg;": "®",
            "&trade;": "™"
        ]

        for (entity, character) in entities {
            result = result.replacingOccurrences(of: entity, with: character)
        }

        // Handle numeric entities
        let numericPattern = "&#(\\d+);"
        if let regex = try? NSRegularExpression(pattern: numericPattern) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }

        return result
    }
}

enum URLFetchError: LocalizedError {
    case invalidURL
    case httpError
    case encodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .httpError: return "HTTP error fetching article"
        case .encodingError: return "Could not decode article content"
        }
    }
}
