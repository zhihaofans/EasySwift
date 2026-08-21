//
//  XiaohongshuParser.swift
//  Easy Swift
//
//  小红书解析：解析 window.__INITIAL_STATE__ 中的 imageList（仅笔记图片）。
//  每张图只取原图字段（urlDefault / url），排除 urlPre 等水印、压缩模糊图，
//  避免同一张图出现"清晰 + 模糊"两份。
//
//  Created by zzh on 2026/08/20.
//

import Foundation

struct XiaohongshuParser: LinkParser {
    var name: String {
        "小红书"
    }

    /// 支持的链接：小红书主站 + App 分享短链接（xhslink.cn / xhslink.com 会重定向到笔记页）
    private static let supportedHosts = ["xiaohongshu.com", "xhslink.com", "xhslink.cn"]

    /// 仅保留小红书图片域名
    private static let allowedImageHosts = ["xiaohongshu.com", "xhscdn.com"]

    func canParse(_ url: URL) -> Bool {
        guard let host = url.host else { return false }
        let bare = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return Self.supportedHosts.contains(bare)
    }

    func parse(url: URL) async throws -> LinkParseResult {
        let (html, _) = try await HTMLFetcher.fetchHTML(url: url)

        let title = OGMetaExtractor.extract(property: "og:title", from: html).first

        var images = extractNoteImages(from: html)
        // 兜底：取不到 imageList 时使用 og:image 封面
        if images.isEmpty {
            images = OGMetaExtractor.extract(property: "og:image", from: html).compactMap { URL(string: $0) }
        }
        images = images
            .map { $0.httpsURL }
            .filter { Self.isAllowedImageURL($0) }
            .unique

        // 视频笔记：从 video.media.stream 提取视频地址（masterUrl）
        let videos = extractNoteVideos(from: html)

        guard !images.isEmpty || !videos.isEmpty || title?.isNotEmpty == true else {
            #if DEBUG
            debugPrint("[XiaohongshuParser] 解析失败（emptyResult）: \(url.absoluteString)")
            debugPrint("  - 主站 HTML: \(html.count) 字符, 含 __INITIAL_STATE__=\(html.contains("window.__INITIAL_STATE__")), imageList 数量=\(extractNoteImages(from: html).count), og:image=\(OGMetaExtractor.extract(property: "og:image", from: html).count)")
            #endif
            throw LinkParseError.emptyResult
        }
        return LinkParseResult(title: title, images: images, videos: videos)
    }

    private static func isAllowedImageURL(_ url: URL) -> Bool {
        guard let host = url.host else { return false }
        return allowedImageHosts.contains { host.contains($0) }
    }

    // MARK: - __INITIAL_STATE__ 解析

    /// 从页面 JSON 的所有 imageList 中提取笔记图片（每张图只取一个原图 URL）
    private func extractNoteImages(from html: String) -> [URL] {
        guard let json = extractInitialStateJSON(from: html) else { return [] }
        let contents = extractAllImageListContents(from: json)
        var urls: [URL] = []
        for content in contents {
            for object in extractObjects(from: content) {
                if let url = extractImageURL(from: object) {
                    urls.append(url)
                }
            }
        }
        return urls
    }

    /// 提取视频笔记的视频地址：优先 video 流的 masterUrl，兜底 playUrl / downloadUrl
    private func extractNoteVideos(from html: String) -> [URL] {
        guard let json = extractInitialStateJSON(from: html) else { return [] }
        // masterUrl 是视频流地址（多清晰度/多协议，取第一个即可）
        let masterURLs = extractFieldValues(json, field: "masterUrl")
        if !masterURLs.isEmpty {
            return [masterURLs[0].httpsURL]
        }
        var urls = extractFieldValues(json, field: "playUrl")
        urls += extractFieldValues(json, field: "downloadUrl")
        return urls.map { $0.httpsURL }.unique
    }

    /// 提取 JSON 中指定字段的字符串值（还原转义）
    private func extractFieldValues(_ json: String, field: String) -> [URL] {
        let pattern = "\"\(field)\"\\s*:\\s*\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = json as NSString
        let matches = regex.matches(in: json, range: NSRange(location: 0, length: ns.length))
        return matches.compactMap { match -> URL? in
            guard match.numberOfRanges > 1 else { return nil }
            let raw = ns.substring(with: match.range(at: 1))
                .replacingOccurrences(of: "\\u002F", with: "/")
                .replacingOccurrences(of: "\\/", with: "/")
            return URL(string: raw)
        }
    }

    /// 截取 window.__INITIAL_STATE__= 后的 JSON 字符串
    private func extractInitialStateJSON(from html: String) -> String? {
        guard let markerRange = html.range(of: "window.__INITIAL_STATE__=") else { return nil }
        let jsonStart = markerRange.upperBound
        guard let scriptEnd = html[jsonStart...].range(of: "</script>") else { return nil }
        var json = String(html[jsonStart..<scriptEnd.lowerBound])
        if json.hasSuffix(";") {
            json.removeLast()
        }
        return json
    }

    /// 提取 JSON 中所有 "imageList" 数组的内容（不含外层方括号），括号配对扫描
    private func extractAllImageListContents(from json: String) -> [String] {
        var contents: [String] = []
        var searchStart = json.startIndex
        while searchStart < json.endIndex,
              let match = json.range(of: #""imageList"\s*:\s*\["#, options: .regularExpression, range: searchStart..<json.endIndex)
        {
            var index = match.upperBound
            var depth = 1
            while index < json.endIndex {
                let ch = json[index]
                if ch == "[" {
                    depth += 1
                } else if ch == "]" {
                    depth -= 1
                    if depth == 0 {
                        contents.append(String(json[match.upperBound..<index]))
                        searchStart = json.index(after: index)
                        break
                    }
                }
                index = json.index(after: index)
            }
            if depth != 0 {
                break
            } // 防御：括号不配对时停止，避免死循环
        }
        return contents
    }

    /// 括号配对提取所有顶层对象（支持嵌套）
    private func extractObjects(from content: String) -> [String] {
        var objects: [String] = []
        var start: String.Index?
        var depth = 0
        var index = content.startIndex
        while index < content.endIndex {
            let ch = content[index]
            if ch == "{" {
                if depth == 0 {
                    start = index
                }
                depth += 1
            } else if ch == "}" {
                depth -= 1
                if depth == 0, let s = start {
                    objects.append(String(content[s ... index]))
                    start = nil
                }
            }
            index = content.index(after: index)
        }
        return objects
    }

    /// 从单个图片对象中取 URL，只取原图字段（urlDefault > url），排除 urlPre/urlPreDefault 等压缩模糊图
    private func extractImageURL(from object: String) -> URL? {
        for field in ["urlDefault", "url"] {
            let pattern = "\"\(field)\"\\s*:\\s*\"([^\"]+)\""
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: object, range: NSRange(location: 0, length: (object as NSString).length)),
               match.numberOfRanges > 1
            {
                let raw = (object as NSString).substring(with: match.range(at: 1))
                // JSON 转义还原
                let cleaned = raw
                    .replacingOccurrences(of: "\\u002F", with: "/")
                    .replacingOccurrences(of: "\\/", with: "/")
                return URL(string: cleaned)
            }
        }
        return nil
    }
}
