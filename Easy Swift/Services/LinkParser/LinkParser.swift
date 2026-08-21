//
//  LinkParser.swift
//  Easy Swift
//
//  通用链接解析接口：输入链接 → 解析页面中的图片/视频
//  新网站支持：实现 LinkParser 协议并注册到 LinkParserRegistry 即可
//
//  Created by zzh on 2026/08/20.
//

import Foundation

/// 解析结果
struct LinkParseResult {
    var title: String?
    var images: [URL]
    var videos: [URL]

    init(title: String? = nil, images: [URL] = [], videos: [URL] = []) {
        self.title = title
        self.images = images
        self.videos = videos
    }
}

/// 解析错误
enum LinkParseError: LocalizedError {
    case unsupported // 不支持的网站
    case fetchFailed // 页面抓取失败
    case emptyResult // 未解析到内容

    var errorDescription: String? {
        switch self {
        case .unsupported: return "暂不支持该网站"
        case .fetchFailed: return "获取页面失败，请检查网络或稍后重试"
        case .emptyResult: return "未解析到图片或视频"
        }
    }
}

/// 链接解析器协议：新网站只需实现此协议并注册
protocol LinkParser: Sendable {
    /// 网站名称（用于展示）
    var name: String { get }
    /// 是否支持解析该链接
    func canParse(_ url: URL) -> Bool
    /// 解析链接，返回页面中的图片/视频
    func parse(url: URL) async throws -> LinkParseResult
}

/// 解析器注册表：集中管理所有支持的网站
enum LinkParserRegistry {
    /// 新网站在此注册
    static let parsers: [any LinkParser] = [
        XiaohongshuParser(),
        DouyinParser(),
    ]

    /// 按链接分发给对应解析器
    static func parse(url: URL) async throws -> LinkParseResult {
        guard let parser = parsers.first(where: { $0.canParse(url) }) else {
            throw LinkParseError.unsupported
        }
        return try await parser.parse(url: url)
    }
}

/// HTML 抓取工具
enum HTMLFetcher {
    /// 模拟浏览器 UA 抓取页面 HTML，返回 HTML 与重定向后的最终 URL（短链会跳到真实页面）
    static func fetchHTML(url: URL) async throws -> (html: String, finalURL: URL) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                print("[LinkParser] 请求无 HTTP 响应: \(url.absoluteString)")
                throw LinkParseError.fetchFailed
            }
            guard (200 ..< 300).contains(http.statusCode) else {
                // 非 2xx：输出状态码与响应开头，便于排查（如反爬 403）
                let snippet = String(data: data, encoding: .utf8)?.prefix(300) ?? "<非文本响应>"
                print("[LinkParser] 请求失败 \(url.absoluteString) -> HTTP \(http.statusCode), 响应开头: \(snippet)")
                throw LinkParseError.fetchFailed
            }
            let finalURL = http.url ?? url
            print("[LinkParser] 请求成功 \(url.absoluteString) -> \(finalURL.absoluteString) HTTP \(http.statusCode), \(data.count) bytes")
            return (String(data: data, encoding: .utf8) ?? "", finalURL)
        } catch let error as LinkParseError {
            throw error
        } catch {
            print("[LinkParser] 请求异常 \(url.absoluteString): \(error.localizedDescription)")
            throw LinkParseError.fetchFailed
        }
    }

    /// 从 HTML 中收集符合域名特征的图片 URL（去重、去水印参数前的原始地址）
    static func extractImageURLs(from html: String, hostPattern: String) -> [URL] {
        let pattern = #"https?://[^"'\s\\]*\#(hostPattern)[^"'\s\\]*"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let ns = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
        return matches.compactMap { match -> URL? in
            let raw = ns.substring(with: match.range)
            // 去掉常见转义与尾部标点
            let cleaned = raw.trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
            return URL(string: cleaned)
        }.unique
    }
}

/// OG Meta 标签提取（og:title / og:image / og:video 等）
enum OGMetaExtractor {
    static func extract(property: String, from html: String) -> [String] {
        var results: [String] = []
        // 变体1：property 在 content 前
        let p1 = #"<meta[^>]*property=["']\#(property)["'][^>]*content=["']([^"']+)["'][^>]*>"#
        // 变体2：content 在 property 前
        let p2 = #"<meta[^>]*content=["']([^"']+)["'][^>]*property=["']\#(property)["'][^>]*>"#
        for pattern in [p1, p2] {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let ns = html as NSString
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
            for match in matches where match.numberOfRanges > 1 {
                results.append(ns.substring(with: match.range(at: 1)))
            }
        }
        return results.unique
    }
}

extension Array where Element == String {
    /// 去重并保持顺序
    var unique: [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}

extension Array where Element == URL {
    /// 去重并保持顺序
    var unique: [URL] {
        var seen = Set<String>()
        return filter { seen.insert($0.absoluteString).inserted }
    }
}

extension URL {
    /// 强制转为 https：图片 CDN 普遍支持 https，规避 App Transport Security 对 http 明文链接的拦截
    var httpsURL: URL {
        guard scheme == "http" else { return self }
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.scheme = "https"
        return components?.url ?? self
    }
}
