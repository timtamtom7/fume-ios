import Foundation
import Speech

// MARK: - Speech Service (macOS version)

actor SpeechService {
    static let shared = SpeechService()

    private init() {}

    func transcribe(audioURL: URL) async throws -> String {
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        guard let recognizer = recognizer, recognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false

        // Use a simple class to hold continuation state safely
        let state = TranscriptionState()

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            state.continuation = cont

            // Start timeout
            state.timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                state.cancel()
            }

            // Start recognition
            recognizer.recognitionTask(with: request) { result, error in
                if state.isCancelled { return }
                state.timeoutTask?.cancel()

                if let error = error {
                    state.continuation?.resume(throwing: error)
                    state.continuation = nil
                } else if let result = result, result.isFinal {
                    state.continuation?.resume(returning: result.bestTranscription.formattedString)
                    state.continuation = nil
                }
            }
        }
    }
}

// Simple class to hold mutable continuation state (avoids actor isolation issues for the callback)
private final class TranscriptionState: @unchecked Sendable {
    var continuation: CheckedContinuation<String, Error>?
    var timeoutTask: Task<Void, Never>?
    var isCancelled = false

    func cancel() {
        isCancelled = true
        timeoutTask?.cancel()
        continuation?.resume(throwing: SpeechError.requestError)
        continuation = nil
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
