# Personal AI Journal and Media Companion — Phased V1 Roadmap (draft)

*Derived from PRD v3. Sequencing follows the dependency chain in the PRD: validate the riskiest assumption before building the pipeline it would justify, get the core loop working before layering retrieval/recap, and treat polish (liquid glass, ripple) as its own late phase rather than something to get "right" early.*

## Phase 0 — Validate the core thesis (no app required)

**Goal:** Confirm the proactive media-prompt thesis (Section 9) before writing any vision-pipeline code.

- Hand-pick real photos (your own camera roll or a willing tester's).
- Manually write the reflective prompts the app would generate for each.
- Show to a few people, collect real responses.
- Score against the two PRD criteria: (a) thoughtful friend vs. surveillance, (b) "would you want to read this back in a year?"
- Bonus: hand-check what people/places/intentions naturally surface in responses — an early read on the extraction prompt (Section 5).

**Exit criteria:** Both signals positive on a majority of test prompts. If not, revisit the proactive-prompt concept before Phase 2.

**Depends on:** nothing. Can run in parallel with Phase 1.

---

## Phase 1 — Core capture loop

**Goal:** The smallest version of the app that's useful daily: record, transcribe, save, summarize.

- Voice journal capture UI (record → transcript via `SpeechAnalyzer`/`SpeechTranscriber`).
- Local storage in the portable markdown + JSON manifest format (Section 3/4) — get this format right early since everything else builds on it.
- AI summarization pass (Foundation Models) producing the 1-2 sentence summary.
- **Crisis detection wired in from day one** — keyword/phrase match, bypasses summarization on match, shows fixed supportive message (Section 5/6). This is a safety floor, not a "later" feature.
- Mood tagging (text-derived only) as part of the same summarization pass.
- Basic chat-style interface to view saved entries.

**Exit criteria:** Can record a voice entry and see it transcribed, summarized, mood-tagged, and saved within ~5 seconds, fully offline (Section 11 success criteria).

**Depends on:** nothing blocking — can start immediately alongside Phase 0.

---

## Phase 2 — Retrieval and recap

**Goal:** Make past entries useful — the "remembering" half of the product.

- On-device embeddings + local vector store (`sqlite-vector` or similar) for entries saved in Phase 1.
- Query interface: "what did I say about work last month?" → retrieval QA prompt (Section 5).
- Extraction pass (people/places/intentions) added to the summarization call (Section 5) — reuses the Phase 1 model, so mostly a prompt-engineering addition.
- Weekly recap: 3-sentence theme/mood summary + the quiet list of repeated people/places/intentions (Section 2/5).
- Mood timeline view, rendered from accumulated mood tags.

**Exit criteria:** User can ask a question about past entries and get an accurate answer; weekly recap renders both the summary and the plain list with zero interpretive commentary (Section 11).

**Depends on:** Phase 1 (needs entries with summaries/embeddings to retrieve over).

---

## Phase 3 — Proactive prompting and media understanding

**Goal:** Build the vision pipeline — but only because Phase 0 said to.

- On-device image/video understanding via Vision framework + Foundation Models multimodal prompts (Section 7).
- Proactive prompting engine: decide *when* to surface a prompt (new media + time since last entry), generate the question (Section 5).
- MediaItem schema implementation (captions, tags, file references).
- Opt-in media scanning UI with folder exclusions (Section 6 consent requirements).

**Exit criteria:** App generates at least one relevant media-based prompt per day when new media exists, and the prompts hold up against the Phase 0 bar in real use.

**Depends on:** Phase 0 (go/no-go), Phase 1 (entries need to exist for prompts to be saved into).

---

## Phase 4 — Data ownership and sync

**Goal:** Turn "local-first" into "actually backed up and portable" without compromising the no-backend principle.

- OS-level sync of the data folder to the user's chosen cloud storage (iCloud Drive / Google Drive / Dropbox).
- One-tap delete-all, including the open question of synced/backed-up copies (Section 10).
- Resolve the encryption-vs-portability open question (Section 10) — likely a per-user opt-in tradeoff rather than a single default.

**Exit criteria:** Data folder round-trips through a cloud provider and remains human-readable; delete-all behavior is clearly communicated re: synced copies.

**Depends on:** Phase 1 (storage format must be stable before building sync around it).

---

## Phase 5 — Craft pass: liquid glass + touch interaction

**Goal:** The splash/onboarding material quality and water-like touch ripple flagged in `design_notes.md` — deliberately last, since it's pure polish and has a confirmed implementation path (`.glassEffect` + `layerEffect` shaders) that doesn't need to block functional phases.

- Implement morphing blob shape with `.glassEffect(.regular, in: shape)`.
- Layer touch-ripple Metal shader on top, keyed to touch position with decay.
- Apply the same material language anywhere else in the app it'd fit (recap cards, prompt cards) — but only after the core loop is solid.

**Exit criteria:** Splash/onboarding meets the "crystal ball" bar from our brainstorm; touch interaction feels like disturbing a liquid surface.

**Depends on:** Phases 1-2 functionally complete — this phase is additive polish, not a blocker for anything else.

---

## Sequencing summary

```
Phase 0 (validation) ──┐
Phase 1 (core loop)  ───┼──► Phase 2 (retrieval/recap) ──► Phase 4 (sync/ownership)
                        │
                        └──► Phase 3 (proactive prompting) [gated on Phase 0]
                                                              │
                                                              ▼
                                                  Phase 5 (liquid glass craft pass)
```

Phases 0 and 1 can start the same day. Phase 3 is the only phase with a hard go/no-go gate (Phase 0's results). Phase 5 is intentionally decoupled — it can slot in whenever there's appetite for UI polish without waiting on the rest of the roadmap.
