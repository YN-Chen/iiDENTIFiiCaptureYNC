//
//  PersistenceController.swift
//  iiDENTIFiiCaptureYNC
//
//  Created by Yi-Nain Chen on 2026/09/15.
//

import CoreData

// NOTES:
// if the loadPersistentStores fails with error it just fatal errors for now for this POC.
// In a finalised app it could fail gracefully to some sort of error handling screen that gets displayed in UI.
struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer
    let backgroundContext: NSManagedObjectContext

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "CaptureModel")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Unresolved Core Data error: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        backgroundContext = container.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
