import SwiftUI
import Combine
import UIKit
import PhotosUI

@MainActor
final class AddContentViewModel: ObservableObject {
    @Published var noteText: String = ""
    @Published var noteTitle: String = ""
    @Published var urlText: String = ""
    @Published var isProcessing: Bool = false
    @Published var processingMessage: String = ""
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var didSave: Bool = false

    // Voice memo
    @Published var isRecording: Bool = false
    @Published var recordingTranscript: String = ""
    @Published var hasRecordingPermission: Bool = false

    // Camera/Photo
    @Published var capturedImage: UIImage?
    @Published var recognizedText: String = ""

    private let speechService = SpeechService.shared
    private let visionService = VisionService.shared
    private let urlFetchService = URLFetchService.shared
    private let embeddingService = EmbeddingService.shared

    private var liveTranscriptionTask: Task<Void, Never>?
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?

    init() {
        Task {
            hasRecordingPermission = await speechService.requestAuthorization()
        }
    }

    // MARK: - Note
    func saveNote() async {
        guard !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isProcessing = true
        processingMessage = "Embedding note..."

        let title = noteTitle.isEmpty ? "Note \(formattedDate())" : noteTitle
        let content = noteText.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            let embedding = await embeddingService.generateEmbedding(for: content)

            let source = Source(
                type: .note,
                title: title,
                content: content,
                embedding: embedding
            )

            do {
                try await DatabaseService.shared.insertSource(source)
                didSave = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }

            isProcessing = false
            clearNoteFields()
        }
    }

    // MARK: - URL
    func saveURL() async {
        let urlString = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlString.isEmpty, URL(string: urlString) != nil else { return }

        isProcessing = true
        processingMessage = "Fetching article..."

        do {
            let article = try await urlFetchService.fetchArticle(from: urlString)
            processingMessage = "Embedding article..."

            let embedding = await embeddingService.generateEmbedding(for: article.content)

            let source = Source(
                type: .article,
                title: article.title,
                content: article.content,
                url: article.url.absoluteString,
                embedding: embedding
            )

            try await DatabaseService.shared.insertSource(source)
            didSave = true
            urlText = ""
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isProcessing = false
    }

    // MARK: - Voice Memo
    func startRecording() async {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)

            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioDir = documentsPath.appendingPathComponent("audio", isDirectory: true)
            try? FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)

            let fileName = "voice_\(Date().timeIntervalSince1970).m4a"
            recordingURL = audioDir.appendingPathComponent(fileName)

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.record()
            isRecording = true
            recordingTranscript = ""

            // Start live transcription
            liveTranscriptionTask = Task {
                do {
                    let stream = try await speechService.startLiveTranscription()
                    for await text in stream {
                        recordingTranscript = text
                    }
                } catch {
                    print("Transcription error: \(error)")
                }
            }
        } catch {
            errorMessage = "Could not start recording: \(error.localizedDescription)"
            showError = true
        }
    }

    func stopRecording() async {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false

        liveTranscriptionTask?.cancel()
        liveTranscriptionTask = nil

        await speechService.stopLiveTranscription()

        guard let recordingURL = recordingURL else { return }

        isProcessing = true
        processingMessage = "Transcribing..."

        do {
            let transcript = try await speechService.transcribe(audioURL: recordingURL)
            recognizedText = transcript
        } catch {
            errorMessage = "Transcription failed: \(error.localizedDescription)"
            showError = true
        }

        isProcessing = false
    }

    func saveVoiceMemo() async {
        guard !recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isProcessing = true
        processingMessage = "Saving voice memo..."

        let content = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = "Voice Memo \(formattedDate())"

        let embedding = await embeddingService.generateEmbedding(for: content)

        let source = Source(
            type: .voiceMemo,
            title: title,
            content: content,
            embedding: embedding
        )

        do {
            try await DatabaseService.shared.insertSource(source)
            didSave = true
            clearVoiceFields()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isProcessing = false
    }

    // MARK: - Camera/OCR
    func processImage(_ image: UIImage) async {
        capturedImage = image
        isProcessing = true
        processingMessage = "Recognizing text..."

        do {
            let text = try await visionService.recognizeText(in: image)
            recognizedText = text
        } catch {
            errorMessage = "OCR failed: \(error.localizedDescription)"
            showError = true
        }

        isProcessing = false
    }

    func saveOCRText() async {
        guard !recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isProcessing = true
        processingMessage = "Saving image text..."

        let content = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = "Image Text \(formattedDate())"

        var thumbnailData: Data? = nil
        if let image = capturedImage {
            thumbnailData = visionService.compressImage(image, maxSizeKB: 100)
        }

        let embedding = await embeddingService.generateEmbedding(for: content)

        let source = Source(
            type: .image,
            title: title,
            content: content,
            thumbnailData: thumbnailData,
            embedding: embedding
        )

        do {
            try await DatabaseService.shared.insertSource(source)
            didSave = true
            clearImageFields()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isProcessing = false
    }

    // MARK: - Helpers
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: Date())
    }

    private func clearNoteFields() {
        noteText = ""
        noteTitle = ""
    }

    private func clearVoiceFields() {
        recognizedText = ""
        recordingTranscript = ""
        recordingURL = nil
    }

    private func clearImageFields() {
        capturedImage = nil
        recognizedText = ""
    }

    func reset() {
        didSave = false
        noteText = ""
        noteTitle = ""
        urlText = ""
        capturedImage = nil
        recognizedText = ""
        recordingTranscript = ""
        errorMessage = ""
    }
}
