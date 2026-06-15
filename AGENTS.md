# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Project status

This repository currently contains **planning documents only** — no app code has been written yet:
- `PRD_v3_draft.md` — product requirements (purpose, user flows, data schema, AI prompts, safety requirements, open questions)
- `roadmap_v1.md` — phased implementation roadmap with dependency ordering
- `design_notes.md` — visual/interaction direction for onboarding (liquid glass material, touch ripple), with a confirmed iOS 26 API implementation path

When implementation starts, follow the phase ordering in `roadmap_v1.md` (Phase 0 validation → Phase 1 core capture loop → Phase 2 retrieval/recap → Phase 3 proactive prompting → Phase 4 sync → Phase 5 craft pass). Phase 0 (manual validation of the proactive-prompting thesis) should happen before any vision-pipeline code is written, and Phase 3 is gated on its result.

## Product summary

A self-contained iOS app that turns everyday photos/videos and voice journaling into lasting reflections — helping people notice and remember the people, places, and moments that matter to them. There is a separate "builder's goal" (learning on-device ASR/vision/LLM/RAG/mobile dev) that should not drive product scope decisions (PRD §1).

**Core loop:** voice journal capture → on-device transcription → AI summary + mood tags + people/places/intentions extraction → stored locally → retrievable via semantic search and weekly recap.

## Architectural constraints (non-negotiable, drive every implementation decision)

- **Fully on-device, no backend, no developer access to user data.** No accounts, no auth, no Anthropic/dev-controlled servers (PRD §3, §8).
- **Local-first, portable storage**: entries stored as markdown files + JSON manifest in a user-visible folder the user can sync via OS-level cloud sync (iCloud Drive/Google Drive/Dropbox). The app must remain fully usable offline (PRD §3).
- **Target stack is iOS 26+ / Apple Intelligence-capable devices** — confirm target device support before finalizing scope (PRD §7):
  - Voice-to-text: `SpeechAnalyzer`/`SpeechTranscriber` (fallback `SFSpeechRecognizer` on older OS, with reduced quality)
  - Vision/captioning: Vision framework + Foundation Models multimodal prompts
  - LLM (summarization, extraction, mood tagging, retrieval QA): Apple Foundation Models (~3B on-device)
  - Vector search: local SQLite-based vector extension (e.g. `sqlite-vector`)
- **Crisis detection is independent of the LLM**: high-recall local keyword/phrase matching, not model judgment. On match, skip summarization/extraction for that entry and show a fixed pre-written supportive message (PRD §5/§6). This must be wired in from Phase 1, not added later.
- **Mood detection is text-derived only** — no acoustic/voice-tone emotion analysis (PRD §6).
- **No AI-initiated coaching/advice/recommendations in v1.** Pattern surfacing (people/places/intentions) is observational only, shown without commentary, only in the weekly recap (PRD §3, §8).
- **No cross-entry relationship/entity graph** — aggregation across entries happens at recap-generation time from per-entry fields, not a persistent database (PRD §4).

## Data schema (PRD §4)

- **Entry**: `id`, `created_at`, `type` (voice/text), `raw_content`, `summary` (omitted if `crisis_flag`), `mood_tags`, `media_references`, `embeddings`, `mentioned_people`, `mentioned_places`, `stated_intentions`, `crisis_flag`
- **MediaItem**: `id`, `file_path`, `type` (image/video), `captured_at`, `caption`, `tags`

## AI prompt conventions (PRD §5)

All prompts must be supportive, curious, non-judgmental, and avoid giving advice or diagnoses. The extraction pass (people/places/intentions) reuses the same model call as summarization — don't introduce a separate model/pass for it. When writing new prompts, follow the existing pattern: list exactly what to extract/output, explicitly forbid interpretation/commentary/follow-up where the PRD specifies "quiet mirror" behavior.

## Onboarding visuals (design_notes.md)

Splash/onboarding uses a full-screen morphing "liquid glass" blob persisting through the whole onboarding flow, with touch producing a water-like ripple. Confirmed implementation path: `.glassEffect(.regular, in: shape)` (SwiftUI iOS 26) for the material, layered with a `layerEffect` Metal shader (via `Inferno` or similar) for the ripple, driven by `UIGestureRecognizerRepresentable` touch capture + `keyframeAnimator` decay. This is Phase 5 (polish) — don't let it block functional phases.

## Imported Claude Cowork project instructions
