//
//  UploadManagerTests.swift
//  iiDENTIFiiCaptureYNC
//
//  Created by Yi-Nain Chen on 2026/09/15.
//

import CoreData
import XCTest
@testable import iiDENTIFiiCaptureYNC

final class UploadManagerTests: XCTestCase {
    private var persistenceController: PersistenceController!
    private var transport: FakeUploadTransport!
    private var connectivity: FakeConnectivity!
    private var sut: UploadManager!

    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        transport = FakeUploadTransport()
        connectivity = FakeConnectivity(isSatisfied: true)
        sut = UploadManager(persistenceController: persistenceController, transport: transport, connectivity: connectivity)
    }

    override func tearDown() {
        sut = nil
        transport = nil
        connectivity = nil
        persistenceController = nil
        super.tearDown()
    }

// MARK: - Helpers
    @discardableResult
    private func insertItem(status: CaptureStatus = .pending) -> NSManagedObjectID {
        let context = persistenceController.backgroundContext
        var objectID: NSManagedObjectID!
        context.performAndWait {
            let item = CaptureItem.makeInsert(into: context, imageData: Data([0xAA]))
            item.captureStatus = status
            try? context.save()
            objectID = item.objectID
        }
        return objectID
    }

    private func status(of objectID: NSManagedObjectID) -> CaptureStatus? {
        let context = persistenceController.backgroundContext
        var result: CaptureStatus?
        context.performAndWait {
            let item = try? context.existingObject(with: objectID) as? CaptureItem
            result = item?.captureStatus
        }
        return result
    }

// MARK: - Attempt / success / failure
    func testAttemptAllPendingUploadsSuccessfully() async {
        let id = insertItem()

        await sut.attemptAllPending()
        await sut.waitForInFlightTasks()

        XCTAssertEqual(status(of: id), .uploaded)
        let callCount = await transport.uploadCallCount
        XCTAssertEqual(callCount, 1)
    }

    func testFailedUploadMarksItemFailedAndIncrementsRetryCount() async {
        await transport.setBehavior(.fail)
        let id = insertItem()

        await sut.attemptAllPending()
        await sut.waitForInFlightTasks()

        XCTAssertEqual(status(of: id), .failed)
    }

// MARK: - Connectivity gate
    func testAttemptAllPendingSkipsWhenConnectivityUnsatisfied() async {
        connectivity.isSatisfied = false
        let id = insertItem()

        await sut.attemptAllPending()
        await sut.waitForInFlightTasks()

        XCTAssertEqual(status(of: id), .pending)
        let callCount = await transport.uploadCallCount
        XCTAssertEqual(callCount, 0)
    }

// MARK: - Manual retry bypasses backoff
    func testManualRetryBypassesBackoffWait() async {
        await transport.setBehavior(.fail)
        let id = insertItem()

        await sut.attemptAllPending()
        await sut.waitForInFlightTasks()
        XCTAssertEqual(status(of: id), .failed) // first attempt fails, backoff window starts

        await transport.setBehavior(.succeed)
        // Immediately after a failure the 2s backoff window hasn't elapsed —
        // attemptAllPending()'s normal path would skip it; retry() bypasses that.
        await sut.retry(itemID: id)
        await sut.waitForInFlightTasks()

        XCTAssertEqual(status(of: id), .uploaded)
    }

// MARK: - In-flight guard prevents duplicate uploads
    func testConcurrentAttemptsDoNotDuplicateUpload() async {
        let id = insertItem()

        async let first: Void = sut.attemptAllPending()
        async let second: Void = sut.attemptAllPending()
        _ = await (first, second)
        await sut.waitForInFlightTasks()

        let callCount = await transport.uploadCallCount
        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(status(of: id), .uploaded)
    }

// MARK: - Backgrounding
    func testHandleDidEnterBackgroundResetsUploadingToPending() async {
        let id = insertItem(status: .uploading)

        await sut.handleDidEnterBackground()

        XCTAssertEqual(status(of: id), .pending)
    }
}
