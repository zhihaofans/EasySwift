//
//  InboxActions.swift
//  Easy Swift
//
//  收件箱面板的「能做什么」：由内容类型 + 解析器支持情况决定，**只在主 App 编译**。
//
//  为什么单独一个文件：
//  分享扩展也编译 InboxClassifier（它要算 kind 存下来），但扩展不编译链接解析器 ——
//  把「支不支持解析」的判断放这里，扩展就不用拖一整套 VideoHTTP/解析器进来。
//

import Foundation

/// 收件箱里能给这条内容做什么
enum InboxAction: String, CaseIterable, Identifiable {
    /// 复制到剪贴板（复制原文）
    case copy
    /// 解析链接（只对注册表支持的平台出现）
    case parse
    /// 生成二维码
    case qrcode
    /// 用这段文字搜索（只有文本类才有）
    case search

    var id: String { rawValue }

    var title: String {
        switch self {
        case .copy: return "复制到剪贴板"
        case .parse: return "解析链接"
        case .qrcode: return "生成二维码"
        case .search: return "用这段文字搜索"
        }
    }

    var systemImage: String {
        switch self {
        case .copy: return "doc.on.doc"
        case .parse: return "link"
        case .qrcode: return "qrcode"
        case .search: return "magnifyingglass"
        }
    }
}

extension InboxClassification {
    /// 这条内容能做的操作（顺序即面板里的显示顺序）
    ///
    /// - 文本：复制 / 二维码 / 搜索
    /// - 链接：复制 / [解析] / 二维码 —— **「解析」只在解析器真的支持该域名时出现**
    var actions: [InboxAction] {
        guard let link else { return [.copy, .qrcode, .search] }
        var list: [InboxAction]=[.copy]
        if LinkParserRegistry.capability(for: link).isSupported {
            list.append(.parse)
        }
        list.append(.qrcode)
        return list
    }

    /// 面板顶部那句"这是什么"，顺手解释为什么没有「解析」
    var header: String {
        guard let link else {
            return "这是一段文本（\(textLength) 字）"
        }
        let capability=LinkParserRegistry.capability(for: link)
        if let name=capability.platformName {
            return "这是\(name)链接，可以解析"
        }
        return "这是普通网页链接，暂不支持解析"
    }

    /// 解析用哪个链接（没有链接时为 nil）
    var parseLink: String? { link?.absoluteString }
}
