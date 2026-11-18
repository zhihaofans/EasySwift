//
//  LinkHistoryView.swift
//  Easy Swift
//
//  解析历史：解析成功过的链接留痕，能回看、能重新解析。
//
//  列表只读 `@Query`（AGENTS §3.1）；点一条 = **重新解析**，不是复用旧结果 ——
//  历史里的图片/视频直链带时效签名，过一会儿就 403 了。
//

import SwiftData
import SwiftUI
import SwiftUtils

struct LinkHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LinkHistoryItem.create_time_ms, order: .reverse) private var items: [LinkHistoryItem]
    @State private var showingClearConfirm=false

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView("还没有解析记录",
                                       systemImage: "clock.arrow.circlepath",
                                       description: Text("在「链接解析」里成功解析一条链接后，这里会自动留一条记录。"))
            } else {
                List {
                    Section {
                        ForEach(items) { item in
                            NavigationLink {
                                // 重新解析：历史直链会过期，不能直接当结果用
                                LinkParserView(initialLink: item.sourceURL.isEmpty ? item.finalURL : item.sourceURL,
                                               autoParse: true)
                            } label: {
                                row(item)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    LinkHistoryStore.delete(item)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    } footer: {
                        Text("共 \(items.count) 条，最多保留 \(LinkHistoryStore.maxItems) 条；同一条链接重复解析只保留最新一次。点进去会重新解析。")
                    }
                }
            }
        }
        .setNavigationTitle("解析历史")
        .toolbar {
            ToolbarItem(placement: toolbarPlacement) {
                Menu {
                    Button("清空历史", role: .destructive) { showingClearConfirm=true }
                } label: {
                    Label("更多", systemImage: "ellipsis.circle")
                }
                .disabled(items.isEmpty)
            }
        }
        .confirmationDialog("清空全部解析历史？", isPresented: $showingClearConfirm, titleVisibility: .visible) {
            Button("清空", role: .destructive) { LinkHistoryStore.clear() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("共 \(items.count) 条，清空后无法恢复。")
        }
    }

    // MARK: - 行

    private func row(_ item: LinkHistoryItem) -> some View {
        HStack(spacing: 10) {
            cover(item)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title.isEmpty ? item.finalURL : item.title)
                    .font(.subheadline)
                    .lineLimit(2)
                Text(item.summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(RelativeTimeFormatter.string(from: item.date))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func cover(_ item: LinkHistoryItem) -> some View {
        // 封面横向略竖一点，列表里不抢戏
        let size=CGSize(width: 44, height: 58)
        if let raw=item.coverURL, let url=URL(string: raw) {
            RemoteImageThumb(url: url, referer: referer(url))
                .frame(width: size.width, height: size.height)
                .clipped()
                .background(Color.gray.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.12))
                .frame(width: size.width, height: size.height)
                .overlay {
                    Image(systemName: item.videoCount > 0 ? "play.rectangle" : "photo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func referer(_ url: URL) -> String {
        guard let host=url.host else { return "" }
        if host.contains("xiaohongshu") || host.contains("xhscdn") { return "https://www.xiaohongshu.com/" }
        if host.contains("douyin") { return "https://www.douyin.com/" }
        return ""
    }

    private var toolbarPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .navigationBarTrailing
        #else
        return .automatic
        #endif
    }
}

/// 小缩略图（只做列表用）：走共享缓存，滚动时不重复下载
private struct RemoteImageThumb: View {
    let url: URL
    let referer: String
    @State private var image: PlatformImage?

    var body: some View {
        Group {
            if let image {
                Image(platformImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.clear
            }
        }
        .task(id: url) {
            guard let cached=try? await RemoteImageCache.shared.image(for: url,
                                                                     referer: referer.isEmpty ? nil : referer,
                                                                     maxPixelSize: 200)
            else { return }
            image=cached.image
        }
    }
}

#Preview {
    NavigationStack {
        LinkHistoryView()
    }
    .modelContainer(AppDataStore.container)
}
