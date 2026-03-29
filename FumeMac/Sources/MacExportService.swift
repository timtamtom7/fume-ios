import Foundation
import AppKit

// MARK: - Mac Export Service
// Simplified export for macOS using AppKit instead of UIKit

actor MacExportService {
    static let shared = MacExportService()

    private init() {}

    func export(sources: [Source], format: ExportFormat) async throws -> (data: Data, filename: String) {
        switch format {
        case .json:
            return try exportToJSON(sources: sources)
        case .obsidian:
            return try exportToMarkdown(sources: sources)
        case .pdf:
            return try exportToPDF(sources: sources)
        }
    }

    // MARK: - JSON Export

    private func exportToJSON(sources: [Source]) throws -> (Data, String) {
        struct ExportPackage: Codable {
            let exportedAt: String
            let totalSources: Int
            let sources: [SourceExport]
        }

        struct SourceExport: Codable {
            let id: String
            let type: String
            let title: String
            let content: String
            let url: String?
            let createdAt: String
            let updatedAt: String
            let tagIDs: [String]
        }

        let package = ExportPackage(
            exportedAt: ISO8601DateFormatter().string(from: Date()),
            totalSources: sources.count,
            sources: sources.map { source in
                SourceExport(
                    id: source.id.uuidString,
                    type: source.type.rawValue,
                    title: source.title,
                    content: source.content,
                    url: source.url,
                    createdAt: ISO8601DateFormatter().string(from: source.createdAt),
                    updatedAt: ISO8601DateFormatter().string(from: source.updatedAt),
                    tagIDs: source.tagIDs.map { $0.uuidString }
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(package)
        let filename = "Fume_Export_\(dateString()).json"
        return (data, filename)
    }

    // MARK: - Markdown Export

    private func exportToMarkdown(sources: [Source]) throws -> (Data, String) {
        var combinedMarkdown = ""

        for (index, source) in sources.enumerated() {
            let frontmatter = buildFrontmatter(for: source)
            let content = """
            \(frontmatter)

            # \(source.title)

            \(source.content)

            ---
            *Exported from Fume on \(formattedDate(source.createdAt))*
            """

            combinedMarkdown += content

            if index < sources.count - 1 {
                combinedMarkdown += "\n\n---\n\n"
            }
        }

        let data = combinedMarkdown.data(using: .utf8) ?? Data()
        let filename = "Fume_Export_\(dateString()).md"
        return (data, filename)
    }

    private func buildFrontmatter(for source: Source) -> String {
        var lines = ["---"]
        lines.append("title: \"\(escapeMarkdown(source.title))\"")
        lines.append("type: \"\(source.type.rawValue)\"")
        if let url = source.url {
            lines.append("source: \"\(escapeMarkdown(url))\"")
        }
        lines.append("created: \(ISO8601DateFormatter().string(from: source.createdAt))")
        lines.append("---")
        return lines.joined(separator: "\n")
    }

    private func escapeMarkdown(_ text: String) -> String {
        text.replacingOccurrences(of: "\"", with: "\\\"")
    }

    // MARK: - PDF Export

    private func exportToPDF(sources: [Source]) throws -> (Data, String) {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 72
        let contentWidth = pageWidth - (margin * 2)

        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
            throw NSError(domain: "MacExportService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create PDF consumer"])
        }

        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "MacExportService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create PDF context"])
        }

        let titleFont = NSFont.systemFont(ofSize: 16, weight: .bold)
        let bodyFont = NSFont.systemFont(ofSize: 11)
        let metaFont = NSFont.systemFont(ofSize: 9)

        for (pageIndex, source) in sources.enumerated() {
            context.beginPDFPage(nil)

            var yOffset: CGFloat = pageHeight - margin

            // Header bar
            context.setFillColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1.0)
            context.fill(CGRect(x: 0, y: pageHeight - 40, width: pageWidth, height: 40))

            let fumeAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14, weight: .bold),
                .foregroundColor: NSColor.white
            ]
            let fumeText = "FUME" as NSString
            fumeText.draw(at: CGPoint(x: margin, y: pageHeight - 28), withAttributes: fumeAttrs)

            let pageText = "Page \(pageIndex + 1) of \(sources.count)" as NSString
            let pageSize = pageText.size(withAttributes: [.font: NSFont.systemFont(ofSize: 9)])
            pageText.draw(at: CGPoint(x: pageWidth - margin - pageSize.width, y: pageHeight - 26), withAttributes: [.font: NSFont.systemFont(ofSize: 9), .foregroundColor: NSColor.white])

            yOffset = pageHeight - margin - 20

            // Title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: NSColor.black
            ]
            let titleRect = CGRect(x: margin, y: yOffset - 20, width: contentWidth, height: 30)
            (source.title as NSString).draw(in: titleRect, withAttributes: titleAttrs)
            yOffset -= 35

            // Meta
            let metaAttrs: [NSAttributedString.Key: Any] = [
                .font: metaFont,
                .foregroundColor: NSColor.gray
            ]
            let metaLine = "\(source.type.label) · \(formattedDate(source.createdAt))" as NSString
            metaLine.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: metaAttrs)
            yOffset -= 25

            // Separator
            context.setStrokeColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 0.5)
            context.setLineWidth(1)
            context.move(to: CGPoint(x: margin, y: yOffset))
            context.addLine(to: CGPoint(x: pageWidth - margin, y: yOffset))
            context.strokePath()
            yOffset -= 15

            // Content
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 6

            let contentAttrs: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .foregroundColor: NSColor.darkGray,
                .paragraphStyle: paragraphStyle
            ]

            let attrContent = NSAttributedString(string: source.content, attributes: contentAttrs)
            let contentRect = CGRect(x: margin, y: yOffset, width: contentWidth, height: pageHeight - yOffset - margin)
            attrContent.draw(in: contentRect)

            // Footer
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 8),
                .foregroundColor: NSColor.lightGray
            ]
            let footerText = "Exported from Fume · \(formattedFullDate(Date()))" as NSString
            let footerSize = footerText.size(withAttributes: footerAttrs)
            footerText.draw(at: CGPoint(x: (pageWidth - footerSize.width) / 2, y: margin / 2 - 4), withAttributes: footerAttrs)

            context.endPDFPage()
        }

        context.closePDF()

        let filename = "Fume_Export_\(dateString()).pdf"
        return (pdfData as Data, filename)
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func formattedFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }

    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
