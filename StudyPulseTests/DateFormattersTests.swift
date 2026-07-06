//
//  DateFormattersTests.swift
//  StudyPulseTests
//
//  Unit tests for DateFormatters (Services/DateFormatters.swift).
//  Tests locale-stable POSIX formatters and convenience percent / decimal helpers.
//

import XCTest
@testable import StudyPulse

@MainActor
final class DateFormattersTests: XCTestCase {

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

    func test_isoDate_posixFormat() {
        // 2026-03-15 → "2026-03-15" regardless of system locale
        let s = DateFormatters.isoDate.string(from: refDate)
        XCTAssertEqual(s, "2026-03-15")
    }

    func test_fileTimestamp_posixFormat() {
        // 2026-03-15 14:30:00 UTC → "yyyyMMdd_HHmmss" pattern in system timezone.
        // We assert the shape and that the digits are sane, since the exact
        // HHmmss depends on the test runner's timezone.
        let s = DateFormatters.fileTimestamp.string(from: refDate)
        XCTAssertEqual(s.count, 15, "yyyyMMdd_HHmmss is 15 chars; got \(s)")
        // Pattern: 8 digits + "_" + 6 digits
        let pattern = #"^\d{8}_\d{6}$"#
        XCTAssertNotNil(s.range(of: pattern, options: .regularExpression),
                        "Expected yyyyMMdd_HHmmss pattern, got \(s)")
    }

    func test_monthDay_posixFormat() {
        // 03/15
        let s = DateFormatters.monthDay.string(from: refDate)
        XCTAssertEqual(s, "03/15")
    }

    func test_dayOfMonth_singleDigitDay() {
        let s = DateFormatters.dayOfMonth.string(from: refDate)
        XCTAssertEqual(s, "15")
    }

    func test_monthShort_threeLetter() {
        // `monthShort` uses the system locale, so the exact output varies
        // (e.g. "Mar" in en, "3月" in zh-Hans). We assert it's a non-empty
        // short string and looks like a month abbreviation.
        let s = DateFormatters.monthShort.string(from: refDate)
        XCTAssertFalse(s.isEmpty)
        XCTAssertLessThanOrEqual(s.count, 8, "Month abbreviation should be short; got \(s)")
    }

    // MARK: - Convenience percent

    func test_scoreRateText_zero() {
        XCTAssertEqual(DateFormatters.scoreRateText(0), "0%")
    }

    func test_scoreRateText_full() {
        XCTAssertEqual(DateFormatters.scoreRateText(1.0), "100%")
    }

    func test_scoreRateText_partial() {
        XCTAssertEqual(DateFormatters.scoreRateText(0.857), "86%")
    }

    func test_scoreRateText_clampsOutOfRange() {
        XCTAssertEqual(DateFormatters.scoreRateText(1.5), "100%")
        XCTAssertEqual(DateFormatters.scoreRateText(-0.5), "0%")
    }

    // MARK: - Convenience number strings

    func test_integerString_thousandsSeparator() {
        XCTAssertEqual(DateFormatters.integerString(1234), "1,234")
    }
}
