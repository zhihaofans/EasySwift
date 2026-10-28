//
//  InboxClassifier.swift
//  Easy Swift
//
//  收件箱的分类与分派建议。**纯逻辑**：不碰网络、不碰 SwiftData，
//  仓库外的 harness 能直接编它做断言（这条规则来自 AGENTS §5：能抽纯函数就别靠点 UI 验证）。
//
//  分类只看"这段文本是什么"，**不替用户决定要做什么** —— 由收件箱面板把可做的操作列出来问。
//  - 链接：复制 + 二维码；**只有解析器支持的平台（小红书/抖音…）才额外给「解析」**
//    （支不支持问 LinkParserRegistry.capability(for:)，收件箱不写死域名列表）
//  - 文本：复制 + 二维码 + 搜索
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
    /// 历史版本存过这个值（短文本当关键词用）；新分类不再产生它，但旧数据要能读
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

/// 分类结果：**只描述内容本身**（类型、链接、原文）。
///
/// 「能做什么操作」「面板顶部那句话」放在 App 专属的 InboxActions.swift 里 ——
/// 那部分要问 LinkParserRegistry（支持哪些平台），而分享扩展不编译链接解析器。
struct InboxClassification: Equatable {
    let kind: InboxKind
    let link: URL?

    private let trimmedText: String

    /// 复制：一律复制**原文**（分享文案里常带标题/描述，粘出去更完整）
    var copyText: String { trimmedText }

    /// 二维码：链接编链接（短且指向明确），文本编原文
    var qrcodeText: String { link?.absoluteString ?? trimmedText }

    /// 搜索：用原文当关键词（用户进去还能改）
    var searchText: String { trimmedText }

    /// 文本长度（面板里显示"12 字"）
    var textLength: Int { trimmedText.count }

    init(kind: InboxKind, link: URL?, trimmedText: String) {
        self.kind=kind
        self.link=link
        self.trimmedText=trimmedText
    }
}

enum InboxClassifier {
    private static let xhsHosts=["xiaohongshu.com", "xhslink.com", "xhslink.cn"]
    private static let douyinHosts=["douyin.com", "iesdouyin.com"]

    /// 只判断"这是什么"，不判断"能做什么"（后者在 App 侧的 InboxActions）
    static func classify(_ rawText: String) -> InboxClassification {
        let text=rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url=LinkExtractor.firstURL(in: text) else {
            return InboxClassification(kind: .text, link: nil, trimmedText: text)
        }
        let host=(url.host ?? "").lowercased()
        let bare=host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        let kind: InboxKind
        if xhsHosts.contains(where: { bare == $0 || bare.hasSuffix("." + $0) }) {
            kind = .xiaohongshu
        } else if douyinHosts.contains(where: { bare == $0 || bare.hasSuffix("." + $0) }) {
            kind = .douyin
        } else {
            kind = .link
        }
        return InboxClassification(kind: kind, link: url, trimmedText: text)
    }
}
