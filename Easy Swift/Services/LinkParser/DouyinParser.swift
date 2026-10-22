//
//  DouyinParser.swift
//  Easy Swift
//
//  抖音解析。
//
//  主路线是"真跑一遍页面"（DouyinWebExtractor：隐藏 WebView + XHR 钩子 + SSR 取数），
//  因为纯 HTTP 拿到的分享页会被换成风控挑战页，JSON 接口要签名。
//
//  HTTP 回退（iesdouyin 分享页里的 _ROUTER_DATA）保留着，但 2026 年起基本拿不到数据，
//  只在 WebView 超时/无窗口时试一次，失败了要给用户明确交代，不能含糊报"作品已删除"。
//
//  Created by zzh on 2026/08/20.
//

import Foundation

struct DouyinParser: LinkParser {
    var name: String {
        "抖音"
    }

    /// 支持的链接：主站作品页、App 分享短链、移动端分享页
    private static let supportedHosts = ["douyin.com", "v.douyin.com", "iesdouyin.com"]

    func canParse(_ url: URL) -> Bool {
        guard let host = url.host else { return false }
        let bare = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return Self.supportedHosts.contains(bare)
    }

    func parse(url: URL) async throws -> LinkParseResult {
        // 1. 短链展开（分享链认 iOS UA，桌面 UA 拿不到 Location）
        let page = try await expandIfNeeded(url)
        debugPrint("[抖音] 展开后: \(page.absoluteString)")

        guard let awemeID = Self.awemeID(from: page) else {
            throw LinkParseError.unknown("没从链接里识别出作品 id，请确认这是作品分享链接")
        }

        // 2. 两条路线同时跑，谁先出结果用谁：
        //    分享页 HTTP 一般 1 秒内返回（实测有时能直接拿到数据），隐藏 WebView 要 5–20 秒；
        //    只在 WebView 卡住时让用户干等 18 秒，而不是 40 秒。
        return try await Self.race(awemeID: awemeID)
    }

    /// 哪条路线出的结果
    private enum RouteResult {
        case http(LinkParseResult)
        case web(LinkParseResult)
    }

    /// HTTP 分享页 vs 隐藏 WebView 竞速。
    ///
    /// 但**图文作品不能谁快用谁**：HTTP 分享页里没有动图资源，谁先到就用谁会把
    /// 「7 张图 + 7 个动图」降级成「7 张图」。所以规则是：
    /// - 视频作品：HTTP 先到就直接用（1 秒级）
    /// - 图文作品：先存下 HTTP 结果，等 WebView 给完整结果；WebView 失败才退回 HTTP
    private static func race(awemeID: String) async throws -> LinkParseResult {
        var webErrors: [DouyinExtractError]=[]
        var httpErrors: [LinkParseError]=[]
        var httpImageResult: LinkParseResult?

        return try await withThrowingTaskGroup(of: RouteResult.self) { group in
            group.addTask {
                .http(try await parseSharePage(awemeID: awemeID))
            }
            group.addTask {
                .web(try await DouyinWebExtractor.extract(awemeID: awemeID))
            }

            while true {
                do {
                    guard let route=try await group.next() else { break }
                    switch route {
                    case let .web(result):
                        // WebView 拿到就是最完整的（含动图），直接收工
                        group.cancelAll()
                        return result
                    case let .http(result):
                        if result.images.isEmpty {
                            // 视频作品：HTTP 已经给全了
                            group.cancelAll()
                            return result
                        }
                        // 图文：先留着，等 WebView 的动图
                        httpImageResult=result
                        debugPrint("[抖音] HTTP 先拿到 \(result.images.count) 张图（无动图），继续等 WebView 补动图")
                    }
                } catch let error as DouyinExtractError {
                    webErrors.append(error)
                } catch let error as LinkParseError {
                    httpErrors.append(error)
                } catch {
                    webErrors.append(.failed(error.localizedDescription))
                }
            }

            group.cancelAll()
            if let httpImageResult {
                debugPrint("[抖音] WebView 没补上动图，退回 HTTP 结果")
                return httpImageResult
            }
            throw Self.bestError(webErrors: webErrors, httpErrors: httpErrors)
        }
    }

    /// 失败时给用户的话：能从界面上解决的（登录、验证码）优先说
    private static func bestError(webErrors: [DouyinExtractError], httpErrors: [LinkParseError]) -> LinkParseError {
        if webErrors.contains(where: { if case .needLogin=$0 { true } else { false } }) {
            return .needLogin
        }
        if webErrors.contains(where: { if case .blocked=$0 { true } else { false } }) {
            return .blocked
        }
        if webErrors.contains(where: { if case .noFrontWindow=$0 { true } else { false } }) {
            return .unknown("抖音解析需要应用在前台，请切回应用后重试")
        }
        // HTTP 路线给出的具体原因比"超时"更有助于排查
        if let specific=httpErrors.first(where: { error in
            if case .unknown=error { true } else { false }
        }) {
            return specific
        }
        if webErrors.contains(where: { if case .busy=$0 { true } else { false } }) {
            return .unknown("正在解析另一个抖音作品，请稍后再试")
        }
        return httpErrors.first ?? .unknown("抖音解析失败，请稍后重试")
    }

    // MARK: - 链接处理

    private func expandIfNeeded(_ url: URL) async throws -> URL {
        guard let host = url.host, host.contains("v.douyin") else { return url }
        return try await VideoHTTP.expandShortLink(url, ua: VideoHTTP.UA.iOSSafari)
    }

    /// 作品 id：/video/<id>、/note/<id>、/slides/<id>，或查询参数 modal_id
    static func awemeID(from url: URL) -> String? {
        let parts = url.path.split(separator: "/").map(String.init)
        if let marker = parts.lastIndex(where: { ["video", "note", "slides"].contains($0) }), marker + 1 < parts.count {
            let candidate = parts[marker + 1]
            if candidate.count >= 10, candidate.allSatisfy({ $0.isNumber }) {
                return candidate
            }
        }
        if let last = parts.last, last.count >= 10, last.allSatisfy({ $0.isNumber }) {
            return last
        }
        if let modal = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "modal_id" })?.value,
            modal.count >= 10
        {
            return modal
        }
        return nil
    }

    // MARK: - HTTP 回退

    static func parseSharePage(awemeID: String) async throws -> LinkParseResult {
        let url = URL(string: "https://www.iesdouyin.com/share/video/\(awemeID)/")!
        debugPrint("[抖音] HTTP 回退: \(url.absoluteString)")
        let response = try await VideoHTTP.get(url, ua: VideoHTTP.UA.iOSSafari, headers: ["Referer": "https://www.iesdouyin.com/"])
        guard (200 ..< 300).contains(response.status) else {
            throw LinkParseError.unknown("抖音分享页返回 HTTP \(response.status)（可能需要换网络或稍后重试）")
        }
        guard let state = routerData(from: response.body) else {
            throw LinkParseError.unknown("抖音分享页里没有作品数据（页面结构可能已变）")
        }
        guard let item = videoItem(in: state), let result = makeResult(item) else {
            throw LinkParseError.unknown("抖音没有返回该作品的数据（作品可能已删除，或需要登录）")
        }
        debugPrint("[抖音] 解析成功(HTTP 回退): 标题=\(result.title ?? "nil") 图=\(result.images.count) 动图=\(result.motions.count) 视频=\(result.videos.count)")
        return result
    }

    /// 抠 `window._ROUTER_DATA`，兼容裸 JSON 与 `JSON.parse("…")` 包裹
    static func routerData(from html: String) -> [String: Any]? {
        guard let marker = html.range(of: "window._ROUTER_DATA") else { return nil }
        guard let equal = html[marker.upperBound...].firstIndex(of: "=") else { return nil }
        let start = html.index(after: equal)
        guard let end = html[start...].range(of: "</script>") else { return nil }

        var raw = String(html[start ..< end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasSuffix(";") { raw.removeLast() }
        raw = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if raw.hasPrefix("JSON.parse(") {
            var inner = String(raw.dropFirst("JSON.parse(".count))
            if inner.hasSuffix(");") {
                inner = String(inner.dropLast(2))
            } else if inner.hasSuffix(")") {
                inner = String(inner.dropLast())
            }
            guard let data = inner.data(using: .utf8),
                  let decoded = (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) as? String
            else { return nil }
            raw = decoded
        }
        guard let data = raw.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    /// `loaderData["video_(id)/page"].videoInfoRes.item_list[0]`
    static func videoItem(in state: [String: Any]) -> [String: Any]? {
        guard let loader = state["loaderData"] as? [String: Any] else { return nil }
        for (key, value) in loader where key.contains("page") {
            guard let page = value as? [String: Any],
                  let info = page["videoInfoRes"] as? [String: Any],
                  let list = info["item_list"] as? [[String: Any]],
                  let first = list.first
            else { continue }
            return first
        }
        return nil
    }

    static func makeResult(_ item: [String: Any]) -> LinkParseResult? {
        var images: [URL] = []
        var motions: [Int: URL] = [:]

        if let list = item["images"] as? [[String: Any]] {
            for (index, image) in list.enumerated() {
                let urls = image["url_list"] as? [String] ?? []
                if let raw = urls.last ?? urls.first, let url = URL(string: raw) {
                    images.append(url.httpsURL)
                }
                if let video = image["video"] as? [String: Any], let motion = playURL(video) {
                    motions[index] = motion
                }
            }
        }

        var videos: [URL] = []
        // 图文作品的 video 字段是配乐（ies-music 的 mp3），有图片时不能当视频返回
        if images.isEmpty, let video = item["video"] as? [String: Any], let url = playURL(video) {
            videos.append(url)
        }
        guard !images.isEmpty || !videos.isEmpty else { return nil }

        let desc = item["desc"] as? String
        return LinkParseResult(title: desc?.isEmpty == false ? desc : nil,
                               images: images,
                               videos: videos,
                               motions: motions)
    }

    /// 播放地址：优先 play_addr，其次码率列表；带水印地址把 `playwm` 换成 `play`
    static func playURL(_ video: [String: Any]) -> URL? {
        if let address = video["play_addr"] as? [String: Any],
           let list = address["url_list"] as? [String],
           let raw = list.first,
           let url = URL(string: raw.replacingOccurrences(of: "playwm", with: "play"))
        {
            return url.httpsURL
        }
        if let rates = video["bit_rate"] as? [[String: Any]] {
            for rate in rates {
                guard let address = rate["play_addr"] as? [String: Any],
                      let list = address["url_list"] as? [String],
                      let raw = list.first,
                      let url = URL(string: raw.replacingOccurrences(of: "playwm", with: "play"))
                else { continue }
                return url.httpsURL
            }
        }
        return nil
    }
}
