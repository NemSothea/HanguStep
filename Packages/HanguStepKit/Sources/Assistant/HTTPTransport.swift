import Foundation

/// The one seam between the Claude provider and the network, so tests can stub
/// responses without URLProtocol tricks.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (data: Data, status: Int)
}

/// Ephemeral session: no cookies, no URL cache, no credential storage on disk.
/// Phase 10 hardening: redirects are never followed (the API key header must not
/// reach another host) and replies are capped in size before they are decoded.
public struct URLSessionTransport: HTTPTransport {
    /// A Messages API reply for `max_tokens` 8192 is well under 100 KB.
    public static let defaultMaxResponseBytes = 1_048_576

    private let session: URLSession
    private let maxResponseBytes: Int

    public init(timeout: TimeInterval = 90, maxResponseBytes: Int = URLSessionTransport.defaultMaxResponseBytes) {
        self.init(timeout: timeout, maxResponseBytes: maxResponseBytes, protocolClasses: nil)
    }

    /// `protocolClasses` lets tests serve responses through a `URLProtocol` stub.
    init(timeout: TimeInterval, maxResponseBytes: Int, protocolClasses: [AnyClass]?) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.waitsForConnectivity = false
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        if let protocolClasses { configuration.protocolClasses = protocolClasses }
        session = URLSession(configuration: configuration)
        self.maxResponseBytes = maxResponseBytes
    }

    public func send(_ request: URLRequest) async throws -> (data: Data, status: Int) {
        let (bytes, response) = try await session.bytes(for: request, delegate: RefuseRedirects.shared)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if http.expectedContentLength > Int64(maxResponseBytes) {
            bytes.task.cancel()
            throw URLError(.dataLengthExceedsMaximum)
        }
        var data = Data()
        data.reserveCapacity(min(Int(max(http.expectedContentLength, 0)), maxResponseBytes))
        for try await byte in bytes {
            data.append(byte)
            if data.count > maxResponseBytes {
                bytes.task.cancel()
                throw URLError(.dataLengthExceedsMaximum)
            }
        }
        return (data, http.statusCode)
    }
}

/// Returning `nil` hands the 3xx response itself back to the caller, which the
/// provider reports as an invalid response.
private final class RefuseRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    static let shared = RefuseRedirects()

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest) async -> URLRequest? {
        nil
    }
}
