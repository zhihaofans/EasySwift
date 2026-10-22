//
//  VideoHTTP.swift
//  Easy Swift
//
//  链接解析的统一抓取层。
//
//  为什么单独一层：这些平台的行为差异全在「请求细节」上——UA 换错会被引到登录页或 SPA 壳，
//  「是否被登录墙拦住」只能看重定向终点，短链必须逐跳跟。解析器里不要再直接开 URLSession。
//

import Foundation

enum VideoHTTP {
    /// UA 分档。
    /// - 桌面 Chrome：通用网页抓取（默认）
    /// - iOS Safari：短视频/笔记站的分享链与移动端页面认这个，换成桌面 UA 会被导去桌面版或登录页
    enum UA {
        static let desktopChrome = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
        static let iOSSafari = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    }

    struct Response {
        /// 跟随重定向后的最终地址。登录墙/风控页的判定一律看它，不要看入参
        let url: URL
        let status: Int
        let body: String
        /// 键统一小写，取值时不用再猜大小写
        let headers: [String: String]

        func header(_ name: String) -> String? {
            return headers[name.lowercased()]
        }
    }

    // MARK: - 请求

    /// GET 页面。
    /// - Important: 返回状态码而不是"非 2xx 就抛错"——很多平台用 200 + 登录墙页面表达失败，
    ///   由调用方结合 `response.url` 判断，这里不替它下结论。
    static func get(_ url: URL,
                    ua: String = UA.desktopChrome,
                    headers: [String: String] = [:],
                    cookies: String? = nil,
                    timeout: TimeInterval = 20) async throws -> Response
    {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.httpMethod = "GET"
        request.setValue(ua, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")
        if let cookies, !cookies.isEmpty {
            request.setValue(cookies, forHTTPHeaderField: "Cookie")
        }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw LinkParseError.unknown("请求没有拿到 HTTP 响应")
            }
            let body = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
                ?? ""
            let finalURL = http.url ?? url
            debugPrint("[VideoHTTP] GET \(url.absoluteString) -> \(finalURL.absoluteString) [\(http.statusCode)] \(data.count) bytes")
            return Response(url: finalURL,
                            status: http.statusCode,
                            body: body,
                            headers: normalizedHeaders(http.allHeaderFields))
        } catch let error as LinkParseError {
            throw error
        } catch {
            debugPrint("[VideoHTTP] GET 失败 \(url.absoluteString): \(error.localizedDescription)")
            throw LinkParseError.network
        }
    }

    /// HEAD 探测：只用来判断"这个地址还在不在"。
    /// 返回 `nil` 表示没拿到可信状态（超时 / 网络错误 / 服务端不支持 HEAD），
    /// 调用方应把它当成"可用"，不要当成"资源没了"。
    static func head(_ url: URL,
                     ua: String = UA.desktopChrome,
                     headers: [String: String] = [:],
                     cookies: String? = nil,
                     timeout: TimeInterval = 10) async -> Int?
    {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = timeout
        request.setValue(ua, forHTTPHeaderField: "User-Agent")
        if let cookies, !cookies.isEmpty {
            request.setValue(cookies, forHTTPHeaderField: "Cookie")
        }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode
        } catch {
            debugPrint("[VideoHTTP] HEAD 未拿到状态 \(url.absoluteString): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - 短链展开

    /// 逐跳跟随重定向，最多 `maxHops` 跳，返回最终地址（**保留原查询串**）。
    ///
    /// 不用 `URLSession` 的自动跟随：一是要限制跳数，二是要把每一跳打出来——
    /// 分享链落到哪里，往往就是"能解析 / 被登录墙拦住"的分水岭。
    static func expandShortLink(_ url: URL,
                                ua: String = UA.iOSSafari,
                                maxHops: Int = 5,
                                timeout: TimeInterval = 15) async throws -> URL
    {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.httpCookieAcceptPolicy = .never
        let blocker = RedirectBlocker()
        let session = URLSession(configuration: configuration, delegate: blocker, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        var current = url
        for hop in 0 ..< maxHops {
            var request = URLRequest(url: current)
            request.timeoutInterval = timeout
            request.setValue(ua, forHTTPHeaderField: "User-Agent")

            let response: URLResponse
            do {
                (_, response) = try await session.data(for: request)
            } catch {
                debugPrint("[VideoHTTP] 短链展开失败 \(current.absoluteString): \(error.localizedDescription)")
                throw LinkParseError.network
            }
            guard let http = response as? HTTPURLResponse else { return current }
            guard (300 ..< 400).contains(http.statusCode),
                  let location = http.value(forHTTPHeaderField: "Location"),
                  let next = URL(string: location, relativeTo: current)?.absoluteURL,
                  next != current
            else {
                return http.url ?? current
            }
            debugPrint("[VideoHTTP] 短链第 \(hop + 1) 跳: \(current.absoluteString) -> \(next.absoluteString)")
            current = next
        }
        debugPrint("[VideoHTTP] 短链跳数超过 \(maxHops)，停在: \(current.absoluteString)")
        return current
    }

    // MARK: - 内部

    private static func normalizedHeaders(_ raw: [AnyHashable: Any]) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in raw {
            guard let key = key as? String else { continue }
            result[key.lowercased()] = String(describing: value)
        }
        return result
    }

    /// 阻止 URLSession 自动跟随重定向，让调用方逐跳处理
    private final class RedirectBlocker: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession,
                        task: URLSessionTask,
                        willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest,
                        completionHandler: @escaping (URLRequest?) -> Void)
        {
            completionHandler(nil)
        }
    }
}
