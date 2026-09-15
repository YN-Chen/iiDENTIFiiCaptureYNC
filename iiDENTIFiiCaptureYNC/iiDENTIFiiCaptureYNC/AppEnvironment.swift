//
//  AppEnvironment.swift
//  iiDENTIFiiCaptureYNC
//
//  Created by Yi-Nain Chen on 2026/09/15.
//

import Foundation

// NOTES:
// Main configuration file called once per app launch to create all the files needed for the pipeline.
// Example it starts off the local server, and creates the Upload manager.
// Singleton instance as we want to only have one instance of the pipelines functionality.
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let persistenceController = PersistenceController.shared
    let connectivityMonitor = ConnectivityMonitor()
    private let mockServer = MockUploadServer()
    private(set) var uploadManager: UploadManager?

    private init() {}

    func start() async {
        guard uploadManager == nil else { return }

        try? await mockServer.start()

        let transport = URLSessionUploadTransport(endpoint: mockServer.uploadURL)
        let uploadManager = UploadManager(
            persistenceController: persistenceController,
            transport: transport,
            connectivity: connectivityMonitor
        )
        self.uploadManager = uploadManager

        await uploadManager.resetStaleUploadingItemsAtLaunch()

        connectivityMonitor.start {
            Task { await uploadManager.attemptAllPending() }
        }

        await uploadManager.attemptAllPending()
        await BackgroundTaskScheduler.scheduleNextRefresh()
    }
}
