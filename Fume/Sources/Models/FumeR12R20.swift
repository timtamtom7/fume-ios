import Foundation

// MARK: - Fume R12-R20: Social, Collaboration, Platform

// MARK: R12: Shared Libraries, Social Features, Collaboration

struct SharedLibrary: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var ownerID: String
    var memberIDs: [String]
    var noteIDs: [UUID]
    var permissions: Permissions
    var createdAt: Date
    var isPublic: Bool
    
    struct Permissions: Codable, Equatable {
        var canAddNotes: Bool
        var canRemoveNotes: Bool
        var canInviteMembers: Bool
        var canComment: Bool
        
        init(canAddNotes: Bool = true, canRemoveNotes: Bool = false, canInviteMembers: Bool = false, canComment: Bool = true) {
            self.canAddNotes = canAddNotes
            self.canRemoveNotes = canRemoveNotes
            self.canInviteMembers = canInviteMembers
            self.canComment = canComment
        }
    }
    
    init(id: UUID = UUID(), name: String, ownerID: String, memberIDs: [String] = [], noteIDs: [UUID] = [], permissions: Permissions = Permissions(), createdAt: Date = Date(), isPublic: Bool = false) {
        self.id = id
        self.name = name
        self.ownerID = ownerID
        self.memberIDs = memberIDs
        self.noteIDs = noteIDs
        self.permissions = permissions
        self.createdAt = createdAt
        self.isPublic = isPublic
    }
}

struct CommunityNote: Identifiable, Codable, Equatable {
    let id: UUID
    var noteID: UUID
    var authorID: String
    var authorName: String
    var title: String
    var summary: String
    var tags: [String]
    var likes: Int
    var commentCount: Int
    var views: Int
    var createdAt: Date
    var isPublished: Bool
    
    init(id: UUID = UUID(), noteID: UUID, authorID: String, authorName: String, title: String, summary: String = "", tags: [String] = [], likes: Int = 0, commentCount: Int = 0, views: Int = 0, createdAt: Date = Date(), isPublished: Bool = false) {
        self.id = id
        self.noteID = noteID
        self.authorID = authorID
        self.authorName = authorName
        self.title = title
        self.summary = summary
        self.tags = tags
        self.likes = likes
        self.commentCount = commentCount
        self.views = views
        self.createdAt = createdAt
        self.isPublished = isPublished
    }
}

struct Annotation: Identifiable, Codable, Equatable {
    let id: UUID
    var noteID: UUID
    var authorID: String
    var authorName: String
    var text: String
    var highlightRange: HighlightRange?
    var replyToAnnotationID: UUID?
    var createdAt: Date
    var likes: Int
    
    struct HighlightRange: Codable, Equatable {
        var startOffset: Int
        var endOffset: Int
        var highlightedText: String
    }
    
    init(id: UUID = UUID(), noteID: UUID, authorID: String, authorName: String, text: String, highlightRange: HighlightRange? = nil, replyToAnnotationID: UUID? = nil, createdAt: Date = Date(), likes: Int = 0) {
        self.id = id
        self.noteID = noteID
        self.authorID = authorID
        self.authorName = authorName
        self.text = text
        self.highlightRange = highlightRange
        self.replyToAnnotationID = replyToAnnotationID
        self.createdAt = createdAt
        self.likes = likes
    }
}

// MARK: R13: API, Developer Platform, Embeddings

struct FumeAPI: Codable, Equatable {
    var clientID: String
    var clientSecret: String
    var accessToken: String?
    var refreshToken: String?
    var expiresAt: Date?
    var tier: APITier
    
    enum APITier: String, Codable {
        case free = "Free"
        case pro = "Pro"
        case developer = "Developer"
    }
    
    init(clientID: String = UUID().uuidString, clientSecret: String = UUID().uuidString, accessToken: String? = nil, refreshToken: String? = nil, expiresAt: Date? = nil, tier: APITier = .free) {
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.tier = tier
    }
}

struct EmbeddingIndex: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var description: String
    var noteCount: Int
    var lastIndexedAt: Date
    var embeddingDimension: Int
    
    init(id: UUID = UUID(), name: String, description: String = "", noteCount: Int = 0, lastIndexedAt: Date = Date(), embeddingDimension: Int = 1536) {
        self.id = id
        self.name = name
        self.description = description
        self.noteCount = noteCount
        self.lastIndexedAt = lastIndexedAt
        self.embeddingDimension = embeddingDimension
    }
}

struct WebhookSubscription: Identifiable, Codable, Equatable {
    let id: UUID
    var callbackURL: String
    var events: [WebhookEvent]
    var secret: String
    var isActive: Bool
    
    enum WebhookEvent: String, Codable {
        case noteCreated = "note.created"
        case noteUpdated = "note.updated"
        case noteDeleted = "note.deleted"
        case tagAdded = "tag.added"
        case sharedWithUser = "library.shared_with_user"
    }
    
    init(id: UUID = UUID(), callbackURL: String, events: [WebhookEvent] = [], secret: String = UUID().uuidString, isActive: Bool = true) {
        self.id = id
        self.callbackURL = callbackURL
        self.events = events
        self.secret = secret
        self.isActive = isActive
    }
}

// MARK: R14: Obsidian Sync, Export, Markdown Improvements

struct ObsidianVault: Identifiable, Codable, Equatable {
    let id: UUID
    var vaultPath: String
    var vaultName: String
    var isSyncing: Bool
    var lastSyncAt: Date?
    var syncDirection: SyncDirection
    var linkedNoteIDs: [UUID]
    
    enum SyncDirection: String, Codable {
        case fumeToObsidian = "Fume → Obsidian"
        case obsidianToFume = "Obsidian → Fume"
        case bidirectional = "Bidirectional"
    }
    
    init(id: UUID = UUID(), vaultPath: String = "", vaultName: String, isSyncing: Bool = false, lastSyncAt: Date? = nil, syncDirection: SyncDirection = .bidirectional, linkedNoteIDs: [UUID] = []) {
        self.id = id
        self.vaultPath = vaultPath
        self.vaultName = vaultName
        self.isSyncing = isSyncing
        self.lastSyncAt = lastSyncAt
        self.syncDirection = syncDirection
        self.linkedNoteIDs = linkedNoteIDs
    }
}

struct ExportConfiguration: Identifiable, Codable, Equatable {
    let id: UUID
    var format: Format
    var includeMetadata: Bool
    var includeTags: Bool
    var includeAIAnnotations: Bool
    
    enum Format: String, Codable {
        case markdown = "Markdown"
        case html = "HTML"
        case pdf = "PDF"
        case json = "JSON"
        case epub = "EPUB"
        case notion = "Notion"
    }
    
    init(id: UUID = UUID(), format: Format, includeMetadata: Bool = true, includeTags: Bool = true, includeAIAnnotations: Bool = false) {
        self.id = id
        self.format = format
        self.includeMetadata = includeMetadata
        self.includeTags = includeTags
        self.includeAIAnnotations = includeAIAnnotations
    }
}

// MARK: R15: Mobile Optimizations, iPad Multitasking, Widgets

struct HomeScreenWidget: Identifiable, Codable, Equatable {
    let id: UUID
    var widgetKind: WidgetKind
    var displaySize: DisplaySize
    var refreshInterval: TimeInterval
    var lastRefreshedAt: Date
    
    enum WidgetKind: String, Codable {
        case recentNotes = "Recent Notes"
        case search = "Quick Search"
        case statistics = "Statistics"
        case featuredNote = "Featured Note"
        case todayNotes = "Today's Notes"
    }
    
    enum DisplaySize: String, Codable {
        case small, medium, large
    }
    
    init(id: UUID = UUID(), widgetKind: WidgetKind, displaySize: DisplaySize = .medium, refreshInterval: TimeInterval = 900, lastRefreshedAt: Date = Date()) {
        self.id = id
        self.widgetKind = widgetKind
        self.displaySize = displaySize
        self.refreshInterval = refreshInterval
        self.lastRefreshedAt = lastRefreshedAt
    }
}

struct SpotlightIndex: Codable, Equatable {
    var indexedNoteIDs: [UUID]
    var lastIndexedAt: Date
    var totalTokens: Int
    
    init(indexedNoteIDs: [UUID] = [], lastIndexedAt: Date = Date(), totalTokens: Int = 0) {
        self.indexedNoteIDs = indexedNoteIDs
        self.lastIndexedAt = lastIndexedAt
        self.totalTokens = totalTokens
    }
}

// MARK: R16: Subscription Business

struct FumeSubscriptionTier: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var displayName: String
    var monthlyPrice: Decimal
    var annualPrice: Decimal
    var lifetimePrice: Decimal
    var features: [String]
    var isMostPopular: Bool
    
    static let free = FumeSubscriptionTier(id: UUID(), name: "free", displayName: "Free", monthlyPrice: 0, annualPrice: 0, lifetimePrice: 0, features: ["50 notes", "Basic search", "3 collections"], isMostPopular: false)
    static let pro = FumeSubscriptionTier(id: UUID(), name: "pro", displayName: "Pro", monthlyPrice: 8.99, annualPrice: 89.99, lifetimePrice: 199, features: ["Unlimited notes", "AI search", "Unlimited collections", "Shared libraries", "API access"], isMostPopular: true)
    static let team = FumeSubscriptionTier(id: UUID(), name: "team", displayName: "Team", monthlyPrice: 14.99, annualPrice: 149.99, lifetimePrice: 0, features: ["Everything in Pro", "Team workspaces", "Admin controls", "Priority support"], isMostPopular: false)
}

// MARK: R17: i18n, Localization, International

struct SupportedLocale: Identifiable, Codable, Equatable {
    let id: UUID
    var code: String
    var displayName: String
    var nativeName: String
    var isRTL: Bool
    
    init(id: UUID = UUID(), code: String, displayName: String, nativeName: String, isRTL: Bool = false) {
        self.id = id
        self.code = code
        self.displayName = displayName
        self.nativeName = nativeName
        self.isRTL = isRTL
    }
    
    static let supported: [SupportedLocale] = [
        SupportedLocale(code: "en", displayName: "English", nativeName: "English"),
        SupportedLocale(code: "de", displayName: "German", nativeName: "Deutsch"),
        SupportedLocale(code: "fr", displayName: "French", nativeName: "Français"),
        SupportedLocale(code: "es", displayName: "Spanish", nativeName: "Español"),
        SupportedLocale(code: "zh-Hans", displayName: "Chinese (Simplified)", nativeName: "简体中文", isRTL: false),
        SupportedLocale(code: "ja", displayName: "Japanese", nativeName: "日本語"),
        SupportedLocale(code: "ko", displayName: "Korean", nativeName: "한국어"),
    ]
}

// MARK: R18: Vision, Long-Term Architecture, Awards

struct AwardSubmission: Identifiable, Codable, Equatable {
    let id: UUID
    var awardName: String
    var category: String
    var status: Status
    var submittedAt: Date
    
    enum Status: String, Codable {
        case draft, submitted, inReview, won, rejected
    }
    
    init(id: UUID = UUID(), awardName: String, category: String, status: Status = .draft, submittedAt: Date = Date()) {
        self.id = id
        self.awardName = awardName
        self.category = category
        self.status = status
        self.submittedAt = submittedAt
    }
}

struct TeamMember: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var role: String
    var email: String
    
    init(id: UUID = UUID(), name: String, role: String, email: String) {
        self.id = id
        self.name = name
        self.role = role
        self.email = email
    }
}

// MARK: R19: macOS App, Full Platform Parity

struct CrossPlatformDevice: Identifiable, Codable, Equatable {
    let id: UUID
    var deviceName: String
    var platform: Platform
    var lastSyncAt: Date
    var noteCount: Int
    var isPrimary: Bool
    
    enum Platform: String, Codable {
        case ios, macOS, web
    }
    
    init(id: UUID = UUID(), deviceName: String, platform: Platform, lastSyncAt: Date = Date(), noteCount: Int = 0, isPrimary: Bool = false) {
        self.id = id
        self.deviceName = deviceName
        self.platform = platform
        self.lastSyncAt = lastSyncAt
        self.noteCount = noteCount
        self.isPrimary = isPrimary
    }
}

// MARK: R20: Fume 3.0 Vision, Platform Ecosystem

struct VisionDocument: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var version: String
    var createdAt: Date
    
    init(id: UUID = UUID(), title: String, content: String, version: String = "3.0", createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.content = content
        self.version = version
        self.createdAt = createdAt
    }
}

struct PlatformIntegration: Identifiable, Codable, Equatable {
    let id: UUID
    var platform: Platform
    var integrationType: IntegrationType
    var isEnabled: Bool
    var config: [String: String]
    
    enum Platform: String, Codable {
        case obsidian = "Obsidian"
        case notion = "Notion"
        case appleNotes = "Apple Notes"
        case readwise = "Readwise"
        case kindle = "Kindle"
        case evernote = "Evernote"
    }
    
    enum IntegrationType: String, Codable {
        case sync = "Sync"
        case export = "Export"
        case import_ = "Import"
    }
    
    init(id: UUID = UUID(), platform: Platform, integrationType: IntegrationType, isEnabled: Bool = false, config: [String: String] = [:]) {
        self.id = id
        self.platform = platform
        self.integrationType = integrationType
        self.isEnabled = isEnabled
        self.config = config
    }
}
