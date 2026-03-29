# FumeMac — Launch Checklist

## Pre-Launch (R13 — Current)

### Marketing & Listing
- [x] App Store listing content created (`Marketing/APPSTORE.md`)
- [ ] App Store Connect metadata entered (title, description, keywords, screenshots)
- [ ] Screenshots designed and uploaded (4+ screenshots)
- [ ] Category selected: Productivity (primary), Utilities (secondary)
- [ ] Age rating set: 4+
- [ ] Privacy policy URL added (if applicable)
- [ ] Pricing configured (Free / Pro $9.99 / Archive $19.99)

### Build & Code Signing
- [x] XcodeGen project generated
- [x] Release build succeeds (`xcodebuild -configuration Release`)
- [ ] Code signing configured (Apple Developer account)
- [ ] App Store Connect app record created
- [ ] Bundle identifier registered: `com.fume.mac`
- [ ] App Sandbox enabled (required for Mac App Store)
- [ ] Hardened Runtime enabled
- [ ] Notarization successful

### Accessibility (R13)
- [x] VoiceOver labels on all interactive views
- [x] Dynamic Type support (scaled fonts via `.font(.system(size:))`)
- [x] All semantic colors defined in `FumeColors` (no hardcoded system colors except type-specific)
- [ ] Accessibility audit run with VoiceOver (full pass)
- [ ] Keyboard navigation tested (Tab, Enter, Escape)

### Offline-First Verification (R13)
- [x] Core features verified without network:
  - [x] Note creation and storage (SQLite)
  - [x] Library browsing and search
  - [x] AI chat (NaturalLanguage framework — no external calls)
  - [x] Voice memo recording (AVFoundation + Speech — no external calls)
  - [x] Image import (local file only)
  - [x] PDF import (Vision framework — no external calls)
  - [x] Export (JSON/TXT/Markdown — local file save)
- [x] No external API calls detected in codebase
- [x] All AI features use on-device Apple frameworks only

### Functionality
- [ ] All source types work: Note, Article, Voice Memo, Image, PDF
- [ ] Search returns relevant results
- [ ] AI chat returns context-grounded answers
- [ ] Export produces valid files
- [ ] Settings stats are accurate
- [ ] Clear all data works correctly
- [ ] Context menu actions work (Ask AI, Delete)
- [ ] Sheet presentation (Add, Settings) works
- [ ] Empty states display correctly
- [ ] Error states display correctly

### UI/UX
- [ ] Three-column layout renders correctly at minimum size (900×500)
- [ ] Menu bar extra (status item) works
- [ ] Keyboard shortcuts work (if any)
- [ ] Dark theme consistent across all views
- [ ] Animations are smooth (no jank on 60fps)
- [ ] Empty detail pane shows correct placeholder

### Data & Storage
- [ ] SQLite database created on first launch
- [ ] Sources persist after app restart
- [ ] Embeddings generated and stored correctly
- [ ] Thumbnails stored for images
- [ ] Voice recordings saved and retrievable
- [ ] Tags stored and displayed correctly

### Performance
- [ ] App launches in < 2 seconds on M1
- [ ] Library loads 1000+ sources without lag
- [ ] AI chat responds within 1 second for local queries
- [ ] No memory leaks after extended use

---

## Launch Day
- [ ] Build uploaded to App Store Connect
- [ ] TestFlight beta created (optional but recommended)
- [ ] App Store review submitted
- [ ] Release notes written
- [ ] Social media / announcements ready
- [ ] Support channel configured (email or link)

---

## Post-Launch
- [ ] Monitor App Store reviews
- [ ] Monitor crash reports (Xcode Cloud / Firebase Crashlytics optional)
- [ ] Gather user feedback
- [ ] Plan R14 iteration

---

## Known Issues / Tech Debt

- Collaborative space view (`MacCollaborativeSpaceView`) is a stub — not functional
- Shared pages view (`MacSharedPagesView`) is a stub — not functional
- Menu bar extra (`FumeMenuBar`) is a stub — shows placeholder window
- PDF type selectable in editor but PDF-specific import UI not fully implemented
- No push notifications or CloudKit sync (by design — privacy-first)
- No i18n / localization (English only at launch)

---

*Last updated: R13*
