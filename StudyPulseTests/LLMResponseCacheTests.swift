import Testing
@testable import StudyPulse

struct LLMResponseCacheTests {
    @Test
    func testClearRemovesCachedResponseAndResetsCount() {
        let cache = LLMResponseCache()
        let prompt = LLMPrompt(system: "system", messages: [.user("question")])

        cache.set(caller: "test", prompt: prompt, config: .empty, response: "answer")
        #expect(cache.entryCount == 1)
        #expect(cache.get(caller: "test", prompt: prompt, config: .empty) == "answer")

        cache.clear()

        #expect(cache.entryCount == 0)
        #expect(cache.get(caller: "test", prompt: prompt, config: .empty) == nil)
    }

    @Test
    func testExpiredEntriesAreNotCounted() {
        let cache = LLMResponseCache(ttl: -1)
        let prompt = LLMPrompt(system: "system", messages: [.user("question")])
        cache.set(caller: "test", prompt: prompt, config: .empty, response: "answer")

        #expect(cache.entryCount == 0)
    }
}
