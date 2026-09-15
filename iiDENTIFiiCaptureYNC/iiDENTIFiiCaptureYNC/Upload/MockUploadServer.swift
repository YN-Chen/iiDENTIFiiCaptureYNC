//
//  MockUploadServer.swift
//  iiDENTIFiiCaptureYNC
//
//  Created by Yi-Nain Chen on 2026/09/15.
//

import Foundation
import Network

// NOTES:
// This is a tiny real HTTP server that hand-parses raw HTTP just enough to find content length, wait for the full body, and reply 200 OK
// This is added to mimick a real server since we don't have a real backend service
nonisolated final class MockUploadServer: @unchecked Sendable {
    private(set) var port: UInt16 = 0
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "MockUploadServer")

    var uploadURL: URL {
        URL(string: "http://127.0.0.1:\(port)/upload")!
    }

    func start() async throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        let listener = try NWListener(using: parameters, on: .any)
        self.listener = listener

        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            listener.stateUpdateHandler = { [weak self, weak listener] state in
                switch state {
                case .ready:
                    listener?.stateUpdateHandler = { _ in }
                    self?.port = listener?.port?.rawValue ?? 0
                    continuation.resume()
                case .failed(let error):
                    listener?.stateUpdateHandler = { _ in }
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            listener.start(queue: queue)
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            var newBuffer = buffer
            if let data, !data.isEmpty {
                newBuffer.append(data)
            }

            if let response = self.completedResponse(for: newBuffer) {
                self.send(response, on: connection)
                return
            }

            if isComplete || error != nil {
                connection.cancel()
                return
            }

            self.receive(on: connection, buffer: newBuffer)
        }
    }

    private func completedResponse(for buffer: Data) -> Data? {
        guard let headerEndRange = buffer.range(of: Data("\r\n\r\n".utf8)) else {
            return nil
        }

        let headerData = buffer[..<headerEndRange.lowerBound]
        let headerString = String(decoding: headerData, as: UTF8.self)
        let contentLength = Self.contentLength(fromHeaders: headerString)

        let bodyLength = buffer.distance(from: headerEndRange.upperBound, to: buffer.endIndex)
        guard bodyLength >= contentLength else { return nil }

        return Self.okResponse()
    }

    private static func contentLength(fromHeaders headerString: String) -> Int {
        for line in headerString.split(separator: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = String(parts[0]).trimmingCharacters(in: .whitespaces).lowercased()
            guard key == "content-length" else { continue }
            return Int(String(parts[1]).trimmingCharacters(in: .whitespaces)) ?? 0
        }
        return 0
    }

    private static func okResponse() -> Data {
        let body = "{\"status\":\"ok\"}"
        let response = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        return Data(response.utf8)
    }

    private func send(_ response: Data, on connection: NWConnection) {
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
