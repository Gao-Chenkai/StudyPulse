import XCTest
@testable import StudyPulse

final class MistakeImageRecognitionLLMTests: XCTestCase {
    func testParsesJSONWrappedInCodeFence() throws {
        let raw = """
        ```json
        {"question":"解 $x^2=1$","errorReason":"符号判断错误","wrongSolution":"$x=1$","correctSolution":"因此 $x=\\pm 1$"}
        ```
        """

        let result = try MistakeImageRecognitionLLM.parseResponse(raw)

        XCTAssertEqual(result.question, "解 $x^2=1$")
        XCTAssertEqual(result.wrongSolution, "$x=1$")
        XCTAssertTrue(result.correctSolution.contains("\\pm"))
    }

    func testRejectsMissingRequiredContent() {
        let raw = #"{"question":"题目","errorReason":"","wrongSolution":"","correctSolution":""}"#

        XCTAssertThrowsError(try MistakeImageRecognitionLLM.parseResponse(raw))
    }

    func testRepairsUnescapedLatexBackslashes() throws {
        let raw = #"""
        {"question":"求 $\frac{1}{2}$","errorReason":"计算错误","wrongSolution":"","correctSolution":"第一步
        答案是 $\sqrt{2}$"}
        """#

        let result = try MistakeImageRecognitionLLM.parseResponse(raw)

        XCTAssertEqual(result.question, #"求 $\frac{1}{2}$"#)
        XCTAssertEqual(result.correctSolution, "第一步\n" + #"答案是 $\sqrt{2}$"#)
    }
}
