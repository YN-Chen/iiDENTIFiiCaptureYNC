//
//  CaptureItem+Support.swift
//  iiDENTIFiiCaptureYNC
//
//  Created by Yi-Nain Chen on 2026/09/15.
//

import CoreData
import Foundation

enum CaptureStatus: String {
    case pending
    case uploading
    case uploaded
    case failed
}

// NOTES:
// makeInsert -> Creates and inserts a new item as .pending`, before any network call is attempted.
extension CaptureItem {
    var captureStatus: CaptureStatus {
        get { CaptureStatus(rawValue: status ?? "") ?? .pending }
        set { status = newValue.rawValue }
    }

    @discardableResult
    static func makeInsert(into context: NSManagedObjectContext, imageData: Data) -> CaptureItem {
        let item = CaptureItem(context: context)
        item.id = UUID()
        item.createdAt = Date()
        item.imageData = imageData
        item.retryCount = 0
        item.captureStatus = .pending
        return item
    }

    static func fetchRequest(status: CaptureStatus) -> NSFetchRequest<CaptureItem> {
        let request = CaptureItem.fetchRequest()
        request.predicate = NSPredicate(format: "status == %@", status.rawValue)
        return request
    }

    static func allItemsSortedByCreatedAt() -> NSFetchRequest<CaptureItem> {
        let request = CaptureItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CaptureItem.createdAt, ascending: false)]
        return request
    }
}
