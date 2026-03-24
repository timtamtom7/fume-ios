import Foundation
import Speech
import AVFoundation

actor SpeechService {
    static let shared = SpeechService()

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private init() {}

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func transcribe(audioURL: URL) async throws -> String {
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        guard let recognizer = recognizer, recognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                if let result = result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }

    func startLiveTranscription() async throws -> AsyncStream<String> {
        let authorized = await requestAuthorization()
        guard authorized else { throw SpeechError.notAuthorized }

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { throw SpeechError.audioEngineError }

        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        guard let recognizer = recognizer, recognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { throw SpeechError.requestError }

        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        return AsyncStream { continuation in
            recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { result, error in
                if let result = result {
                    continuation.yield(result.bestTranscription.formattedString)
                }

                if error != nil || (result?.isFinal ?? false) {
                    continuation.finish()
                }
            }

            continuation.onTermination = { @Sendable _ in
                Task {
                    await self.stopLiveTranscription()
                }
            }
        }
    }

    func stopLiveTranscription() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
    }

    func saveAudioFile(from url: URL, fileName: String) throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioDir = documentsPath.appendingPathComponent("audio", isDirectory: true)

        try? FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)

        let destinationURL = audioDir.appendingPathComponent("\(fileName).m4a")

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.copyItem(at: url, to: destinationURL)
        return destinationURL
    }
}

enum SpeechError: LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case audioEngineError
    case requestError

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Speech recognition not authorized"
        case .recognizerUnavailable: return "Speech recognizer unavailable"
        case .audioEngineError: return "Audio engine error"
        case .requestError: return "Speech request error"
        }
    }
}
