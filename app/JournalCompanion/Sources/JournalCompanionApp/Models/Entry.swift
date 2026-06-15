import Foundation

/// How an entry was created. Both types end up as text (`rawContent`) —
/// `type` is kept mainly for UI ("you recorded this" vs "you typed this")
/// and for any future ASR-quality analysis.
enum EntryType: String, Codable, CaseIterable {
    case voice
    case text
}

/// A single journal entry.
///
/// Mirrors PRD v3 §4. `summary`, `moodTags`, `mentionedPeople`,
/// `mentionedPlaces`, and `statedIntentions` are all produced by the same
/// Foundation Models call (see `EntryAnalysisService`) and are left empty/nil
/// when `crisisFlag` is true — crisis-flagged entries skip the AI pass
/// entirely (PRD §5/§6).
struct Entry: Identifiable, Codable, Equatable {
    let id: UUID
    var createdAt: Date
    var type: EntryType

    /// Full transcript (voice) or typed text.
    var rawContent: String

    /// 1-2 sentence AI summary. Omitted (`nil`) if `crisisFlag` is true.
    var summary: String?

    /// Mood tags derived from `rawContent` only — no acoustic/voice-tone analysis (PRD §6).
    var moodTags: [String]

    /// Local file paths / ids for any attached media (Phase 3+).
    var mediaReferences: [String]

    /// People mentioned, extracted verbatim by first name or relationship (PRD §5).
    var mentionedPeople: [String]

    /// Places mentioned, extracted verbatim (PRD §5).
    var mentionedPlaces: [String]

    /// Goals/intentions/values the user expressed about themselves or
    /// their relationships, extracted verbatim — no interpretation (PRD §5).
    var statedIntentions: [String]

    /// Set by `CrisisKeywordMatcher` before any AI processing happens.
    /// When true: `summary`, `moodTags`, `mentionedPeople`, `mentionedPlaces`,
    /// and `statedIntentions` are all left empty, and the UI shows the fixed
    /// supportive message from `CrisisResponse` instead of a summary.
    var crisisFlag: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        type: EntryType,
        rawContent: String,
        summary: String? = nil,
        moodTags: [String] = [],
        mediaReferences: [String] = [],
        mentionedPeople: [String] = [],
        mentionedPlaces: [String] = [],
        statedIntentions: [String] = [],
        crisisFlag: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.type = type
        self.rawContent = rawContent
        self.summary = summary
        self.moodTags = moodTags
        self.mediaReferences = mediaReferences
        self.mentionedPeople = mentionedPeople
        self.mentionedPlaces = mentionedPlaces
        self.statedIntentions = statedIntentions
        self.crisisFlag = crisisFlag
    }
}

/// Lightweight per-entry record kept in `manifest.json` for fast listing and
/// (in Phase 2) retrieval, without re-parsing every markdown file.
struct EntryManifestRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var createdAt: Date
    var type: EntryType
    var summarySnippet: String?
    var moodTags: [String]
    var mentionedPeople: [String]
    var mentionedPlaces: [String]
    var statedIntentions: [String]
    var crisisFlag: Bool

    init(entry: Entry) {
        self.id = entry.id
        self.createdAt = entry.createdAt
        self.type = entry.type
        self.summarySnippet = entry.summary
        self.moodTags = entry.moodTags
        self.mentionedPeople = entry.mentionedPeople
        self.mentionedPlaces = entry.mentionedPlaces
        self.statedIntentions = entry.statedIntentions
        self.crisisFlag = entry.crisisFlag
    }
}
