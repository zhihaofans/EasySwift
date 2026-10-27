//
//  InboxView.swift
//  Easy Swift
//
//  收件箱：外部分享/链接调起/剪贴板收进来的东西都先落在这里。
//  点一条 → 按分类建议跳到对应功能页，文本自动带过去（不在这里重做一套解析界面）。
//

import SwiftUI
import SwiftUtils

struct InboxView: View {
    @ObservedObject private var store=InboxStore.shared
    @State private var message: String?

    var body: some View {
        Group {
            if store.items.isEmpty {
                ContentUnavailableView("收件箱是空的",
                                       systemImage: "tray",
                                       description: Text("从别的 App 分享文本/链接给 我，或点右上角「从剪贴板收件」。"))
            } else {
                List {
                    Section {
                        ForEach(store.items) { item in
                            NavigationLink {
                                destination(for: item)
                            } label: {
                                row(item)
                            }
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
        .alert("收件箱", isPresented: Binding(get: { message != nil },
                                            set: { if !$0 { message=nil } })) {
            Button("好") { message=nil }
        } message: {
            Text(message ?? "")
        }
        .onAppear {
            // 从分享扩展/其他进程写过文件之后再进来，能看到最新内容
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
        }
        .padding(.vertical, 2)
    }

    private var footerText: String {
        var lines=["同一条 10 秒内重复分享只收一次；最多保留 \(maxItemsHint) 条。点击条目会跳到对应功能并把文本填好。"]
        if !store.usesAppGroup {
            lines.append("当前收件箱存在 App 容器里：分享扩展还没接入（下一步），所以暂时只有「链接调起」和「剪贴板」两个入口。")
        }
        return lines.joined(separator: "\n")
    }

    private var maxItemsHint: Int { 200 }

    // MARK: - 分派

    /// 分类是**纯函数现算**的（不读存的 kind），规则改了以后老条目也跟着变
    @ViewBuilder
    private func destination(for item: InboxItem) -> some View {
        let classification=InboxClassifier.classify(item.rawText)
        switch classification.route {
        case .linkParser:
            LinkParserView(initialLink: classification.payload)
        case .search:
            SearchView(initialKeyword: classification.payload)
        case .qrcode:
            QrcodeView(initialText: classification.payload)
        }
    }

    // MARK: - 动作

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
