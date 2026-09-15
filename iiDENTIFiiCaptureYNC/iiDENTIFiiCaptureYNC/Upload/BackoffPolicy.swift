//
//  BackoffPolicy.swift
//  iiDENTIFiiCaptureYNC
//
//  Created by Yi-Nain Chen on 2026/09/15.
//

import Foundation

// NOTES:
// Tight coupling free retry timing, kept on its own so it can be unit testable.
// Doubles timing from 2s after each failure, capped at 60s so that it won't run endlessly.
nonisolated enum BackoffPolicy {
    static let baseDelay: TimeInterval = 2
    static let maxDelay: TimeInterval = 60

    static func delay(forRetryCount retryCount: Int16) -> TimeInterval {
        guard retryCount > 0 else { return 0 }
        let exponent = Double(retryCount - 1)
        return min(baseDelay * pow(2, exponent), maxDelay)
    }

    static func shouldAttempt(now: Date, lastAttemptAt: Date?, retryCount: Int16) -> Bool {
        guard let lastAttemptAt else { return true }
        return now.timeIntervalSince(lastAttemptAt) >= delay(forRetryCount: retryCount)
    }
}
