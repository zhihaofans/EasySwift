//
//  InboxShared.swift
//  Easy Swift
//
//  **主 App 与分享扩展共用的收件箱文件层**。
//
//  为什么单独一个文件：
//  - 分享扩展（第二步）要把收到的东西写进同一个 `inbox.json`，格式必须只有一份定义；
//  - 扩展不该依赖 SwiftUtils / SwiftUI，所以这里只用 Foundation + os.Logger；
//  - App Group 的"写探针"逻辑也在这里 —— 主 App 和扩展都可能遇到"没权限写 group 目录"，
//    判定方式必须一致，否则一端写进去、另一端读不到。
//
//  记录格式（JSON 数组，按 createdAt 倒序存）见 InboxItem。
//

import Foundation
import os

/// 一条收件箱记录（扩展与主 App 都靠它编解码）
struct InboxItem: Codable, Identifiable, Equatable {
    var id: UUID=UUID()
    /// 原始文本（可能是整段分享文案）
    var rawText: String
    /// 从文本里抠出来的第一个链接
    var link: String?
    /// 分类结果（InboxKind 的 rawValue）
    var kind: String
    /// 来源（InboxSource 的 rawValue）
    var source: String
    /// Unix 秒
    var createdAt: Int
    var handled: Bool=false

    var date: Date { Date(timeIntervalSince1970: TimeInterval(createdAt)) }
    var kindValue: InboxKind { InboxKind(rawValue: kind) ?? .text }
    var sourceValue: InboxSource { InboxSource(rawValue: source) ?? .manual }

    var previewText: String {
        if let link, !link.isEmpty { return link }
        return rawText.replacingOccurrences(of: "\n", with: " ")
    }
}

/// 收件箱的磁盘读写。所有路径都走这里，避免主 App 和扩展各写一套。
enum InboxFile {
    /// App Group（主 App 与扩展共享）。必须与开发者后台、两个 entitlements 里的值完全一致。
    static let appGroupID="group.me.zzhhoo.easyswift"
    static let fileName="inbox.json"
    /// 收件箱是临时中转，不是存档；超过就从最旧的开始丢
    static let maxItems=200
    /// 同一条 10 秒内重复来源（分享一次却多次激活）只收一次
    static let dedupeWindow: TimeInterval=10

    private static let logger=Logger(subsystem: "me.zzhhoo.easyswift", category: "inbox")

    // MARK: - 位置

    /// 目录 + 是否真的在 App Group 里。
    ///
    /// 踩过的坑：没有 App Group entitlement 时 `containerURL(forSecurityApplicationGroupIdentifier:)`
    /// **仍然返回路径**，写进去报"没有权限保存到文件夹"。所以要拿真实写入探针确认，
    /// 写不进去就退回 Application Support（此时扩展与主 App 不共享，功能仍可用）。
    static func resolveDirectory() -> (url: URL, usesAppGroup: Bool) {
        let fileManager=FileManager.default
        if let group=fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let directory=group.appendingPathComponent("Inbox", isDirectory: true)
            if isWritableDirectory(directory) {
                return (directory, true)
            }
            logger.error("App Group 目录不可写（缺 entitlement？），退回 AppSupport")
        }
        let base=fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directory=base.appendingPathComponent("Inbox", isDirectory: true)
        _=isWritableDirectory(directory)
        return (directory, false)
    }

    /// 建目录 + 写一个探针文件，能写才算可用
    static func isWritableDirectory(_ directory: URL) -> Bool {
        let fileManager=FileManager.default
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let probe=directory.appendingPathComponent(".write-probe")
            try Data("ok".utf8).write(to: probe, options: [.atomic])
            try? fileManager.removeItem(at: probe)
            return true
        } catch {
            return false
        }
    }

    static func defaultFileURL() -> URL {
        resolveDirectory().url.appendingPathComponent(fileName)
    }

    // MARK: - 读写

    /// 读全部（最新在前）。解析失败时把坏文件改名留证，返回空数组。
    static func load(at fileURL: URL) -> [InboxItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let data=try Data(contentsOf: fileURL)
            var items=try JSONDecoder().decode([InboxItem].self, from: data)
            if items.count > maxItems { items=Array(items.prefix(maxItems)) }
            return items.sorted { $0.createdAt > $1.createdAt }
        } catch {
            logger.error("解析失败：\(error.localizedDescription, privacy: .public)")
            let backup=fileURL.appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970))")
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            return []
        }
    }

    /// 原子写。返回是否成功（调用方据此提示用户，不要静默吞掉）
    @discardableResult
    static func save(_ items: [InboxItem], to fileURL: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let encoder=JSONEncoder()
            encoder.outputFormatting=[.prettyPrinted, .sortedKeys]
            let data=try encoder.encode(Array(items.prefix(maxItems)))
            try data.write(to: fileURL, options: [.atomic])
            return true
        } catch {
            logger.error("保存失败：\(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// 追加一条：分类 → 去重 → 截断 → 落盘。主 App 与扩展走同一个入口。
    @discardableResult
    static func append(rawText: String,
                       source: InboxSource,
                       to fileURL: URL) -> InboxItem?
    {
        let text=rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        var items=load(at: fileURL)
        let cutoff=Int(Date().timeIntervalSince1970 - dedupeWindow)
        if let existing=items.first(where: { $0.rawText == text && $0.createdAt >= cutoff }) {
            logger.debug("\(source.rawValue, privacy: .public) 重复（10 秒内已有），忽略")
            return existing
        }
        let classification=InboxClassifier.classify(text)
        let item=InboxItem(rawText: text,
                           link: classification.link?.absoluteString,
                           kind: classification.kind.rawValue,
                           source: source.rawValue,
                           createdAt: Int(Date().timeIntervalSince1970))
        items.insert(item, at: 0)
        guard save(items, to: fileURL) else { return nil }
        logger.debug("收下：kind=\(item.kind, privacy: .public) source=\(source.rawValue, privacy: .public) 长度=\(text.count)")
        return item
    }
}
