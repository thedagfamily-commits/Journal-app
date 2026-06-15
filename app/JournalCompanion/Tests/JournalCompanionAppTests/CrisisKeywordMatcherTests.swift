import XCTest
@testable import JournalCompanion

final class CrisisKeywordMatcherTests: XCTestCase {

    private let matcher = CrisisKeywordMatcher(phrases: [
        "kill myself",
        "want to die",
        "self harm",
        "i'm a burden",
        "can't take it anymore",
    ])

    func testMatchesExactPhrase() {
        XCTAssertTrue(matcher.matches("Sometimes I just want to die."))
    }

    func testMatchIsCaseInsensitive() {
        XCTAssertTrue(matcher.matches("I KILL MYSELF in this game all the time"))
    }

    func testMatchIsSubstring() {
        XCTAssertTrue(matcher.matches("I feel like I'm a burden to everyone around me."))
    }

    func testNoMatchOnUnrelatedText() {
        XCTAssertFalse(matcher.matches("Had a great day at the park with friends."))
    }

    func testEmptyTextDoesNotMatch() {
        XCTAssertFalse(matcher.matches(""))
    }

    func testBundledPhraseListLoads() {
        let bundled = CrisisKeywordMatcher.loadDefault()
        XCTAssertFalse(bundled.phrases.isEmpty)
        XCTAssertTrue(bundled.matches("I want to kill myself"))
    }
}
