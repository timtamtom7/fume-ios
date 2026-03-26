import Foundation
import Combine

/// Fume R12-R20 Service
final class FumeR12R20Service: ObservableObject, @unchecked Sendable {
    static let shared = FumeR12R20Service()
    
    // R12
    @Published var sharedLibraries: [SharedLibrary] = []
    @Published var communityNotes: [CommunityNote] = []
    @Published var annotations: [Annotation] = []
    
    // R13
    @Published var apiCredentials: FumeAPI?
    @Published var embeddingIndexes: [EmbeddingIndex] = []
    @Published var webhooks: [WebhookSubscription] = []
    
    // R14
    @Published var obsidianVaults: [ObsidianVault] = []
    @Published var exportFormats: [ExportConfiguration] = []
    
    // R15
    @Published var homeScreenWidgets: [HomeScreenWidget] = []
    @Published var spotlightIndex: SpotlightIndex = SpotlightIndex()
    
    // R16
    @Published var currentTier: FumeSubscriptionTier = .free
    
    // R17
    @Published var supportedLocales: [SupportedLocale] = SupportedLocale.supported
    @Published var currentLocale: SupportedLocale = SupportedLocale.supported[0]
    
    // R18
    @Published var awardSubmissions: [AwardSubmission] = []
    @Published var teamMembers: [TeamMember] = []
    
    // R19
    @Published var crossPlatformDevices: [CrossPlatformDevice] = []
    
    // R20
    @Published var visionDocument: VisionDocument?
    @Published var platformIntegrations: [PlatformIntegration] = []
    
    private let userDefaults = UserDefaults.standard
    
    private init() { loadFromDisk() }
    
    // MARK: - R12: Social
    
    func createSharedLibrary(name: String, ownerID: String) -> SharedLibrary {
        let library = SharedLibrary(name: name, ownerID: ownerID)
        sharedLibraries.append(library)
        saveToDisk()
        return library
    }
    
    func inviteToLibrary(_ libraryID: UUID, memberID: String) {
        guard let index = sharedLibraries.firstIndex(where: { $0.id == libraryID }) else { return }
        if !sharedLibraries[index].memberIDs.contains(memberID) {
            sharedLibraries[index].memberIDs.append(memberID)
        }
        saveToDisk()
    }
    
    func publishToCommunity(noteID: UUID, authorID: String, authorName: String, title: String, summary: String, tags: [String]) -> CommunityNote {
        let note = CommunityNote(noteID: noteID, authorID: authorID, authorName: authorName, title: title, summary: summary, tags: tags, isPublished: true)
        communityNotes.append(note)
        saveToDisk()
        return note
    }
    
    func addAnnotation(noteID: UUID, authorID: String, authorName: String, text: String, highlightRange: Annotation.HighlightRange? = nil) -> Annotation {
        let annotation = Annotation(noteID: noteID, authorID: authorID, authorName: authorName, text: text, highlightRange: highlightRange)
        annotations.append(annotation)
        saveToDisk()
        return annotation
    }
    
    // MARK: - R13: API
    
    func registerAPI(tier: FumeAPI.APITier) -> FumeAPI {
        let api = FumeAPI(tier: tier)
        apiCredentials = api
        saveToDisk()
        return api
    }
    
    func createEmbeddingIndex(name: String) -> EmbeddingIndex {
        let index = EmbeddingIndex(name: name)
        embeddingIndexes.append(index)
        saveToDisk()
        return index
    }
    
    func createWebhook(callbackURL: String, events: [WebhookSubscription.WebhookEvent]) -> WebhookSubscription {
        let webhook = WebhookSubscription(callbackURL: callbackURL, events: events)
        webhooks.append(webhook)
        saveToDisk()
        return webhook
    }
    
    // MARK: - R14: Obsidian
    
    func addObsidianVault(name: String, vaultPath: String) -> ObsidianVault {
        let vault = ObsidianVault(vaultPath: vaultPath, vaultName: name)
        obsidianVaults.append(vault)
        saveToDisk()
        return vault
    }
    
    func syncObsidianVault(_ vaultID: UUID) async {
        guard let index = obsidianVaults.firstIndex(where: { $0.id == vaultID }) else { return }
        await MainActor.run {
            obsidianVaults[index].isSyncing = true
        }
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        await MainActor.run {
            obsidianVaults[index].isSyncing = false
            obsidianVaults[index].lastSyncAt = Date()
            saveToDisk()
        }
    }
    
    // MARK: - R15: Widgets
    
    func createWidget(kind: HomeScreenWidget.WidgetKind, size: HomeScreenWidget.DisplaySize) -> HomeScreenWidget {
        let widget = HomeScreenWidget(widgetKind: kind, displaySize: size)
        homeScreenWidgets.append(widget)
        saveToDisk()
        return widget
    }
    
    // MARK: - R16: Subscription
    
    func subscribe(to tier: FumeSubscriptionTier) async -> Bool {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        await MainActor.run {
            currentTier = tier
            saveToDisk()
        }
        return true
    }
    
    // MARK: - R18: Awards
    
    func submitAward(name: String, category: String) -> AwardSubmission {
        let award = AwardSubmission(awardName: name, category: category)
        awardSubmissions.append(award)
        saveToDisk()
        return award
    }
    
    // MARK: - R20: Vision
    
    func setVisionDocument(title: String, content: String) -> VisionDocument {
        let doc = VisionDocument(title: title, content: content)
        visionDocument = doc
        saveToDisk()
        return doc
    }
    
    func enablePlatformIntegration(platform: PlatformIntegration.Platform, integrationType: PlatformIntegration.IntegrationType) -> PlatformIntegration {
        let integration = PlatformIntegration(platform: platform, integrationType: integrationType, isEnabled: true)
        platformIntegrations.append(integration)
        saveToDisk()
        return integration
    }
    
    // MARK: - Persistence
    
    private func saveToDisk() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(sharedLibraries) { userDefaults.set(data, forKey: "fume_shared_libraries") }
        if let data = try? encoder.encode(communityNotes) { userDefaults.set(data, forKey: "fume_community_notes") }
        if let data = try? encoder.encode(annotations) { userDefaults.set(data, forKey: "fume_annotations") }
        if let data = try? encoder.encode(apiCredentials) { userDefaults.set(data, forKey: "fume_api") }
        if let data = try? encoder.encode(embeddingIndexes) { userDefaults.set(data, forKey: "fume_embedding_indexes") }
        if let data = try? encoder.encode(webhooks) { userDefaults.set(data, forKey: "fume_webhooks") }
        if let data = try? encoder.encode(obsidianVaults) { userDefaults.set(data, forKey: "fume_obsidian_vaults") }
        if let data = try? encoder.encode(homeScreenWidgets) { userDefaults.set(data, forKey: "fume_widgets") }
        if let data = try? encoder.encode(crossPlatformDevices) { userDefaults.set(data, forKey: "fume_devices") }
        if let data = try? encoder.encode(awardSubmissions) { userDefaults.set(data, forKey: "fume_awards") }
        if let data = try? encoder.encode(visionDocument) { userDefaults.set(data, forKey: "fume_vision") }
        if let data = try? encoder.encode(platformIntegrations) { userDefaults.set(data, forKey: "fume_platform_integrations") }
    }
    
    private func loadFromDisk() {
        let decoder = JSONDecoder()
        if let data = userDefaults.data(forKey: "fume_shared_libraries"),
           let decoded = try? decoder.decode([SharedLibrary].self, from: data) { sharedLibraries = decoded }
        if let data = userDefaults.data(forKey: "fume_community_notes"),
           let decoded = try? decoder.decode([CommunityNote].self, from: data) { communityNotes = decoded }
        if let data = userDefaults.data(forKey: "fume_annotations"),
           let decoded = try? decoder.decode([Annotation].self, from: data) { annotations = decoded }
        if let data = userDefaults.data(forKey: "fume_api"),
           let decoded = try? decoder.decode(FumeAPI.self, from: data) { apiCredentials = decoded }
        if let data = userDefaults.data(forKey: "fume_embedding_indexes"),
           let decoded = try? decoder.decode([EmbeddingIndex].self, from: data) { embeddingIndexes = decoded }
        if let data = userDefaults.data(forKey: "fume_webhooks"),
           let decoded = try? decoder.decode([WebhookSubscription].self, from: data) { webhooks = decoded }
        if let data = userDefaults.data(forKey: "fume_obsidian_vaults"),
           let decoded = try? decoder.decode([ObsidianVault].self, from: data) { obsidianVaults = decoded }
        if let data = userDefaults.data(forKey: "fume_widgets"),
           let decoded = try? decoder.decode([HomeScreenWidget].self, from: data) { homeScreenWidgets = decoded }
        if let data = userDefaults.data(forKey: "fume_devices"),
           let decoded = try? decoder.decode([CrossPlatformDevice].self, from: data) { crossPlatformDevices = decoded }
        if let data = userDefaults.data(forKey: "fume_awards"),
           let decoded = try? decoder.decode([AwardSubmission].self, from: data) { awardSubmissions = decoded }
        if let data = userDefaults.data(forKey: "fume_vision"),
           let decoded = try? decoder.decode(VisionDocument.self, from: data) { visionDocument = decoded }
        if let data = userDefaults.data(forKey: "fume_platform_integrations"),
           let decoded = try? decoder.decode([PlatformIntegration].self, from: data) { platformIntegrations = decoded }
    }
}
