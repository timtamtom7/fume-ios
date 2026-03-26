import Foundation

/// Real example content used throughout the app.
/// No generic placeholder copy — everything feels genuine.
enum RealContent {

    /// Helper to safely compute a past date. Returns Date() if calculation fails (should never happen with positive day offsets from Date()).
    private static func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -abs(days), to: Date()) ?? Date()
    }

    // MARK: - Example Queries

    /// Things users would actually ask their second brain
    static let exampleQueries: [String] = [
        "What did I read about local AI models?",
        "Show me notes from my trip to Barcelona",
        "What were the key points from the last book I read?",
        "Did I save any articles about Swift testing?",
        "What did I write about attention mechanisms?",
        "Find my notes on the project kickoff meeting",
        "What articles did I save about sleep research?",
        "Show me everything I have on keyboard shortcuts",
        "What did I jot down about the design system?",
        "Find notes about my conversations with Marco",
    ]

    /// Short prompt-style queries for UI demos
    static let demoQueries: [String] = [
        "What did I read about local AI?",
        "Show me my notes on Swift concurrency",
        "Articles about productivity I saved",
    ]

    // MARK: - Example Sources (for demo/seed data)

    static let demoSources: [Source] = [
        Source(
            type: .note,
            title: "Thoughts on on-device AI",
            content: """
            Apple running LLMs locally on the Neural Engine is a genuine shift. I tried the CoreML text generation model on my MacBook Pro and it's surprisingly usable — 30 tokens per second on the M3 chip. No cloud latency, no data leaving the machine.

            The key insight is that quantization matters a lot for on-device. A 4-bit quantized model at 2GB runs much faster than a 16-bit model at 8GB, even on Apple Silicon with its massive memory bandwidth. I should explore this more for the fume project.
            """,
            createdAt: daysAgo(3)
        ),
        Source(
            type: .article,
            title: "How Neural Networks Learn — colah's blog",
            content: """
            This is one of the best visual explanations of backpropagation I've found. The key points:

            1. Neural networks learn by adjusting weights to minimize a loss function
            2. Gradient descent walks downhill on the error surface
            3. Backpropagation efficiently computes gradients using the chain rule

            What I found most useful was the geometric interpretation — each weight adjustment moves the decision boundary closer to correctly classifying the training data. The interactive diagrams really helped.

            Saved this because the explanation of the chain rule in the context of neural networks is the clearest I've encountered.
            """,
            url: "https://colah.github.io/posts/2015-08-Backprop/",
            createdAt: daysAgo(7)
        ),
        Source(
            type: .note,
            title: "Swift Testing talk notes",
            content: """
            WWDC session on the new Testing framework was solid. Main takeaways:

            - @Test functions replace XCTest methods, more declarative
            - #expect macro is way cleaner than XCTAssert for complex assertions
            - Test plans let you parameterize tests across different configurations
            - The macro-based test doubles (@MainActor, isolation) solve real pain points

            The performance improvements are real too — parallel test execution by default. I should migrate fume's tests to the new framework.
            """,
            createdAt: daysAgo(12)
        ),
        Source(
            type: .voiceMemo,
            title: "Voice Memo — Project ideas",
            content: """
            Quick thought about fume — I want to add a feature where you can ask follow-up questions on the same thread. Like, start with a broad query, then narrow it down with follow-ups. The context would carry over.

            Also thinking about the export feature. Obsidian format would just be markdown files. Notion would need their API. The challenge is maintaining links between notes when you export — cross-note connections shouldn't break.

            Another idea: voice query input. Instead of typing, just ask your question out loud. The speech recognizer transcribes it, then feeds it to the query engine.
            """,
            createdAt: daysAgo(2)
        ),
        Source(
            type: .note,
            title: "Book: Thinking in Systems — Donella Meadows",
            content: """
            The core insight from this book is that systems often have counterintuitive behaviors because we're trained to think linearly while systems are inherently nonlinear.

            Key concepts:
            - Stock: anything that accumulates (knowledge, in fume's case)
            - Flow: rate of change (adding notes vs forgetting)
            - Feedback loops: balancing (tries to stabilize) and reinforcing (amplifies)
            - Delays: cause oscillations when the system reacts too slowly

            The implication for fume: the more notes you add, the more valuable the system becomes (reinforcing loop). But only if the quality of connections keeps pace.
            """,
            createdAt: daysAgo(20)
        ),
    ]

    // MARK: - Onboarding Example Query

    static let onboardingQueryExample = "What did I read about local AI last month?"

    // MARK: - App Description (App Store)

    static let appStoreDescription = """
    Fume is your second brain — entirely local, entirely private.

    Dump notes, articles, voice memos, and images into one place. Then ask Fume anything about what you've saved. It searches your knowledge base and answers from your own notes.

    **How it works**
    Add content in seconds — type a note, paste an article URL, record a thought, photograph a document. Fume stores everything on your device and builds a searchable knowledge base from your own information.

    Ask questions in plain language. Fume semantically searches across all your sources and returns answers with citations back to the original content.

    **Privacy first**
    Everything runs on-device using Apple's Neural Engine. Your data never leaves your phone. No cloud. No subscriptions. No data collection.

    **Pro ($9.99/month)**
    — Unlimited sources
    — Semantic search (understands meaning, not just keywords)
    — Voice memo transcription
    — PDF import with OCR

    **Archive ($19.99/month)**
    — Everything in Pro
    — Advanced AI insights and connections
    — Cross-note relationships
    — Export to Obsidian and Notion
    """

    static let appStoreDescriptionShort = """
    Fume is your second brain — entirely local, entirely private. Add notes, articles, voice memos, and images. Ask questions in plain language. Everything runs on-device. No cloud. No data collection.
    """

    static let appStoreKeywords: [String] = [
        "second brain",
        "personal knowledge base",
        "local AI",
        "notes app",
        "semantic search",
        "voice memos",
        "offline notes",
        "private notes",
        "knowledge management",
        "ai notes",
        "local LLM",
        "article reader",
        "PDF OCR",
        "obsidian alternative",
        "note taking",
    ]
}

// MARK: - App Store Metadata

struct AppStoreMetadata {
    static let name = "Fume"
    static let subtitle = "Your second brain, on-device"
    static let category = "Productivity"
    static let primaryCategory = "Productivity"
    static let secondaryCategory = "Utilities"

    static let versionHistory: [String] = [
        "1.0.0 — Initial release"
    ]
}
