import SwiftUI

// MARK: - Sync Status Bar

/// Shows sync status — offline indicator, syncing spinner, last synced time
struct SyncStatusBar: View {
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @State private var syncStatus: SyncService.SyncStatus = .idle
    @State private var lastSynced: Date?
    @State private var pendingCount: Int = 0
    @State private var showSyncDetails = false

    var body: some View {
        if !networkMonitor.isConnected {
            offlineBar
        } else if syncStatus == .syncing {
            syncingBar
        } else if syncStatus == .upToDate || syncStatus == .idle {
            upToDateBar
        } else if case .error(let msg) = syncStatus {
            errorBar(message: msg)
        } else if pendingCount > 0 {
            pendingBar
        }
    }

    // MARK: - Offline Bar

    private var offlineBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 12, weight: .medium))

            Text("Offline — changes will sync when connected")
                .font(.system(size: 12))

            Spacer()

            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 12))
                .foregroundStyle(FumeColors.textSecondary)
        }
        .foregroundStyle(FumeColors.textSecondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(FumeColors.surfaceRaised)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Syncing Bar

    private var syncingBar: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(FumeColors.accent)
                .scaleEffect(0.6)

            Text("Syncing...")
                .font(.system(size: 12))
                .foregroundStyle(FumeColors.textSecondary)

            Spacer()

            if pendingCount > 0 {
                Text("\(pendingCount) pending")
                    .font(.system(size: 11))
                    .foregroundStyle(FumeColors.textSecondary)
            }
        }
        .foregroundStyle(FumeColors.textSecondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(FumeColors.surfaceRaised)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Up To Date Bar

    private var upToDateBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.icloud")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: "10b981"))

            if let lastSynced = lastSynced {
                Text("Synced \(lastSynced.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 12))
                    .foregroundStyle(FumeColors.textSecondary)
            } else {
                Text("iCloud synced")
                    .font(.system(size: 12))
                    .foregroundStyle(FumeColors.textSecondary)
            }

            Spacer()

            Button {
                Task { await triggerManualSync() }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12))
                    .foregroundStyle(FumeColors.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(FumeColors.surfaceRaised)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Pending Bar

    private var pendingBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "icloud.badge.exclamationmark")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(FumeColors.accent)

            Text("\(pendingCount) change\(pendingCount == 1 ? "" : "s") pending sync")
                .font(.system(size: 12))
                .foregroundStyle(FumeColors.textSecondary)

            Spacer()

            Button {
                Task { await triggerManualSync() }
            } label: {
                Text("Sync now")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FumeColors.accent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(FumeColors.surfaceRaised)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Error Bar

    private func errorBar(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.icloud")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: "ef4444"))

            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(FumeColors.textSecondary)

            Spacer()

            Button {
                Task { await triggerManualSync() }
            } label: {
                Text("Retry")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FumeColors.accent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(FumeColors.surfaceRaised)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Actions

    private func triggerManualSync() async {
        do {
            try await SyncService.shared.syncAllSources()
            await updateStatus()
        } catch {
            // Error state handled via syncStatus
        }
    }

    @MainActor
    private func updateStatus() async {
        let state = await SyncService.shared.syncState
        syncStatus = state.status
        lastSynced = state.lastSyncedAt
        pendingCount = state.pendingChanges
    }
}

// MARK: - Sync Settings View

struct SyncSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var iCloudStatus: String = "Checking..."
    @State private var lastSynced: Date?
    @State private var pendingChanges: Int = 0
    @State private var isSyncing: Bool = false
    @State private var syncError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                FumeColors.background
                    .ignoresSafeArea()

                List {
                    // iCloud Status Section
                    Section {
                        HStack {
                            Image(systemName: "icloud")
                                .foregroundStyle(FumeColors.accent)
                            Text("iCloud Sync")
                                .font(.system(size: 15))

                            Spacer()

                            Text(iCloudStatus)
                                .font(.system(size: 13))
                                .foregroundStyle(FumeColors.textSecondary)
                        }
                        .listRowBackground(FumeColors.surfaceRaised)

                        if let lastSynced = lastSynced {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundStyle(FumeColors.textSecondary)
                                Text("Last synced")
                                    .font(.system(size: 15))

                                Spacer()

                                Text(lastSynced.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 13))
                                    .foregroundStyle(FumeColors.textSecondary)
                            }
                            .listRowBackground(FumeColors.surfaceRaised)
                        }

                        if pendingChanges > 0 {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundStyle(FumeColors.accent)
                                Text("Pending changes")
                                    .font(.system(size: 15))

                                Spacer()

                                Text("\(pendingChanges)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(FumeColors.accent)
                            }
                            .listRowBackground(FumeColors.surfaceRaised)
                        }
                    } header: {
                        Text("Status")
                    }

                    // Sync Actions
                    Section {
                        Button {
                            Task { await syncNow() }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundStyle(FumeColors.accent)

                                if isSyncing {
                                    ProgressView()
                                        .tint(FumeColors.accent)
                                        .scaleEffect(0.7)
                                }

                                Text(isSyncing ? "Syncing..." : "Sync Now")
                                    .font(.system(size: 15))
                                    .foregroundStyle(isSyncing ? FumeColors.textSecondary : FumeColors.accent)

                                Spacer()
                            }
                        }
                        .disabled(isSyncing)
                        .listRowBackground(FumeColors.surfaceRaised)
                    } header: {
                        Text("Actions")
                    }

                    // Offline Queue Info
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Offline Support", systemImage: "wifi.slash")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(FumeColors.textPrimary)

                            Text("Changes made while offline are automatically synced when you reconnect. No data is lost.")
                                .font(.system(size: 12))
                                .foregroundStyle(FumeColors.textSecondary)
                                .lineSpacing(3)
                        }
                        .listRowBackground(FumeColors.surfaceRaised)
                    } header: {
                        Text("How it works")
                    }

                    if let error = syncError {
                        Section {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundStyle(Color(hex: "ef4444"))
                                .listRowBackground(FumeColors.surfaceRaised)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("iCloud Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(FumeColors.accent)
                }
            }
            .task {
                await checkStatus()
            }
        }
    }

    private func checkStatus() async {
        let status = await SyncService.shared.checkAccountStatus()
        switch status {
        case .available:
            iCloudStatus = "Connected"
        case .noAccount:
            iCloudStatus = "No iCloud account"
        case .restricted:
            iCloudStatus = "Restricted"
        case .couldNotDetermine:
            iCloudStatus = "Unknown"
        case .temporarilyUnavailable:
            iCloudStatus = "Temporarily unavailable"
        @unknown default:
            iCloudStatus = "Unknown"
        }

        let state = await SyncService.shared.syncState
        lastSynced = state.lastSyncedAt
        pendingChanges = state.pendingChanges
    }

    private func syncNow() async {
        isSyncing = true
        syncError = nil

        do {
            try await SyncService.shared.syncAllSources()
            await checkStatus()
        } catch {
            syncError = error.localizedDescription
        }

        isSyncing = false
    }
}
