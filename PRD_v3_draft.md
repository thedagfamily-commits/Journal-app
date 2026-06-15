# Personal AI Journal and Media Companion — PRD v3 (draft)

*Draft reflecting our brainstorm — changes from v2 are marked with **(NEW)** or **(CHANGED)**. Open questions are called out explicitly rather than silently resolved.*

## 1. Purpose

This project has two distinct goals that shouldn't be conflated **(CHANGED — was blended in v2)**:

- **Builder's goal (personal):** An end-to-end vehicle for learning AI-native development — on-device ASR, vision, LLM inference, RAG, and mobile deployment. This is about your own growth as a developer and doesn't drive product decisions on its own.
- **Product goal (for end users):** A self-contained mobile app that helps people reflect on their lives — especially the people, places, and moments that matter most — by turning everyday photos/videos and voice journaling into lasting, meaningful reflections.

**Core thesis (NEW):** Most of what makes up a person's life — walks, dinners, small moments with people they love — gets captured in photos and videos that pile up, get lost in phone upgrades, and are rarely revisited. This app converts those fleeting captures into intentional reflection: journal entries that outlast the media that inspired them.

**North star (NEW):** Over time, help people become better friends, partners, family members, and community members — not by telling them how, but by helping them notice and remember what (and who) they've already told themselves matters.

## 2. Core User Flows

- **Voice journal capture**: User taps record, speaks, app transcribes and saves entry.
- **Media scan and proactive prompt**: App scans new photos/videos on device, uses on-device vision to understand content, and generates a contextual question like "I see you at Golden Gate Park yesterday, how did that walk feel?" *(See Section 9 — this must be validated with a manual/wizard-of-oz test before the vision pipeline is built.)*
- **Query past entries**: User can ask "what did I say about work last month?" and get a synthesized answer from stored entries.
- **Weekly recap**: App summarizes themes and mood from the week in 3 sentences, **and (NEW)** quietly lists any people, places, or personal intentions that came up more than once — as plain observations, no commentary or suggestions.
- **Mood timeline**: User can view mood tags (derived from journal text only — see Section 6) over time to notice patterns.

## 3. Key Features

- **Voice to text**: Low-latency transcription with timestamps, processed locally.
- **On-device multimodal understanding**: Caption and tag local images/short videos without upload.
- **AI summarization**: 1-2 sentence summary of each entry after saving. **(CHANGED)** Skipped entirely for entries flagged by crisis detection — see Section 6.
- **Retrieval layer**: On-device embeddings + vector store for semantic search across entries.
- **Proactive prompting engine**: Decides when to ask questions based on new media + time since last entry. Prompts are open, curious, never pushy.
- **Mood detection (CHANGED)**: Inferred from journal *text* only. Voice-tone/acoustic emotion detection is cut entirely — too unreliable to be the basis for telling someone how they feel.
- **Pattern/dimension tracking (NEW)**: During the same pass as summarization, lightly extract people, places, and stated intentions/values mentioned in the entry (e.g., "I should call my sister more"). Stored per-entry. Surfaced only in the weekly recap as a plain list — no interpretation, no follow-up questions, no AI-initiated coaching in v1. This is a *quiet mirror*, not a coach.
- **Local-first storage with user-owned cloud backup (CHANGED)**: Entries and manifests stored in portable, human-readable formats (e.g., markdown per entry + JSON manifest) in a folder the user can sync to their own cloud storage (iCloud Drive, Google Drive, Dropbox, etc.) via the OS filesystem. No app backend, no developer-controlled servers, no Anthropic/dev access to user data. The app remains fully usable offline; sync is opportunistic.
- **Data controls**: Folder-based export is continuous (it's just the synced folder), plus one-tap delete-all. Opt-in media scanning with folder exclusions.
- **Chat interface**: Simple UI to review entries, see prompts, and query past content.
- **Crisis response (CHANGED)**: Detection via a maintained, deliberately high-recall/low-precision local keyword and phrase list — not LLM judgment. Flagged entries skip summarization and pattern extraction and instead show a fixed, pre-written supportive message.

## 4. Data Schema

**Entry**
- `id`: string, unique
- `created_at`: timestamp
- `type`: enum[voice, text]
- `raw_content`: string, full transcript
- `summary`: string, AI generated 1-2 sentences (omitted if `crisis_flag` is true)
- `mood_tags`: array[string], derived from transcript text only
- `media_references`: array[string], local file paths or ids
- `embeddings`: vector, for semantic search
- `mentioned_people`: array[string] **(NEW)** — first names/relationships mentioned, extracted verbatim
- `mentioned_places`: array[string] **(NEW)**
- `stated_intentions`: array[string] **(NEW)** — goals/values/intentions the user expressed about themselves or their relationships
- `crisis_flag`: bool **(NEW)**

**MediaItem**
- `id`: string, unique
- `file_path`: string, on device
- `type`: enum[image, video]
- `captured_at`: timestamp
- `caption`: string, AI generated description
- `tags`: array[string], keywords from model

**Note (NEW):** Cross-entry aggregation (e.g., "you've mentioned your sister 3 times this month") is computed at recap-generation time from these per-entry fields. No separate persistent relationship/entity database in v1 — keeps the schema simple and avoids committing to a model of "what matters" before we've watched real usage.

## 5. Example Prompts for AI Layer

- **Summarization**: `Summarize this journal entry in two sentences focusing on mood and key events. Do not give advice.` *(Skipped if crisis_flag is true.)*
- **Extraction (NEW)**: `From this journal entry, list: (1) any people mentioned, by first name or relationship, (2) any places mentioned, (3) any goals, intentions, or values the user expressed about themselves or their relationships. List only what is explicitly stated. Do not interpret, infer, or comment.`
- **Proactive Prompting**: `You took a photo at Ocean Beach yesterday evening. Ask one open-ended question about how the user felt during that moment. Be supportive and non-judgmental.`
- **Retrieval QA**: `Based only on the user's past journal entries, answer this question. If the answer isn't there, say "I don't have that from your journal." Do not diagnose or give medical advice.`
- **Weekly Recap (CHANGED)**: `From these entries from the last 7 days: (1) give 3 sentences on main themes and overall mood, avoiding judgment, and (2) list any people, places, or personal intentions that were mentioned more than once — with no commentary, suggestions, or follow-up questions.`
- **Crisis detection (CHANGED)**: Not a model prompt. Matches transcript text directly against a maintained local list of high-recall self-harm/crisis phrases.

## 6. Wellbeing & Safety Requirements

- **Tone**: All prompts and summaries must be supportive, curious, and non-judgmental. Never guilt-trip or pressure.
- **No imposed standards (NEW)**: The app reflects back only what the user has expressed themselves. It never introduces a goal, value, or standard of behavior the user hasn't already stated. No AI-initiated coaching, advice, or recommendations in v1 — pattern surfacing (Section 3) is observation only.
- **No medical advice**: App states "I'm not a therapist" where relevant. Do not diagnose or suggest treatment.
- **Mood detection (CHANGED)**: Text-derived only. No acoustic/voice-tone emotion analysis.
- **Crisis response (CHANGED)**: High-recall local keyword/phrase matching, independent of the LLM. On a match: skip summarization and pattern extraction for that entry, show a fixed, pre-written supportive message (contact a trusted person or professional resource). Do not attempt counseling.
- **Storage & data ownership (CHANGED)**: Local-first, portable formats. No proprietary database lock-in. User can sync their data folder to their own cloud storage of choice. No backend, no developer access.
- **Encryption**: *(Open question — see Section 10. Tension between "portable, human-readable files" and "encrypted at rest.")*
- **Consent**: Media scanning is opt-in. User can exclude folders. Clear permission screens.
- **Deletion**: One-tap "delete all data" available in settings. *(Open question — see Section 10, re: cloud-synced copies.)*
- **Output guardrails**: Filter model outputs to block harmful, self-harm, or disallowed content.

## 7. Tech & AI Tool Requirements

- **Voice to text**: Apple's `SpeechAnalyzer` (iOS 26+) — on-device, ships a `SpeechTranscriber` module suited to long-form dictation (journal entries), reportedly ~2x faster than Whisper Large V3 Turbo. Falls back to `SFSpeechRecognizer` for older OS versions, though it lacks `SpeechAnalyzer`'s voice-activity-detection and long-form tuning. **(CHANGED — concrete candidate identified)**
- **Vision model**: Apple's Vision framework (on-device OCR, object/scene detection) combined with Apple Intelligence's Foundation Models multimodal prompts — pass an image + text prompt and get on-device reasoning about visual content (the basis for "I see you at Golden Gate Park yesterday" captions). Vision framework tools (OCR, barcode) are callable directly by the model. **(CHANGED — concrete candidate identified)**
- **LLM**: Apple's Foundation Models framework (iOS 26+) — ~3B-parameter on-device LLM behind Apple Intelligence, fully on-device/private/offline. Handles summarization, entity extraction, sentiment/mood tagging, and short Q&A (retrieval synthesis) — covers every prompt in Section 5 with one model. The extraction pass reuses the same model/call as summarization — no new model needed. Best practice from Apple's guidance: keep prompts specific (e.g. "summarize in exactly one sentence") and chunk-then-summarize for longer entries. **(CHANGED — concrete candidate identified)**
- **Vector store**: Local SQLite-based vector extension (e.g. `sqlite-vector`) for embedding storage + similarity search — pairs naturally with the local-first markdown+JSON storage model (Section 3), no separate database engine needed. **(CHANGED — concrete candidate identified)**
- **Dev tools**: Use end-to-end AI-native dev tools to scaffold UI, model calls, data layer, and deploy to device — this is the personal learning track from Section 1 and shouldn't drive product scope decisions on its own.

**Net effect**: every item in this section now has a named, current (iOS 26) Apple framework as the primary candidate, all on-device and free of third-party model hosting — consistent with the "no backend, no dev access" storage principle in Section 3/6. Tradeoff to keep in mind: this ties the v1 build to iOS 26+ and Apple Silicon devices capable of running Apple Intelligence (not all iPhones that can run iOS 26 support Apple Intelligence) — worth confirming against your target device(s) before finalizing scope.

## 8. Non-Goals for V1

- No social sharing or developer-run cloud sync (user-controlled storage sync is in scope; a social/multi-device service is not).
- No multi-user support.
- No backend or authentication.
- No video beyond short clips <30s.
- No custom voice cloning.
- No voice-tone-based mood/emotion detection **(NEW)**.
- No AI-initiated coaching, advice, or behavior recommendations — pattern surfacing is observational only **(NEW)**.
- No cross-entry relationship/entity graph — aggregation happens at recap time from per-entry tags **(NEW)**.

## 9. Validation Approach (NEW)

Before building the on-device vision pipeline for proactive prompting, validate the core thesis cheaply:

1. Hand-pick a handful of real photos (from your own camera roll or a willing tester's).
2. Manually write the kind of prompt the app would generate for each.
3. Show these to a few people and have them respond for real.
4. Evaluate on two dimensions: (a) does it feel like a thoughtful friend or a surveillance notification, and (b) imagining reading their own answer back in a year — does it capture something they'd actually want to remember?

Only build the vision pipeline if both signals are positive. This also doubles as an early test of the extraction prompt (Section 5) — see what people/places/intentions naturally come up in real answers.

## 10. Open Questions

- **Encryption vs. portability**: If entries are stored as plain markdown/JSON for true portability and ownership, how (or whether) to layer on encryption-at-rest without undermining "the user can read their journal in a text editor with the app uninstalled."
- **Delete-all and cloud-synced copies**: If a user's data folder is synced to their own cloud, does "delete all" need to explicitly address those synced/backed-up copies, and how is that communicated?
- **Crisis phrase list maintenance**: Who/what maintains the high-recall keyword list over time, and how do we avoid the fixed response feeling cold or repetitive on repeated triggers?
- **When (if ever) does the "quiet mirror" grow a voice?** v1 deliberately surfaces patterns without commentary. If usage data later shows people want more — e.g., "you mentioned this in March, here it is again" — that's a deliberate v2+ decision, not a default.

## 11. Success Criteria

- Record a voice entry and see it transcribed + summarized within 5 seconds.
- App generates at least one relevant media-based prompt per day when new media exists *(pending validation in Section 9)*.
- User can ask a question about past entries and get an accurate synthesized answer.
- Weekly recap includes both the 3-sentence summary and the plain people/places/intentions list, with no interpretive commentary.
- All core features (capture, transcription, recap, query) run on device with airplane mode on; cloud sync to the user's own storage happens opportunistically when available.
- Mood timeline renders from text-derived mood tags.
- All data can be deleted with one tap.
