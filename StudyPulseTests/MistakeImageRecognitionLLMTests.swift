import Testing
@testable import StudyPulse

struct MistakeImageRecognitionLLMTests {
    @Test
    func testParsesJSONWrappedInCodeFence() throws {
        let raw = """
        ```json
        {"question":"解 $x^2=1$","errorReason":"符号判断错误","wrongSolution":"$x=1$","correctSolution":"因此 $x=\\pm 1$"}
        ```
        """

        let result = try MistakeImageRecognitionLLM.parseResponse(raw)

        #expect(result.question == "解 $x^2=1$")
        #expect(result.wrongSolution == "$x=1$")
        #expect(result.correctSolution.contains("\\pm"))
    }

    @Test
    func testRejectsMissingRequiredContent() {
        let raw = #"{"question":"题目","errorReason":"","wrongSolution":"","correctSolution":""}"#

        #expect(throws: (any Error).self) {
            try MistakeImageRecognitionLLM.parseResponse(raw)
        }
    }

    @Test
    func testRepairsUnescapedLatexBackslashes() throws {
        let raw = #"""
        {"question":"求 $\frac{1}{2}$","errorReason":"计算错误","wrongSolution":"","correctSolution":"第一步
        答案是 $\sqrt{2}$"}
        """#

        let result = try MistakeImageRecognitionLLM.parseResponse(raw)

        #expect(result.question == #"求 $\frac{1}{2}$"#)
        #expect(result.correctSolution == "第一步\n" + #"答案是 $\sqrt{2}$"#)
    }
}
