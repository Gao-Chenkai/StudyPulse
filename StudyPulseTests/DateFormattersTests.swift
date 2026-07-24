//
//  DateFormattersTests.swift
//  StudyPulseTests
//
//  Unit tests for DateFormatters (Services/DateFormatters.swift).
//  Tests locale-stable POSIX formatters and convenience percent / decimal helpers.
//

import Foundation
import Testing
@testable import StudyPulse

@MainActor
struct DateFormattersTests {

    // Fixed reference date: 2026-03-15 14:30:00 UTC
    private let refDate: Date = {
        var c = DateComponents()
        c.year = 2026
        c.month = 3
        c.day = 15
        c.hour = 14
        c.minute = 30
        c.second = 0
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c) ?? Date()
    }()

    // MARK: - POSIX formatters (locale-stable)

    @Test
    func test_isoDate_posixFormat() {
        // 2026-03-15 → "2026-03-15" regardless of system locale
        let s = DateFormatters.isoDate.string(from: refDate)
        #expect(s == "2026-03-15")
    }

    @Test
    func test_fileTimestamp_posixFormat() {
        // 2026-03-15 14:30:00 UTC → "yyyyMMdd_HHmmss" pattern in system timezone.
        // We assert the shape and that the digits are sane, since the exact
        // HHmmss depends on the test runner's timezone.
        let s = DateFormatters.fileTimestamp.string(from: refDate)
        #expect(s.count == 15, "yyyyMMdd_HHmmss is 15 chars; got \(s)")
        // Pattern: 8 digits + "_" + 6 digits
        let pattern = #"^\d{8}_\d{6}$"#
        #expect(
            s.range(of: pattern, options: .regularExpression) != nil,
            "Expected yyyyMMdd_HHmmss pattern, got \(s)"
        )
    }

    @Test
    func test_monthDay_posixFormat() {
        // 03/15
        let s = DateFormatters.monthDay.string(from: refDate)
        #expect(s == "03/15")
    }

    @Test
    func test_dayOfMonth_singleDigitDay() {
        let s = DateFormatters.dayOfMonth.string(from: refDate)
        #expect(s == "15")
    }

    @Test
    func test_monthShort_threeLetter() {
        // `monthShort` uses the system locale, so the exact output varies
        // (e.g. "Mar" in en, "3月" in zh-Hans). We assert it's a non-empty
        // short string and looks like a month abbreviation.
        let s = DateFormatters.monthShort.string(from: refDate)
        #expect(!s.isEmpty)
        #expect(s.count <= 8, "Month abbreviation should be short; got \(s)")
    }

    // MARK: - Convenience percent

    @Test(
        arguments: [
            (value: 0.0, expected: "0%"),
            (value: 1.0, expected: "100%"),
            (value: 0.857, expected: "86%"),
            (value: 1.5, expected: "100%"),
            (value: -0.5, expected: "0%")
        ]
    )
    func scoreRateText(value: Double, expected: String) {
        #expect(DateFormatters.scoreRateText(value) == expected)
    }

    // MARK: - Convenience number strings

    @Test
    func test_integerString_thousandsSeparator() {
        #expect(DateFormatters.integerString(1234) == "1,234")
    }
}
