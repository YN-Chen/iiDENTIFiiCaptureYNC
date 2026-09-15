//
//  Fakes.swift
//  iiDENTIFiiCaptureYNC
//
//  Created by Yi-Nain Chen on 2026/09/15.
//

import Foundation
@testable import iiDENTIFiiCaptureYNC

struct FakeError: Error {}

final actor FakeUploadTransport: UploadTransport {
    enum Behavior: Sendable {
        case succeed
        case fail
    }

    private(set) var uploadCallCount = 0
    private(set) var uploadedIDs: [UUID] = []
    private var behavior: Behavior = .succeed

    func setBehavior(_ behavior: Behavior) {
        self.behavior = behavior
    }

    func upload(id: UUID, imageData: Data) async throws {
        uploadCallCount += 1
        uploadedIDs.append(id)
        switch behavior {
        case .succeed:
            return
        case .fail:
            throw FakeError()
        }
    }
}

final class FakeConnectivity: ConnectivityProviding, @unchecked Sendable {
    var isSatisfied: Bool

    init(isSatisfied: Bool) {
        self.isSatisfied = isSatisfied
    }
}
