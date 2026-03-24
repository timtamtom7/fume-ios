import WidgetKit
import SwiftUI

// MARK: - Widget Entry

struct FumeWidgetEntry: TimelineEntry {
    let date: Date
    let lastSourceTitle: String?
    let lastSourceType: String?
    let lastSourceDate: Date?
    let sourcesCount: Int
    let query: String?
    let displayMode: DisplayMode
    let configuration: ConfigurationIntent?

    enum DisplayMode {
        case small
        case medium
    }

    static var placeholder: FumeWidgetEntry {
        FumeWidgetEntry(
            date: Date(),
            lastSourceTitle: "Sample Note Title",
            lastSourceType: "Note",
            lastSourceDate: Date(),
            sourcesCount: 12,
            query: nil,
            displayMode: .small,
            configuration: nil
        )
    }
}

// MARK: - Configuration Intent

struct ConfigurationIntent {
    // Empty for now - could be expanded to allow user to select what to display
}

// MARK: - Timeline Provider

struct FumeWidgetProvider: TimelineProvider {
    typealias Entry = FumeWidgetEntry

    func placeholder(in context: Context) -> FumeWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (FumeWidgetEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FumeWidgetEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> FumeWidgetEntry {
        // Load from shared UserDefaults (App Group)
        let defaults = UserDefaults(suiteName: "group.com.fume.app") ?? .standard

        let lastTitle = defaults.string(forKey: "widget_last_source_title")
        let lastType = defaults.string(forKey: "widget_last_source_type")
        let lastDateInterval = defaults.double(forKey: "widget_last_source_date")
        let lastDate = lastDateInterval > 0 ? Date(timeIntervalSince1970: lastDateInterval) : nil
        let sourcesCount = defaults.integer(forKey: "widget_sources_count")

        let displayMode: FumeWidgetEntry.DisplayMode = .small

        return FumeWidgetEntry(
            date: Date(),
            lastSourceTitle: lastTitle,
            lastSourceType: lastType,
            lastSourceDate: lastDate,
            sourcesCount: sourcesCount,
            query: nil,
            displayMode: displayMode,
            configuration: nil
        )
    }
}

// MARK: - Widget Views

struct FumeWidgetEntryView: View {
    var entry: FumeWidgetProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    let entry: FumeWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "f59e0b"))
                Text("Fume")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }

            Spacer()

            // Last source
            if let title = entry.lastSourceTitle {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            } else {
                Text("No sources yet")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Footer
            HStack {
                if let type = entry.lastSourceType {
                    Label(type, systemImage: iconForType(type))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(entry.sourcesCount) total")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .containerBackground(for: .widget) {
            Color(UIColor.systemBackground)
        }
    }

    private func iconForType(_ type: String) -> String {
        switch type.lowercased() {
        case "note": return "note.text"
        case "article": return "link"
        case "voice memo": return "waveform"
        case "image": return "photo"
        case "pdf": return "doc.text"
        default: return "doc.text"
        }
    }
}

struct MediumWidgetView: View {
    let entry: FumeWidgetEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left side - Fume branding
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "f59e0b"))
                    Text("Fume")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                Text("Your second brain")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .frame(height: 50)

            // Right side - Quick query or last source
            VStack(alignment: .leading, spacing: 6) {
                Text("Quick Query")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("Tap to ask Fume anything")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Spacer()

                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "f59e0b"))

                    Text("Ask a question")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "f59e0b"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .containerBackground(for: .widget) {
            Color(UIColor.systemBackground)
        }
    }
}

// MARK: - Widget Configuration

struct FumeWidget: Widget {
    let kind: String = "FumeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FumeWidgetProvider()) { entry in
            FumeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Fume")
        .description("Quick access to your second brain.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct FumeWidgetBundle: WidgetBundle {
    var body: some Widget {
        FumeWidget()
    }
}

// MARK: - Color Extension for Widget

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    FumeWidget()
} timeline: {
    FumeWidgetEntry.placeholder
}

#Preview(as: .systemMedium) {
    FumeWidget()
} timeline: {
    FumeWidgetEntry.placeholder
}
