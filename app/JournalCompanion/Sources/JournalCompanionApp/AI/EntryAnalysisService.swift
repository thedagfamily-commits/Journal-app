import Foundation
import FoundationModels

/// Result of the combined summarization + extraction pass.
///
/// PRD §5: "The extraction pass (people/places/intentions) reuses the same
/// model call as summarization — don't introduce a separate model/pass."
struct EntryAnalysis: Equatable {
    var summary: String
    var moodTags: [String]
    var mentionedPeople: [String]
    var mentionedPlaces: [String]
    var statedIntentions: [String]

    static let empty = EntryAnalysis(summary: "", moodTags: [], mentionedPeople: [], mentionedPlaces: [], statedIntentions: [])
}

/// Summarizes + extracts from raw journal text.
///
/// IMPORTANT: must NOT be called for crisis-flagged entries (PRD §5/§6) —
/// callers run `CrisisKeywordMatcher` first and skip this entirely on a
/// match, showing `CrisisResponse.fixedMessage` instead.
protocol EntryAnalysisService {
    func analyze(text: String) async throws -> EntryAnalysis
}

/// On-device implementation using Apple's Foundation Models framework
/// (iOS 26+), per PRD §7.
///
/// NOTE: written from documentation, not a live compiler — see README
/// "Things to verify in Xcode" for the `LanguageModelSession` / `@Generable` /
/// `@Guide` API surface. The `EntryAnalysisService` protocol and
/// `EntryAnalysis` struct are the stable contract the rest of the app
/// depends on; if the FoundationModels API differs slightly, adjust the body
/// of `analyze(text:)` rather than the contract.
@available(iOS 26.0, *)
struct FoundationModelsEntryAnalysisService: EntryAnalysisService {

    /// Structured output shape for the model. Field descriptions double as
    /// the extraction instructions, per PRD §5's "list exactly what to
    /// extract/output" prompt convention.
    @Generable
    fileprivate struct GeneratedAnalysis {
        @Guide(description: "A 1-2 sentence summary of the journal entry, focused on mood and key events. Do not give advice.")
        var summary: String

        @Guide(description: "Mood tags inferred from the text only (no voice-tone analysis), e.g. calm, anxious, happy, tired. 1-3 tags.")
        var moodTags: [String]

        @Guide(description: "People mentioned, by first name or relationship, exactly as stated. Empty array if none mentioned.")
        var mentionedPeople: [String]

        @Guide(description: "Places mentioned, exactly as stated. Empty array if none mentioned.")
        var mentionedPlaces: [String]

        @Guide(description: "Goals, intentions, or values the user expressed about themselves or their relationships, exactly as stated. Do not interpret or infer. Empty array if none.")
        var statedIntentions: [String]
    }

    /// Mirrors PRD §5's extraction prompt: "List only what is explicitly
    /// stated. Do not interpret, infer, or comment." Same "quiet mirror"
    /// framing as the weekly recap (PRD §3/§8 — no AI-initiated coaching).
    private static let instructions = """
    You are a quiet, supportive journaling assistant. You read a personal journal entry and produce a summary and some plain extracted facts about it.

    Guidelines:
    - The summary should be 1-2 sentences focused on mood and key events. Do not give advice, ask questions, or suggest anything.
    - Mood tags come only from the text itself.
    - People, places, and stated intentions/goals/values must be listed only if explicitly mentioned, using the user's own words. Do not interpret, infer, comment, or add anything not stated.
    """

    func analyze(text: String) async throws -> EntryAnalysis {
        let session = LanguageModelSession(instructions: Self.instructions)
        let response = try await session.respond(
            to: "Journal entry:\n\n\(text)",
            generating: GeneratedAnalysis.self
        )
        let result = response.content

        return EntryAnalysis(
            summary: result.summary,
            moodTags: result.moodTags,
            mentionedPeople: result.mentionedPeople,
            mentionedPlaces: result.mentionedPlaces,
            statedIntentions: result.statedIntentions
        )
    }
}

/// Fallback for iOS < 26 or devices without Apple Intelligence. Phase 1
/// scaffold: returns an empty analysis rather than failing the save, so the
/// capture loop still works end-to-end (entry is saved with raw content only,
/// no summary/tags — same shape as a crisis-flagged entry, minus the fixed
/// message).
struct UnavailableEntryAnalysisService: EntryAnalysisService {
    func analyze(text: String) async throws -> EntryAnalysis {
        .empty
    }
}

enum EntryAnalysisServiceFactory {
    static func make() -> EntryAnalysisService {
        if #available(iOS 26.0, *) {
            return FoundationModelsEntryAnalysisService()
        } else {
            return UnavailableEntryAnalysisService()
        }
    }
}
