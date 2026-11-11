@testable import Assistant
import Foundation
import XCTest

/// Phase 10 hardening of the real transport, served through a `URLProtocol` stub.
/// The stub picks its response from the request path, so it holds no shared state.
final class URLSessionTransportTests: XCTestCase {
    private func transport(limit: Int = 1024) -> URLSessionTransport {
        URLSessionTransport(timeout: 5, maxResponseBytes: limit, protocolClasses: [StubProtocol.self])
    }

    private func request(_ path: String) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com\(path)")!)
        request.setValue("sk-test-key", forHTTPHeaderField: "x-api-key")
        return request
    }

    func testSmallReplyIsReturned() async throws {
        let (data, status) = try await transport().send(request("/ok"))
        XCTAssertEqual(status, 200)
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "{}")
    }

    func testReplyOverLimitIsRejected() async throws {
        do {
            _ = try await transport(limit: 1024).send(request("/big"))
            XCTFail("expected size limit error")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .dataLengthExceedsMaximum)
        }
    }

    func testRedirectIsNotFollowed() async throws {
        let (_, status) = try await transport().send(request("/redirect"))
        XCTAssertEqual(status, 302, "the key header must never be replayed to the Location host")
        XCTAssertFalse(StubProtocol.sawRedirectTarget, "the redirect target was requested")
    }
}

private final class StubProtocol: URLProtocol, @unchecked Sendable {
    /// Set if the client ever requests the redirect target; read once per test.
    nonisolated(unsafe) static var sawRedirectTarget = false

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let client else { return }
        if url.host == "elsewhere.example" { Self.sawRedirectTarget = true }
        switch url.path {
        case "/redirect":
            let response = HTTPURLResponse(url: url, statusCode: 302, httpVersion: "HTTP/1.1", headerFields: ["Location": "https://elsewhere.example/steal"])!
            var next = URLRequest(url: URL(string: "https://elsewhere.example/steal")!)
            next.allHTTPHeaderFields = request.allHTTPHeaderFields
            client.urlProtocol(self, wasRedirectedTo: next, redirectResponse: response)
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client.urlProtocolDidFinishLoading(self)
        case "/big":
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client.urlProtocol(self, didLoad: Data(repeating: 0x41, count: 4096))
            client.urlProtocolDidFinishLoading(self)
        default:
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client.urlProtocol(self, didLoad: Data("{}".utf8))
            client.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
