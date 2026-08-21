//
//  LinkParserView.swift
//  Easy Swift
//
//  链接解析页面：输入链接 → 解析页面图片/视频（参考 QrcodeView 布局）
//  当前支持：小红书、抖音（通过 LinkParserRegistry 扩展新网站）
//
//  Created by zzh on 2026/08/20.
//

import _QuickLook_SwiftUI
import SwiftUI
import SwiftUtils
#if os(macOS)
import AppKit
import CoreServices
#endif

struct LinkParserView: View {
    @State private var linkInput=""
    @State private var isParsing=false
    @State private var result: LinkParseResult?
    @State private var showingAlert=false
    @State private var alertTitle="未知错误"
    @State private var alertText="未知错误"
    @State private var previewFileURL: URL?
    @State private var isPreparingPreview=false
    @State private var previewProgress: Double=0
    @State private var previewDownloadTask: Task<Void, Never>?
    @State private var showingWebParser=false
    @State private var webParseURL: URL?
    @State private var webParseStatus: WebParserStatus = .loading
    @State private var retryTrigger: UUID?
    #if os(macOS)
    @State private var showingAppPicker=false
    @State private var videoAppChoices: [URL]=[]
    @State private var pendingVideoFile: URL?
    #endif

    var body: some View {
        VStack(spacing: 16) {
            // 输入区：玻璃材质，与 QrcodeView 一致
            TextField("粘贴链接（支持小红书 / 抖音）", text: $linkInput, axis: .vertical)
                .lineLimit(3)
                .font(.title3)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                .padding(.horizontal)

            // 解析按钮
            HStack {
                Spacer()
                Button(action: {
                    parseLink()
                }) {
                    Label {
                        Text("解析链接")
                    } icon: {
                        Image(systemName: "link")
                            .foregroundStyle(.tint)
                            .padding(5)
                            .background(Circle().fill(.white))
                    }
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                Spacer()
            }

            if isParsing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在解析...")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            if let result {
                parseResultView(result)
            }
            Spacer()
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", action: {
                alertTitle=""
                alertText=""
                showingAlert=false
            })
        } message: {
            Text(alertText)
        }
        .setNavigationTitle("链接解析")
        // 单点全屏预览：iOS 用系统 QuickLook 预览本地文件
        .quickLookPreview($previewFileURL)
        // 预览下载中的加载提示
        .overlay {
            if isPreparingPreview {
                ZStack {
                    Color.black.opacity(0.15)
                    VStack(spacing: 12) {
                        ProgressView(value: previewProgress)
                            .progressViewStyle(.linear)
                            .frame(width: 180)
                        Text("正在加载预览... \(Int(previewProgress * 100))%")
                            .font(.subheadline)
                        Button("取消加载") {
                            cancelPreviewDownload()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .ignoresSafeArea()
            }
        }
        #if os(macOS)
        // macOS 视频：选择打开方式（枚举系统可打开该视频的 App）
        .confirmationDialog("选择打开方式", isPresented: $showingAppPicker, titleVisibility: .visible) {
            ForEach(videoAppChoices, id: \.self) { appURL in
                Button(appDisplayName(appURL)) {
                    if let fileURL=pendingVideoFile {
                        NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                            if let error {
                                Task { @MainActor in
                                    showAlert(title: "打开失败", text: error.localizedDescription)
                                }
                            }
                        }
                    }
                }
            }
            Button("取消", role: .cancel) {}
        }
        #endif
        // 抖音等 SPA 页面：HTML 解析失败时用 WebView 执行 JS 兜底
        .sheet(isPresented: $showingWebParser) {
            if let url=webParseURL {
                VStack(spacing: 8) {
                    if webParseStatus == .captcha {
                        Label("检测到安全验证，请在下方页面中手动完成滑块验证", systemImage: "exclamationmark.triangle")
                            .font(.callout)
                            .foregroundStyle(.orange)
                            .padding(.horizontal)
                    } else {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("正在用浏览器内核加载页面并解析...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    WebParserView(url: url, onResult: { parsed in
                        showingWebParser=false
                        result=parsed
                    }, onFail: { message in
                        showingWebParser=false
                        showAlert(title: "解析失败", text: message)
                    }, onStatusChange: { status in
                        webParseStatus=status
                    }, retryTrigger: retryTrigger)
                    HStack {
                        if webParseStatus == .captcha {
                            Button("完成验证后重新解析") {
                                retryTrigger=UUID()
                            }
                        }
                        Button("取消") {
                            showingWebParser=false
                        }
                    }
                    .padding(.bottom, 8)
                }
                .presentationDetents([.large])
                #if os(macOS)
                .frame(minWidth: 480, minHeight: 480)
                #endif
            }
        }
    }

    // 结果区：标题 + 图片网格 + 视频链接
    private func parseResultView(_ result: LinkParseResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let title=result.title, title.isNotEmpty {
                    Text(title)
                        .font(.headline)
                }
                if result.images.isNotEmpty {
                    Text("图片（\(result.images.count)）")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                        ForEach(result.images, id: \.self) { url in
                            RemoteImageView(url: url, referer: refererForImage(url))
                                .frame(height: 100)
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .contentShape(RoundedRectangle(cornerRadius: 8))
                                // 单点：全屏预览
                                .onTapGesture {
                                    previewItem(url)
                                }
                                // 长按：菜单用浏览器打开
                                .contextMenu {
                                    Button("用浏览器打开") { openURL(url) }
                                }
                        }
                    }
                }
                if result.videos.isNotEmpty {
                    Text("视频")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ForEach(result.videos, id: \.self) { url in
                        Button {
                            // 单点：全屏预览
                            previewItem(url)
                        } label: {
                            Label("视频链接", systemImage: "play.rectangle")
                                .foregroundStyle(.tint)
                        }
                        // 长按：菜单用浏览器打开
                        .contextMenu {
                            Button("用浏览器打开") { openURL(url) }
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // 解析入口
    private func parseLink() {
        guard let url=extractURL(from: linkInput) else {
            showAlert(title: "链接无效", text: "未找到有效链接")
            return
        }
        Task { @MainActor in
            isParsing=true
        }
        Task {
            do {
                let parsed=try await LinkParserRegistry.parse(url: url)
                await MainActor.run {
                    isParsing=false
                    result=parsed
                }
            } catch LinkParseError.emptyResult {
                // HTML 方案拿不到数据（抖音 SPA 反爬）→ 用 WKWebView 执行 JS 兜底解析
                debugPrint("[LinkParserView] HTML 解析为空，启动 WebView 兜底: \(url.absoluteString)")
                await MainActor.run {
                    isParsing=false
                    webParseURL=url
                    showingWebParser=true
                }
            } catch LinkParseError.unsupported {
                debugPrint("[LinkParserView] 暂不支持的链接: \(url.absoluteString)")
                await MainActor.run {
                    isParsing=false
                    showAlert(title: "暂不支持", text: "目前支持小红书、抖音链接，更多网站敬请期待")
                }
            } catch {
                debugPrint("[LinkParserView] 解析失败: \(url.absoluteString) -> \(error.localizedDescription)")
                await MainActor.run {
                    isParsing=false
                    showAlert(title: "解析失败", text: error.localizedDescription)
                }
            }
        }
    }

    // 从输入文本中自动提取链接：支持纯链接，也支持包含链接的文本
    private func extractURL(from text: String) -> URL? {
        let trimmed=text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isNotEmpty else { return nil }
        // 1. 整段就是链接（自动补 https://）
        let candidate=trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)"
        if let url=URL(string: candidate), url.host != nil {
            return url
        }
        // 2. 从文本中提取第一个 http(s) 链接
        guard let regex=try? NSRegularExpression(pattern: #"https?://[^\s"']+"#) else { return nil }
        let ns=trimmed as NSString
        if let match=regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: ns.length)) {
            let raw=ns.substring(with: match.range)
            let cleaned=raw.trimmingCharacters(in: .punctuationCharacters)
            if let url=URL(string: cleaned), url.host != nil {
                return url
            }
        }
        return nil
    }

    // 打开链接（系统浏览器）
    private func openURL(_ url: URL) {
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
    }

    // 按图片域名返回防盗链所需的 Referer
    private func refererForImage(_ url: URL) -> String {
        guard let host=url.host else { return "" }
        if host.contains("xiaohongshu.com") || host.contains("xhscdn.com") {
            return "https://www.xiaohongshu.com/"
        }
        if host.contains("douyin") {
            return "https://www.douyin.com/"
        }
        return ""
    }

    // 单点全屏预览：下载到本地临时文件后
    //  - macOS：图片交给系统"预览"App；视频弹出"选择打开方式"（枚举系统可打开视频的 App）
    //  - iOS：QuickLook 预览本地文件（有正确扩展名，避免 remote URL 类型推断失败）
    // HLS 视频流（m3u8）预览 App 不支持，直接浏览器播放
    private func previewItem(_ url: URL) {
        if url.pathExtension.lowercased() == "m3u8" {
            openURL(url)
            return
        }
        // 取消可能仍在进行的下载
        previewDownloadTask?.cancel()
        Task { @MainActor in
            isPreparingPreview=true
            previewProgress=0
        }
        previewDownloadTask=Task {
            do {
                let fileURL=try await downloadToTempFile(url) { progress in
                    Task { @MainActor in
                        previewProgress=progress
                    }
                }
                try Task.checkCancellation()
                #if os(macOS)
                if isVideoURL(fileURL) {
                    let apps=appsThatCanOpen(fileURL)
                    await MainActor.run {
                        isPreparingPreview=false
                        if apps.isEmpty {
                            // 没有可选的 App 时直接用默认打开
                            NSWorkspace.shared.open(fileURL)
                        } else {
                            videoAppChoices=apps
                            pendingVideoFile=fileURL
                            showingAppPicker=true
                        }
                    }
                } else {
                    await MainActor.run {
                        isPreparingPreview=false
                        NSWorkspace.shared.open(fileURL)
                    }
                }
                #else
                await MainActor.run {
                    isPreparingPreview=false
                    previewFileURL=fileURL
                }
                #endif
            } catch {
                await MainActor.run {
                    isPreparingPreview=false
                    // 用户主动取消：静默关闭，不弹错误
                    if !Task.isCancelled {
                        showAlert(title: "预览失败", text: "下载失败：\(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // 手动取消预览下载（网络差/视频太大时）
    private func cancelPreviewDownload() {
        previewDownloadTask?.cancel()
        previewDownloadTask=nil
        isPreparingPreview=false
        previewProgress=0
    }

    // 是否为常见视频文件扩展名
    private func isVideoURL(_ url: URL) -> Bool {
        let ext=url.pathExtension.lowercased()
        return ["mp4", "mov", "m4v", "webm", "avi", "mkv", "flv", "wmv", "3gp"].contains(ext)
    }

    #if os(macOS)
    // LaunchServices：枚举系统注册的能打开该文件的 App（查看者角色）
    private func appsThatCanOpen(_ url: URL) -> [URL] {
        guard let result=LSCopyApplicationURLsForURL(url as CFURL, .viewer)?.takeRetainedValue() as? [URL] else {
            return []
        }
        return result
    }

    // App 显示名（去 .app 后缀）
    private func appDisplayName(_ appURL: URL) -> String {
        appURL.deletingPathExtension().lastPathComponent
    }
    #endif

    // 带防盗链头（UA + Referer）流式下载到临时目录，返回带扩展名的本地文件；onProgress 回调下载进度（0~1）
    private func downloadToTempFile(_ url: URL, onProgress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        var request=URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        let referer=refererForImage(url)
        if referer.isNotEmpty {
            request.setValue(referer, forHTTPHeaderField: "Referer")
        }
        let (bytes, response)=try await URLSession.shared.bytes(for: request)
        guard let http=response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw LinkParseError.fetchFailed
        }
        let expectedLength=Int(http.expectedContentLength)
        var data=Data()
        var buffer=Data()
        var received=0
        var lastReported=0
        for try await byte in bytes {
            buffer.append(byte)
            received += 1
            // 每 64KB 冲刷一次，避免逐字节 append 开销过大
            if buffer.count >= 64 * 1024 {
                data.append(buffer)
                buffer.removeAll(keepingCapacity: true)
                // 冲刷时检查取消：Task.cancel() 后下一个数据块到达即退出下载
                try Task.checkCancellation()
            }
            // 节流上报：每 256KB 或进度满时
            if expectedLength > 0 {
                if received - lastReported >= 256 * 1024 || received == expectedLength {
                    lastReported=received
                    onProgress(Double(received) / Double(expectedLength))
                }
            }
        }
        if !buffer.isEmpty {
            data.append(buffer)
        }
        try Task.checkCancellation()
        onProgress(1.0)
        let ext=url.pathExtension.isEmpty ? "jpg" : url.pathExtension
        let fileURL=FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try data.write(to: fileURL)
        return fileURL
    }

    @MainActor
    private func showAlert(title: String, text: String) {
        alertTitle=title
        alertText=text
        showingAlert=true
    }
}

#Preview {
    LinkParserView()
}

/// 带防盗链头（UA + Referer）的远程图片加载视图
/// AsyncImage 的请求不带 Referer，小红书/抖音图片会返回 403 导致一直加载失败
private struct RemoteImageView: View {
    let url: URL
    let referer: String

    /// 图片加载状态
    private enum LoadState {
        case loading // 加载中
        case notImage // 返回内容不是图片
        case failed // 网络/HTTP 加载失败
    }

    @State private var image: PlatformImage?
    @State private var state: LoadState = .loading

    var body: some View {
        Group {
            if let image {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                statusPlaceholder
            }
        }
        .task(id: url) {
            await load()
        }
    }

    // 状态占位：加载中 / 非图片 / 加载失败
    private var statusPlaceholder: some View {
        VStack(spacing: 4) {
            switch state {
            case .loading:
                ProgressView()
                    .controlSize(.small)
                Text("加载中")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .notImage:
                Image(systemName: "doc.questionmark")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("非图片")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .failed:
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("加载失败")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func load() async {
        image=nil
        state = .loading
        var request=URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        if referer.isNotEmpty {
            request.setValue(referer, forHTTPHeaderField: "Referer")
        }
        do {
            let (data, response)=try await URLSession.shared.data(for: request)
            guard let http=response as? HTTPURLResponse else {
                state = .failed
                return
            }
            guard (200..<300).contains(http.statusCode) else {
                state = .failed
                return
            }
            // 2xx 但无法解码为图片 → 判定为"非图片"内容
            #if os(macOS)
            image=NSImage(data: data)
            #else
            image=UIImage(data: data)
            #endif
            if image == nil {
                state = .notImage
            }
        } catch {
            state = .failed
        }
    }
}

extension Image {
    /// 跨平台构造（PlatformImage = UIImage / NSImage）
    init(platformImage: PlatformImage) {
        #if os(macOS)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}
