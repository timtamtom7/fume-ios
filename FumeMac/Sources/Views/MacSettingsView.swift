import SwiftUI
import UniformTypeIdentifiers

// MARK: - Mac Settings View

struct MacSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var showExportSheet = false
    @State private var selectedExportFormat: ExportFormat = .json
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var showClearConfirmation = false
    @State private var isClearing = false
    @State private var clearProgress = ""

    @State private var totalSources = 0
    @State private var totalNotes = 0
    @State private var totalArticles = 0
    @State private var totalVoiceMemos = 0
    @State private var totalImages = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(FumeColors.textSecondary)
            }
            .padding()
            .background(FumeColors.surface)

            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    // Statistics
                    statsSection

                    Divider()

                    // Export
                    exportSection

                    Divider()

                    // Data management
                    dataManagementSection

                    Divider()

                    // About
                    aboutSection
                }
                .padding()
            }
            .background(FumeColors.background)
        }
        .frame(width: 480, height: 520)
        .background(FumeColors.background)
        .task {
            await loadStats()
        }
        .confirmationDialog("Clear All Data", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("Clear Everything", role: .destructive) {
                Task { await clearAllData() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all your notes, articles, voice memos, and images. This action cannot be undone.")
        }
        .sheet(isPresented: $showExportSheet) {
            exportSheet
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar")
                    .font(.system(size: 13))
                    .foregroundStyle(FumeColors.accent)
                Text("Library Statistics")
                    .font(.system(size: 14, weight: .semibold))
            }

            HStack(spacing: 12) {
                statCard(label: "Total", value: "\(totalSources)", icon: "doc.text", color: FumeColors.accent)
                statCard(label: "Notes", value: "\(totalNotes)", icon: "note.text", color: Color.blue)
                statCard(label: "Articles", value: "\(totalArticles)", icon: "link", color: Color.purple)
                statCard(label: "Voice", value: "\(totalVoiceMemos)", icon: "waveform", color: Color.orange)
                statCard(label: "Images", value: "\(totalImages)", icon: "photo", color: Color.green)
            }
        }
    }

    private func statCard(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(FumeColors.textPrimary)

            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(FumeColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(FumeColors.surfaceRaised)
        .cornerRadius(12)
    }

    // MARK: - Export Section

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 13))
                    .foregroundStyle(FumeColors.accent)
                Text("Export Data")
                    .font(.system(size: 14, weight: .semibold))
            }

            Text("Export your entire knowledge base. Choose a format below.")
                .font(.system(size: 12))
                .foregroundStyle(FumeColors.textSecondary)

            HStack(spacing: 10) {
                ForEach(ExportFormat.allCases) { format in
                    Button {
                        selectedExportFormat = format
                        showExportSheet = true
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: format.icon)
                                .font(.system(size: 20))
                            Text(format.rawValue)
                                .font(.system(size: 10, weight: .medium))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(FumeColors.surfaceRaised)
                        .foregroundStyle(FumeColors.textPrimary)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(FumeColors.border.opacity(0.5), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Data Management

    private var dataManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "externaldrive")
                    .font(.system(size: 13))
                    .foregroundStyle(FumeColors.accent)
                Text("Data Management")
                    .font(.system(size: 14, weight: .semibold))
            }

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Clear All Data")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(FumeColors.textPrimary)
                        Text("Delete all notes, articles, voice memos, and images")
                            .font(.system(size: 11))
                            .foregroundStyle(FumeColors.textSecondary)
                    }

                    Spacer()

                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        if isClearing {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Text("Clear All")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(isClearing)
                }
                .padding()

                if isClearing {
                    Text(clearProgress)
                        .font(.system(size: 11))
                        .foregroundStyle(FumeColors.textSecondary)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            }
            .background(FumeColors.surfaceRaised)
            .cornerRadius(12)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(FumeColors.accent)
                Text("About")
                    .font(.system(size: 14, weight: .semibold))
            }

            VStack(spacing: 0) {
                aboutRow(label: "App", value: "Fume")
                Divider()
                aboutRow(label: "Version", value: "1.0.0")
                Divider()
                aboutRow(label: "Platform", value: "macOS")
                Divider()
                aboutRow(label: "AI", value: "On-device (NaturalLanguage)")
            }
            .background(FumeColors.surfaceRaised)
            .cornerRadius(12)
        }
    }

    private func aboutRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(FumeColors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(FumeColors.textPrimary)
        }
        .padding()
    }

    // MARK: - Export Sheet

    private var exportSheet: some View {
        VStack(spacing: 16) {
            Text("Export as \(selectedExportFormat.rawValue)")
                .font(.system(size: 15, weight: .semibold))

            if isExporting {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(FumeColors.accent)
                    Text("Exporting...")
                        .font(.system(size: 13))
                        .foregroundStyle(FumeColors.textSecondary)
                }
            } else if let error = exportError {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
            } else {
                Text("Your knowledge base will be exported.")
                    .font(.system(size: 13))
                    .foregroundStyle(FumeColors.textSecondary)
            }

            HStack {
                Button("Cancel") {
                    showExportSheet = false
                    isExporting = false
                    exportError = nil
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await performExport() }
                } label: {
                    Text("Export")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(FumeColors.accent)
                .disabled(isExporting)
            }
        }
        .padding(24)
        .frame(width: 320)
    }

    // MARK: - Helpers

    private func loadStats() async {
        do {
            let sources = try await DatabaseService.shared.fetchAllSources()
            totalSources = sources.count
            totalNotes = sources.filter { $0.type == .note }.count
            totalArticles = sources.filter { $0.type == .article }.count
            totalVoiceMemos = sources.filter { $0.type == .voiceMemo }.count
            totalImages = sources.filter { $0.type == .image }.count
        } catch {
            print("Failed to load stats: \(error)")
        }
    }

    private func performExport() async {
        isExporting = true
        exportError = nil

        do {
            let sources = try await DatabaseService.shared.fetchAllSources()
            guard !sources.isEmpty else {
                exportError = "No sources to export"
                isExporting = false
                return
            }

            let (exportData, filename) = try await MacExportService.shared.export(sources: sources, format: selectedExportFormat)

            // Save to file
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [UTType(filenameExtension: selectedExportFormat.fileExtension) ?? .json]
            savePanel.nameFieldStringValue = filename

            if savePanel.runModal() == .OK, let url = savePanel.url {
                try exportData.write(to: url)
                await MainActor.run {
                    showExportSheet = false
                    isExporting = false
                }
            } else {
                await MainActor.run { isExporting = false }
            }
        } catch {
            await MainActor.run {
                exportError = error.localizedDescription
                isExporting = false
            }
        }
    }

    private func clearAllData() async {
        isClearing = true
        clearProgress = "Fetching all sources..."

        do {
            let sources = try await DatabaseService.shared.fetchAllSources()
            clearProgress = "Deleting \(sources.count) sources..."

            for (index, source) in sources.enumerated() {
                try await DatabaseService.shared.deleteSource(id: source.id)
                clearProgress = "Deleted \(index + 1) of \(sources.count)..."
            }

            clearProgress = "Done."
            await MainActor.run {
                isClearing = false
                showClearConfirmation = false
            }
            await loadStats()
        } catch {
            clearProgress = "Error: \(error.localizedDescription)"
            await MainActor.run { isClearing = false }
        }
    }
}
