//
//  InboxActionSheetView.swift
//  Easy Swift
//
//  收件箱里点一条内容后弹出的处理面板：
//  先告诉用户「这是什么」，再把这条内容能做的操作列出来让他选。
//
//  为什么用面板而不是"点一下就跳默认功能"：
//  同一条内容可能有多种用法（复制 / 解析 / 生成二维码 / 搜索），
//  猜错的代价是用户要退回来重来 —— 不如一次问清楚。
//

import SwiftUI
import SwiftUtils

struct InboxActionSheetView: View {
    let item: InboxItem
    /// 用户选了某个操作（执行完由调用方负责标记已处理并跳转）
    let onAction: (InboxAction) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    /// 内容很短时不用滚动；长文案给固定高度让它自己滚
    private var classification: InboxClassification {
        InboxClassifier.classify(item.rawText)
    }

    var body: some View {
        let info=classification
        // sheet 里必须自己套 NavigationStack，否则标题与工具栏不渲染（AGENTS §3.6）
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerView(info)
                    contentView(info)
                    Divider()
                    actionsView(info)
                }
                .padding(20)
            }
            .setNavigationTitle("怎么处理这条")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - 识别结果

    private func headerView(_ info: InboxClassification) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.kindValue.systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(info.header)
                    .font(.headline)
                HStack(spacing: 6) {
                    Text(item.sourceValue.title)
                    Text("·")
                    Text(item.date.formatted(date: .abbreviated, time: .shortened))
                    if item.handled {
                        Text("· 已处理")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    /// 原文预览：长文本限制高度，自己能滚，不把按钮挤出屏幕
    private func contentView(_ info: InboxClassification) -> some View {
        ScrollView {
            Text(item.rawText)
                .font(.callout)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 180)
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 操作

    private func actionsView(_ info: InboxClassification) -> some View {
        VStack(spacing: 12) {
            ForEach(info.actions) { action in
                Button {
                    onAction(action)
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: action.systemImage)
                            .frame(width: 22)
                        Text(action.title)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            }
        }
    }
}

#Preview {
    InboxActionSheetView(item: InboxItem(rawText: "南京我最红🔥 https://xhslink.cn/o/7wAkW1PBaXP",
                                         link: "https://xhslink.cn/o/7wAkW1PBaXP",
                                         kind: InboxKind.xiaohongshu.rawValue,
                                         source: InboxSource.share.rawValue,
                                         createdAt: Int(Date().timeIntervalSince1970)),
                         onAction: { _ in },
                         onDelete: {})
}
