//
//  InboxClassifier.swift
//  Easy Swift
//
//  收件箱的分类与分派建议。**纯逻辑**：不碰网络、不碰 SwiftData，
//  仓库外的 harness 能直接编它做断言（这条规则来自 AGENTS §5：能抽纯函数就别靠点 UI 验证）。
//
//  分类只看"这段文本最像什么"，不猜用户的意图：
//  - 认出小红书/抖音域名 → 建议去链接解析（对应平台）
//  - 其它 http(s) 链接 → 链接解析（解析器不支持时会自己报"暂不支持"）
//  - 没有任何链接、且短得像关键词 → 搜索
//  - 其它（长文本/多行）→ 生成二维码（二维码能把整段文本编进去，也最通用）
//

import Foundation

/// 从分享文本里抠链接：整段可能夹着标题、emoji、话题。
enum LinkExtractor {
    /// 链接末尾常见的标点（**不包含 `/`**：`punctuationCharacters` 会把路径里的斜杠一起吃掉，
    /// 实测 `v.douyin.com/iAbCdEf/` 变成没有斜杠）
    private static let trailingPunctuation=CharacterSet(charactersIn: "\"'，。；、）)】」》>,.")

    /// 整段文本是否"看起来就是个域名"：必须纯 ASCII、含点、无空白。
    /// 不加这条的话，像"没有链接"这种不带空格的中文会被拼成 `https://没有链接`，
    /// 而 URL.host 居然不为 nil —— 于是中文被误判成链接。
    private static func looksLikeBareDomain(_ text: String) -> Bool {
        guard text.contains(".") else { return false }
        return text.unicodeScalars.allSatisfy { $0.isASCII && !$0.properties.isWhitespace }
    }

    /// 第一个 http(s) 链接；没有就 nil
    static func firstURL(in text: String) -> URL? {
        let trimmed=text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 1) 整段就是一个链接（带 scheme，或者是不带 scheme 的裸域名）
        if !trimmed.contains(where: { $0.isWhitespace }) {
            if trimmed.hasPrefix("http") {
                if let url=URL(string: trimmed), url.host != nil { return url }
            } else if looksLikeBareDomain(trimmed) {
                if let url=URL(string: "https://\(trimmed)"), url.host?.contains(".") == true { return url }
            }
        }

        // 2) 从文本里找第一个 http(s) 链接
        guard let regex=try? NSRegularExpression(pattern: #"https?://[^\s"'<>，。；、）)】]+"#) else { return nil }
        let ns=trimmed as NSString
        guard let match=regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let raw=ns.substring(with: match.range).trimmingCharacters(in: trailingPunctuation)
        guard let url=URL(string: raw), url.host != nil else { return nil }
        return url
    }
}

/// 分类结果
enum InboxKind: String, CaseIterable {
    case xiaohongshu
    case douyin
    case link
    case keyword
    case text

    var title: String {
        switch self {
        case .xiaohongshu: return "小红书"
        case .douyin: return "抖音"
        case .link: return "链接"
        case .keyword: return "关键词"
        case .text: return "文本"
        }
    }

    var systemImage: String {
        switch self {
        case .xiaohongshu, .douyin, .link: return "link"
        case .keyword: return "magnifyingglass"
        case .text: return "text.alignleft"
        }
    }
}

/// 来源
enum InboxSource: String, CaseIterable {
    case share
    case urlScheme
    case clipboard
    case manual

    var title: String {
        switch self {
        case .share: return "分享"
        case .urlScheme: return "链接调起"
        case .clipboard: return "剪贴板"
        case .manual: return "手动"
        }
    }
}

/// 建议送去哪个功能页
enum InboxRoute: Equatable {
    case linkParser
    case search
    case qrcode
}

/// 分类 + 分派建议
struct InboxClassification: Equatable {
    let kind: InboxKind
    let link: URL?
    let route: InboxRoute

    /// 走进这个页面时要带上哪段文本：
    /// - 链接解析/搜索：优先只带链接或关键词，别把整段分享文案塞进输入框
    /// - 二维码：带原文（整段文本编进二维码才是本意）
    var payload: String {
        switch route {
        case .linkParser:
            return link?.absoluteString ?? trimmedText
        case .search:
            return trimmedText
        case .qrcode:
            return trimmedText
        }
    }

    private let trimmedText: String

    init(kind: InboxKind, link: URL?, route: InboxRoute, trimmedText: String) {
        self.kind=kind
        self.link=link
        self.route=route
        self.trimmedText=trimmedText
    }
}

enum InboxClassifier {
    /// 关键词上限：超过这个长度就不当关键词（用户不会拿一句长文去搜）
    private static let keywordLengthLimit=24

    private static let xhsHosts=["xiaohongshu.com", "xhslink.com", "xhslink.cn"]
    private static let douyinHosts=["douyin.com", "iesdouyin.com"]

    static func classify(_ rawText: String) -> InboxClassification {
        let text=rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url=LinkExtractor.firstURL(in: text) else {
            let looksLikeKeyword = text.count <= keywordLengthLimit && !text.contains("\n")
            return InboxClassification(kind: looksLikeKeyword ? .keyword : .text,
                                       link: nil,
                                       route: looksLikeKeyword ? .search : .qrcode,
                                       trimmedText: text)
        }

        let host=(url.host ?? "").lowercased()
        let bare=host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        if xhsHosts.contains(where: { bare == $0 || bare.hasSuffix("." + $0) }) {
            return InboxClassification(kind: .xiaohongshu, link: url, route: .linkParser, trimmedText: text)
        }
        if douyinHosts.contains(where: { bare == $0 || bare.hasSuffix("." + $0) }) {
            return InboxClassification(kind: .douyin, link: url, route: .linkParser, trimmedText: text)
        }
        return InboxClassification(kind: .link, link: url, route: .linkParser, trimmedText: text)
    }
}
