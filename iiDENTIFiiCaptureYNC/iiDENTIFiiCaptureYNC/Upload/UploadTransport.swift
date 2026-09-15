//
//  UploadTransport.swift
//  iiDENTIFiiCaptureYNC
//
//  Created by Yi-Nain Chen on 2026/09/15.
//

import Foundation

// NOTES:
// Protocol implementation with concrete implementation for the Network call
// Protocol driven so that it decouples the concrete transport to make it unit testable with test stubs.
nonisolated protocol UploadTransport: Sendable {
    func upload(id: UUID, imageData: Data) async throws
}

enum UploadTransportError: Error {
    case serverError(statusCode: Int)
}


struct URLSessionUploadTransport: UploadTransport {
    let endpoint: URL
    let session: URLSession

    init(endpoint: URL, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    func upload(id: UUID, imageData: Data) async throws {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue(id.uuidString, forHTTPHeaderField: "X-Capture-Id")

        let (_, response) = try await session.upload(for: request, from: imageData)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw UploadTransportError.serverError(statusCode: statusCode)
        }
    }
}
