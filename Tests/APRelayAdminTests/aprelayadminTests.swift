import AsyncHTTPClient
import Foundation
import NIOCore
import NIOEmbedded
import NIOHTTP1
import Testing
@testable import APRelayAdmin

@Test func subscriberActionsBuildExpectedRequests() throws {
    var requests: [HTTPClient.Request] = []
    let client = AdminAPIClient(
        relayURL: "https://relay.example",
        adminToken: "secret"
    ) {
        requests.append($0)
        return httpResponse()
    }

    try client.acceptSubscriber(domain: "example.com")
    try client.rejectSubscriber(domain: "example.org")
    try client.deleteSubscriber(domain: "example.net")

    #expect(requests.map(\.method) == [.POST, .POST, .DELETE])
    #expect(
        requests.map(\.url.absoluteString) == [
            "https://relay.example/api/admin/subscribers/example.com/accept",
            "https://relay.example/api/admin/subscribers/example.org/reject",
            "https://relay.example/api/admin/subscribers/example.net",
        ]
    )
    #expect(
        requests.allSatisfy {
            $0.headers.first(name: "Authorization") == "Bearer secret"
        }
    )
}

@Test func blockedDomainListBuildsExpectedRequest() throws {
    var request: HTTPClient.Request?
    let client = AdminAPIClient(
        relayURL: "https://relay.example",
        adminToken: "secret"
    ) {
        request = $0
        return httpResponse(
            body: """
            [
                {"domain":"z.example","reason":null,"createdAt":null},
                {"domain":"a.example","reason":"spam","createdAt":null}
            ]
            """
        )
    }

    let blockedDomains = try client.listBlockedDomains()

    #expect(request?.method == .GET)
    #expect(request?.url.absoluteString == "https://relay.example/api/admin/blocked-domains")
    #expect(request?.headers.first(name: "Authorization") == "Bearer secret")
    #expect(blockedDomains.map(\.domain) == ["a.example", "z.example"])
}

@Test func blockedDomainActionsBuildExpectedRequests() throws {
    var requests: [HTTPClient.Request] = []
    let client = AdminAPIClient(
        relayURL: "https://relay.example",
        adminToken: "secret"
    ) {
        requests.append($0)
        return httpResponse()
    }

    try client.blockDomain(domain: "example.com", reason: "spam")
    try client.unblockDomain(domain: "example.org")

    #expect(requests.map(\.method) == [.POST, .DELETE])
    #expect(
        requests.map(\.url.absoluteString) == [
            "https://relay.example/api/admin/blocked-domains",
            "https://relay.example/api/admin/blocked-domains/example.org",
        ]
    )
    #expect(
        requests.allSatisfy {
            $0.headers.first(name: "Authorization") == "Bearer secret"
        }
    )
    #expect(requests.first?.headers.first(name: "Content-Type") == "application/json")

    let body = try #require(requests.first?.body)
    let requestBody = try JSONDecoder().decode(BlockDomainRequestBody.self, from: try data(from: body))
    #expect(requestBody.domain == "example.com")
    #expect(requestBody.reason == "spam")
}

@Test func blockDomainOmitsEmptyReasonBodyValue() throws {
    var request: HTTPClient.Request?
    let client = AdminAPIClient(
        relayURL: "https://relay.example",
        adminToken: "secret"
    ) {
        request = $0
        return httpResponse()
    }

    try client.blockDomain(domain: "example.com", reason: nil)

    let body = try #require(request?.body)
    let bodyData = try data(from: body)
    let requestBody = try JSONDecoder().decode(BlockDomainRequestBody.self, from: bodyData)
    let json = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
    #expect(requestBody.domain == "example.com")
    #expect(requestBody.reason == nil)
    #expect(json["reason"] == nil)
}

@Test func unblockDomainEncodesDomainPathSegment() throws {
    var request: HTTPClient.Request?
    let client = AdminAPIClient(
        relayURL: "https://relay.example",
        adminToken: "secret"
    ) {
        request = $0
        return httpResponse()
    }

    try client.unblockDomain(domain: "example.com:8443")

    #expect(
        request?.url.absoluteString == "https://relay.example/api/admin/blocked-domains/example.com%3A8443"
    )
}

@Test func subscriberActionEncodesDomainPathSegment() throws {
    var request: HTTPClient.Request?
    let client = AdminAPIClient(
        relayURL: "https://relay.example",
        adminToken: "secret"
    ) {
        request = $0
        return httpResponse()
    }

    try client.deleteSubscriber(domain: "example.com:8443")

    #expect(
        request?.url.absoluteString == "https://relay.example/api/admin/subscribers/example.com%3A8443"
    )
}

@Test func subscriberActionReportsNonSuccessStatus() throws {
    let client = AdminAPIClient(
        relayURL: "https://relay.example",
        adminToken: "secret"
    ) {
        _ in

        return httpResponse(status: .notFound, body: "missing")
    }

    do {
        try client.deleteSubscriber(domain: "missing.example")
        Issue.record("Expected deleteSubscriber to throw.")
    } catch let error as AdminAPIClient.Error {
        switch error {
        case .requestFailed(let status, let reason):
            #expect(status == 404)
            #expect(reason == "missing")
        default:
            Issue.record("Expected requestFailed, got \(error).")
        }
    } catch {
        Issue.record("Expected AdminAPIClient.Error, got \(error).")
    }
}

private struct BlockDomainRequestBody: Decodable {

    let domain: String

    let reason: String?
}

private final class BodyCollector: @unchecked Sendable {

    private var buffer = ByteBuffer()

    func append(_ data: IOData) {
        switch data {
        case .byteBuffer(var part):
            buffer.writeBuffer(&part)
        case .fileRegion:
            break
        }
    }

    func data() -> Data {
        Data(buffer.readableBytesView)
    }
}

private func data(from body: HTTPClient.Body) throws -> Data {
    let eventLoop = EmbeddedEventLoop()
    let collector = BodyCollector()
    let writer = HTTPClient.Body.StreamWriter {
        data in

        collector.append(data)
        return eventLoop.makeSucceededFuture(())
    }
    try body.stream(writer).wait()
    return collector.data()
}

private func httpResponse(
    status: HTTPResponseStatus = .ok,
    body: String = "[]"
) -> HTTPClient.Response {
    var buffer = ByteBufferAllocator().buffer(capacity: body.utf8.count)
    buffer.writeString(body)

    return HTTPClient.Response(
        host: "relay.example",
        status: status,
        version: HTTPVersion(major: 1, minor: 1),
        headers: HTTPHeaders(),
        body: buffer
    )
}
