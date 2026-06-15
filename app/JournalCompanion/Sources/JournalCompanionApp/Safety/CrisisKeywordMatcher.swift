import Foundation

/// High-recall, low-precision keyword/phrase matching for crisis detection.
///
/// Deliberately independent of any LLM (PRD §5/§6): this check runs on the
/// raw transcript/text *before* any AI processing, so it can't be affected by
/// model behavior or prompt-following. A match sets `Entry.crisisFlag = true`,
/// which causes the app to skip summarization/extraction entirely and show
/// `CrisisResponse.fixedMessage` instead.
///
/// IMPORTANT: see README "Crisis phrase list — please review" and
/// `PRD_v3_draft.md` §10 — this starter list needs review (ideally against
/// established crisis-line keyword lists, and/or with professional input)
/// before this is relied on for anyone other than you.
struct CrisisKeywordMatcher {
    let phrases: [String]

    /// Loads the bundled starter phrase list from `crisis_phrases.json`.
    static func loadDefault() -> CrisisKeywordMatcher {
        guard
            let url = Bundle.main.url(forResource: "crisis_phrases", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let phrases = try? JSONDecoder().decode([String].self, from: data)
        else {
            // Fail safe: if the bundled resource can't be loaded for some
            // reason, fall back to a small built-in list rather than
            // disabling detection entirely.
            return CrisisKeywordMatcher(phrases: fallbackPhrases)
        }
        return CrisisKeywordMatcher(phrases: phrases)
    }

    private static let fallbackPhrases = [
        "kill myself",
        "end my life",
        "suicide",
        "want to die",
        "don't want to be here anymore",
        "hurt myself",
        "self harm",
        "no reason to live"
    ]

    /// Case-insensitive substring match against the full text.
    ///
    /// High recall is the explicit goal — false positives are acceptable
    /// (the user just sees a supportive message and the entry skips AI
    /// processing for that one entry); false negatives are not.
    func matches(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return phrases.contains { lowered.contains($0.lowercased()) }
    }
}
