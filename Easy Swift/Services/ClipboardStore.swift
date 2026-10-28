//
//  ClipboardStore.swift
//  Easy Swift
//
//  应用内剪贴板的写入入口（SwiftData 的 ClipItemDataModel）。
//
//  为什么要有这一层：
//  收件箱的「复制到剪贴板」指的是**应用内剪贴板**（首页那个「剪贴板」功能里能看到的条目），
//  不是系统粘贴板。而收件箱不在剪贴板页的视图树里，拿不到那边的 ModelContext，
//  所以容器与写入逻辑收敛到这里，两边共用同一份 —— 各建各的容器会争同一个 default.store。
//

import Foundation
import SwiftData
import SwiftUtils

enum ClipboardStore {
    /// 全 App 共用一份容器（剪贴板页与收件箱都用它，避免两个容器争同一个 store 文件）
    ///
    /// 容器建不起来时退回**内存容器**：本次运行还能用，重启丢 —— 但会打日志说清楚，
    /// 不能静默变成"存了读不回来"。
    static let container: ModelContainer = {
        do {
            return try ModelContainer(for: ClipItemDataModel.self)
        } catch {
            debugPrint("[剪贴板] 容器创建失败: \(error.localizedDescription)，退回内存容器（重启后丢失）")
            do {
                return try ModelContainer(for: ClipItemDataModel.self,
                                          configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            } catch {
                // 连内存容器都建不起来说明 schema 本身有问题，这时崩溃比静默假成功更好
                fatalError("[剪贴板] 连内存容器都创建失败: \(error)")
            }
        }
    }()

    /// 存一条进应用内剪贴板。返回是否真的落库（调用方据此提示用户，不要假装成功）。
    @MainActor
    @discardableResult
    static func append(text: String) -> Bool {
        let content=text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            debugPrint("[剪贴板] 内容为空，跳过")
            return false
        }
        let context=container.mainContext
        do {
            // 已有同一条就不再重复插（和剪贴板页自己的判重口径一致）
            let predicate=#Predicate<ClipItemDataModel> { $0.text == content }
            if let existing=try context.fetch(FetchDescriptor<ClipItemDataModel>(predicate: predicate)).first {
                debugPrint("[剪贴板] 已存在 id=\(existing.id)，更新时间为最新")
                existing.update_time=DateUtil().getTimestamp()
            } else {
                let now=DateUtil().getTimestamp()
                context.insert(ClipItemDataModel(id: UUID(), text: content, create_time: now, update_time: now))
            }
            try context.save()
            debugPrint("[剪贴板] 已写入 \(content.count) 字符")
            return true
        } catch {
            debugPrint("[剪贴板] 保存失败: \(error.localizedDescription)")
            return false
        }
    }
}
