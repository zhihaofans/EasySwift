//
//  XhsQRLoginService.swift
//  Easy Swift
//
//  小红书扫码登录（App 内原生展示二维码）。
//
//  为什么不去调登录接口：`/api/sns/web/v1/login/qrcode/create`、`/api/qrcode/userinfo`、
//  `/api/sns/web/v1/login/qrcode/status` 三个接口全都要 `x-s` / `x-s-common` / `x-t` 签名，
//  算法在第三方 Python 库（xhshow）里，Swift 侧复刻成本高且平台一改就废。
//
//  这里的做法：开一个**隐藏 WKWebView** 打开网页登录页，让页面自己的 JS 去调签名接口、
//  渲染二维码；我们只做三件事——
//    1. 把 `img.qrcode-img` 的 data URL 取出来，在原生界面里显示；
//    2. 轮询页面状态文案（等待扫码 / 已扫码待确认）；
//    3. 轮询 cookie 存储，出现 `web_session` 后做一次行为探测，通过才算登录成功。
//
//  二维码这一步是"白嫖"网页的渲染结果，所以不需要任何签名代码。
//

import Foundation
import SwiftUI
import SwiftUtils
import WebKit

@MainActor
final class XhsQRLoginService: NSObject, ObservableObject {
    enum Phase: Equatable {
        /// 页面加载中 / 还没出二维码
        case loading
        /// 二维码已显示，等用户扫
        case waiting
        /// 已扫码，等手机上点确认
        case scanned
        /// 正在校验登录态
        case verifying
        /// 成功
        case success
        /// 失败（附一句给用户看的原因）
        case failed(String)
    }

    /// 页面里的轮询结果
    private struct Snapshot: Decodable {
        let url: String
        let src: String
        let status: String
    }

    static let loginURL = URL(string: "https://www.xiaohongshu.com/login")!
    /// 二维码一般 2 分钟过期；这里给 3 分钟，超时就提示用户刷新或改用网页登录
    private static let timeout: TimeInterval = 180
    private static let pollInterval: TimeInterval = 0.7
    /// 页面没给状态文案时，靠文案关键词兜底判断"已扫"
    private static let scannedKeywords = ["确认", "扫描成功", "扫码成功"]

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var qrImage: PlatformImage?

    let webView: WKWebView

    private var lastQRSource: String?
    private var lastStatusText=""
    private var startedAt=Date()
    private var hasSeenSession=false
    private var lastCookieCount = -1
    private var lastSessionPrefix=""
    private var pollTask: Task<Void, Never>?
    private var isVerifying=false

    override init() {
        let configuration=WKWebViewConfiguration()
        // 每次登录用干净会话：旧 cookie 会让页面直接跳进去，拿不到二维码
        configuration.websiteDataStore = .nonPersistent()
        webView=WKWebView(frame: CGRect(x: 0, y: 0, width: 375, height: 600), configuration: configuration)
        super.init()
        // 桌面 UA：移动 UA 会拿到另一种登录页，里面没有 PC 的扫码区域
        webView.customUserAgent=VideoHTTP.UA.desktopChrome
        // 完全透明时部分页面会暂停渲染，留一点点（和抖音那个隐藏 WebView 同一个理由）
        #if os(iOS)
        webView.isOpaque=false
        webView.alpha=0.01
        #elseif os(macOS)
        webView.alphaValue=0.01
        #endif
        webView.navigationDelegate=self
    }

    // MARK: - 对外

    func start() {
        guard pollTask == nil else { return }
        phase = .loading
        startedAt=Date()
        hasSeenSession=false
        lastQRSource=nil
        webView.load(URLRequest(url: Self.loginURL))
        pollTask=Task { [weak self] in
            await self?.pollLoop()
        }
    }

    /// 换一张二维码（页面自己会重新申请）
    func refresh() {
        qrImage=nil
        lastQRSource=nil
        lastStatusText=""
        phase = .loading
        startedAt=Date()
        webView.reload()
    }

    func cancel() {
        pollTask?.cancel()
        pollTask=nil
        webView.stopLoading()
    }

    // MARK: - 轮询

    private func pollLoop() async {
        while !Task.isCancelled {
            if Date().timeIntervalSince(startedAt) > Self.timeout {
                phase = .failed("二维码已超时，请刷新二维码重试")
                return
            }
            await pollPage()
            await pollCookies()
            if case .success=phase { return }
            try? await Task.sleep(for: .seconds(Self.pollInterval))
        }
    }

    private func pollPage() async {
        let snapshot=await evaluatePage()
        guard let snapshot else { return }

        if snapshot.src != lastQRSource, !snapshot.src.isEmpty {
            lastQRSource=snapshot.src
            qrImage=decodeDataURL(snapshot.src)
            debugPrint("[小红书扫码] 拿到二维码，长度=\(snapshot.src.count)，解出来的图=\(qrImage == nil ? "nil" : "ok")")
            if phase == .loading { phase = .waiting }
        }

        let text=snapshot.status
        if text != lastStatusText {
            lastStatusText=text
            if !text.isEmpty { debugPrint("[小红书扫码] 页面状态: \(text)") }
        }
        // 页面没给文案时用关键词兜底；给了文案且含"确认"也算
        let looksScanned=Self.scannedKeywords.contains { text.contains($0) }
        if looksScanned, phase == .waiting || phase == .loading {
            phase = .scanned
        }
        // 页面离开登录页 = 网页那边认为登录完成了，交给 cookie 轮询去确认
        if !snapshot.url.contains("/login"), phase != .verifying {
            debugPrint("[小红书扫码] 页面已离开登录页: \(snapshot.url)")
        }
    }

    private func evaluatePage() async -> Snapshot? {
        let script = #"""
        (function(){
          var img = document.querySelector('img.qrcode-img');
          var status = document.querySelector('.qrcode [class*="status"], [class*="qrcode"] [class*="status"]');
          return JSON.stringify({
            url: location.href,
            src: img ? img.src : '',
            status: status ? (status.innerText || '').trim() : ''
          });
        })();
        """#
        let value: Any?=await withCheckedContinuation { (continuation: CheckedContinuation<Any?, Never>) in
            webView.evaluateJavaScript(script) { result, _ in
                continuation.resume(returning: result)
            }
        }
        guard let text=value as? String, let data=text.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    private func pollCookies() async {
        guard !isVerifying else { return }
        let cookies=await loadCookies()
        // 这条日志同时是「存储接对了没」的判据：页面加载后这里应该能看到 a1/gid 这些游客 cookie
        if cookies.count != lastCookieCount {
            lastCookieCount=cookies.count
            let names=cookies.compactMap { $0.domain.contains("xiaohongshu") ? $0.name : nil }.sorted()
            debugPrint("[小红书扫码] 当前 cookie 数=\(cookies.count) 小红书域=\(names)")
        }
        guard let session=cookies.first(where: { $0.name == "web_session" }), !session.value.isEmpty else { return }
        // 游客态也会种 web_session（03 开头）：只有 04 开头才是真登录
        let prefix=String(session.value.prefix(2))
        if prefix != lastSessionPrefix {
            lastSessionPrefix=prefix
            // 只打前缀，绝不打印整串（它是凭据）
            debugPrint("[小红书扫码] 出现 web_session，前缀=\(prefix)（04=真登录，03=游客态）")
        }
        guard session.value.hasPrefix("04") else { return }
        guard !hasSeenSession else { return }
        hasSeenSession=true
        isVerifying=true
        phase = .verifying
        defer { isVerifying=false }

        let header=XiaohongshuSession.header(from: cookies.filter { XiaohongshuSession.isRelevant($0) }) ?? ""
        debugPrint("[小红书扫码] 拿到 web_session（04 开头），开始行为探测")
        guard await XiaohongshuSession.shared.validate(cookieHeader: header) else {
            // 探测没过：可能是平台抖动，也可能是游客态假象。把 hasSeenSession 放开让下一轮再试
            debugPrint("[小红书扫码] 探测未通过，继续等待")
            hasSeenSession=false
            phase = .scanned
            return
        }
        await XiaohongshuSession.shared.save(cookies: cookies)
        await XiaohongshuSession.shared.refreshState()
        debugPrint("[小红书扫码] 登录成功")
        phase = .success
        pollTask?.cancel()
        pollTask=nil
        webView.stopLoading()
    }

    /// 读**这个 WebView 用的**存储里的 cookie。
    /// 踩过：写成 `WKWebsiteDataStore.default()` 读的是另一个存储，页面明明登录了这里永远是空的。
    private func loadCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { (continuation: CheckedContinuation<[HTTPCookie], Never>) in
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
    }

    // MARK: - 工具

    /// `data:image/png;base64,…` → 图片
    private func decodeDataURL(_ source: String) -> PlatformImage? {
        guard let comma=source.firstIndex(of: ",") else { return nil }
        let base64=String(source[source.index(after: comma)...])
        guard let data=Data(base64Encoded: base64) else {
            debugPrint("[小红书扫码] base64 解码失败")
            return nil
        }
        return PlatformImage(data: data)
    }
}

// MARK: - 导航回调

extension XhsQRLoginService: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            debugPrint("[小红书扫码] 页面加载完成: \(webView.url?.absoluteString.prefix(80) ?? "nil")")
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            if (error as NSError).code == NSURLErrorCancelled { return }
            self.phase = .failed("页面加载失败：\(error.localizedDescription)")
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            if (error as NSError).code == NSURLErrorCancelled { return }
            self.phase = .failed("页面加载失败：\(error.localizedDescription)")
        }
    }
}
