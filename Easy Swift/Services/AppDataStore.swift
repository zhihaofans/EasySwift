//
//  AppDataStore.swift
//  Easy Swift
//
//  App 内**唯一**的 SwiftData 容器（剪贴板 + 解析历史共用）。
//
//  为什么必须只有一个：`.modelContainer(for:)` 每调一次都会按默认 URL
//  （Application Support/default.store）建容器，两个容器挂不同 schema 去开**同一个文件**
//  会出现模型不兼容 / 各自缓存不一致的问题。所以把模型都登记到这一个容器里，
//  各处用 `.modelContainer(AppDataStore.container)`。
//

import Foundation
import SwiftData

enum AppDataStore {
    /// 全 App 共用：剪贴板条目 + 解析历史
    static let container: ModelContainer = {
        let schema=Schema([ClipItemDataModel.self, LinkHistoryItem.self])
        do {
            return try ModelContainer(for: schema)
        } catch {
            debugPrint("[数据] 容器创建失败: \(error.localizedDescription)，退回内存容器（重启后丢失）")
            do {
                return try ModelContainer(for: schema,
                                          configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
            } catch {
                // 连内存容器都建不起来说明 schema 本身有问题，崩溃比静默假成功好
                fatalError("[数据] 连内存容器都创建失败: \(error)")
            }
        }
    }()
}
