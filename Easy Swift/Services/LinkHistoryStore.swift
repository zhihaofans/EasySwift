//
//  LinkHistoryStore.swift
//  Easy Swift
//
//  解析历史的写入/清理。列表本身由页面的 `@Query` 提供（AGENTS §3.1：不要另存一份数组）。
//
//  去重规则：同一条**最终地址**只保留最新一条（短链不同、展开后同一篇 → 只留一条）。
//  上限：最近 200 条，超出从最旧的开始删。
//

import Foundation
import SwiftData
import SwiftUtils

enum LinkHistoryStore {
    static let maxItems=200

    /// 记一条解析成功的历史。返回是否真的写入（调用方一般不需要处理失败）。
    @MainActor
    @discardableResult
    static func record(sourceURL: String,
                       finalURL: String,
                       platform: String,
                       result: LinkParseResult) -> Bool
    {
        let source=sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let final=finalURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !final.isEmpty else {
            debugPrint("[解析历史] 最终地址为空，跳过")
            return false
        }

        let context=AppDataStore.container.mainContext
        let now=Int(Date().timeIntervalSince1970 * 1000)

        // 封面：视频优先取封面，其次第一张图
        let cover=result.videoCovers.compactMap { $0 }.first?.absoluteString
            ?? result.images.first?.absoluteString

        do {
            // 同一条最终地址：更新原有那条（时间、标题、计数），不新增
            let predicate=#Predicate<LinkHistoryItem> { $0.finalURL == final }
            if let existing=try context.fetch(FetchDescriptor<LinkHistoryItem>(predicate: predicate)).first {
                existing.sourceURL=source
                existing.platform=platform
                existing.title=result.title ?? ""
                existing.coverURL=cover
                existing.imageCount=result.images.count
                existing.videoCount=result.videos.count
                existing.motionCount=result.motions.count
                existing.create_time_ms=now
                debugPrint("[解析历史] 更新已有条目（同一最终地址）")
            } else {
                context.insert(LinkHistoryItem(sourceURL: source,
                                               finalURL: final,
                                               platform: platform,
                                               title: result.title ?? "",
                                               coverURL: cover,
                                               imageCount: result.images.count,
                                               videoCount: result.videos.count,
                                               motionCount: result.motions.count,
                                               create_time_ms: now))
                debugPrint("[解析历史] 新增一条：\(platform) \(result.images.count) 图 / \(result.videos.count) 视频")
            }
            try context.save()
            trimIfNeeded(context: context)
            return true
        } catch {
            debugPrint("[解析历史] 保存失败: \(error.localizedDescription)")
            return false
        }
    }

    /// 超过上限就从最旧的开始删
    @MainActor
    private static func trimIfNeeded(context: ModelContext) {
        do {
            let all=try context.fetch(FetchDescriptor<LinkHistoryItem>(sortBy: [SortDescriptor(\.create_time_ms, order: .reverse)]))
            guard all.count > maxItems else { return }
            for item in all[maxItems...] { context.delete(item) }
            try context.save()
            debugPrint("[解析历史] 超出上限，清理了 \(all.count - maxItems) 条")
        } catch {
            debugPrint("[解析历史] 裁剪失败: \(error.localizedDescription)")
        }
    }

    @MainActor
    static func delete(_ item: LinkHistoryItem) {
        let context=AppDataStore.container.mainContext
        context.delete(item)
        do { try context.save() } catch { debugPrint("[解析历史] 删除失败: \(error.localizedDescription)") }
    }

    @MainActor
    static func clear() {
        let context=AppDataStore.container.mainContext
        do {
            for item in try context.fetch(FetchDescriptor<LinkHistoryItem>()) {
                context.delete(item)
            }
            try context.save()
            debugPrint("[解析历史] 已清空")
        } catch {
            debugPrint("[解析历史] 清空失败: \(error.localizedDescription)")
        }
    }
}
