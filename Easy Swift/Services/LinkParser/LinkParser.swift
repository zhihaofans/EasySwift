//
//  LinkParser.swift
//  Easy Swift
//
//  链接解析的公共契约：结果模型、错误模型、解析器协议与注册表。
//
//  约定：
//  - 抓取一律走 VideoHTTP（它负责 UA、最终 URL、Cookie、短链）；
//  - 失败必须抛 LinkParseError，由它决定用户看到的那句话；
//  - 「解析不到」和「被拦住」是两件事，不要都报成"内容不存在"。
//
//  新网站支持：实现 LinkParser 协议并注册到 LinkParserRegistry 即可。
//
//  Created by zzh on 2026/08/20.
//

import Foundation

/// 解析结果
struct LinkParseResult {
    var title: String?
    var images: [URL]
    var videos: [URL]
    /// 动图 / Live Photo：键是它在 `images` 里的下标，值是该图的短视频地址。
    /// 用下标而不是数组下标对齐——动图只出现在部分图上，用数组会整体错位。
    var motions: [Int: URL]
    /// 成功但有话说：去水印回退、动图缺失之类，界面上提示一次即可
    var notice: String?

    init(title: String? = nil,
         images: [URL] = [],
         videos: [URL] = [],
         motions: [Int: URL] = [:],
         notice: String? = nil)
    {
        self.title = title
        self.images = images
        self.videos = videos
        self.motions = motions
        self.notice = notice
    }

    var isEmpty: Bool {
        return images.isEmpty && videos.isEmpty
    }
}

/// 解析错误：`kind` 决定用户看到的文案，**不要**把 HTTP 状态码直接甩给用户。
enum LinkParseError: LocalizedError {
    /// 不支持的网站 / 链接形态
    case unsupported
    /// 需要登录才能看（平台登录墙）
    case needLogin
    /// 网络层失败：超时、DNS、连接被拒
    case network
    /// 被风控拦截（验证码页、异常跳转）
    case blocked
    /// 作品确实没了：删除、私密、不可见
    case notFound
    /// 页面拿到了，但没解析出内容
    case emptyResult
    /// 平台改版 / 响应结构变了，`message` 写实测事实，便于排查
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return "暂不支持该网站"
        case .needLogin:
            return "该内容需要登录后才能查看"
        case .network:
            return "网络请求失败，请检查网络后重试"
        case .blocked:
            return "平台风控拦截了本次请求，请稍后重试"
        case .notFound:
            return "内容不存在、已删除或不可见"
        case .emptyResult:
            return "未解析到图片或视频"
        case let .unknown(message):
            return message.isEmpty ? "解析失败，请稍后重试" : message
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

    /// 该链接由哪个解析器负责（nil = 不支持）
    static func parser(for url: URL) -> (any LinkParser)? {
        return parsers.first(where: { $0.canParse(url) })
    }
}

// MARK: - 兼容层（抖音回退路线仍在使用，迁移完成后删除）

/// 简单的页面抓取：等价于 `VideoHTTP.get` + 非 2xx 抛错。
/// 新代码请直接用 `VideoHTTP`，这里只为还没迁完的解析器保留。
enum HTMLFetcher {
    static func fetchHTML(url: URL) async throws -> (html: String, finalURL: URL) {
        let response = try await VideoHTTP.get(url, ua: VideoHTTP.UA.desktopChrome)
        guard (200 ..< 300).contains(response.status) else {
            let snippet = response.body.prefix(300)
            debugPrint("[LinkParser] 请求失败 \(url.absoluteString) -> HTTP \(response.status)，响应开头: \(snippet)")
            // 非 2xx 多半是 SPA/风控页，交给上层走 WebView 兜底，而不是直接判失败
            throw LinkParseError.emptyResult
        }
        return (response.body, response.url)
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

// MARK: - 工具

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
