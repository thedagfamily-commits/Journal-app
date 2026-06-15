# Handoff notes (Cowork → Claude Code)

Written 2026-06-14. Context for picking up this project in Claude Code after
scaffolding it in Cowork.

## Where things stand

- Planning docs (`PRD_v3_draft.md`, `roadmap_v1.md`, `design_notes.md`) are done.
  `roadmap_v1.md` defines the phase ordering — Phase 0 (manual validation of the
  proactive-prompting thesis) gates Phase 3, and should happen before any
  vision-pipeline code.
- Phase 1 ("core capture loop") scaffold is built under `app/JournalCompanion/`:
  Xcode project (via XcodeGen), Entry data model, markdown + JSON manifest storage,
  crisis-keyword detection (independent of the LLM, wired in from the start),
  on-device transcription (SpeechAnalyzer w/ SFSpeechRecognizer fallback),
  Foundation Models summarization/extraction, and SwiftUI views (record/list/detail).
- **Build status: builds successfully in Xcode 26** (confirmed by user). One fix
  already applied: `GeneratedAnalysis` in `EntryAnalysisService.swift` had to be
  `fileprivate` (not `private`) for the `@Generable` macro to work.
- Not yet tested: actually running the record → transcribe → analyze → save loop on
  a physical device (mic/speech permissions, FoundationModels availability).

## Known caveats / likely next issues

- `app/JournalCompanion/README.md` has a "Things to verify in Xcode" section —
  FoundationModels and SpeechAnalyzer API surfaces were written from documentation
  without a compiler, so small signature mismatches are possible beyond the one
  already fixed.
- `Safety/Resources/crisis_phrases.json` is a **starter** crisis-keyword list and
  needs review per PRD §10 before anyone but the user relies on it.
- `crisis_phrases.json` bundling into "Copy Bundle Resources" should be confirmed
  in Xcode's Build Phases (XcodeGen should pick it up automatically as a non-Swift
  resource, but not yet visually confirmed).

## Not started yet (per roadmap_v1.md)

- Phase 0: manual validation of the proactive-prompting thesis (no app code)
- Phase 2: vector store/semantic search, weekly recap UI
- Phase 3: media scanning + proactive prompting (gated on Phase 0 result)
- Phase 4: iCloud/cloud sync wiring, delete-all addressing synced copies
- Phase 5: liquid glass material + touch ripple onboarding (design_notes.md has a
  confirmed iOS 26 API path: `.glassEffect`, `GlassEffectContainer`, `layerEffect`
  Metal shader, `UIGestureRecognizerRepresentable`)

## Suggested next step

Run the app on a physical device, do an end-to-end voice entry, and report back
whether transcription/analysis actually work — that will surface any remaining
FoundationModels/SpeechAnalyzer adjustments before starting Phase 2.
