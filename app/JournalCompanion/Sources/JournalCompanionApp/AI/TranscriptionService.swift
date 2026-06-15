import Foundation
import AVFoundation
import Speech

enum TranscriptionError: Error {
    case recognizerUnavailable
}

/// On-device speech-to-text. PRD §7: "Voice to text — Apple's SpeechAnalyzer
/// (iOS 26+) ... falls back to SFSpeechRecognizer for older OS versions."
protocol TranscriptionService {
    func transcribe(audioURL: URL) async throws -> String
}

/// Picks the best available on-device transcriber at call time.
struct DefaultTranscriptionService: TranscriptionService {
    func transcribe(audioURL: URL) async throws -> String {
        if #available(iOS 26.0, *) {
            return try await SpeechAnalyzerTranscriptionService().transcribe(audioURL: audioURL)
        } else {
            return try await SFSpeechRecognizerTranscriptionService().transcribe(audioURL: audioURL)
        }
    }

    /// Requests speech-recognition authorization (separate from microphone
    /// permission, which `AudioRecorder` handles).
    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

// MARK: - iOS 26: SpeechAnalyzer / SpeechTranscriber

/// Uses the iOS 26 `SpeechAnalyzer` framework with its long-form
/// `SpeechTranscriber` module — tuned for dictation-length audio like a
/// spoken journal entry, and reportedly faster than Whisper Large V3 Turbo
/// at equivalent quality (per Apple's framework announcement).
///
/// NOTE: written from documentation, not a live compiler — see README
/// "Things to verify in Xcode" for the `SpeechAnalyzer`/`SpeechTranscriber`
/// API surface (asset installation, analyzer lifecycle, result stream).
@available(iOS 26.0, *)
struct SpeechAnalyzerTranscriptionService: TranscriptionService {
    func transcribe(audioURL: URL) async throws -> String {
        let transcriber = SpeechTranscriber(locale: Locale.current, preset: .transcription)

        // Make sure the on-device model assets for this locale are present.
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let audioFile = try AVAudioFile(forReading: audioURL)

        try await analyzer.start(inputAudioFile: audioFile)

        var fullText = ""
        for try await result in transcriber.results {
            fullText += String(result.text.characters)
        }

        try await analyzer.finalizeAndFinishThroughEndOfInput()
        return fullText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Fallback: SFSpeechRecognizer

/// On-device transcription via the older `SFSpeechRecognizer` API, for
/// devices/OS versions where `SpeechAnalyzer` isn't available. Lower quality
/// and no built-in voice-activity detection, but ships back to earlier iOS
/// versions.
struct SFSpeechRecognizerTranscriptionService: TranscriptionService {
    func transcribe(audioURL: URL) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(locale: Locale.current), recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = false

            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result, result.isFinal else { return }
                continuation.resume(returning: result.bestTranscription.formattedString)
            }
        }
    }
}
