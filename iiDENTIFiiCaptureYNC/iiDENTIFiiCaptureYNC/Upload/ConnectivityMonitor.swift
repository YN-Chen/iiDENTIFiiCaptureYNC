//
//  ConnectivityMonitor.swift
//  iiDENTIFiiCaptureYNC
//
//  Created by Yi-Nain Chen on 2026/09/15.
//

import Foundation
import Network

/// Abstracts "is there a real network path right now," mirroring the same
/// protocol-for-testability pattern as `UploadTransport` — tests can inject a fake
/// that's always/never satisfied without touching real networking.
// NOTES:
// Wrapper for Apple's NWPathMonitor to monitor connectivity.
// Because the mock backend HTTP server is running locally when turning on Airplane Mode, it does not stop the app from successfully reaching that local server as its self contained and it won't pick up Airplane mode, so this is to monitor the actual OS network state.
nonisolated protocol ConnectivityProviding: Sendable {
    var isSatisfied: Bool { get }
}

nonisolated final class ConnectivityMonitor: ConnectivityProviding, @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ConnectivityMonitor")

    var isSatisfied: Bool {
        monitor.currentPath.status == .satisfied
    }

    func start(onSatisfied: @escaping @Sendable () -> Void) {
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                onSatisfied()
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }
}
