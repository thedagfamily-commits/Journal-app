import Foundation
import AVFoundation

/// Records microphone audio to a local temporary file using `AVAudioRecorder`.
///
/// Output is `.m4a` (AAC) — broadly compatible with both
/// `SFSpeechRecognizer` (file-based recognition request) and
/// `SpeechAnalyzer`/`SpeechTranscriber` (reads via `AVAudioFile`), see
/// `TranscriptionService.swift`.
@MainActor
final class AudioRecorder: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var lastRecordingURL: URL?

    private var recorder: AVAudioRecorder?

    /// Requests microphone permission. Call before `startRecording()`.
    func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func startRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .spokenAudio)
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("journal-\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        recorder.record()

        self.recorder = recorder
        self.lastRecordingURL = url
        self.isRecording = true
    }

    /// Stops recording. The recorded file remains at `lastRecordingURL` until
    /// the caller is done with it (e.g. after transcription) — callers should
    /// delete it themselves once finished, since it lives in the temp
    /// directory and isn't part of the journal's permanent storage.
    func stopRecording() {
        recorder?.stop()
        recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        // isRecording / lastRecordingURL are updated synchronously by
        // start/stopRecording on the main actor; nothing to do here.
    }
}
