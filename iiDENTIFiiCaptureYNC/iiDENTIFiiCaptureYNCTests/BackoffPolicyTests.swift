//
//  BackoffPolicyTests.swift
//  iiDENTIFiiCaptureYNC
//
//  Created by Yi-Nain Chen on 2026/09/15.
//

import XCTest
@testable import iiDENTIFiiCaptureYNC

final class BackoffPolicyTests: XCTestCase {
    func testDelayIsZeroForNeverAttempted() {
        XCTAssertEqual(BackoffPolicy.delay(forRetryCount: 0), 0)
    }

    func testDelayDoublesWithEachRetry() {
        XCTAssertEqual(BackoffPolicy.delay(forRetryCount: 1), 2)
        XCTAssertEqual(BackoffPolicy.delay(forRetryCount: 2), 4)
        XCTAssertEqual(BackoffPolicy.delay(forRetryCount: 3), 8)
        XCTAssertEqual(BackoffPolicy.delay(forRetryCount: 4), 16)
    }

    func testDelayIsCappedAtMaxDelay() {
        XCTAssertEqual(BackoffPolicy.delay(forRetryCount: 10), BackoffPolicy.maxDelay)
    }

    func testShouldAttemptIsTrueWhenNeverAttempted() {
        XCTAssertTrue(BackoffPolicy.shouldAttempt(now: Date(), lastAttemptAt: nil, retryCount: 0))
    }

    func testShouldAttemptIsFalseBeforeDelayElapses() {
        let lastAttempt = Date()
        let now = lastAttempt.addingTimeInterval(1) // < 2s delay for retryCount 1
        XCTAssertFalse(BackoffPolicy.shouldAttempt(now: now, lastAttemptAt: lastAttempt, retryCount: 1))
    }

    func testShouldAttemptIsTrueAfterDelayElapses() {
        let lastAttempt = Date()
        let now = lastAttempt.addingTimeInterval(2.5) // > 2s delay for retryCount 1
        XCTAssertTrue(BackoffPolicy.shouldAttempt(now: now, lastAttemptAt: lastAttempt, retryCount: 1))
    }
}
