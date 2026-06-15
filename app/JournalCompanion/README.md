# Journal Companion — Phase 1 scaffold

This is the Phase 1 ("core capture loop") scaffold from `roadmap_v1.md`: record a voice
journal entry, transcribe it on-device, run crisis-keyword detection, summarize +
extract people/places/intentions (skipped if crisis-flagged), and save everything
locally as portable markdown + a JSON manifest.

**This was written outside of Xcode** (no compiler available in this environment), so
treat it as a strong starting point, not a guaranteed-green build. See
"Things to verify in Xcode" below before you spend too long debugging — a couple of
spots are most likely to need small adjustments against the real iOS 26 SDK.

## One-time setup

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) if you don't have it:
   ```
   brew install xcodegen
   ```
2. From this folder (`app/JournalCompanion`), generate the Xcode project:
   ```
   xcodegen generate
   ```
   This reads `project.yml` and produces `JournalCompanion.xcodeproj`.
3. Open `JournalCompanion.xcodeproj` in Xcode 26.
4. Set your signing team (Signing & Capabilities tab) so it can run on a physical
   device — on-device speech recognition and Foundation Models work best on-device,
   and Apple Intelligence features require a physical Apple Intelligence-capable
   device (not all simulators support this).
5. Build and run.

## What's here

```
Sources/JournalCompanionApp/
  JournalCompanionApp.swift      App entry point
  ContentView.swift              Tab shell: Journal list + Record
  Models/
    Entry.swift                  Entry schema (PRD §4)
    MediaItem.swift               MediaItem schema (PRD §4, used from Phase 3)
  Storage/
    EntryStore.swift              Reads/writes entries/ + manifest.json
    EntryMarkdownCoder.swift       Entry <-> markdown w/ YAML frontmatter
  Safety/
    CrisisKeywordMatcher.swift     High-recall keyword/phrase match (PRD §5/§6)
    CrisisResponse.swift           Fixed supportive message (not LLM-generated)
    Resources/crisis_phrases.json  Starter phrase list — see caveat below
  AI/
    EntryAnalysisService.swift     Foundation Models summarization + extraction (PRD §5)
    TranscriptionService.swift     SpeechAnalyzer (iOS 26) w/ SFSpeechRecognizer fallback
    AudioRecorder.swift            Mic capture to a local file
  Views/
    RecordEntryView.swift          Record -> transcribe -> crisis check -> analyze -> save
    EntryListView.swift            List of saved entries
    EntryDetailView.swift          Full entry view
```

## Where entries are stored

`EntryStore` writes to `<Documents>/JournalData/` by default:

```
JournalData/
  manifest.json          lightweight index (id, created_at, summary snippet, mood_tags, crisis_flag, ...)
  entries/
    <uuid>.md             one markdown file per entry, YAML frontmatter + body
```

This folder lives in the app's Documents directory, which is automatically included
in iCloud Drive backups if you enable "iCloud Drive" + Documents folder sync for the
app (Phase 4) — but that wiring isn't done yet. For now it's just local.

## Things to verify in Xcode

These were written from documentation/research rather than a live compiler — double
check them first if something doesn't build:

- **`FoundationModels` API surface** (`EntryAnalysisService.swift`): the
  `LanguageModelSession`, `@Generable`, and `@Guide` names/signatures reflect the
  iOS 26 Foundation Models framework as documented, but Apple has tweaked similar
  betas before. If it doesn't compile, check Xcode's autocomplete/quick help for the
  current `FoundationModels` symbols and adjust the service's internals — the
  `EntryAnalysisService` protocol and `EntryAnalysis` struct shape are what the rest
  of the app depends on, so keep that contract stable even if the implementation
  inside changes.
- **`SpeechAnalyzer` / `SpeechTranscriber` API surface** (`TranscriptionService.swift`):
  same caveat — the high-level flow (configure analyzer, feed audio buffers, get
  transcript) should be right, but exact type/method names may need small fixes.
  `SFSpeechRecognizerTranscriptionService` (the fallback) is older and more stable.
- **Availability checks**: both services gate on `if #available(iOS 26, *)` —
  confirm the actual minimum OS version Foundation Models / SpeechAnalyzer require
  on your target device.
- **Microphone/Speech permission prompts**: `Info.plist` keys are set via
  `project.yml`; Xcode may also want you to confirm capabilities (Background Modes
  not needed for Phase 1).
- **`Info.plist` generation**: there's no checked-in `Info.plist` — `project.yml`
  points at `Sources/JournalCompanionApp/Info.plist` and XcodeGen generates it from
  `properties` on first `xcodegen generate`. If you ever add custom Info.plist keys
  by hand later, add them under `properties` in `project.yml` instead, or XcodeGen
  will overwrite them on the next `generate`.
- **`crisis_phrases.json` bundling**: XcodeGen should pick this up automatically as a
  "Copy Bundle Resources" entry since it's a non-Swift file under `Sources/`. After
  `xcodegen generate`, check the target's Build Phases to confirm it's listed — if
  not, add it manually so `CrisisKeywordMatcher.loadDefault()` can find it via
  `Bundle.main` (it falls back to a small built-in list if the resource is missing,
  but the full list should be present).

## Crisis phrase list — please review

`Safety/Resources/crisis_phrases.json` is a **starter** list, deliberately high-recall.
Per `PRD_v3_draft.md` Section 10 (open question), this list needs ongoing review —
ideally checked against established crisis-line keyword lists and/or a professional
in this space before this app is used by anyone other than you. Don't treat the
shipped list as sufficient on its own.

## Not in this scaffold yet (later phases)

- Vector store / semantic search (Phase 2)
- Weekly recap UI (Phase 2)
- Media scanning + proactive prompting (Phase 3)
- iCloud/cloud sync wiring + delete-all (Phase 4)
- Liquid glass / touch ripple onboarding (Phase 5)
