import SwiftUI

struct PricingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTier: SubscriptionTier = .free
    @State private var showUpgradeConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                FumeColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Choose your plan")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(FumeColors.textPrimary)

                            Text("Start free. Upgrade when you're ready.")
                                .font(.system(size: 15))
                                .foregroundStyle(FumeColors.textSecondary)
                        }
                        .padding(.top, 8)

                        // Tier Cards
                        VStack(spacing: 16) {
                            PricingTierCard(
                                tier: .free,
                                isSelected: selectedTier == .free,
                                onSelect: { selectedTier = .free }
                            )

                            PricingTierCard(
                                tier: .pro,
                                isSelected: selectedTier == .pro,
                                onSelect: { selectedTier = .pro }
                            )

                            PricingTierCard(
                                tier: .archive,
                                isSelected: selectedTier == .archive,
                                onSelect: { selectedTier = .archive }
                            )
                        }

                        // Feature comparison
                        featureComparison

                        // CTA
                        if selectedTier != .free {
                            Button {
                                FumeHaptic.medium()
                                showUpgradeConfirm = true
                            } label: {
                                Text(upgradeButtonTitle)
                                    .font(.system(size: FumeTokens.fontSizeTitle, weight: .semibold))
                                    .foregroundStyle(FumeColors.background)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        Capsule()
                                            .fill(FumeColors.accent)
                                    )
                            }
                            .accessibilityLabel("Upgrade to \(selectedTier.name)")
                        }

                        // Privacy note
                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 12))
                            Text("All plans include end-to-end on-device processing. No cloud. No data collection.")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(FumeColors.textSecondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle("Pricing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(FumeColors.accent)
                }
            }
            .confirmationDialog(
                "Upgrade to \(upgradeButtonTitle)?",
                isPresented: $showUpgradeConfirm,
                titleVisibility: .visible
            ) {
                Button("Upgrade", role: .none) {
                    // In production: trigger StoreKit subscription flow
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will open the App Store subscription flow. Cancel anytime.")
            }
        }
    }

    private var upgradeButtonTitle: String {
        switch selectedTier {
        case .pro: return "Upgrade to Pro — $9.99/mo"
        case .archive: return "Upgrade to Archive — $19.99/mo"
        case .free: return ""
        }
    }

    private var featureComparison: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Feature")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FumeColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(SubscriptionTier.allCases, id: \.self) { tier in
                    Text(tier == .free ? "Free" : (tier == .pro ? "Pro" : "Archive"))
                        .font(.system(size: FumeTokens.fontSizeCaption2, weight: .medium))
                        .foregroundStyle(tier == selectedTier ? FumeColors.accent : FumeColors.textSecondary)
                        .frame(width: 60)
                }
            }

            Divider()
                .background(FumeColors.divider)

            ForEach(featureRows, id: \.0) { row in
                featureRow(label: row.0, values: row.1)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: FumeTokens.cornerRadiusLarge)
                .fill(FumeColors.glassOverlay)
                .overlay(
                    RoundedRectangle(cornerRadius: FumeTokens.cornerRadiusLarge)
                        .stroke(FumeColors.border, lineWidth: 0.5)
                )
        )
    }

    private var featureRows: [(String, [(SubscriptionTier, String)])] {
        [
            ("Sources", [(.free, "50"), (.pro, "Unlimited"), (.archive, "Unlimited")]),
            ("Search", [(.free, "Basic"), (.pro, "Semantic"), (.archive, "Semantic")]),
            ("Voice memos", [(.free, "—"), (.pro, "✓"), (.archive, "✓")]),
            ("PDF import", [(.free, "—"), (.pro, "✓"), (.archive, "✓")]),
            ("AI insights", [(.free, "—"), (.pro, "—"), (.archive, "✓")]),
            ("Cross-note links", [(.free, "—"), (.pro, "—"), (.archive, "✓")]),
            ("Export", [(.free, "—"), (.pro, "—"), (.archive, "Obsidian\nNotion")]),
        ]
    }

    private func featureRow(label: String, values: [(SubscriptionTier, String)]) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(FumeColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(values, id: \.0) { tier, value in
                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(tier == selectedTier ? FumeColors.textPrimary : FumeColors.textSecondary)
                    .frame(width: 60)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Subscription Tier

enum SubscriptionTier: String, CaseIterable {
    case free
    case pro
    case archive

    var name: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .archive: return "Archive"
        }
    }

    var price: String {
        switch self {
        case .free: return "Free"
        case .pro: return "$9.99/mo"
        case .archive: return "$19.99/mo"
        }
    }

    var tagline: String {
        switch self {
        case .free: return "Start building your knowledge base"
        case .pro: return "For power users who think deeply"
        case .archive: return "Maximum intelligence, full export"
        }
    }

    var features: [String] {
        switch self {
        case .free:
            return [
                "50 sources",
                "Basic keyword search",
                "Add notes and articles",
            ]
        case .pro:
            return [
                "Unlimited sources",
                "Semantic search",
                "Voice memo transcription",
                "PDF import & OCR",
            ]
        case .archive:
            return [
                "Everything in Pro",
                "Advanced AI insights",
                "Cross-note connections",
                "Export to Obsidian & Notion",
            ]
        }
    }
}

// MARK: - Pricing Tier Card

struct PricingTierCard: View {
    let tier: SubscriptionTier
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: {
            FumeHaptic.selection()
            onSelect()
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(tier.name)
                                .font(.system(size: FumeTokens.fontSizeTitle, weight: .bold))
                                .foregroundStyle(tier == .free ? FumeColors.textPrimary : FumeColors.accent)

                            if tier != .free {
                                Text(tier.price)
                                    .font(.system(size: FumeTokens.fontSizeBodySmall, weight: .medium))
                                    .foregroundStyle(FumeColors.textSecondary)
                            }
                        }

                        Text(tier.tagline)
                            .font(.system(size: FumeTokens.fontSizeCaption))
                            .foregroundStyle(FumeColors.textSecondary)
                    }

                    Spacer()

                    // Selection indicator
                    ZStack {
                        Circle()
                            .stroke(isSelected ? FumeColors.accent : FumeColors.border, lineWidth: 2)
                            .frame(width: 24, height: 24)

                        if isSelected {
                            Circle()
                                .fill(FumeColors.accent)
                                .frame(width: 14, height: 14)
                        }
                    }
                }

                Divider()
                    .background(FumeColors.divider)

                // Features
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(tier.features, id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: FumeTokens.fontSizeCaption2, weight: .bold))
                                .foregroundStyle(tier == .free ? FumeColors.textSecondary : FumeColors.accent)

                            Text(feature)
                                .font(.system(size: 13))
                                .foregroundStyle(FumeColors.textSecondary)
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: FumeTokens.cornerRadiusLarge)
                    .fill(isSelected ? FumeColors.sourceHighlight : FumeColors.glassOverlay)
                    .overlay(
                        RoundedRectangle(cornerRadius: FumeTokens.cornerRadiusLarge)
                            .stroke(isSelected ? FumeColors.accent : FumeColors.border, lineWidth: isSelected ? 1.5 : 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tier.name) plan: \(tier.tagline)")
    }
}
