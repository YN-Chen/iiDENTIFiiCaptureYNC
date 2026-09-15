//
//  UploadManager.swift
//  iiDENTIFiiCaptureYNC
//
//  Created by Yi-Nain Chen on 2026/09/15.
//

import CoreData
import Foundation

// NOTES:
// Main manager that owns the upload lifecycle.
// UploadManager is an actor -> to guarantee that only one piece of code is running here at any given moment to prevent race conditions.
// resetStaleUploadingItemsAtLaunch() -> Safety net to make sure states get reset to .pending if there are items on app launch that have the states of .uploading
// handleDidEnterBackground() -> Handles the backgrounding of the app, by cancelling the uploading process and setting states to .pending so that a relaunch or foregrounding will retry uplaod of items that are in .pending state. Done so that it is deterministic when an app gets backgrounded, and not having to deal with the window of proccesses in flight when in background.
// guard connectivity.isSatisfied else { return } calls on ConnectivityMonitor to check the real state of network on the phone. This is due to the local HTTP server that bypasses Airplane mode, so we have to check for the real network state if Airplane mode is on. This isn't a problem when we have a real backend service.
actor UploadManager {
    private let persistenceController: PersistenceController
    private let transport: UploadTransport
    private let connectivity: ConnectivityProviding
    private var inFlightTasks: [NSManagedObjectID: Task<Void, Never>] = [:]

    private var context: NSManagedObjectContext { persistenceController.backgroundContext }

    init(persistenceController: PersistenceController, transport: UploadTransport, connectivity: ConnectivityProviding) {
        self.persistenceController = persistenceController
        self.transport = transport
        self.connectivity = connectivity
    }

    func resetStaleUploadingItemsAtLaunch() async {
        await context.perform { [context] in
            let request = CaptureItem.fetchRequest(status: .uploading)
            guard let items = try? context.fetch(request), !items.isEmpty else { return }
            for item in items {
                item.captureStatus = .pending
            }
            try? context.save()
        }
    }

    func handleDidEnterBackground() async {
        for task in inFlightTasks.values {
            task.cancel()
        }
        inFlightTasks.removeAll()

        await context.perform { [context] in
            let request = CaptureItem.fetchRequest(status: .uploading)
            guard let items = try? context.fetch(request), !items.isEmpty else { return }
            for item in items {
                item.captureStatus = .pending
            }
            try? context.save()
        }
    }

// MARK: - Upload Attempts functionality
    func attemptAllPending() async {
        let ids = await context.perform { [context] in
            let request = CaptureItem.fetchRequest(status: .pending)
            let items = (try? context.fetch(request)) ?? []
            return items.map(\.objectID)
        }
        for id in ids {
            attempt(itemID: id)
        }
    }

    func retry(itemID: NSManagedObjectID) {
        attempt(itemID: itemID, ignoreBackoff: true)
    }

    private func attempt(itemID: NSManagedObjectID, ignoreBackoff: Bool = false) {
        guard inFlightTasks[itemID] == nil else { return }
        inFlightTasks[itemID] = Task { [weak self] in
            await self?.performAttempt(itemID: itemID, ignoreBackoff: ignoreBackoff)
        }
    }

    private struct Snapshot {
        let id: UUID
        let imageData: Data
        let lastAttemptAt: Date?
        let retryCount: Int16
    }

    private func performAttempt(itemID: NSManagedObjectID, ignoreBackoff: Bool) async {
        defer { inFlightTasks[itemID] = nil }

        guard let snapshot = await snapshot(itemID: itemID) else { return }

        if !ignoreBackoff {
            let dueForRetry = BackoffPolicy.shouldAttempt(
                now: Date(),
                lastAttemptAt: snapshot.lastAttemptAt,
                retryCount: snapshot.retryCount
            )
            guard dueForRetry else { return }
        }

        guard connectivity.isSatisfied else { return }

        await markUploading(itemID: itemID)
        guard !Task.isCancelled else { return }

        do {
            try await transport.upload(id: snapshot.id, imageData: snapshot.imageData)
            guard !Task.isCancelled else { return }
            await markUploaded(itemID: itemID)
        } catch {
            guard !Task.isCancelled else { return }
            await markFailed(itemID: itemID, error: error)
        }
    }

// MARK: - Core Data tie in
    private func snapshot(itemID: NSManagedObjectID) async -> Snapshot? {
        await context.perform { [context] in
            guard let item = try? context.existingObject(with: itemID) as? CaptureItem,
                  let id = item.id, let data = item.imageData else {
                return nil
            }
            return Snapshot(id: id, imageData: data, lastAttemptAt: item.lastAttemptAt, retryCount: item.retryCount)
        }
    }

    private func markUploading(itemID: NSManagedObjectID) async {
        await context.perform { [context] in
            guard let item = try? context.existingObject(with: itemID) as? CaptureItem else { return }
            item.captureStatus = .uploading
            item.lastAttemptAt = Date()
            try? context.save()
        }
    }

    private func markUploaded(itemID: NSManagedObjectID) async {
        await context.perform { [context] in
            guard let item = try? context.existingObject(with: itemID) as? CaptureItem else { return }
            item.captureStatus = .uploaded
            item.lastError = nil
            try? context.save()
        }
    }

    private func markFailed(itemID: NSManagedObjectID, error: Error) async {
        await context.perform { [context] in
            guard let item = try? context.existingObject(with: itemID) as? CaptureItem else { return }
            item.captureStatus = .failed
            item.retryCount += 1
            item.lastError = error.localizedDescription
            try? context.save()
        }
    }
}
