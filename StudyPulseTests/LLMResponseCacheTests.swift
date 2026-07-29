import Testing
@testable import StudyPulse

struct LLMResponseCacheTests {
    @Test
    func testClearRemovesCachedResponseAndResetsCount() async {
        let cache = LLMResponseCache()
        let prompt = LLMPrompt(system: "system", messages: [.user("question")])

        await cache.set(caller: "test", prompt: prompt, config: .empty, response: "answer")
        #expect(await cache.entryCount == 1)
        #expect(await cache.get(caller: "test", prompt: prompt, config: .empty) == "answer")

        await cache.clear()

        #expect(await cache.entryCount == 0)
        #expect(await cache.get(caller: "test", prompt: prompt, config: .empty) == nil)
    }

    @Test
    func testExpiredEntriesAreNotCounted() async {
        let cache = LLMResponseCache(ttl: -1)
        let prompt = LLMPrompt(system: "system", messages: [.user("question")])
        await cache.set(caller: "test", prompt: prompt, config: .empty, response: "answer")

        #expect(await cache.entryCount == 0)
    }
}
