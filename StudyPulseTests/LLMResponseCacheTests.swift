import XCTest
@testable import StudyPulse

final class LLMResponseCacheTests: XCTestCase {
    func testClearRemovesCachedResponseAndResetsCount() {
        let cache = LLMResponseCache()
        let prompt = LLMPrompt(system: "system", messages: [.user("question")])

        cache.set(caller: "test", prompt: prompt, config: .empty, response: "answer")
        XCTAssertEqual(cache.entryCount, 1)
        XCTAssertEqual(cache.get(caller: "test", prompt: prompt, config: .empty), "answer")

        cache.clear()

        XCTAssertEqual(cache.entryCount, 0)
        XCTAssertNil(cache.get(caller: "test", prompt: prompt, config: .empty))
    }

    func testExpiredEntriesAreNotCounted() {
        let cache = LLMResponseCache(ttl: -1)
        let prompt = LLMPrompt(system: "system", messages: [.user("question")])
        cache.set(caller: "test", prompt: prompt, config: .empty, response: "answer")

        XCTAssertEqual(cache.entryCount, 0)
    }
}
