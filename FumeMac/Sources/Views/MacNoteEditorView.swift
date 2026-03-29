import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers
import Speech

// MARK: - Mac Note Editor View

struct MacNoteEditorView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var content = ""
    @State private var selectedType: SourceType = .note
    @State private var urlInput = ""
    @State private var tags: [Tag] = []
    @State private var newTagName = ""
    @State private var showTagPicker = false

    @State private var selectedImageData: Data?
    @State private var showImagePicker = false

    @State private var isRecordingVoice = false
    @State private var voiceMemoURL: URL?
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer?

    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Source")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(FumeColors.textSecondary)

                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(FumeColors.accent)
                .disabled(title.isEmpty || content.isEmpty || isSaving)
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Type selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TYPE")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(FumeColors.textSecondary)

                        HStack(spacing: 8) {
                            ForEach([SourceType.note, .article, .voiceMemo, .image], id: \.self) { type in
                                Button {
                                    selectedType = type
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: type.icon)
                                            .font(.system(size: 11))
                                        Text(type.label)
                                            .font(.system(size: 12))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(selectedType == type ? FumeColors.accent.opacity(0.2) : FumeColors.surfaceRaised)
                                    .foregroundStyle(selectedType == type ? FumeColors.accent : FumeColors.textSecondary)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedType == type ? FumeColors.accent : Color.clear, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TITLE")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(FumeColors.textSecondary)

                        TextField("Enter title...", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15))
                            .padding(12)
                            .background(FumeColors.surfaceRaised)
                            .cornerRadius(10)
                    }

                    // Type-specific content
                    switch selectedType {
                    case .note:
                        noteContentEditor

                    case .article:
                        articleContentEditor

                    case .voiceMemo:
                        voiceMemoRecorder

                    case .image:
                        imagePickerSection

                    case .pdf:
                        EmptyView()
                    }

                    // Tags
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TAGS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(FumeColors.textSecondary)

                        FlowLayout(spacing: 6) {
                            ForEach(tags) { tag in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(hex: tag.colorHex))
                                        .frame(width: 6, height: 6)
                                    Text(tag.name)
                                        .font(.system(size: 11))
                                        .foregroundStyle(FumeColors.textPrimary)

                                    Button {
                                        tags.removeAll { $0.id == tag.id }
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundStyle(FumeColors.textSecondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(FumeColors.surfaceRaised)
                                .cornerRadius(12)
                            }

                            Button {
                                showTagPicker = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 10))
                                    Text("Add tag")
                                        .font(.system(size: 11))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .foregroundStyle(FumeColors.textSecondary)
                                .background(FumeColors.surfaceRaised.opacity(0.5))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .background(FumeColors.background)
        }
        .frame(width: 600, height: 600)
        .background(FumeColors.background)
        .sheet(isPresented: $showTagPicker) {
            TagPickerSheet(allTags: viewModel.allTags, selectedTags: $tags)
        }
    }

    // MARK: - Note Content Editor

    private var noteContentEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CONTENT")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(FumeColors.textSecondary)

            TextEditor(text: $content)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .foregroundStyle(FumeColors.textPrimary)
                .padding(12)
                .background(FumeColors.surfaceRaised)
                .cornerRadius(10)
                .frame(minHeight: 200)
        }
    }

    // MARK: - Article Content Editor

    private var articleContentEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("URL")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FumeColors.textSecondary)

                TextField("https://...", text: $urlInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(12)
                    .background(FumeColors.surfaceRaised)
                    .cornerRadius(10)

                if !urlInput.isEmpty, let url = URL(string: urlInput) {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "arrow.up.right.square")
                            Text("Open URL")
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(Color.blue)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("NOTES")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FumeColors.textSecondary)

                TextEditor(text: $content)
                    .font(.system(size: 14))
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(FumeColors.textPrimary)
                    .padding(12)
                    .background(FumeColors.surfaceRaised)
                    .cornerRadius(10)
                    .frame(minHeight: 150)
            }
        }
    }

    // MARK: - Voice Memo Recorder

    private var voiceMemoRecorder: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("VOICE MEMO")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(FumeColors.textSecondary)

            VStack(spacing: 16) {
                if let voiceURL = voiceMemoURL {
                    // Show recorded memo
                    HStack {
                        Image(systemName: "waveform")
                            .font(.system(size: 20))
                            .foregroundStyle(FumeColors.accent)

                        VStack(alignment: .leading) {
                            Text("Recording saved")
                                .font(.system(size: 13, weight: .medium))
                            Text(formatDuration(recordingDuration))
                                .font(.system(size: 11))
                                .foregroundStyle(FumeColors.textSecondary)
                        }

                        Spacer()

                        Button {
                            voiceMemoURL = nil
                            content = ""
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background(FumeColors.surfaceRaised)
                    .cornerRadius(10)
                } else {
                    // Recording UI
                    VStack(spacing: 12) {
                        Button {
                            if isRecordingVoice {
                                stopRecording()
                            } else {
                                startRecording()
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(isRecordingVoice ? Color.red.opacity(0.2) : FumeColors.accent.opacity(0.2))
                                    .frame(width: 80, height: 80)

                                Circle()
                                    .fill(isRecordingVoice ? Color.red : FumeColors.accent)
                                    .frame(width: isRecordingVoice ? 30 : 60, height: isRecordingVoice ? 30 : 60)
                                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isRecordingVoice)
                            }
                        }
                        .buttonStyle(.plain)

                        Text(isRecordingVoice ? "Tap to stop (\(formatDuration(recordingDuration)))" : "Tap to record")
                            .font(.system(size: 13))
                            .foregroundStyle(FumeColors.textSecondary)

                        Text("Speak your thoughts — Fume will transcribe and save it.")
                            .font(.system(size: 11))
                            .foregroundStyle(FumeColors.textSecondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(FumeColors.surfaceRaised)
                    .cornerRadius(10)
                }
            }

            if !content.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TRANSCRIPTION")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(FumeColors.textSecondary)

                    Text(content)
                        .font(.system(size: 13))
                        .foregroundStyle(FumeColors.textPrimary)
                        .padding(12)
                        .background(FumeColors.surfaceRaised)
                        .cornerRadius(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Image Picker

    private var imagePickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("IMAGE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(FumeColors.textSecondary)

            if let imageData = selectedImageData, let nsImage = NSImage(data: imageData) {
                VStack(spacing: 12) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(10)

                    HStack {
                        Button("Change") {
                            showImagePicker = true
                        }
                        .buttonStyle(.bordered)

                        Button(role: .destructive) {
                            selectedImageData = nil
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(FumeColors.surfaceRaised)
                .cornerRadius(10)
            } else {
                Button {
                    showImagePicker = true
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 32))
                            .foregroundStyle(FumeColors.textSecondary)
                        Text("Click to select an image")
                            .font(.system(size: 13))
                            .foregroundStyle(FumeColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                    .background(FumeColors.surfaceRaised)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .fileImporter(isPresented: $showImagePicker, allowedContentTypes: [.image]) { result in
            if case .success(let url) = result {
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: url) {
                        selectedImageData = data
                    }
                }
            }
        }
    }

    // MARK: - Save

    private func save() async {
        isSaving = true

        var thumbnailData: Data? = nil
        if selectedType == .image, let imgData = selectedImageData {
            thumbnailData = imgData
        }

        let source = Source(
            type: selectedType,
            title: title,
            content: content,
            url: selectedType == .article && !urlInput.isEmpty ? urlInput : nil,
            thumbnailData: thumbnailData,
            tagIDs: tags.map { $0.id }
        )

        let embedding = await EmbeddingService.shared.generateEmbedding(for: source.content)
        var sourceWithEmbedding = source
        sourceWithEmbedding.embedding = embedding

        do {
            try await DatabaseService.shared.insertSource(sourceWithEmbedding)
            await viewModel.loadSources()
            dismiss()
        } catch {
            print("Failed to save source: \(error)")
        }

        isSaving = false
    }

    // MARK: - Recording

    private func startRecording() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent("recording_\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.record()
            voiceMemoURL = audioURL
            isRecordingVoice = true
            recordingDuration = 0

            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                recordingDuration += 1
            }
        } catch {
            print("Recording error: \(error)")
        }
    }

    private func stopRecording() {
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecordingVoice = false

        // Transcribe
        if let url = voiceMemoURL {
            Task {
                do {
                    let transcription = try await SpeechService.shared.transcribe(audioURL: url)
                    await MainActor.run {
                        content = transcription
                    }
                } catch {
                    print("Transcription error: \(error)")
                    await MainActor.run {
                        content = "[Voice memo recorded — transcription unavailable]"
                    }
                }
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Tag Picker Sheet

struct TagPickerSheet: View {
    let allTags: [Tag]
    @Binding var selectedTags: [Tag]
    @Environment(\.dismiss) private var dismiss

    @State private var newTagName = ""
    @State private var selectedColor: TagColor = .amber

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Select Tags")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("Done") { dismiss() }
            }

            Divider()

            // New tag
            HStack {
                TextField("New tag name...", text: $newTagName)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(FumeColors.surfaceRaised)
                    .cornerRadius(8)

                HStack(spacing: 4) {
                    ForEach(TagColor.allCases, id: \.self) { color in
                        Circle()
                            .fill(Color(hex: color.rawValue))
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(selectedColor == color ? Color.white : Color.clear, lineWidth: 1)
                            )
                            .onTapGesture { selectedColor = color }
                    }
                }

                Button {
                    if !newTagName.isEmpty {
                        let tag = Tag(name: newTagName, colorHex: selectedColor.rawValue)
                        if !allTags.contains(where: { $0.name == tag.name }) {
                            selectedTags.append(tag)
                        }
                        newTagName = ""
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(FumeColors.accent)
                }
                .buttonStyle(.plain)
            }

            // Existing tags
            ScrollView {
                FlowLayout(spacing: 6) {
                    ForEach(allTags) { tag in
                        let isSelected = selectedTags.contains { $0.id == tag.id }
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: tag.colorHex))
                                .frame(width: 6, height: 6)
                            Text(tag.name)
                                .font(.system(size: 12))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isSelected ? FumeColors.accent.opacity(0.2) : FumeColors.surfaceRaised)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isSelected ? FumeColors.accent : Color.clear, lineWidth: 1)
                        )
                        .onTapGesture {
                            if isSelected {
                                selectedTags.removeAll { $0.id == tag.id }
                            } else {
                                selectedTags.append(tag)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .frame(width: 350, height: 350)
        .background(FumeColors.background)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}
