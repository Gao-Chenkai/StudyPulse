//
//  QuoteProviderTests.swift
//  StudyPulseTests
//
//  Unit tests for QuoteProvider (Services/QuoteProvider.swift).
//  Tests the day-of-year rotation logic and array integrity.
//

import XCTest
@testable import StudyPulse

@MainActor
final class QuoteProviderTests: XCTestCase {

    // MARK: - all

    func test_all_contains14Quotes() {
        // Service hardcodes 14 quotes ("Quote 1" .. "Quote 14")
        XCTAssertEqual(QuoteProvider.all.count, 14)
    }

    func test_all_noEmptyEntries() {
        XCTAssertFalse(QuoteProvider.all.contains { $0.isEmpty })
    }

    // MARK: - dailyQuote(for:)

    func test_dailyQuote_returnsNonEmptyString() {
        let q = QuoteProvider.dailyQuote(for: Date())
        XCTAssertFalse(q.isEmpty)
    }

    func test_dailyQuote_rotatesByDayOfYear() {
        // Two different day-of-year should return (very likely) different quotes.
        // We use day 1 vs day 8 to span more than 1 day.
        let cal = Calendar(identifier: .gregorian)
        var c1 = DateComponents(); c1.year = 2026; c1.month = 1; c1.day = 1
        var c2 = DateComponents(); c2.year = 2026; c2.month = 1; c2.day = 8
        let d1 = cal.date(from: c1) ?? Date()
        let d2 = cal.date(from: c2) ?? Date()
        let q1 = QuoteProvider.dailyQuote(for: d1)
        let q2 = QuoteProvider.dailyQuote(for: d2)
        XCTAssertNotEqual(q1, q2)
    }

    func test_dailyQuote_wrapsAroundAtYearEnd() {
        // day-of-year % 14 should land on Quote.all[14 % 14] = Quote.all[0] for some inputs
        // day 15 → 15 % 14 = 1 → all[1]; day 14 → 0
        let cal = Calendar(identifier: .gregorian)
        var c = DateComponents()
        c.year = 2026; c.month = 1; c.day = 14
        let date = cal.date(from: c) ?? Date()
        let expected = QuoteProvider.all[14 % QuoteProvider.all.count] // = all[0]
        XCTAssertEqual(QuoteProvider.dailyQuote(for: date), expected)
    }

    func test_dailyQuote_sameDay_returnsSameQuote() {
        // Two Date instances on the same day should yield the same quote.
        let cal = Calendar.current
        let morning = cal.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
        let evening = cal.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
        let q1 = QuoteProvider.dailyQuote(for: morning)
        let q2 = QuoteProvider.dailyQuote(for: evening)
        XCTAssertEqual(q1, q2)
    }
}
