import SwiftUI

// MARK: - Mac Collaborative Space View
// Create shared research spaces and collaborate with others

struct MacCollaborativeSpaceView: View {
    @State private var spaces: [KnowledgeSharingService.CollaborativeSpace] = []
    @State private var isLoading = false
    @State private var showCreateSheet = false
    @State private var newSpaceName = ""
    @State private var selectedSpace: KnowledgeSharingService.CollaborativeSpace?
    @State private var inviteEmail = ""
    @State private var synthesisResult: KnowledgeSharingService.AIResponse?
    @State private var isSynthesizing = false
    @State private var showingSynthesized = false

    private let service = KnowledgeSharingService.shared

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()

            if isLoading {
                Spacer()
                ProgressView("Loading spaces...")
                    .tint(FumeColors.accent)
                Spacer()
            } else if spaces.isEmpty {
                emptyState
            } else {
                spacesList
            }
        }
        .background(FumeColors.background)
        .task {
            await loadSpaces()
        }
        .sheet(isPresented: $showCreateSheet) {
            createSpaceSheet
        }
        .sheet(item: $selectedSpace) { space in
            spaceDetailSheet(space)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(FumeColors.accent)

                    Text("Collaborative Spaces")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FumeColors.textPrimary)
                }

                Text("Create shared research spaces and synthesize knowledge together")
                    .font(.system(size: 11))
                    .foregroundStyle(FumeColors.textSecondary)
            }

            Spacer()

            Button {
                showCreateSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("New Space")
                }
                .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(FumeColors.accent)
        }
        .padding()
        .background(FumeColors.surface)
    }

    // MARK: - Spaces List

    private var spacesList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(spaces) { space in
                    spaceRow(space)
                }
            }
            .padding()
        }
    }

    private func spaceRow(_ space: KnowledgeSharingService.CollaborativeSpace) -> some View {
        Button {
            selectedSpace = space
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    // Space icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(FumeColors.accent.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: "person.3.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(FumeColors.accent)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(space.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(FumeColors.textPrimary)

                        Text("by \(space.ownerName)")
                            .font(.system(size: 11))
                            .foregroundStyle(FumeColors.textSecondary)
                    }

                    Spacer()

                    // Status indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(space.isActive ? Color.green : Color.gray)
                            .frame(width: 6, height: 6)

                        Text(space.isActive ? "Active" : "Archived")
                            .font(.system(size: 10))
                            .foregroundStyle(FumeColors.textSecondary)
                    }
                }

                Divider()

                HStack(spacing: 16) {
                    statItem(icon: "person.2", value: "\(space.collaboratorIDs.count + 1)", label: "members")
                    statItem(icon: "note.text", value: "\(space.noteIDs.count)", label: "notes")
                    statItem(icon: "arrow.up.circle", value: "\(space.noteContributions.count)", label: "contributions")

                    Spacer()

                    Text("Last active \(space.lastActivityAt.formatted(.relative(presentation: .named)))")
                        .font(.system(size: 10))
                        .foregroundStyle(FumeColors.textSecondary)
                }
            }
            .padding(14)
            .background(FumeColors.surfaceRaised)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func statItem(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(FumeColors.accent)

            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(FumeColors.textPrimary)

            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(FumeColors.textSecondary)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "person.3.fill")
                .font(.system(size: 36))
                .foregroundStyle(FumeColors.textSecondary.opacity(0.4))

            Text("No collaborative spaces yet")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(FumeColors.textSecondary)

            Text("Create a space to start collaborating on research with others")
                .font(.system(size: 12))
                .foregroundStyle(FumeColors.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            Button {
                showCreateSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("Create Your First Space")
                }
                .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(FumeColors.accent)

            Spacer()
        }
    }

    // MARK: - Create Space Sheet

    private var createSpaceSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Collaborative Space")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FumeColors.textPrimary)

                Spacer()

                Button {
                    showCreateSheet = false
                    newSpaceName = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(FumeColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(FumeColors.surface)

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Space Name")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FumeColors.textSecondary)

                    TextField("e.g. SwiftUI Research, Product Roadmap...", text: $newSpaceName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .padding(12)
                        .background(FumeColors.surfaceRaised)
                        .cornerRadius(8)
                }

                Text("You can invite collaborators and add notes after creating the space.")
                    .font(.system(size: 11))
                    .foregroundStyle(FumeColors.textSecondary)

                Spacer()

                Button {
                    createSpace()
                } label: {
                    Text("Create Space")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(FumeColors.accent)
                .disabled(newSpaceName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 240)
        .background(FumeColors.background)
    }

    // MARK: - Space Detail Sheet

    private func spaceDetailSheet(_ space: KnowledgeSharingService.CollaborativeSpace) -> some View {
        VStack(spacing: 0) {
            // Sheet header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(space.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FumeColors.textPrimary)

                    Text("Owned by \(space.ownerName)")
                        .font(.system(size: 11))
                        .foregroundStyle(FumeColors.textSecondary)
                }

                Spacer()

                Button {
                    selectedSpace = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(FumeColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(FumeColors.surface)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Collaborators section
                    collaboratorsSection(space)

                    Divider()

                    // Contributions section
                    contributionsSection(space)

                    Divider()

                    // Synthesize section
                    synthesizeSection(space)
                }
                .padding()
            }
            .background(FumeColors.background)
        }
        .frame(width: 520, height: 480)
        .background(FumeColors.background)
    }

    private func collaboratorsSection(_ space: KnowledgeSharingService.CollaborativeSpace) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(FumeColors.accent)

                Text("Collaborators (\(space.collaboratorIDs.count + 1))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FumeColors.textPrimary)

                Spacer()

                // Invite button
                Button {
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 11))
                        Text("Invite")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .tint(FumeColors.accent)
            }

            // Owner
            collaboratorRow(name: space.ownerName, role: "Owner", isOwner: true)

            // Other collaborators
            ForEach(space.collaboratorIDs, id: \.self) { collabID in
                collaboratorRow(name: "Collaborator", role: "Member", isOwner: false)
            }

            // Invite field
            HStack(spacing: 8) {
                TextField("Enter collaborator ID or email...", text: $inviteEmail)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(8)
                    .background(FumeColors.surfaceRaised)
                    .cornerRadius(6)

                Button {
                    inviteCollaborator(to: space)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(FumeColors.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func collaboratorRow(name: String, role: String, isOwner: Bool) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isOwner ? FumeColors.accent.opacity(0.2) : FumeColors.surfaceRaised)
                    .frame(width: 28, height: 28)

                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isOwner ? FumeColors.accent : FumeColors.textSecondary)
            }

            Text(name)
                .font(.system(size: 12))
                .foregroundStyle(FumeColors.textPrimary)

            Text(role)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(FumeColors.accent)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(FumeColors.accent.opacity(0.1))
                .cornerRadius(8)

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func contributionsSection(_ space: KnowledgeSharingService.CollaborativeSpace) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "arrow.up.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(FumeColors.accent)

                Text("Recent Contributions (\(space.noteContributions.count))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FumeColors.textPrimary)

                Spacer()
            }

            if space.noteContributions.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "note.text")
                            .font(.system(size: 24))
                            .foregroundStyle(FumeColors.textSecondary.opacity(0.4))

                        Text("No contributions yet")
                            .font(.system(size: 11))
                            .foregroundStyle(FumeColors.textSecondary)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            } else {
                ForEach(space.noteContributions.prefix(5)) { contribution in
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 10))
                            .foregroundStyle(FumeColors.accent)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(contribution.contributionSummary)
                                .font(.system(size: 11))
                                .foregroundStyle(FumeColors.textPrimary)
                                .lineLimit(1)

                            Text("\(contribution.contributorName) • \(contribution.contributedAt.formatted(.relative(presentation: .named)))")
                                .font(.system(size: 9))
                                .foregroundStyle(FumeColors.textSecondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func synthesizeSection(_ space: KnowledgeSharingService.CollaborativeSpace) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 12))
                    .foregroundStyle(FumeColors.accent)

                Text("AI Synthesis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FumeColors.textPrimary)

                Spacer()

                Button {
                    Task { await synthesizeSpace(space) }
                } label: {
                    if isSynthesizing {
                        ProgressView()
                            .tint(FumeColors.accent)
                            .scaleEffect(0.7)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11))
                            Text("Synthesize")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                }
                .buttonStyle(.bordered)
                .tint(FumeColors.accent)
                .disabled(isSynthesizing || space.noteContributions.isEmpty)
            }

            Text("Get an AI-powered synthesis of all contributions in this space.")
                .font(.system(size: 10))
                .foregroundStyle(FumeColors.textSecondary)

            if showingSynthesized, let result = synthesisResult {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Synthesis")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(FumeColors.textSecondary)

                        Spacer()

                        Text(String(format: "%.0f%% confidence", result.confidence * 100))
                            .font(.system(size: 9))
                            .foregroundStyle(FumeColors.textSecondary)
                    }

                    Text(result.answer)
                        .font(.system(size: 12))
                        .foregroundStyle(FumeColors.textPrimary)
                        .textSelection(.enabled)
                }
                .padding()
                .background(FumeColors.surfaceRaised)
                .cornerRadius(10)
            }
        }
    }

    // MARK: - Actions

    private func loadSpaces() async {
        isLoading = true
        spaces = service.getSpaces()
        isLoading = false
    }

    private func createSpace() {
        let trimmedName = newSpaceName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        _ = service.createSpace(name: trimmedName)
        newSpaceName = ""
        showCreateSheet = false

        Task {
            await loadSpaces()
        }
    }

    private func inviteCollaborator(to space: KnowledgeSharingService.CollaborativeSpace) {
        let trimmed = inviteEmail.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        do {
            try service.inviteToSpace(spaceID: space.id, collaboratorID: trimmed)
            inviteEmail = ""
            if let updated = service.getSpaces().first(where: { $0.id == space.id }) {
                selectedSpace = updated
            }
        } catch {
            // Handle error silently
        }
    }

    private func synthesizeSpace(_ space: KnowledgeSharingService.CollaborativeSpace) async {
        isSynthesizing = true
        showingSynthesized = false

        do {
            synthesisResult = try await service.synthesizeSpace(space.id)
            showingSynthesized = true
        } catch {
            synthesisResult = KnowledgeSharingService.AIResponse(
                answer: "Failed to synthesize. Please try again.",
                sources: [],
                confidence: 0.0
            )
            showingSynthesized = true
        }

        isSynthesizing = false
    }
}
