import AsyncHTTPClient
import Foundation
import NIOCore
import NIOHTTP1

struct AdminAPIClient {

    typealias RequestExecutor = (HTTPClient.Request) throws -> HTTPClient.Response

    enum SubscriberState: String, Decodable {

        case pending

        case accepted

        case rejected
    }

    enum Error: Swift.Error, CustomStringConvertible {

        case missingRelayURL

        case invalidRelayURL(String)

        case missingAdminToken

        case connectionFailed(String)

        case requestFailed(status: Int, reason: String)

        case invalidResponse(String)

        var description: String {
            switch self {
            case .missingRelayURL:
                return "Relay URL is not configured."
            case .invalidRelayURL(let value):
                return "Relay URL is invalid: \(value)"
            case .missingAdminToken:
                return "Admin token is not configured."
            case .connectionFailed(let detail):
                return "Could not connect to the relay server. \(detail)"
            case .requestFailed(let status, let reason):
                return "Request failed (\(status)): \(reason)"
            case .invalidResponse(let detail):
                return "Invalid response from relay server. \(detail)"
            }
        }
    }

    struct Subscriber: Decodable {

        let domain: String

        let inboxURL: String

        let actorID: String

        let state: SubscriberState

        let followActivityID: String

        let followObjectURI: String?

        let outboundFollowActivityID: String?

        let createdAt: Date?

        let updatedAt: Date?
    }

    struct BlockedDomain: Decodable {

        let domain: String

        let reason: String?

        let createdAt: Date?
    }

    private struct BlockRequest: Encodable {

        let domain: String

        let reason: String?
    }

    private let relayURL: String

    private let adminToken: String

    private let executeRequest: RequestExecutor

    init(
        relayURL: String,
        adminToken: String,
        executeRequest: @escaping RequestExecutor = { try HTTPClient.shared.execute(request: $0).wait() }
    ) {
        self.relayURL = relayURL.trimmingCharacters(in: .whitespacesAndNewlines)
        self.adminToken = adminToken.trimmingCharacters(in: .whitespacesAndNewlines)
        self.executeRequest = executeRequest
    }

    func listSubscriberDomains(state: SubscriberState) throws -> [Subscriber] {
        let data = try performRequest(
            method: .GET,
            path: "api/admin/subscribers?state=\(state.rawValue)"
        )

        do {
            let subscribers = try Self.jsonDecoder.decode([Subscriber].self, from: data)
            return subscribers.sorted(by: { $0.domain < $1.domain })
        } catch {
            throw Error.invalidResponse(error.localizedDescription)
        }
    }

    func acceptSubscriber(domain: String) throws {
        try performSubscriberAction(domain: domain, action: "accept", method: .POST)
    }

    func rejectSubscriber(domain: String) throws {
        try performSubscriberAction(domain: domain, action: "reject", method: .POST)
    }

    func deleteSubscriber(domain: String) throws {
        let encodedDomain = try Self.pathSegment(for: domain)
        _ = try performRequest(
            method: .DELETE,
            path: "api/admin/subscribers/\(encodedDomain)"
        )
    }

    func listBlockedDomains() throws -> [BlockedDomain] {
        let data = try performRequest(
            method: .GET,
            path: "api/admin/blocked-domains"
        )

        do {
            let blockedDomains = try Self.jsonDecoder.decode([BlockedDomain].self, from: data)
            return blockedDomains.sorted(by: { $0.domain < $1.domain })
        } catch {
            throw Error.invalidResponse(error.localizedDescription)
        }
    }

    func blockDomain(domain: String, reason: String?) throws {
        let body = try Self.jsonEncoder.encode(
            BlockRequest(domain: domain, reason: reason)
        )
        _ = try performRequest(
            method: .POST,
            path: "api/admin/blocked-domains",
            body: body
        )
    }

    func unblockDomain(domain: String) throws {
        let encodedDomain = try Self.pathSegment(for: domain)
        _ = try performRequest(
            method: .DELETE,
            path: "api/admin/blocked-domains/\(encodedDomain)"
        )
    }

    @discardableResult
    private func performRequest(method: HTTPMethod, path: String, body requestBody: Data? = nil) throws -> Data {
        guard !relayURL.isEmpty else {
            throw Error.missingRelayURL
        }
        guard !adminToken.isEmpty else {
            throw Error.missingAdminToken
        }
        guard let baseURL = URL(string: relayURL) else {
            throw Error.invalidRelayURL(relayURL)
        }
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw Error.invalidRelayURL(relayURL)
        }

        var request = try HTTPClient.Request(url: url.absoluteString, method: method)
        request.headers.add(name: "Authorization", value: "Bearer \(adminToken)")
        if let requestBody {
            request.headers.add(name: "Content-Type", value: "application/json")
            request.body = .data(requestBody)
        }

        let response: HTTPClient.Response
        do {
            response = try executeRequest(request)
        } catch {
            throw Error.connectionFailed(error.localizedDescription)
        }

        let body = response.body ?? ByteBuffer()
        let data = Data(body.readableBytesView)

        guard (200..<300).contains(response.status.code) else {
            throw Error.requestFailed(
                status: Int(response.status.code),
                reason: String(decoding: data, as: UTF8.self)
            )
        }

        return data
    }

    private func performSubscriberAction(domain: String, action: String, method: HTTPMethod) throws {
        let encodedDomain = try Self.pathSegment(for: domain)
        _ = try performRequest(
            method: method,
            path: "api/admin/subscribers/\(encodedDomain)/\(action)"
        )
    }

    private static func pathSegment(for value: String) throws -> String {
        var allowedCharacters = CharacterSet.alphanumerics
        allowedCharacters.insert(charactersIn: "-._~")

        guard let encoded = value.addingPercentEncoding(withAllowedCharacters: allowedCharacters) else {
            throw Error.invalidRelayURL(value)
        }
        return encoded
    }

    private static let jsonEncoder = JSONEncoder()

    private static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom {
            (decoder) in

            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                return Date(timeIntervalSince1970: 0)
            }

            if let seconds = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: seconds)
            }

            let value = try container.decode(String.self)
            let fractionalSecondsFormatter = ISO8601DateFormatter()
            fractionalSecondsFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let internetDateTimeFormatter = ISO8601DateFormatter()
            internetDateTimeFormatter.formatOptions = [.withInternetDateTime]

            if let date = fractionalSecondsFormatter.date(from: value)
                ?? internetDateTimeFormatter.date(from: value)
            {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date: \(value)"
            )
        }
        return decoder
    }()
}
