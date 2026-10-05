# Fume

A clip-and-analyse app — capture content, then interrogate it with AI.

## What it does

- Clip content
- AI query and analysis
- embeddings
- Obsidian sync

## Targets

- iOS with Mac and widget companions

## Structure

Key types:

- ``EmbeddingService``
- ``AIQueryService``
- ``VisionService``
- ``ObsidianSyncService``
- ``SpeechService``
- ``FileImportService``
- ``URLFetchService``

Notable for syncing to Obsidian — treating a Markdown vault as a first-class backend.

## Status

Apple-platform experiment built to explore what an AI coding agent could produce for a native app. Not actively maintained.

Xcode projects here were generated with XcodeGen (`project.yml`) unless noted; open the `.xcodeproj` directly.
