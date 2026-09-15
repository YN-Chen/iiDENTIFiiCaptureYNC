//
//  PersistenceTests.swift
//  iiDENTIFiiCaptureYNC
//
//  Created by Yi-Nain Chen on 2026/09/15.
//

import CoreData
import XCTest
@testable import iiDENTIFiiCaptureYNC

final class PersistenceTests: XCTestCase {
    private var persistenceController: PersistenceController!

    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
    }

    override func tearDown() {
        persistenceController = nil
        super.tearDown()
    }

    func testMakeInsertPersistsAsPending() throws {
        let context = persistenceController.backgroundContext
        let imageData = Data([0x01, 0x02, 0x03])
        var objectID: NSManagedObjectID?

        context.performAndWait {
            let item = CaptureItem.makeInsert(into: context, imageData: imageData)
            do {
                try context.save()
                objectID = item.objectID
            } catch {
                XCTFail("Save failed: \(error)")
            }
        }

        let id = try XCTUnwrap(objectID)
        let fetched = try context.existingObject(with: id) as? CaptureItem
        XCTAssertEqual(fetched?.captureStatus, .pending)
        XCTAssertEqual(fetched?.imageData, imageData)
        XCTAssertEqual(fetched?.retryCount, 0)
        XCTAssertNotNil(fetched?.id)
        XCTAssertNotNil(fetched?.createdAt)
    }

    func testFetchRequestByStatusFiltersCorrectly() throws {
        let context = persistenceController.backgroundContext

        context.performAndWait {
            let pendingItem = CaptureItem.makeInsert(into: context, imageData: Data())
            let uploadedItem = CaptureItem.makeInsert(into: context, imageData: Data())
            uploadedItem.captureStatus = .uploaded
            do {
                try context.save()
            } catch {
                XCTFail("Save failed: \(error)")
            }
            _ = pendingItem
        }

        let pendingItems = try context.fetch(CaptureItem.fetchRequest(status: .pending))
        let uploadedItems = try context.fetch(CaptureItem.fetchRequest(status: .uploaded))

        XCTAssertEqual(pendingItems.count, 1)
        XCTAssertEqual(uploadedItems.count, 1)
    }

    func testCaptureStatusDefaultsToPendingForUnknownRawValue() {
        let context = persistenceController.backgroundContext

        context.performAndWait {
            let item = CaptureItem.makeInsert(into: context, imageData: Data())
            item.status = "not-a-real-status"
            XCTAssertEqual(item.captureStatus, .pending)
        }
    }
}
