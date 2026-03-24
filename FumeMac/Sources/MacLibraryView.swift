import SwiftUI

// MARK: - Mac Library View (macOS version without UIKit dependency)

struct MacLibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @State private var selectedSource: Source?
    @State private var showDeleteConfirmation = false
    @State private var sourceToDelete: Source?

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar

            Divider()

            // Content
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.filteredSources.isEmpty {
                emptyState
            } else {
                sourceList
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            await viewModel.loadSources()
        }
        .sheet(item: $selectedSource) { source in
            MacSourceDetailSheet(source: source)
        }
        .confirmationDialog(
            "Delete Source",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let source = sourceToDelete {
                    Task {
                        await viewModel.deleteSource(source)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this source from your knowledge base.")
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search library...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .onChange(of: viewModel.searchText) { _, newValue in
                    Task {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        if viewModel.searchText == newValue {
                            await viewModel.performSearch(newValue)
                        }
                    }
                }

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if viewModel.isSearching {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding(12)
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(10)
        .padding()
    }

    // MARK: - Source List

    private var sourceList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.filteredSources) { source in
                    MacLibraryRow(source: source)
                        .contextMenu {
                            Button(role: .destructive) {
                                sourceToDelete = source
                                showDeleteConfirmation = true
                            } label: {
                                Text("Delete")
                            }
                        }
                        .onTapGesture {
                            selectedSource = source
                        }
                }
            }
            .padding()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "books.vertical")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.4))

            Text("Library is empty")
                .font(.system(size: 17, weight: .semibold))

            Text("Add notes, articles, or voice memos\nto build your knowledge base.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
    }
}

// MARK: - Mac Library Row

struct MacLibraryRow: View {
    let source: Source

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(width: 44, height: 44)

                Image(systemName: source.type.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Color(hex: "f59e0b"))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(source.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                Text(source.content.prefix(100) + (source.content.count > 100 ? "..." : ""))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(source.formattedDate)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Mac Source Detail Sheet

struct MacSourceDetailSheet: View {
    let source: Source
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(source.title)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(2)

                    Text(source.formattedDate)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Done") {
                    dismiss()
                }
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Type badge
                    HStack(spacing: 8) {
                        Image(systemName: source.type.icon)
                            .foregroundStyle(Color(hex: "f59e0b"))
                        Text(source.type.label)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "f59e0b").opacity(0.15))
                    .cornerRadius(20)

                    // Content
                    Text(source.content)
                        .font(.system(size: 15))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // URL
                    if let url = source.url, let parsedURL = URL(string: url) {
                        Link(destination: parsedURL) {
                            HStack {
                                Image(systemName: "link")
                                Text(url)
                                    .lineLimit(1)
                            }
                            .font(.system(size: 13))
                        }
                    }

                    // Metadata
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Details")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)

                        HStack {
                            Text("Characters")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(source.content.count)")
                                .font(.system(size: 13))
                        }

                        HStack {
                            Text("Words")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(source.content.split(separator: " ").count)")
                                .font(.system(size: 13))
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(10)
                }
                .padding()
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}
