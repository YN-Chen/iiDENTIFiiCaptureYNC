//
//  LaunchSweepTests.swift
//  iiDENTIFiiCaptureYNC
//
//  Created by Yi-Nain Chen on 2026/09/15.
//

import CoreData
import XCTest
@testable import iiDENTIFiiCaptureYNC

final class LaunchSweepTests: XCTestCase {
    private var persistenceController: PersistenceController!
    private var sut: UploadManager!

    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        sut = UploadManager(
            persistenceController: persistenceController,
            transport: FakeUploadTransport(),
            connectivity: FakeConnectivity(isSatisfied: true)
        )
    }

    override func tearDown() {
        sut = nil
        persistenceController = nil
        super.tearDown()
    }

    func testResetStaleUploadingItemsAtLaunchResetsToPending() async throws {
        let context = persistenceController.backgroundContext
        var objectID: NSManagedObjectID?

        context.performAndWait {
            let item = CaptureItem.makeInsert(into: context, imageData: Data())
            item.captureStatus = .uploading
            do {
                try context.save()
                objectID = item.objectID
            } catch {
                XCTFail("Save failed: \(error)")
            }
        }
        let id = try XCTUnwrap(objectID)

        await sut.resetStaleUploadingItemsAtLaunch()

        let fetched = try context.existingObject(with: id) as? CaptureItem
        XCTAssertEqual(fetched?.captureStatus, .pending)
    }

    func testResetStaleUploadingItemsAtLaunchLeavesOtherStatusesUntouched() async throws {
        let context = persistenceController.backgroundContext
        var uploadedID: NSManagedObjectID?
        var failedID: NSManagedObjectID?

        context.performAndWait {
            let uploaded = CaptureItem.makeInsert(into: context, imageData: Data())
            uploaded.captureStatus = .uploaded
            let failed = CaptureItem.makeInsert(into: context, imageData: Data())
            failed.captureStatus = .failed
            do {
                try context.save()
                uploadedID = uploaded.objectID
                failedID = failed.objectID
            } catch {
                XCTFail("Save failed: \(error)")
            }
        }

        await sut.resetStaleUploadingItemsAtLaunch()

        let uploadedItem = try context.existingObject(with: try XCTUnwrap(uploadedID)) as? CaptureItem
        let failedItem = try context.existingObject(with: try XCTUnwrap(failedID)) as? CaptureItem
        XCTAssertEqual(uploadedItem?.captureStatus, .uploaded)
        XCTAssertEqual(failedItem?.captureStatus, .failed)
    }
}
