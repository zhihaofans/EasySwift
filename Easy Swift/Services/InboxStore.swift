//
//  InboxStore.swift
//  Easy Swift
//
//  收件箱的存储与写入口。所有"外面进来一段文本"的路径都收敛到这里：
//  - URL scheme：`easyswift://inbox?text=<percent-encoded>`
//  - 剪贴板收件（用户点按钮，系统会弹一次粘贴授权）
//  - 第二步的系统分享（Share Extension 写同一个 JSON 文件，主 App 打开就是同一份数据）
//
//  **为什么不用 SwiftData**：
//  1. 分享扩展不能直接共享主 App 的 SwiftData 容器，靠 App Group 里的文件最直接；
//  2. 工程里剪贴板页已经占了一个 `.modelContainer(for: [ClipItemDataModel.self])`，
//     再挂一个不同 schema 的容器会去抢同一个 default.store，容易出"模型不兼容"。
//  3. 这份数据量小（条数上限 200），JSON 原子写入足够。
//

import Foundation
import SwiftUI
import SwiftUtils

@MainActor
final class InboxStore: ObservableObject {
    static let shared=InboxStore()

    /// 最新在前
    @Published private(set) var items: [InboxItem]=[]

    private let fileURL: URL
    /// 当前是否真的落在 App Group 容器里
    private(set) var usesAppGroup=false

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL=fileURL
            usesAppGroup=false
        } else {
            let resolved=InboxFile.resolveDirectory()
            self.fileURL=resolved.url.appendingPathComponent(InboxFile.fileName)
            usesAppGroup=resolved.usesAppGroup
            debugPrint("[收件箱] 存储位置=\(resolved.usesAppGroup ? "AppGroup" : "AppSupport") \(self.fileURL.path)")
        }
        load()
    }

    // MARK: - 位置（App Group / AppSupport 的判定都在 InboxFile 里，主 App 与扩展共用）

    // MARK: - 读

    private func load() {
        items=InboxFile.load(at: fileURL)
        debugPrint("[收件箱] 读取 \(items.count) 条，文件=\(fileURL.path)")
    }

    /// 重新从磁盘读一遍（从别的进程/扩展写完之后调它）
    func reload() {
        load()
    }

    // MARK: - 写

    @discardableResult
    func add(_ rawText: String, source: InboxSource) -> InboxItem? {
        guard let item=InboxFile.append(rawText: rawText, source: source, to: fileURL) else {
            debugPrint("[收件箱] 写入失败（磁盘或权限问题），文件=\(fileURL.path)")
            return nil
        }
        // 以磁盘为准重新读一遍：扩展可能同时也写了
        load()
        return item
    }

    /// 显式设置已处理状态（操作执行完自动标已处理）
    func markHandled(_ item: InboxItem, _ handled: Bool) {
        guard let index=items.firstIndex(where: { $0.id == item.id }) else { return }
        guard items[index].handled != handled else { return }
        items[index].handled=handled
        persist()
    }

    func toggleHandled(_ item: InboxItem) {
        guard let index=items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].handled.toggle()
        persist()
    }

    func markAllHandled(_ handled: Bool) {
        for index in items.indices { items[index].handled=handled }
        persist()
    }

    func delete(_ item: InboxItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    func clear() {
        items=[]
        persist()
    }

    var unhandledCount: Int {
        items.filter { !$0.handled }.count
    }

    private func persist() {
        if !InboxFile.save(items, to: fileURL) {
            debugPrint("[收件箱] 保存失败，文件=\(fileURL.path)")
        }
    }

    // MARK: - 剪贴板

    /// 收剪贴板。iOS 会触发系统的"允许粘贴"提示，所以**只在用户点按钮时调用**，
    /// 不要放到 onAppear 里偷偷读（会反复弹窗，也容易被判成骚扰）。
    @discardableResult
    func collectFromClipboard() -> InboxItem? {
        let text=ClipboardUtil().getString()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return add(text, source: .clipboard)
    }

    // MARK: - URL scheme

    static let urlScheme="easyswift"
    static let inboxHost="inbox"

    /// 是不是收件箱链接（允许不带 text：扩展里的「打开 Easy Swift」只开 App，不再收东西）
    static func isInboxURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == urlScheme && (url.host ?? "").lowercased() == inboxHost
    }

    /// `easyswift://inbox?text=…` → 文本；不是收件箱链接返回 nil
    static func inboxText(from url: URL) -> String? {
        guard url.scheme?.lowercased() == urlScheme else { return nil }
        guard (url.host ?? "").lowercased() == inboxHost else { return nil }
        guard let components=URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let text=components.queryItems?.first(where: { $0.name == "text" })?.value
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }

    /// 生成一条收件箱链接（方便外部 App/快捷指令，也方便手工测试）
    static func url(text: String) -> URL? {
        var components=URLComponents()
        components.scheme=urlScheme
        components.host=inboxHost
        components.queryItems=[URLQueryItem(name: "text", value: text)]
        return components.url
    }
}
