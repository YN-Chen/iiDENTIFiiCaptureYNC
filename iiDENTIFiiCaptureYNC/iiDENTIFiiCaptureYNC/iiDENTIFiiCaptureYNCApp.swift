//
//  iiDENTIFiiCaptureYNCApp.swift
//  iiDENTIFiiCaptureYNC
//
//  Created by Yi-Nain Chen on 2026/09/15.
//

import CoreData
import SwiftUI

// NOTES:
// BGTaskScheduler registration must happen before the app finishes launching.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        BackgroundTaskScheduler.register {
            guard let uploadManager = await AppEnvironment.shared.uploadManager else { return }
            await uploadManager.attemptAllPending()
        }
        return true
    }
}

// NOTES:
// Root view setup for background/foreground execution paths.
@main
struct iiDENTIFiiCaptureYNCApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, AppEnvironment.shared.persistenceController.container.viewContext)
                .task {
                    await AppEnvironment.shared.start()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                Task {
                    await AppEnvironment.shared.uploadManager?.handleDidEnterBackground()
                    await BackgroundTaskScheduler.scheduleNextRefresh()
                }
            case .active:
                Task { await AppEnvironment.shared.uploadManager?.attemptAllPending() }
            default:
                break
            }
        }
    }
}
