//
//  DouyinParser.swift
//  Easy Swift
//
//  抖音解析：解析 window._ROUTER_DATA 内嵌数据（yt-dlp / you-get 同源方案）。
//  视频地址在 video.play_addr.url_list，封面在 cover.url_list；og 标签作兜底。
//
//  Created by zzh on 2026/08/20.
//

import Foundation

struct DouyinParser: LinkParser {
    var name: String {
        "抖音"
    }

    /// 支持的链接：抖音主站 + App 分享短链接（v.douyin.com 会重定向到视频页）
    private static let supportedHosts = ["douyin.com", "v.douyin.com", "iesdouyin.com"]

    func canParse(_ url: URL) -> Bool {
        guard let host = url.host else { return false }
        let bare = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return Self.supportedHosts.contains(bare)
    }

    func parse(url: URL) async throws -> LinkParseResult {
        let (html, finalURL) = try await HTMLFetcher.fetchHTML(url: url)
        var parsed = parseHTML(html)

        // 兜底：拿不到数据时，用重定向后的最终 URL（短链会跳到 iesdouyin.com/share/note|video/{id}）
        // 提取视频 id，按路径类型构造移动端分享页再抓一次
        if parsed.videos.isEmpty && parsed.images.isEmpty,
           let videoID = extractVideoID(from: finalURL),
           let shareURL = Self.sharePageURL(finalURL, videoID: videoID)
        {
            do {
                let (shareHTML, _) = try await HTMLFetcher.fetchHTML(url: shareURL)
                let fallback = parseHTML(shareHTML)
                if !fallback.videos.isEmpty || !fallback.images.isEmpty {
                    parsed = fallback
                }
            } catch {
                // 兜底失败时保留主站结果，由 emptyResult 兜底
            }
        }

        guard !parsed.images.isEmpty || !parsed.videos.isEmpty || parsed.title?.isNotEmpty == true else {
            #if DEBUG
            let hasRouter = html.contains("window._ROUTER_DATA")
            let ogImage = OGMetaExtractor.extract(property: "og:image", from: html).count
            let ogVideo = OGMetaExtractor.extract(property: "og:video", from: html).count
            debugPrint("[DouyinParser] 解析失败（emptyResult）: \(url.absoluteString)")
            debugPrint("  - 最终 URL: \(finalURL.absoluteString)")
            debugPrint("  - HTML: \(html.count) 字符, 含 _ROUTER_DATA=\(hasRouter), og:image=\(ogImage), og:video=\(ogVideo)")
            debugPrint("  - 视频 id: \(extractVideoID(from: finalURL) ?? "nil")")
            #endif
            throw LinkParseError.emptyResult
        }
        return LinkParseResult(title: parsed.title, images: parsed.images, videos: parsed.videos)
    }

    // 按最终 URL 路径类型构造移动端分享页（note 类型与 video 类型路径不同）
    private static func sharePageURL(_ url: URL, videoID: String) -> URL? {
        if url.path.contains("/share/note/") {
            return URL(string: "https://www.iesdouyin.com/share/note/\(videoID)/")
        }
        return URL(string: "https://www.iesdouyin.com/share/video/\(videoID)/")
    }

    // 从 HTML 中解析视频/封面/标题（主站与分享页共用）
    private func parseHTML(_ html: String) -> (title: String?, images: [URL], videos: [URL]) {
        let title = OGMetaExtractor.extract(property: "og:title", from: html).first
        var videos: [URL] = []
        var images: [URL] = []

        if let json = extractRouterDataJSON(from: html) {
            // 视频地址：play_addr.url_list 第一个（兜底 download_addr）
            if let videoURL = extractFirstURL(from: json, underKey: "play_addr") {
                videos = [videoURL.httpsURL]
            } else if let downloadURL = extractFirstURL(from: json, underKey: "download_addr") {
                videos = [downloadURL.httpsURL]
            }
            // 封面：cover.url_list 第一个
            if let coverURL = extractFirstURL(from: json, underKey: "cover") {
                images = [coverURL.httpsURL]
            }
        }
        // 兜底：og 标签
        if images.isEmpty {
            images = OGMetaExtractor.extract(property: "og:image", from: html)
                .compactMap { URL(string: $0) }
                .map { $0.httpsURL }
        }
        if videos.isEmpty {
            videos = OGMetaExtractor.extract(property: "og:video", from: html)
                .compactMap { URL(string: $0) }
                .map { $0.httpsURL }
        }
        return (title, images, videos)
    }

    // 从 URL 路径提取抖音视频 id（/video/{id} 或 /note/{id}）
    private func extractVideoID(from url: URL) -> String? {
        let components = url.path.split(separator: "/")
        // 1. 路径最后一段是纯数字且够长
        if let last = components.last, last.count >= 10, last.allSatisfy({ $0.isNumber }) {
            return String(last)
        }
        // 2. video / note / share/video 后的数字段
        for (i, comp) in components.enumerated() {
            if ["video", "note"].contains(comp), i + 1 < components.count, components[i + 1].count >= 10, components[i + 1].allSatisfy({ $0.isNumber }) {
                return String(components[i + 1])
            }
        }
        return nil
    }

    // MARK: - _ROUTER_DATA 解析（yt-dlp 同源）

    /// 截取 window._ROUTER_DATA= 后的 JSON 字符串
    /// 兼容两种格式：裸 JSON（主站）与 JSON.parse("...") 包裹（iesdouyin 分享页）
    private func extractRouterDataJSON(from html: String) -> String? {
        guard let markerRange = html.range(of: "window._ROUTER_DATA") else { return nil }
        let after = html[markerRange.upperBound...]
        guard let eqRange = after.range(of: "=") else { return nil }
        let jsonStart = eqRange.upperBound
        guard let scriptEnd = html[jsonStart...].range(of: "</script>") else { return nil }
        var raw = String(html[jsonStart..<scriptEnd.lowerBound])
        raw = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix(";") {
            raw.removeFirst()
        }
        raw = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // JSON.parse("...") 包裹形式：用 JSONSerialization 解码字符串字面量（还原所有转义）
        if raw.hasPrefix("JSON.parse(") {
            var inner = String(raw.dropFirst("JSON.parse(".count))
            if inner.hasSuffix(")") || inner.hasSuffix(");") {
                inner = String(inner.dropLast(inner.hasSuffix(");") ? 2 : 1))
            }
            inner = inner.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let data = inner.data(using: .utf8),
                  let decoded = (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) as? String
            else {
                return nil
            }
            return decoded
        }

        if raw.hasSuffix(";") {
            raw.removeLast()
        }
        return raw
    }

    /// 在 JSON 中定位指定对象（如 "play_addr":{...}），括号配对提取其内容
    private func extractObjectContent(_ json: String, key: String) -> String? {
        guard let match = json.range(of: "\"\(key)\"\\s*:\\s*\\{", options: .regularExpression) else { return nil }
        var index = match.upperBound
        var depth = 1
        while index < json.endIndex {
            let ch = json[index]
            if ch == "{" {
                depth += 1
            } else if ch == "}" {
                depth -= 1
                if depth == 0 {
                    return String(json[match.upperBound..<index])
                }
            }
            index = json.index(after: index)
        }
        return nil
    }

    /// 在对象内容中取 "url_list":["...", ...] 的第一个 URL
    private func extractFirstURL(from json: String, underKey key: String) -> URL? {
        guard let content = extractObjectContent(json, key: key) else { return nil }
        guard let match = content.range(of: #""url_list"\s*:\s*\["#, options: .regularExpression) else { return nil }
        var index = match.upperBound
        var depth = 1
        while index < content.endIndex {
            let ch = content[index]
            if ch == "[" {
                depth += 1
            } else if ch == "]" {
                depth -= 1
                if depth == 0 {
                    return nil
                }
            } else if ch == "\"", depth == 1 {
                // 读取字符串
                var str = ""
                index = content.index(after: index)
                while index < content.endIndex, content[index] != "\"" {
                    str.append(content[index])
                    index = content.index(after: index)
                }
                let cleaned = str
                    .replacingOccurrences(of: "\\u002F", with: "/")
                    .replacingOccurrences(of: "\\/", with: "/")
                if let url = URL(string: cleaned), url.scheme != nil {
                    return url
                }
            }
            index = content.index(after: index)
        }
        return nil
    }
}
