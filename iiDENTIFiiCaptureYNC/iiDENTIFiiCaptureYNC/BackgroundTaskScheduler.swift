//
//  BackgroundTaskScheduler.swift
//  iiDENTIFiiCaptureYNC
//
//  Created by Yi-Nain Chen on 2026/09/15.
//

import BackgroundTasks
import Foundation

// NOTES:
// Wraps Apple's BGTaskScheduler API -> register(handler:) && scheduleNextRefresh()
// Registers the background task scheduler once on app launch to schedule.
// To handle cases of if app is not launched for a long time that a background task will trigger and auto upload the pending items.
// The background task scheduler is next best effort due to how iOS sets a custom algorithm of when the background task should run based on the individuals device usage.
// submitTaskRequest(_:) is iOS 27+ only, submit(_:) is the fallback for older deployment targets/devices.
nonisolated enum BackgroundTaskScheduler {
    static let refreshTaskIdentifier = "com.iidentifii.capture.refresh"

    static func register(handler: @escaping @Sendable () async -> Void) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }

            let work = Task {
                await scheduleNextRefresh()
                await handler()
                refreshTask.setTaskCompleted(success: true)
            }

            refreshTask.expirationHandler = {
                work.cancel()
            }
        }
    }

    static func scheduleNextRefresh() async {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

        if #available(iOS 27.0, *) {
            try? await BGTaskScheduler.shared.submitTaskRequest(request)
        } else {
            try? BGTaskScheduler.shared.submit(request)
        }
    }
}
