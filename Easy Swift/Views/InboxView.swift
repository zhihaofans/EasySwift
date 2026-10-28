//
//  InboxView.swift
//  Easy Swift
//
//  收件箱：外部分享 / 链接调起 / 剪贴板收进来的东西都先落在这里。
//
//  交互：点一条 → 弹出处理面板（先说明"这是什么"，再列出能做的操作），
//  由用户选 —— 不猜默认动作。操作执行完自动标为已处理并跳到对应页面。
//

import SwiftUI
import SwiftUtils

/// 面板里选完操作后要去哪
private enum InboxRouteTarget: Hashable {
    case parse(String)
    case qrcode(String)
    case search(String)
}

struct InboxView: View {
    @ObservedObject private var store=InboxStore.shared
    @State private var message: String?
    @State private var selectedItem: InboxItem?
    @State private var route: InboxRouteTarget?

    var body: some View {
        Group {
            if store.items.isEmpty {
                ContentUnavailableView("收件箱是空的",
                                       systemImage: "tray",
                                       description: Text("从别的 App 分享文本/链接给 Easy Swift，或点右上角「从剪贴板收件」。"))
            } else {
                List {
                    Section {
                        ForEach(store.items) { item in
                            Button {
                                selectedItem=item
                            } label: {
                                row(item)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    store.delete(item)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    store.toggleHandled(item)
                                } label: {
                                    Label(item.handled ? "标为未处理" : "标为已处理",
                                          systemImage: item.handled ? "envelope.badge" : "envelope.open")
                                }
                                .tint(.blue)
                            }
                        }
                    } footer: {
                        Text(footerText)
                    }
                }
            }
        }
        .setNavigationTitle("收件箱")
        .toolbar {
            ToolbarItem(placement: toolbarPlacement) {
                Button {
                    collectFromClipboard()
                } label: {
                    Label("从剪贴板收件", systemImage: "doc.on.clipboard")
                }
            }
            ToolbarItem(placement: toolbarPlacement) {
                Menu {
                    Button("全部标为已处理") { store.markAllHandled(true) }
                    Button("全部标为未处理") { store.markAllHandled(false) }
                    Divider()
                    Button("清空收件箱", role: .destructive) { store.clear() }
                } label: {
                    Label("更多", systemImage: "ellipsis.circle")
                }
                .disabled(store.items.isEmpty)
            }
        }
        .sheet(item: $selectedItem) { item in
            InboxActionSheetView(item: item,
                                 onAction: { action in perform(action, for: item) },
                                 onDelete: { store.delete(item) })
                .presentationDetents([.medium, .large])
        }
        .navigationDestination(item: $route) { target in
            switch target {
            case let .parse(link):
                // 带链接进去并自动开跑，用户不用再点一次「解析链接」
                LinkParserView(initialLink: link, autoParse: true)
            case let .qrcode(text):
                QrcodeView(initialText: text)
            case let .search(keyword):
                SearchView(initialKeyword: keyword)
            }
        }
        .alert("收件箱", isPresented: Binding(get: { message != nil },
                                            set: { if !$0 { message=nil } })) {
            Button("好") { message=nil }
        } message: {
            Text(message ?? "")
        }
        .onAppear {
            // 分享扩展/其他进程写过文件之后再进来，能看到最新内容
            store.reload()
        }
    }

    // MARK: - 行

    private func row(_ item: InboxItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.kindValue.systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.previewText)
                    .font(.subheadline)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(item.kindValue.title)
                    Text("·")
                    Text(item.sourceValue.title)
                    Text("·")
                    Text(item.date.formatted(date: .omitted, time: .shortened))
                    if !item.handled {
                        Text("· 未处理").foregroundStyle(.tint)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "ellipsis.circle")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private var footerText: String {
        var lines=["点一条会问你要怎么处理：链接给「复制 / 解析（仅支持的平台）/ 二维码」，文本给「复制 / 二维码 / 搜索」。操作完自动标为已处理。",
                   "同一条 10 秒内重复分享只收一次；最多保留 200 条。"]
        if !store.usesAppGroup {
            lines.append("当前收件箱存在 App 容器里：分享扩展未生效时，只有「链接调起」和「剪贴板」两个入口。")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - 动作

    private func perform(_ action: InboxAction, for item: InboxItem) {
        let info=InboxClassifier.classify(item.rawText)
        switch action {
        case .copy:
            // 存进**应用内剪贴板**（首页「剪贴板」里能看到），不是系统粘贴板
            if ClipboardStore.append(text: info.copyText) {
                store.markHandled(item, true)
                message="已存进剪贴板"
            } else {
                message="存入剪贴板失败，请重试"
            }
        case .parse:
            guard let link=info.parseLink else {
                message="这条内容里没有可解析的链接"
                return
            }
            store.markHandled(item, true)
            route = .parse(link)
        case .qrcode:
            store.markHandled(item, true)
            route = .qrcode(info.qrcodeText)
        case .search:
            store.markHandled(item, true)
            route = .search(info.searchText)
        }
    }

    private func collectFromClipboard() {
        if let item=store.collectFromClipboard() {
            message="已收录：\(item.kindValue.title)"
        } else {
            message="剪贴板里没有文本（或者你拒绝了粘贴授权）"
        }
    }

    private var toolbarPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .navigationBarTrailing
        #else
        return .automatic
        #endif
    }
}

#Preview {
    NavigationStack {
        InboxView()
    }
}
