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
    /// 输入框焦点：点解析/回车时主动收起键盘
    @FocusState private var inputFocused: Bool
    @State private var isParsing=false
    /// 解析进行中"具体在等什么"：由解析器上报，nil 表示还没轮到具体阶段
    @State private var parseStage: LinkParseStage?
    /// 本轮解析的开始时间，用来显示"已经等了多久"
    @State private var parseStartedAt: Date?
    /// 本轮已经等了多少秒（自己走，不需要解析线程推）
    @State private var parseElapsed=0
    @State private var result: LinkParseResult?
    @State private var showingAlert=false
    @State private var alertTitle="未知错误"
    @State private var alertText="未知错误"
    /// 就地预览：走通用组件 `.mediaPreview(_:)`
    @State private var previewRequest: MediaPreviewRequest?
    /// 保存到相册
    @State private var isSaving=false
    @State private var saveProgress: Double=0
    @State private var saveSummary: String?
    @State private var showingSaveSummary=false
    /// 保存前先确认要存多少
    @State private var showingSaveConfirm=false
    @State private var pendingSaveResult: LinkParseResult?
    @State private var showingWebParser=false
    @State private var webParseURL: URL?
    @State private var webParseStatus: WebParserStatus = .loading
    /// 兜底 WebView 用哪套脚本：抖音要注入钩子，通用站点保持原样
    @State private var webParserMode: WebParserMode = .generic
    /// 需要登录时的引导
    @State private var showingLoginPrompt=false
    @State private var showingXhsLogin=false
    @State private var showingXhsCookieEdit=false
    /// 撞墙时是"没登录"还是"过期了"，决定弹窗文案
    @State private var loginPromptExpired=false
    @State private var retryTrigger: UUID?

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
                .focused($inputFocused)
                .submitLabel(.search)
                .onSubmit {
                    inputFocused=false
                    parseLink()
                }

            // 解析按钮
            HStack {
                Spacer()
                Button(action: {
                    inputFocused=false
                    parseLink()
                }) {
                    // 用系统图标 + glassProminent，不要自己套白色圆形底
                    Label("解析链接", systemImage: "link")
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                // 解析中再点只会撞上"正在解析另一个作品"，直接禁掉
                .disabled(isParsing)
                Spacer()
            }

            if isParsing {
                parseStatusView
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
        .mediaPreview($previewRequest)
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) { saveToAlbumButton }
            #else
            ToolbarItem(placement: .automatic) { saveToAlbumButton }
            #endif
        }
        .overlay {
            if isSaving {
                ZStack {
                    Color.black.opacity(0.15)
                    VStack(spacing: 10) {
                        ProgressView(value: saveProgress)
                            .frame(width: 180)
                        Text("正在保存到相册… \(Int(saveProgress * 100))%")
                            .font(.subheadline)
                    }
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .ignoresSafeArea()
            }
        }
        .confirmationDialog("保存到相册", isPresented: $showingSaveConfirm, titleVisibility: .visible) {
            Button("保存") {
                if let pending=pendingSaveResult {
                    saveAll(pending)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(saveConfirmMessage)
        }
        .alert("保存结果", isPresented: $showingSaveSummary) {
            Button("好") {}
        } message: {
            Text(saveSummary ?? "")
        }
        // 单点全屏预览：iOS 用系统 QuickLook 预览本地文件
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
                    }, retryTrigger: retryTrigger, mode: webParserMode)
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
        // 需要登录：不硬塞一句错误，直接给"去登录"的出口
        .confirmationDialog(loginPromptExpired ? "登录已过期" : "需要登录",
                            isPresented: $showingLoginPrompt,
                            titleVisibility: .visible) {
            Button(loginPromptExpired ? "重新登录" : "登录小红书") {
                showingXhsLogin=true
            }
            Button("手动填写 Cookie") {
                showingXhsCookieEdit=true
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(loginPromptExpired
                 ? "小红书登录态已失效，重新登录一次即可；也可以用浏览器里的 cookie 手动填。"
                 : "小红书要登录后才能查看这条内容；网页登录被滑块卡住时，可以手动填写 cookie。")
        }
        .sheet(isPresented: $showingXhsLogin) {
            XhsLoginView(onFinished: {
                // 登录成功立刻重试，用户不用再点一次
                parseLink()
            })
        }
        .sheet(isPresented: $showingXhsCookieEdit) {
            XhsCookieEditView(onSaved: {
                parseLink()
            })
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
                if let notice=result.notice, notice.isNotEmpty {
                    Label(notice, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if result.images.isNotEmpty {
                    let motionCount=result.motions.count
                    Text(motionCount > 0 ? "图片（\(result.images.count)，其中 \(motionCount) 张是动图）" : "图片（\(result.images.count)）")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                        ForEach(Array(result.images.enumerated()), id: \.offset) { index, url in
                            let motion=result.motions[index]
                            RemoteImageView(url: url, referer: refererForImage(url))
                                .frame(height: 100)
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .contentShape(RoundedRectangle(cornerRadius: 8))
                                // 动图角标：告诉用户这张图点开是动的
                                .overlay(alignment: .topTrailing) {
                                    if motion != nil {
                                        Text("动图")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.ultraThinMaterial, in: Capsule())
                                            .padding(4)
                                    }
                                }
                                // 单点：有动图就播动图，否则看静态图
                                .onTapGesture {
                                    openPreview(result: result, tapped: motion.map { .video($0) } ?? .image(url))
                                }
                                .contextMenu {
                                    if let motion {
                                        Button("播放动图") { openPreview(result: result, tapped: .video(motion)) }
                                        Button("查看静态图") { openPreview(result: result, tapped: .image(url)) }
                                    }
                                    Button("保存到相册") { saveOne(result: result, image: url, motion: motion) }
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
                            openPreview(result: result, tapped: .video(url))
                        } label: {
                            Label("视频链接", systemImage: "play.rectangle")
                                .foregroundStyle(.tint)
                        }
                        // 长按：保存 / 用浏览器打开
                        .contextMenu {
                            Button("保存到相册") { saveOne(result: result, video: url) }
                            Button("用浏览器打开") { openURL(url) }
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // 上下滑动结果时立即收起键盘，不用先点空白处
        .scrollDismissesKeyboard(.immediately)
    }

    /// 解析中的实时状态。
    ///
    /// 抖音图文要等 5–18 秒：只写「正在解析…」用户会以为卡死，
    /// 所以这里既显示解析器上报的**具体阶段**，也显示本轮**已经等了多久**——
    /// 秒数在走，就说明它还活着。
    private var parseStatusView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(parseStage?.title ?? "正在解析…")
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
                .animation(.default, value: parseStage)
            if parseElapsed >= 2 {
                Text("\(parseElapsed) 秒")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        // 秒数自己走。
        // 不用 TimelineView：它的 schedule 从 `from` 开始发条目，视图是解析开始后几秒才出现的，
        // 于是显示的秒数会永远落后真实时间（实测显示 3 秒时实际已等 7 秒）。
        // 也不用 Timer：.task(id:) 在视图移除时自动取消，不会留下跑着的定时器。
        .task(id: parseStartedAt) {
            parseElapsed=0
            guard let start=parseStartedAt else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                parseElapsed=Int(Date().timeIntervalSince(start))
            }
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
            parseStage=nil
            parseStartedAt=Date()
        }
        // 解析器在关键节点调它；回调在解析线程上，自己抛回主线程再改 State
        let progress=LinkParseProgress { stage in
            Task { @MainActor in
                parseStage=stage
            }
        }
        Task {
            do {
                let parsed=try await LinkParserRegistry.parse(url: url, progress: progress)
                await MainActor.run {
                    isParsing=false
                    parseStage=nil
                    parseStartedAt=nil
                    result=parsed
                }
            } catch let error as LinkParseError {
                await MainActor.run {
                    isParsing=false
                    parseStage=nil
                    parseStartedAt=nil
                    handleParseError(error, url: url)
                }
            } catch {
                debugPrint("[LinkParserView] 解析失败: \(url.absoluteString) -> \(error.localizedDescription)")
                await MainActor.run {
                    isParsing=false
                    parseStage=nil
                    parseStartedAt=nil
                    showAlert(title: "解析失败", text: error.localizedDescription)
                }
            }
        }
    }

    /// 失败分流：能从界面上解决的（验证码、页面改版）就别只丢一句错误
    @MainActor
    private func handleParseError(_ error: LinkParseError, url: URL) {
        debugPrint("[LinkParserView] 解析失败(\(error)): \(url.absoluteString)")
        switch error {
        case .emptyResult, .blocked:
            // 风控/验证码/SPA 拿不到数据 → 打开可见页面，用户过完验证再解析
            webParseURL=url
            webParserMode = DouyinParser().canParse(url) ? .douyin : .generic
            webParseStatus = .loading
            showingWebParser=true
        case .needLogin:
            // 已经判定"已登录"却撞墙，解析器已把它标成过期；这里按状态给不同文案
            Task { @MainActor in
                loginPromptExpired = (await XiaohongshuSession.shared.state() == .expired)
                showingLoginPrompt=true
            }
        case .notFound:
            showAlert(title: "内容不可见", text: error.localizedDescription)
        case .network:
            showAlert(title: "网络错误", text: error.localizedDescription)
        case .unsupported:
            showAlert(title: "暂不支持", text: "目前支持小红书、抖音链接，更多网站敬请期待")
        case let .unknown(message):
            showAlert(title: "解析失败", text: message)
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

    private func showAlert(title: String, text: String) {
        alertTitle=title
        alertText=text
        showingAlert=true
    }

    /// 保存前确认：说清楚要存多少张图、多少个视频、其中多少是动图
    private var saveConfirmMessage: String {
        guard let result=pendingSaveResult else { return "" }
        var parts: [String]=[]
        if !result.images.isEmpty {
            var images="\(result.images.count) 张图片"
            if !result.motions.isEmpty { images += "（其中 \(result.motions.count) 张动图会存成实况照片）" }
            parts.append(images)
        }
        if !result.videos.isEmpty { parts.append("\(result.videos.count) 个视频") }
        return "将保存 " + parts.joined(separator: "、") + "。"
    }

    // MARK: - 保存到相册

    @ViewBuilder
    private var saveToAlbumButton: some View {
        if let result, !result.images.isEmpty || !result.videos.isEmpty {
            Button {
                pendingSaveResult=result
                showingSaveConfirm=true
            } label: {
                Label("保存到相册", systemImage: "square.and.arrow.down")
            }
            .disabled(isSaving)
        }
    }

    /// 保存全部：图片（带动图的存成实况照片）+ 视频
    private func saveAll(_ result: LinkParseResult) {
        guard !isSaving else { return }
        Task { @MainActor in
            isSaving=true
            saveProgress=0
            defer { isSaving=false }

            let total=max(result.images.count + result.videos.count, 1)
            var done=0
            var ok=0
            var failed=0
            var liveSaved=0

            var livePairs=0
            for (index, image) in result.images.enumerated() {
                do {
                    try await PhotoLibrarySaver.save(image: image, motion: result.motions[index])
                    ok += 1
                    if result.motions[index] != nil {
                        // 走的是实况照片分支：配对标识已经在 LivePhotoPair 里回读校验过了
                        livePairs += 1
                        if PhotoLibrarySaver.verifyLatestIsLivePhoto() == true {
                            liveSaved += 1
                        }
                    }
                } catch let error as MediaSaveError {
                    // 权限问题就整批停下：后面每张都会以同样的方式失败，没必要让用户等 N 次
                    if error.isPermissionProblem {
                        saveSummary=error.localizedDescription
                        showingSaveSummary=true
                        return
                    }
                    failed += 1
                    debugPrint("[相册] 第 \(index + 1) 张保存失败: \(error.localizedDescription)")
                } catch {
                    failed += 1
                    debugPrint("[相册] 第 \(index + 1) 张保存失败: \(error.localizedDescription)")
                }
                done += 1
                saveProgress=Double(done) / Double(total)
            }

            for video in result.videos {
                do {
                    try await PhotoLibrarySaver.save(video: video)
                    ok += 1
                } catch let error as MediaSaveError where error.isPermissionProblem {
                    saveSummary=error.localizedDescription
                    showingSaveSummary=true
                    return
                } catch {
                    failed += 1
                    debugPrint("[相册] 视频保存失败: \(error.localizedDescription)")
                }
                done += 1
                saveProgress=Double(done) / Double(total)
            }

            var summary="已保存 \(ok) 项"
            if liveSaved > 0 {
                summary += "（其中 \(liveSaved) 张为实况照片）"
            } else if livePairs > 0 {
                // 没有相册读权限时回读不了 .photoLive，但配对标识这一步已经校验过，
                // 不能说"无法确认"，也不能直接宣称相册侧认了
                summary += "（其中 \(livePairs) 张动图已按实况照片写入，配对标识已校验）"
            }
            if failed > 0 { summary += "，\(failed) 项失败" }
            saveSummary=summary
            showingSaveSummary=true
        }
    }

    private func saveOne(result: LinkParseResult, image: URL, motion: URL?) {
        guard !isSaving else { return }
        Task { @MainActor in
            isSaving=true
            defer { isSaving=false }
            do {
                try await PhotoLibrarySaver.save(image: image, motion: motion)
                if motion != nil {
                    switch PhotoLibrarySaver.verifyLatestIsLivePhoto() {
                    case true: saveSummary="已保存为实况照片"
                    case false: saveSummary="已保存，但相册未把它识别为实况照片"
                    case nil: saveSummary="已保存为实况照片（配对标识已校验；去相册长按确认）"
                    }
                } else {
                    saveSummary="已保存到相册"
                }
            } catch {
                saveSummary=error.localizedDescription
            }
            showingSaveSummary=true
        }
    }

    private func saveOne(result: LinkParseResult, video: URL) {
        guard !isSaving else { return }
        Task { @MainActor in
            isSaving=true
            defer { isSaving=false }
            do {
                try await PhotoLibrarySaver.save(video: video)
                saveSummary="已保存到相册"
            } catch {
                saveSummary=error.localizedDescription
            }
            showingSaveSummary=true
        }
    }

    // MARK: - 就地预览

    /// 把解析结果摊平成一串可翻页的条目。
    /// 动图紧跟在它的静态图后面：点带「动图」角标的缩略图直接播，滑一下能看静态图。
    private func previewList(for result: LinkParseResult) -> [MediaPreviewItem] {
        var items: [MediaPreviewItem]=[]
        for (index, image) in result.images.enumerated() {
            items.append(.image(image))
            if let motion=result.motions[index] {
                items.append(.video(motion))
            }
        }
        for video in result.videos {
            items.append(.video(video))
        }
        return items
    }

    /// 打开预览。`tapped` 是要定位的那一条（带动图的缩略图会直接定位到动图）
    private func openPreview(result: LinkParseResult, tapped: MediaPreviewItem) {
        let items=previewList(for: result)
        guard let index=items.firstIndex(of: tapped) ?? items.firstIndex(where: { $0.url == tapped.url }) else {
            return
        }
        previewRequest=MediaPreviewRequest(items: items, startIndex: index)
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

