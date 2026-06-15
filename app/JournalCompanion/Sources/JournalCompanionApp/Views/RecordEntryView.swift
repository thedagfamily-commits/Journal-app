import SwiftUI

/// The Phase 1 core capture loop (roadmap_v1.md Phase 1):
/// record -> transcribe -> crisis check -> analyze -> save.
///
/// The crisis check (PRD §5/§6) runs on the raw transcript *before* any AI
/// call, independent of the LLM. On a match, summarization/extraction are
/// skipped entirely and the fixed `CrisisResponse.fixedMessage` is shown.
struct RecordEntryView: View {
    @EnvironmentObject private var entryStore: EntryStore
    @StateObject private var recorder = AudioRecorder()

    @State private var phase: Phase = .idle
    @State private var errorMessage: String?

    private let crisisMatcher = CrisisKeywordMatcher.loadDefault()

    enum Phase: Equatable {
        case idle
        case recording
        case transcribing
        case analyzing
        case done(Entry)
        case crisis
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                switch phase {
                case .idle:
                    idleView
                case .recording:
                    recordingView
                case .transcribing:
                    statusView("Transcribing on-device...")
                case .analyzing:
                    statusView("Reflecting on this entry...")
                case .done(let entry):
                    doneView(entry)
                case .crisis:
                    crisisView
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("New entry")
        }
    }

    // MARK: - Subviews

    private var idleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Tap to start your journal entry")
                .font(.headline)
            Button("Start recording") {
                startRecording()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var recordingView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 64))
                .foregroundStyle(.red)
            Text("Listening...")
                .font(.headline)
            Button("Done") {
                finishRecording()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func statusView(_ message: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func doneView(_ entry: Entry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Saved")
                .font(.headline)

            if let summary = entry.summary, !summary.isEmpty {
                Text(summary)
                    .font(.body)
            }

            if !entry.moodTags.isEmpty {
                tagRow(entry.moodTags)
            }

            Button("New entry") {
                reset()
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var crisisView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(CrisisResponse.fixedMessage)
                .font(.body)

            Button("New entry") {
                reset()
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func tagRow(_ tags: [String]) -> some View {
        HStack {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Actions

    private func startRecording() {
        errorMessage = nil
        Task {
            guard await recorder.requestPermission() else {
                errorMessage = "Microphone permission is required to record."
                return
            }
            guard await DefaultTranscriptionService.requestAuthorization() else {
                errorMessage = "Speech recognition permission is required to transcribe."
                return
            }
            do {
                try recorder.startRecording()
                phase = .recording
            } catch {
                errorMessage = "Couldn't start recording: \(error.localizedDescription)"
            }
        }
    }

    private func finishRecording() {
        recorder.stopRecording()
        guard let url = recorder.lastRecordingURL else {
            errorMessage = "No recording found."
            phase = .idle
            return
        }
        phase = .transcribing

        Task {
            do {
                let transcriptionService: TranscriptionService = DefaultTranscriptionService()
                let transcript = try await transcriptionService.transcribe(audioURL: url)
                try? FileManager.default.removeItem(at: url)
                await processTranscript(transcript)
            } catch {
                errorMessage = "Transcription failed: \(error.localizedDescription)"
                phase = .idle
            }
        }
    }

    private func processTranscript(_ transcript: String) async {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Didn't catch anything — try again."
            phase = .idle
            return
        }

        // Crisis check first, independent of the LLM (PRD §5/§6).
        if crisisMatcher.matches(trimmed) {
            let entry = Entry(type: .voice, rawContent: trimmed, crisisFlag: true)
            saveAndShow(entry, crisis: true)
            return
        }

        phase = .analyzing
        do {
            let analysisService: EntryAnalysisService = EntryAnalysisServiceFactory.make()
            let analysis = try await analysisService.analyze(text: trimmed)
            let entry = Entry(
                type: .voice,
                rawContent: trimmed,
                summary: analysis.summary.isEmpty ? nil : analysis.summary,
                moodTags: analysis.moodTags,
                mentionedPeople: analysis.mentionedPeople,
                mentionedPlaces: analysis.mentionedPlaces,
                statedIntentions: analysis.statedIntentions,
                crisisFlag: false
            )
            saveAndShow(entry, crisis: false)
        } catch {
            // Capture should never be blocked by the AI pass — save the raw
            // entry even if summarization/extraction fails.
            let entry = Entry(type: .voice, rawContent: trimmed, crisisFlag: false)
            errorMessage = "Saved your entry, but summarizing it failed: \(error.localizedDescription)"
            saveAndShow(entry, crisis: false)
        }
    }

    private func saveAndShow(_ entry: Entry, crisis: Bool) {
        do {
            try entryStore.save(entry)
            phase = crisis ? .crisis : .done(entry)
        } catch {
            errorMessage = "Couldn't save entry: \(error.localizedDescription)"
            phase = .idle
        }
    }

    private func reset() {
        errorMessage = nil
        phase = .idle
    }
}

#Preview {
    RecordEntryView()
        .environmentObject(EntryStore())
}
