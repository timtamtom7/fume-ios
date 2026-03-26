import Foundation
import PDFKit
import UIKit

// MARK: - Export Service
actor ExportService {
    static let shared = ExportService()

    private init() {}

    // MARK: - Main Export

    func export(sources: [Source], format: ExportFormat) async throws -> ExportResult {
        switch format {
        case .obsidian:
            return try exportToObsidian(sources: sources)
        case .pdf:
            return try exportToPDF(sources: sources)
        case .json:
            return try exportToJSON(sources: sources)
        }
    }

    // MARK: - Obsidian Export

    private func exportToObsidian(sources: [Source]) throws -> ExportResult {
        var combinedMarkdown = ""

        for (index, source) in sources.enumerated() {
            let frontmatter = buildObsidianFrontmatter(for: source)
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

        return ExportResult(
            name: "Fume_Export_\(dateString()).md",
            data: data,
            format: .obsidian
        )
    }

    private func buildObsidianFrontmatter(for source: Source) -> String {
        var lines = ["---"]
        lines.append("title: \"\(escapeMarkdown(source.title))\"")
        lines.append("type: \"\(source.type.rawValue)\"")

        if let url = source.url {
            lines.append("source: \"\(escapeMarkdown(url))\"")
        }

        lines.append("created: \(ISO8601DateFormatter().string(from: source.createdAt))")
        lines.append("exported: \(ISO8601DateFormatter().string(from: Date()))")

        lines.append("---")
        return lines.joined(separator: "\n")
    }

    private func escapeMarkdown(_ text: String) -> String {
        text.replacingOccurrences(of: "\"", with: "\\\"")
    }

    // MARK: - PDF Export

    private func exportToPDF(sources: [Source]) throws -> ExportResult {
        let pageWidth: CGFloat = 612 // US Letter
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 72

        let pdfMetaData = [
            kCGPDFContextCreator: "Fume",
            kCGPDFContextAuthor: "Fume App",
            kCGPDFContextTitle: "Fume Library Export"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            let contentWidth = pageWidth - (margin * 2)
            var currentPage = 0
            let bodyFont = UIFont.systemFont(ofSize: 11)
            let titleFont = UIFont.systemFont(ofSize: 16, weight: .bold)
            let headerFont = UIFont.systemFont(ofSize: 10, weight: .semibold)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 6
            paragraphStyle.paragraphSpacing = 12

            for source in sources {
                context.beginPage()
                currentPage += 1

                var yOffset: CGFloat = margin

                // Header bar
                let headerRect = CGRect(x: 0, y: 0, width: pageWidth, height: 40)
                UIColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1.0).setFill()
                UIRectFill(headerRect)

                let fumeLabel = "FUME"
                let fumeAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
                fumeLabel.draw(at: CGPoint(x: margin, y: 12), withAttributes: fumeAttrs)

                let pageLabel = "Page \(currentPage) of \(sources.count)"
                let pageAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 9, weight: .regular),
                    .foregroundColor: UIColor.white
                ]
                let pageSize = pageLabel.size(withAttributes: pageAttrs)
                pageLabel.draw(at: CGPoint(x: pageWidth - margin - pageSize.width, y: 14), withAttributes: pageAttrs)

                yOffset = margin + 20

                // Title
                let titleRect = CGRect(x: margin, y: yOffset, width: contentWidth, height: 30)
                source.title.draw(in: titleRect, withAttributes: [
                    .font: titleFont,
                    .foregroundColor: UIColor.black,
                    .paragraphStyle: paragraphStyle
                ])
                yOffset += 35

                // Metadata line
                let metaAttrs: [NSAttributedString.Key: Any] = [
                    .font: headerFont,
                    .foregroundColor: UIColor.gray
                ]
                let metaLine = "\(source.type.label) · \(formattedDate(source.createdAt))"
                metaLine.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: metaAttrs)
                yOffset += 25

                // Separator
                UIColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 0.5).setStroke()
                let sepPath = UIBezierPath()
                sepPath.move(to: CGPoint(x: margin, y: yOffset))
                sepPath.addLine(to: CGPoint(x: pageWidth - margin, y: yOffset))
                sepPath.lineWidth = 1
                sepPath.stroke()
                yOffset += 15

                // Content
                let contentAttrs: [NSAttributedString.Key: Any] = [
                    .font: bodyFont,
                    .foregroundColor: UIColor.darkGray,
                    .paragraphStyle: paragraphStyle
                ]

                let contentRect = CGRect(x: margin, y: yOffset, width: contentWidth, height: pageHeight - yOffset - margin)
                let attributedContent = NSAttributedString(string: source.content, attributes: contentAttrs)
                attributedContent.draw(in: contentRect)

                // Footer
                let footerY = pageHeight - margin / 2
                let footerText = "Exported from Fume · \(formattedFullDate(Date()))"
                let footerAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 8),
                    .foregroundColor: UIColor.lightGray
                ]
                let footerSize = footerText.size(withAttributes: footerAttrs)
                footerText.draw(at: CGPoint(x: (pageWidth - footerSize.width) / 2, y: footerY), withAttributes: footerAttrs)
            }
        }

        let itemProvider = NSItemProvider(item: data as NSData, typeIdentifier: "com.adobe.pdf")
        _ = itemProvider  // Reserved for UIActivityViewController sharing

        return ExportResult(
            name: "Fume_Export_\(dateString()).pdf",
            data: data,
            format: .pdf
        )
    }

    // MARK: - JSON Export

    private func exportToJSON(sources: [Source]) throws -> ExportResult {
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
        let jsonData = try encoder.encode(package)

        return ExportResult(
            name: "Fume_Export_\(dateString()).json",
            data: jsonData,
            format: .json
        )
    }

    // MARK: - Single Source Export

    func exportSource(_ source: Source, format: ExportFormat) async throws -> ExportResult {
        switch format {
        case .obsidian:
            return try exportSourceToObsidian(source)
        case .pdf:
            return try exportSourceToPDF(source)
        case .json:
            return try exportSourceToJSON(source)
        }
    }

    private func exportSourceToObsidian(_ source: Source) throws -> ExportResult {
        let frontmatter = buildObsidianFrontmatter(for: source)
        let content = """
        \(frontmatter)

        # \(source.title)

        \(source.content)
        """

        let data = content.data(using: .utf8) ?? Data()
        let itemProvider = NSItemProvider(item: data as NSData, typeIdentifier: "public.plain-text")
        _ = itemProvider  // Reserved for UIActivityViewController sharing

        let safeName = source.title.replacingOccurrences(of: "/", with: "-").prefix(50)
        return ExportResult(
            name: "\(safeName).md",
            data: data,
            format: .obsidian
        )
    }

    private func exportSourceToPDF(_ source: Source) throws -> ExportResult {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 72
        let contentWidth = pageWidth - (margin * 2)

        let pdfMetaData = [
            kCGPDFContextCreator: "Fume",
            kCGPDFContextTitle: source.title
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()

            var yOffset: CGFloat = margin

            // Amber header bar
            UIColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1.0).setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: pageWidth, height: 50))

            let fumeAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            "FUME".draw(at: CGPoint(x: margin, y: 16), withAttributes: fumeAttrs)

            yOffset = margin + 20

            // Title
            let titleFont = UIFont.systemFont(ofSize: 18, weight: .bold)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 6

            let titleRect = CGRect(x: margin, y: yOffset, width: contentWidth, height: 60)
            source.title.draw(in: titleRect, withAttributes: [
                .font: titleFont,
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraphStyle
            ])
            yOffset += 45

            // Type badge
            let badgeText = "  \(source.type.label)  "
            let badgeFont = UIFont.systemFont(ofSize: 9, weight: .semibold)
            let badgeAttrs: [NSAttributedString.Key: Any] = [
                .font: badgeFont,
                .foregroundColor: UIColor.white
            ]
            let badgeSize = badgeText.size(withAttributes: badgeAttrs)
            let badgeRect = CGRect(x: margin, y: yOffset, width: badgeSize.width + 8, height: 18)
            UIColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1.0).setFill()
            UIBezierPath(roundedRect: badgeRect, cornerRadius: 4).fill()
            badgeText.draw(at: CGPoint(x: margin + 4, y: yOffset + 3), withAttributes: badgeAttrs)

            let metaAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.gray
            ]
            let metaX = margin + badgeSize.width + 16
            formattedDate(source.createdAt).draw(at: CGPoint(x: metaX, y: yOffset + 3), withAttributes: metaAttrs)
            yOffset += 30

            // Separator
            UIColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 0.5).setStroke()
            let sepPath = UIBezierPath()
            sepPath.move(to: CGPoint(x: margin, y: yOffset))
            sepPath.addLine(to: CGPoint(x: pageWidth - margin, y: yOffset))
            sepPath.lineWidth = 1
            sepPath.stroke()
            yOffset += 15

            // Body content
            let bodyFont = UIFont.systemFont(ofSize: 12)
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .foregroundColor: UIColor.darkGray,
                .paragraphStyle: paragraphStyle
            ]

            let contentRect = CGRect(x: margin, y: yOffset, width: contentWidth, height: pageHeight - yOffset - margin)
            source.content.draw(in: contentRect, withAttributes: bodyAttrs)

            // Footer
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8),
                .foregroundColor: UIColor.lightGray
            ]
            let footerText = "Exported from Fume · \(formattedFullDate(Date()))"
            let footerSize = footerText.size(withAttributes: footerAttrs)
            footerText.draw(at: CGPoint(x: (pageWidth - footerSize.width) / 2, y: pageHeight - margin / 2), withAttributes: footerAttrs)
        }

        let itemProvider = NSItemProvider(item: data as NSData, typeIdentifier: "com.adobe.pdf")
        _ = itemProvider  // Reserved for UIActivityViewController sharing
        let safeName = source.title.replacingOccurrences(of: "/", with: "-").prefix(50)

        return ExportResult(
            name: "\(safeName).pdf",
            data: data,
            format: .pdf
        )
    }

    private func exportSourceToJSON(_ source: Source) throws -> ExportResult {
        struct SingleSourceExport: Codable {
            let id: String
            let type: String
            let title: String
            let content: String
            let url: String?
            let createdAt: String
            let updatedAt: String
            let tagIDs: [String]
        }

        let export = SingleSourceExport(
            id: source.id.uuidString,
            type: source.type.rawValue,
            title: source.title,
            content: source.content,
            url: source.url,
            createdAt: ISO8601DateFormatter().string(from: source.createdAt),
            updatedAt: ISO8601DateFormatter().string(from: source.updatedAt),
            tagIDs: source.tagIDs.map { $0.uuidString }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(export)

        let safeName = source.title.replacingOccurrences(of: "/", with: "-").prefix(50)

        return ExportResult(
            name: "\(safeName).json",
            data: jsonData,
            format: .json
        )
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

// MARK: - Export Errors
enum ExportError: Error, LocalizedError {
    case noSources
    case encodingFailed
    case pdfGenerationFailed
    case jsonEncodingFailed

    var errorDescription: String? {
        switch self {
        case .noSources: return "No sources available to export."
        case .encodingFailed: return "Failed to encode content."
        case .pdfGenerationFailed: return "Failed to generate PDF."
        case .jsonEncodingFailed: return "Failed to encode JSON."
        }
    }
}
