//
//  HTTPClient.swift
//  PCLMacCE
//

import Foundation
import SwiftyJSON

public protocol URLConvertible {
    var url: URL? { get }
}

extension URL: URLConvertible {
    public var url: URL? { self }
}

extension String: URLConvertible {
    public var url: URL? { URL(string: self) }
}

public class HTTPClient {
    public static let shared: HTTPClient = .init()

    public enum EncodeMethod {
        case json
        case urlEncoded
    }

    public class Response {
        private let response: HTTPURLResponse
        public let statusCode: Int
        public let headers: [String: String]
        public let data: Data

        fileprivate init(data: Data, response: HTTPURLResponse) {
            self.response = response
            self.statusCode = response.statusCode
            self.headers = Self.parseHeaders(response.allHeaderFields)
            self.data = data
        }

        public func json() throws -> JSON {
            do {
                return try JSON(data: data)
            } catch {
                throw ResponseError(.decodeError, url: response.url, response: response)
            }
        }

        public func decode<T: Decodable>(_ type: T.Type) throws -> T {
            do {
                return try JSONDecoder.shared.decode(type, from: data)
            } catch {
                throw ResponseError(.decodeError, url: response.url, response: response)
            }
        }

        private static func parseHeaders(_ headers: [AnyHashable: Any]) -> [String: String] {
            return headers.reduce(into: [:]) { result, entry in
                if let key = entry.key as? String, let value = entry.value as? String {
                    result[key.lowercased()] = value
                }
            }
        }
    }

    /// 向目标 URL 发送请求。
    /// - Parameters:
    ///   - url: 目标 URL，可以是 `String` 与 `URL`。
    ///   - method: 请求方法，如 `GET`、`POST`。
    ///   - headers: 请求头。
    ///   - body: 请求体，在请求方法为 `GET` 时被视为 URL params。
    ///   - encodeMethod: 请求体的编码方式。
    ///   - throwOnError: 在最终响应状态码为非 `2XX` 时是否抛出错误。
    ///   - revalidate: 是否使用 `.reloadIgnoringLocalCacheData` 缓存策略（先判断本地缓存是否过期）。
    ///   - timeout: 请求超时时间。
    /// - Returns: 返回的响应。
    public func request(
        url: URLConvertible,
        method: String,
        headers: [String: String?]? = nil,
        body: [String: Any?]? = nil,
        using encodeMethod: EncodeMethod = .json,
        throwOnError: Bool = false,
        revalidate: Bool = false,
        timeout: TimeInterval
    ) async throws -> Response {
        guard let url = url.url else { throw RequestError.invalidURL(url) }
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { throw RequestError.invalidScheme(url: url) }

        let headers = headers?.compactMapValues(\.self)
        let body = body?.compactMapValues(\.self)

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.allHTTPHeaderFields = headers
        request.setValue("PCL-Mac/\(Metadata.appVersion)", forHTTPHeaderField: "User-Agent")
        if revalidate {
            request.cachePolicy = .reloadRevalidatingCacheData
        }
        request.timeoutInterval = timeout

        if let body {
            if method == "GET" {
                // url params
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
                components.queryItems = body.map { URLQueryItem(name: $0.key, value: String(describing: $0.value)) }
                request.url = components.url
            } else {
                let bodyData: Data
                let contentType: String
                do {
                    (bodyData, contentType) = try encode(body, using: encodeMethod)
                } catch {
                    throw RequestError.encodeError(underlying: error)
                }

                request.httpBody = bodyData
                request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            }
        }

        // GET 幂等：429/5xx 与瞬时网络错误统一退避重试，免去各调用方自行处理
        let maxRetryCount: Int = 2
        var retryCount: Int = 0
        while true {
            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await URLSession.shared.data(for: request)
            } catch let error where error.isCancellationError {
                throw CancellationError()
            } catch let urlError as URLError where method == "GET" && retryCount < maxRetryCount && Self.isTransient(urlError) {
                let delay: Double = Double(retryCount + 1)
                warn("请求 \(url.host ?? "") 失败（\(urlError.localizedDescription)），\(delay)s 后重试 (\(retryCount + 1)/\(maxRetryCount))")
                try await Task.sleep(seconds: delay)
                retryCount += 1
                continue
            }
            guard let response = response as? HTTPURLResponse else {
                throw ResponseError(.invalidType, url: url, response: response)
            }
            if let delay = Self.retryDelay(for: response), method == "GET", retryCount < maxRetryCount {
                warn("\(url.host ?? "") 返回 \(response.statusCode)，\(String(format: "%.1f", delay))s 后重试 (\(retryCount + 1)/\(maxRetryCount))")
                try await Task.sleep(seconds: delay)
                retryCount += 1
                continue
            }
            if throwOnError && !(200..<300).contains(response.statusCode) {
                throw ResponseError(.badStatus, url: url, response: response)
            }

            return Response(data: data, response: response)
        }
    }

    /// 状态码对应的退避秒数；不应重试的状态码返回 `nil`。
    private static func retryDelay(for response: HTTPURLResponse) -> Double? {
        switch response.statusCode {
        case 429:
            // 尊重 Retry-After（秒），超过 10s 时按上限等待
            if let raw = response.value(forHTTPHeaderField: "Retry-After"), let seconds = Double(raw), seconds > 0 {
                return min(seconds, 10)
            }
            return 2
        case 500..<600:
            return 1
        default:
            return nil
        }
    }

    /// 该网络错误是否为瞬时错误（重试通常可以恢复）。
    private static func isTransient(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    /// 向目标 URL 发送 `GET` 请求。
    /// - Parameters:
    ///   - url: 目标 URL，可以是 `String` 与 `URL`。
    ///   - headers: 请求头。
    ///   - params: 请求的 URL params。
    ///   - throwOnError: 在最终响应状态码为非 `2XX` 时是否抛出错误。
    ///   - revalidate: 是否使用 `.reloadIgnoringLocalCacheData` 缓存策略（先判断本地缓存是否过期）。
    ///   - timeout: 请求超时时间，默认 30s。
    /// - Returns: 返回的响应。
    public func get(
        _ url: URLConvertible,
        headers: [String: String?]? = nil,
        params: [String: String?]? = nil,
        throwOnError: Bool = false,
        revalidate: Bool = false,
        timeout: TimeInterval = 30
    ) async throws -> Response {
        return try await request(
            url: url, method: "GET", headers: headers, body: params, using: .urlEncoded,
            throwOnError: throwOnError, revalidate: revalidate, timeout: timeout
        )
    }

    /// 向目标 URL 发送 `POST` 请求。
    /// - Parameters:
    ///   - url: 目标 URL，可以是 `String` 与 `URL`。
    ///   - headers: 请求头。
    ///   - body: 请求体。
    ///   - encodeMethod: 请求体的编码方式。
    ///   - throwOnError: 在最终响应状态码为非 `2XX` 时是否抛出错误。
    ///   - timeout: 请求超时时间，默认 30s。
    /// - Returns: 返回的响应。
    public func post(
        _ url: URLConvertible,
        headers: [String: String?]? = nil,
        body: [String: Any?]?,
        using encodeMethod: EncodeMethod,
        throwOnError: Bool = false,
        timeout: TimeInterval = 30
    ) async throws -> Response {
        return try await request(
            url: url, method: "POST", headers: headers, body: body, using: encodeMethod,
            throwOnError: throwOnError, revalidate: false, timeout: timeout
        )
    }

    private func encode(_ body: [String: Any], using method: EncodeMethod) throws -> (Data, String) {
        switch method {
        case .json:
            return (try JSONSerialization.data(withJSONObject: body), "application/json")
        case .urlEncoded:
            var components = URLComponents()
            components.queryItems = body.sorted { $0.key < $1.key }
                .map { URLQueryItem(name: $0.key, value: String(describing: $0.value)) }
            guard let encoded = components.percentEncodedQuery else {
                throw SimpleError("无法编码表单请求体。")
            }
            // In form encoding a bare '+' means space, so keep literal plus signs escaped.
            let formBody = encoded.replacingOccurrences(of: "+", with: "%2B")
            return (Data(formBody.utf8), "application/x-www-form-urlencoded")
        }
    }

    private init() {
        // API 响应以 JSON 为主（版本清单、项目/版本列表等，单个可达数百 KB），
        // 系统默认 URLCache 容量偏小；扩大后配合各调用的 revalidate 协商
        // 可显著减少重复请求。下载走独立的 downloadTask，不经过 URLCache。
        URLCache.shared.memoryCapacity = 8 * 1024 * 1024
        URLCache.shared.diskCapacity = 128 * 1024 * 1024
    }
}

public enum RequestError: LocalizedError {
    case invalidURL(_ url: URLConvertible)
    case invalidScheme(url: URL)
    case encodeError(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            "无效的 URL：\(url)。"
        case .invalidScheme(let url):
            "无效的 URL Scheme" + (url.scheme == nil ? "" : "：\(url.scheme!)") + "。"
        case .encodeError(let underlying):
            "编码请求体失败：\(underlying.localizedDescription)。"
        }
    }
}

public struct ResponseError: LocalizedError {
    public let kind: Kind
    public let url: URL?
    public let response: URLResponse?
    public let error: Error?

    init(_ kind: Kind, url: URL?, response: URLResponse?, underlying error: Error? = nil) {
        self.kind = kind
        self.url = url
        self.response = response
        self.error = error
    }

    public enum Kind {
        case invalidType
        case badStatus
        case decodeError
    }

    public var errorDescription: String? {
        switch kind {
        case .invalidType:
            return "无效的响应类型" + (response == nil ? "" : "：\(type(of: response))") + "。"
        case .badStatus:
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
                return "错误响应码。"
            }
            return "错误响应码：\(statusCode)。"
        case .decodeError:
            return "解码响应体失败。"
        }
    }
}
