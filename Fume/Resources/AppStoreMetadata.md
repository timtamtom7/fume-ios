# Fume — App Store Assets

## App Icon Concept

**Design:** A stylized brain formed from overlapping translucent amber circles against a dark `#0a0a0b` background. Subtle neural connection lines emanate from the center, suggesting thought and interconnection.

**Visual elements:**
- Primary shape: Abstract brain silhouette in amber gradient (`#f59e0b` → `#d97706`)
- Secondary: Translucent circles suggesting neural clusters
- Glow: Soft amber radial glow at center
- Text: None (icon only)

**In code (SF Symbols fallback):**
```swift
Image(systemName: "brain.head.profile")
    .foregroundStyle(
        LinearGradient(
            colors: [FumeColors.accent, FumeColors.accentDim],
            startPoint: .top,
            endPoint: .bottom
        )
    )
```

## App Description

### Short Description (170 chars)
> Fume: Your second brain, entirely on-device. Private, fast, local AI search across your notes, articles, and voice memos.

### Full Description

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

### Features List
- Add notes, articles, voice memos, images, and PDFs
- Ask questions in natural language
- On-device semantic search
- Voice memo transcription
- PDF OCR import
- Dark, intelligent interface
- All data stays on your device
- No account required

## Keywords

```
second brain, personal knowledge base, local AI, notes app,
semantic search, voice memos, offline notes, private notes,
knowledge management, ai notes, local LLM, article reader,
PDF OCR, obsidian alternative, note taking, productivity,
memory, neural, brain, mind, ideas
```

## Screenshots Concept

### Screen 1 — Query (dark)
Dark background. Top: "Fume" nav bar with + button. Center: Query input field "Ask anything from your notes..." with amber send button. Below: Response card showing AI answer with source citations.

### Screen 2 — Library (dark)
Dark background. Top: "Library" nav bar with search bar. Grid of source cards showing notes, articles, voice memos, images. Filter chips at top: All, Note, Article, Voice, Image.

### Screen 3 — Add Content (dark)
Sheet with 4 tabs: Note, URL, Voice, Image. Note tab shown: title field + large text editor.

### Pricing Screen (dark)
3 tier cards: Free (50 sources), Pro ($9.99/mo, unlimited, semantic), Archive ($19.99/mo, advanced AI, export).

## Privacy Policy Summary

Fume processes all data locally on your device. No data is transmitted to external servers. No user accounts required. No analytics or tracking. All source content and embeddings remain on-device.

## Category

**Primary:** Productivity
**Secondary:** Utilities

## Age Rating

4+ (all ages)
