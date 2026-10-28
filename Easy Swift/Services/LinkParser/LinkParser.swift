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

/// 解析过程中「现在在干嘛」——只喂给界面的状态提示，不参与任何判断。
///
/// 为什么需要它：抖音图文要等隐藏 WebView 5–18 秒，只显示一句「正在解析…」用户会以为卡死。
/// 每个 case 都必须对应解析器里真实发生的下一步，**不许为了好看编阶段**。
enum LinkParseStage: Equatable, Sendable {
    /// 展开短链 / 跟随跳转
    case expandingShortLink
    /// 请求页面（纯 HTTP，一般 1 秒内回）
    case requestingPage
    /// 页面返回登录墙，换桌面 UA 再要一次（风控是概率性的）
    case retryingWithDesktopUA
    /// HTTP 与隐藏浏览器同时在跑（抖音：视频走 HTTP，图文只有页面能拿到动图）
    case racingPageAndWebView
    /// 浏览器页面已打开，等它自己把数据吐出来（抖音最长 18 秒）
    case waitingWebData
    /// HTTP 已经拿到 N 张图，还在等页面补动图
    case waitingMotions(count: Int)
    /// 正在逐张探测去水印原图是否可用
    case checkingOriginalImages

    var title: String {
        switch self {
        case .expandingShortLink:
            return "正在展开短链…"
        case .requestingPage:
            return "正在请求页面…"
        case .retryingWithDesktopUA:
            return "页面要求登录，换桌面版重试…"
        case .racingPageAndWebView:
            return "正在请求页面，并启用浏览器内核…"
        case .waitingWebData:
            return "浏览器已打开，等待页面数据…"
        case let .waitingMotions(count):
            return "已拿到 \(count) 张图，正在补动图…"
        case .checkingOriginalImages:
            return "正在校验原图…"
        }
    }
}

/// 阶段上报器：解析器在关键节点调用一次，界面负责把回调抛回主线程。
/// 调不调都不影响解析结果，所以解析器可以按需忽略。
struct LinkParseProgress: Sendable {
    private let handler: @Sendable (LinkParseStage) -> Void

    init(_ handler: @escaping @Sendable (LinkParseStage) -> Void) {
        self.handler = handler
    }

    func callAsFunction(_ stage: LinkParseStage) {
        handler(stage)
    }

    /// 不关心进度时用它
    static let silent = LinkParseProgress { _ in }
}

/// 链接解析器协议：新网站只需实现此协议并注册
protocol LinkParser: Sendable {
    /// 网站名称（用于展示）
    var name: String { get }
    /// 是否支持解析该链接
    func canParse(_ url: URL) -> Bool
    /// 解析链接，返回页面中的图片/视频。
    /// `progress` 只用于界面提示：不实现也能正常解析。
    func parse(url: URL, progress: LinkParseProgress) async throws -> LinkParseResult
}

extension LinkParser {
    /// 不关心进度的调用方式
    func parse(url: URL) async throws -> LinkParseResult {
        try await parse(url: url, progress: .silent)
    }
}

/// 解析器注册表：集中管理所有支持的网站
/// 解析能力查询结果：给分享/收件箱用，**不发网络请求**（面板要秒开）
struct LinkParserCapability: Equatable {
    /// 平台名（"小红书" / "抖音"）；不支持时为 nil
    let platformName: String?

    var isSupported: Bool { platformName != nil }

    static let unsupported=LinkParserCapability(platformName: nil)
}

enum LinkParserRegistry {
    /// 新网站在此注册
    static let parsers: [any LinkParser] = [
        XiaohongshuParser(),
        DouyinParser(),
    ]

    /// 这个链接我们能不能解析、属于哪个平台。
    /// 只做 host 判定，不发请求 —— 收件箱靠它决定要不要显示「解析」按钮。
    static func capability(for url: URL) -> LinkParserCapability {
        guard let parser=parsers.first(where: { $0.canParse(url) }) else { return .unsupported }
        return LinkParserCapability(platformName: parser.name)
    }

    /// 按链接分发给对应解析器
    static func parse(url: URL, progress: LinkParseProgress = .silent) async throws -> LinkParseResult {
        guard let parser = parsers.first(where: { $0.canParse(url) }) else {
            throw LinkParseError.unsupported
        }
        return try await parser.parse(url: url, progress: progress)
    }

    /// 该链接由哪个解析器负责（nil = 不支持）
    static func parser(for url: URL) -> (any LinkParser)? {
        return parsers.first(where: { $0.canParse(url) })
    }
}

// MARK: - 工具

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
