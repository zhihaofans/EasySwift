//
//  MediaPreviewView.swift
//  Easy Swift
//
//  应用内媒体预览：图片可缩放/翻页，视频直接流式播放。
//
//  以前是"下载到临时文件 → 交给 QuickLook"，问题有两个：
//  1. 列表里已经加载过的图，点开又下载一遍（QuickLook 只认本地文件）；
//  2. 视频要先下完才能看，动图那点内容也要等。
//  现在图片走内存缓存复用，视频用 AVPlayer 带着 Referer 直接播。
//

import AVKit
import SwiftUI
import SwiftUtils
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - 条目

enum MediaPreviewItem: Hashable, Identifiable {
    case image(URL)
    case video(URL)

    var url: URL {
        switch self {
        case let .image(url), let .video(url): return url
        }
    }

    var isVideo: Bool {
        if case .video = self { return true }
        return false
    }

    var id: String {
        return (isVideo ? "v:" : "i:") + url.absoluteString
    }

    /// 平台 CDN 的防盗链头
    static func headers(for url: URL) -> [String: String] {
        var headers = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
        ]
        guard let host = url.host else { return headers }
        if host.contains("xiaohongshu.com") || host.contains("xhscdn.com") {
            headers["Referer"] = "https://www.xiaohongshu.com/"
        } else if host.contains("douyin") || host.contains("douyinpic") || host.contains("byteimg") {
            headers["Referer"] = "https://www.douyin.com/"
        }
        return headers
    }
}

// MARK: - 图片缓存

/// 列表缩略图与全屏预览共用一份缓存，避免"点开又下一次"
@MainActor
final class MediaImageCache {
    static let shared = MediaImageCache()

    private let cache = NSCache<NSURL, PlatformImage>()

    private init() {
        cache.countLimit = 60
    }

    func cached(_ url: URL) -> PlatformImage? {
        return cache.object(forKey: url as NSURL)
    }

    func store(_ image: PlatformImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }

    /// 带防盗链头加载；失败返回 nil，不抛错（展示层只关心能不能显示）
    func load(_ url: URL) async -> PlatformImage? {
        if let cached = cached(url) { return cached }

        var request = URLRequest(url: url)
        for (key, value) in MediaPreviewItem.headers(for: url) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else { return nil }
            guard let image = PlatformImage(data: data) else { return nil }
            store(image, for: url)
            return image
        } catch {
            debugPrint("[预览] 图片加载失败 \(url.absoluteString.prefix(80)): \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - 通用入口

/// 一次预览请求。任何模块都可以攒一组条目丢给 `.mediaPreview(_:)`
struct MediaPreviewRequest: Identifiable {
    let id=UUID()
    var items: [MediaPreviewItem]
    var startIndex: Int

    init(items: [MediaPreviewItem], startIndex: Int = 0) {
        self.items=items
        self.startIndex=max(0, min(startIndex, max(items.count - 1, 0)))
    }
}

extension View {
    /// 通用媒体预览：把 binding 置成非 nil 即弹出，关闭后自动置回 nil。
    ///
    /// ```swift
    /// @State private var preview: MediaPreviewRequest?
    /// ...
    /// .mediaPreview($preview)
    /// // 打开：
    /// preview = MediaPreviewRequest(items: [.image(url)], startIndex: 0)
    /// ```
    func mediaPreview(_ request: Binding<MediaPreviewRequest?>) -> some View {
        modifier(MediaPreviewPresenter(request: request))
    }
}

private struct MediaPreviewPresenter: ViewModifier {
    @Binding var request: MediaPreviewRequest?

    func body(content: Content) -> some View {
        #if os(iOS)
        content.fullScreenCover(item: $request) { req in
            MediaPreviewView(items: req.items, index: req.startIndex)
        }
        #else
        content.sheet(item: $request) { req in
            MediaPreviewView(items: req.items, index: req.startIndex)
                .frame(minWidth: 720, minHeight: 520)
        }
        #endif
    }
}

// MARK: - 预览容器

struct MediaPreviewView: View {
    let items: [MediaPreviewItem]
    @State private var index: Int
    @Environment(\.dismiss) private var dismiss

    init(items: [MediaPreviewItem], index: Int) {
        self.items = items
        _index = State(initialValue: min(max(index, 0), max(items.count - 1, 0)))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(items.enumerated()), id: \.offset) { offset, item in
                    Group {
                        switch item {
                        case let .image(url):
                            PreviewImagePage(url: url)
                        case let .video(url):
                            PreviewVideoPage(url: url)
                        }
                    }
                    .tag(offset)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
            .ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.45), in: Circle())
                    }
                    Spacer()
                    Text("\(min(index + 1, items.count)) / \(items.count)")
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.45), in: Capsule())
                }
                .padding(.horizontal)
                .padding(.top, 8)
                Spacer()
            }
        }
        #if os(iOS)
        .statusBarHidden()
        #endif
    }
}

// MARK: - 图片页（可缩放）

private struct PreviewImagePage: View {
    let url: URL

    @State private var image: PlatformImage?
    @State private var failed = false
    @State private var scale: CGFloat = 1
    @State private var committedScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var committedOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image {
                    Image(platformImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(magnification.simultaneously(with: drag))
                        .onTapGesture(count: 2) { toggleZoom() }
                } else if failed {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.largeTitle)
                        Text("图片加载失败")
                            .font(.footnote)
                    }
                    .foregroundStyle(.white.opacity(0.8))
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .task(id: url) { await load() }
    }

    private var magnification: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = max(1, min(committedScale * value.magnification, 6))
            }
            .onEnded { _ in
                committedScale = scale
                if scale <= 1.01 { resetZoom() }
            }
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                guard committedScale > 1 else { return }
                offset = CGSize(width: committedOffset.width + value.translation.width,
                                height: committedOffset.height + value.translation.height)
            }
            .onEnded { _ in
                guard committedScale > 1 else { return }
                committedOffset = offset
            }
    }

    private func toggleZoom() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if committedScale > 1 {
                resetZoom()
            } else {
                scale = 2.5
                committedScale = 2.5
            }
        }
    }

    private func resetZoom() {
        scale = 1
        committedScale = 1
        offset = .zero
        committedOffset = .zero
    }

    private func load() async {
        if let cached = MediaImageCache.shared.cached(url) {
            image = cached
            return
        }
        image = nil
        failed = false
        let loaded = await MediaImageCache.shared.load(url)
        image = loaded
        failed = (loaded == nil)
    }
}

// MARK: - 视频页（流式播放）

private struct PreviewVideoPage: View {
    let url: URL

    @State private var player: AVPlayer?
    @State private var failed = false

    var body: some View {
        ZStack {
            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else if failed {
                VStack(spacing: 8) {
                    Image(systemName: "film.stack")
                        .font(.largeTitle)
                    Text("视频加载失败")
                        .font(.footnote)
                }
                .foregroundStyle(.white.opacity(0.8))
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .task(id: url) { setup() }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func setup() {
        // 平台 CDN 要 Referer，AVPlayer 默认不带 —— 用 AVURLAsset 的 HTTP 头选项补上
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": MediaPreviewItem.headers(for: url)])
        let item = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.play()
        player = newPlayer

        Task {
            // 资源不可播放时给个明确状态，别一直转圈
            let playable = (try? await asset.load(.isPlayable)) ?? false
            if !playable {
                await MainActor.run {
                    failed = true
                    player = nil
                }
            }
        }
    }
}
