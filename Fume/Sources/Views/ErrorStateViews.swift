import SwiftUI

// MARK: - Error State Container

enum FumeError: Error, Identifiable, Equatable {
    case aiQueryFailed
    case sourceSaveFailed
    case speechTranscriptionFailed
    case storageLimitReached
    case networkError
    case importFailed
    case noSearchResults
    case noRelatedSources
    case exportFailed

    var id: String {
        switch self {
        case .aiQueryFailed: return "ai_query_failed"
        case .sourceSaveFailed: return "source_save_failed"
        case .speechTranscriptionFailed: return "speech_failed"
        case .storageLimitReached: return "storage_limit"
        case .networkError: return "network_error"
        case .importFailed: return "import_failed"
        case .noSearchResults: return "no_search_results"
        case .noRelatedSources: return "no_related_sources"
        case .exportFailed: return "export_failed"
        }
    }

    var icon: String {
        switch self {
        case .aiQueryFailed: return "brain.slash"
        case .sourceSaveFailed: return "square.and.arrow.down.trianglebadge.exclamationmark"
        case .speechTranscriptionFailed: return "waveform.slash"
        case .storageLimitReached: return "internaldrive.fill.badge.xmark"
        case .networkError: return "wifi.exclamationmark"
        case .importFailed: return "square.and.arrow.down.on.square.slash"
        case .noSearchResults: return "magnifyingglass"
        case .noRelatedSources: return "link.badge.plus"
        case .exportFailed: return "square.and.arrow.up.on.square"
        }
    }

    var title: String {
        switch self {
        case .aiQueryFailed: return "Query failed"
        case .sourceSaveFailed: return "Couldn't save"
        case .speechTranscriptionFailed: return "Transcription failed"
        case .storageLimitReached: return "Storage full"
        case .networkError: return "Connection issue"
        case .importFailed: return "Import failed"
        case .noSearchResults: return "No results found"
        case .noRelatedSources: return "No related sources"
        case .exportFailed: return "Export failed"
        }
    }

    var message: String {
        switch self {
        case .aiQueryFailed:
            return "Fume couldn't process your question. This sometimes happens when the model is unavailable. Try again in a moment."
        case .sourceSaveFailed:
            return "The content couldn't be saved. Check your storage and try again."
        case .speechTranscriptionFailed:
            return "Fume couldn't transcribe your voice memo. Make sure speech recognition is enabled in Settings."
        case .storageLimitReached:
            return "You've hit the free plan limit of 50 sources. Upgrade to Pro for unlimited storage."
        case .networkError:
            return "Couldn't reach the network. For article imports, make sure you have an active connection."
        case .importFailed:
            return "The file couldn't be imported. Make sure it's a valid markdown or text file."
        case .noSearchResults:
            return "No sources matched your search. Try different keywords or add more content."
        case .noRelatedSources:
            return "No related sources were found. Add more content to discover connections."
        case .exportFailed:
            return "The export couldn't be generated. Try a different format."
        }
    }

    var suggestion: String? {
        switch self {
        case .aiQueryFailed: return "Try again"
        case .sourceSaveFailed: return "Try again"
        case .speechTranscriptionFailed: return "Open Settings"
        case .storageLimitReached: return "Upgrade to Pro"
        case .networkError: return "Check connection"
        case .importFailed: return "Choose different file"
        case .noSearchResults: return "Clear search"
        case .noRelatedSources: return nil
        case .exportFailed: return "Try again"
        }
    }
}

// MARK: - Error State View

struct ErrorStateView: View {
    let error: FumeError
    var retryAction: (() -> Void)?
    var settingsAction: (() -> Void)?
    var upgradeAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Error icon
            ZStack {
                Circle()
                    .fill(FumeColors.accent.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: error.icon)
                    .font(.system(size: 36))
                    .foregroundStyle(FumeColors.accent.opacity(0.7))
            }

            VStack(spacing: 8) {
                Text(error.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(FumeColors.textPrimary)

                Text(error.message)
                    .font(.system(size: 14))
                    .foregroundStyle(FumeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 32)
            }

            // Action buttons
            VStack(spacing: 12) {
                if let suggestion = error.suggestion {
                    Button {
                        FumeHaptic.light()
                        handleAction()
                    } label: {
                        Text(suggestion)
                            .font(.system(size: FumeTokens.fontSizeBodyLarge, weight: .semibold))
                            .foregroundStyle(FumeColors.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .fill(FumeColors.accent)
                            )
                    }
                    .accessibilityLabel(suggestion)
                }

                Button {
                    // Dismiss / go back
                    retryAction?()
                } label: {
                    Text("Dismiss")
                        .font(.system(size: 14))
                        .foregroundStyle(FumeColors.textSecondary)
                }
            }
            .padding(.horizontal, 48)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func handleAction() {
        switch error {
        case .storageLimitReached:
            upgradeAction?()
        case .speechTranscriptionFailed:
            settingsAction?()
        default:
            retryAction?()
        }
    }
}

// MARK: - Inline Error Banner

struct ErrorBanner: View {
    let error: FumeError
    let onDismiss: () -> Void
    let onAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: error.icon)
                .font(.system(size: 14))
                .foregroundStyle(FumeColors.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(error.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FumeColors.textPrimary)

                Text(error.message)
                    .font(.system(size: 12))
                    .foregroundStyle(FumeColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            if onAction != nil {
                Button {
                    FumeHaptic.light()
                    onAction?()
                } label: {
                    Text(error.suggestion ?? "Retry")
                        .font(.system(size: FumeTokens.fontSizeCaption, weight: .medium))
                        .foregroundStyle(FumeColors.accent)
                }
                .accessibilityLabel(error.suggestion ?? "Retry")
            }

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
                    .foregroundStyle(FumeColors.textSecondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: FumeTokens.cornerRadiusMedium)
                .fill(FumeColors.glassOverlay)
                .overlay(
                    RoundedRectangle(cornerRadius: FumeTokens.cornerRadiusMedium)
                        .stroke(FumeColors.accent.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - Empty Library State

struct EmptyLibraryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Custom illustration
            ZStack {
                Circle()
                    .fill(FumeColors.accent.opacity(0.08))
                    .frame(width: 120, height: 120)

                Image(systemName: "books.vertical")
                    .font(.system(size: 40))
                    .foregroundStyle(FumeColors.textSecondary.opacity(0.4))
            }

            VStack(spacing: 8) {
                Text("Your library is empty")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(FumeColors.textPrimary)

                Text("Add notes, articles, voice memos, or images.\nThey'll appear here, ready to be queried.")
                    .font(.system(size: 14))
                    .foregroundStyle(FumeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Spacer()
        }
    }
}

// MARK: - No Search Results

struct NoSearchResultsView: View {
    let query: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(FumeColors.textSecondary.opacity(0.4))

            VStack(spacing: 6) {
                Text("No results for \"\(query)\"")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FumeColors.textPrimary)

                Text("Try different keywords or add more sources about this topic.")
                    .font(.system(size: 13))
                    .foregroundStyle(FumeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Storage Limit Banner

struct StorageLimitBanner: View {
    let onUpgrade: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(FumeColors.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Free plan — 50 sources used")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FumeColors.textPrimary)

                    Text("Upgrade to Pro for unlimited sources and semantic search.")
                        .font(.system(size: 12))
                        .foregroundStyle(FumeColors.textSecondary)
                }

                Spacer()
            }

            Button {
                FumeHaptic.medium()
                onUpgrade()
            } label: {
                Text("Upgrade to Pro")
                    .font(.system(size: FumeTokens.fontSizeBodySmall, weight: .semibold))
                    .foregroundStyle(FumeColors.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(FumeColors.accent)
                    )
            }
            .accessibilityLabel("Upgrade to Pro")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: FumeTokens.cornerRadiusLarge)
                .fill(FumeColors.sourceHighlight)
                .overlay(
                    RoundedRectangle(cornerRadius: FumeTokens.cornerRadiusLarge)
                        .stroke(FumeColors.accent.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

// MARK: - Speech Permission Banner

struct SpeechPermissionBanner: View {
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mic.slash")
                .font(.system(size: 14))
                .foregroundStyle(FumeColors.accent)

            Text("Microphone access needed for voice memos.")
                .font(.system(size: 13))
                .foregroundStyle(FumeColors.textSecondary)

            Spacer()

            Button {
                FumeHaptic.light()
                onOpenSettings()
            } label: {
                Text("Settings")
                    .font(.system(size: FumeTokens.fontSizeCaption, weight: .semibold))
                    .foregroundStyle(FumeColors.accent)
            }
            .accessibilityLabel("Open Settings")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: FumeTokens.cornerRadiusMedium)
                .fill(FumeColors.surfaceRaised)
        )
        .padding(.horizontal, 16)
    }
}
