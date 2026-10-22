//
//  DouyinWebExtractor.swift
//  Easy Swift
//
//  抖音的主解析路线：用一个 1×1 的隐藏 WKWebView 真跑一遍作品页，再从页面里取数。
//
//  为什么必须这样：纯 HTTP 拿到的分享页会被换成风控挑战页，JSON 接口要签名（a_bogus / msToken），
//  只有让页面自己的 JS 跑起来，XHR 才会带着合法签名发出去。
//
//  三个关键点（改之前先看懂）：
//  1. 注入脚本必须挂在 document-start —— 挂在 didFinish 就晚了，页面自己的请求早发完了；
//  2. 就绪判据是「钩子拿到数据」或「DOM 出现真作品图」，二者取其一，不能只等其中一个；
//  3. 读 XHR 要同时兼容 responseText 与 response：页面把 responseType 设成 json 时，读前者会抛异常。
//

import Foundation
import WebKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// WebView 路线的失败原因。调用方据此决定"给可操作提示"还是"转 HTTP 回退"
enum DouyinExtractError: Error, CustomStringConvertible {
    /// 没有前台窗口：页面跑不起来，回退也救不了
    case noFrontWindow
    /// 已有解析在进行（全局只允许一个隐藏 WebView 存活）
    case busy
    /// 撞上验证码 / 风控
    case blocked
    /// 页面盖着登录浮层（未登录看不到内容）
    case needLogin
    /// 超时未就绪
    case timeout
    case failed(String)

    var description: String {
        switch self {
        case .noFrontWindow: return "noFrontWindow"
        case .busy: return "busy"
        case .blocked: return "blocked"
        case .needLogin: return "needLogin"
        case .timeout: return "timeout"
        case let .failed(message): return "failed(\(message))"
        }
    }
}

@MainActor
final class DouyinWebExtractor {
    /// 实测成功样本 4–7 秒；给 18 秒余量即可。
    /// 超时后由调用方（HTTP 竞速）兜底，不让用户干等 40 秒
    private static let timeout: TimeInterval = 18
    private static let pollInterval: TimeInterval = 1.2
    private static let evalTimeout: TimeInterval = 3

    /// 全局只允许一个隐藏 WebView 存活：批量粘贴多条链接时不能连开
    private static var isRunning = false



    private var webView: WKWebView?
    private var hostView: PlatformView?

    /// 解析一个作品。`awemeID` 已经由调用方从链接里取好。
    @MainActor
    static func extract(awemeID: String) async throws -> LinkParseResult {
        guard !isRunning else { throw DouyinExtractError.busy }
        isRunning = true
        defer { isRunning = false }
        return try await DouyinWebExtractor().run(awemeID: awemeID)
    }

    private func run(awemeID: String) async throws -> LinkParseResult {
        guard let container = Self.keyWindowView() else {
            // 没有前台窗口时页面跑不起来，这是环境问题，不要报成"作品已删除"
            throw DouyinExtractError.noFrontWindow
        }

        let webView = Self.makeWebView()
        webView.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        #if canImport(UIKit)
        webView.alpha = 0.01 // 完全透明时部分页面会暂停渲染，留一点点
        #else
        webView.alphaValue = 0.01
        #endif
        container.addSubview(webView)
        self.webView = webView
        self.hostView = container

        defer { tearDown() }

        let url = URL(string: "https://www.douyin.com/video/\(awemeID)")!
        debugPrint("[抖音] 隐藏 WebView 加载 \(url.absoluteString)")
        webView.load(URLRequest(url: url))

        var readyPayload: [String: Any]?
        var lastState: [String: Any]?
        var loginStreak = 0
        let deadline = Date().addingTimeInterval(Self.timeout)
        while Date() < deadline {
            try? await Task.sleep(for: .seconds(Self.pollInterval))
            if Task.isCancelled { throw DouyinExtractError.failed("已取消") }

            guard let raw = await evaluate(Self.readyJS),
                  let state = Self.jsonObject(raw) else { continue }
            lastState = state

            if (state["captcha"] as? Bool) == true {
                throw DouyinExtractError.blocked
            }
            if (state["login"] as? Bool) == true {
                loginStreak += 1
                if loginStreak >= 3 { throw DouyinExtractError.needLogin }
            } else {
                loginStreak = 0
            }
            let hasHook = (state["hook"] as? Bool) == true
            let hasWorkImage = (state["work"] as? Int ?? 0) > 0
            let hasRenderData = (state["render"] as? Bool) == true
            if hasHook || hasWorkImage || hasRenderData {
                readyPayload = state
                break
            }
        }

        guard readyPayload != nil else {
            // 超时把最后一次探测到的页面状态打出来：
            // hook/render/work 全是 0 → 页面根本没拿到数据（限流或登录墙）；
            // 有值却没就绪 → 判据写错了。两种情况的修法完全不同
            let snapshot=lastState.map { state in
                "hook=\(state["hook"] ?? "-") render=\(state["render"] ?? "-") work=\(state["work"] ?? "-") captcha=\(state["captcha"] ?? "-") login=\(state["login"] ?? "-")"
            } ?? "无状态（脚本一直没返回）"
            debugPrint("[抖音] \(Int(Self.timeout))s 未就绪，finalURL=\(webView.url?.absoluteString ?? "nil") 状态: \(snapshot)")
            DouyinWebViewCooldown.markFailure()
            throw DouyinExtractError.timeout
        }

        guard let raw = await evaluate(Self.extractJS),
              let payload = Self.jsonObject(raw) else {
            throw DouyinExtractError.failed("取数脚本没有返回结果")
        }

        let source = payload["src"] as? String ?? "none"
        debugPrint("[抖音] 取数来源=\(source) 图=\((payload["images"] as? [Any])?.count ?? 0) 动图=\((payload["motions"] as? [Any])?.count ?? 0) 视频=\((payload["videos"] as? [Any])?.count ?? 0)")
        guard let result = Self.makeResult(payload) else {
            throw DouyinExtractError.failed("页面里没有可用的图片或视频（来源=\(source)）")
        }
        debugPrint("[抖音] 解析成功(\(source)): 标题=\(result.title ?? "nil") 图=\(result.images.count) 动图=\(result.motions.count) 视频=\(result.videos.count)")
        return result
    }

    // MARK: - 结果映射

    private static func makeResult(_ payload: [String: Any]) -> LinkParseResult? {
        let images = (payload["images"] as? [String] ?? []).compactMap { URL(string: $0) }.map { $0.httpsURL }
        let videos = (payload["videos"] as? [String] ?? []).compactMap { URL(string: $0) }.map { $0.httpsURL }
        // motions 与图片等长，空串表示该图没有动图
        let motionStrings = payload["motions"] as? [String] ?? []
        var motions: [Int: URL] = [:]
        for (index, raw) in motionStrings.enumerated() where !raw.isEmpty {
            if let url = URL(string: raw) {
                motions[index] = url.httpsURL
            }
        }
        guard !images.isEmpty || !videos.isEmpty else { return nil }
        // 动图与图片靠下标配对，错位了用户看到的"第 N 张是动图"就是错的 —— 打下标便于核对
        if !motions.isEmpty {
            debugPrint("[抖音] 动图下标(0 起)=\(motions.keys.sorted()) 图片数=\(images.count)")
            if let info = payload["motionInfo"] as? [[String: Any]] {
                for item in info {
                    debugPrint("[抖音] 动图[下标\(item["i"] ?? "-")] 时长\(item["d"] ?? "-") URL=\(item["u"] ?? "-")")
                }
            }
        }
        let title = (payload["title"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        return LinkParseResult(title: title, images: images, videos: videos, motions: motions)
    }

    private static func jsonObject(_ value: Any?) -> [String: Any]? {
        // evaluateJavaScript 回传的是 JSON 文本，不是对象
        guard let text = value as? String, let data = text.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    // MARK: - WebView 组装与清理

    private static func makeWebView() -> WKWebView {
        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(source: injectionJS,
                                              injectionTime: .atDocumentStart,
                                              forMainFrameOnly: false))
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        // 每次解析用独立的匿名会话：复用同一个 ttwid 容易被平台标记，
        // 表现就是「页面能打开但没有任何数据」（hook/render/work 全 0）
        configuration.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        // 桌面版页面才给完整的作品数据（移动 UA 会拿到裁剪过的分享页）
        webView.customUserAgent = VideoHTTP.UA.desktopChrome
        return webView
    }

    private func tearDown() {
        webView?.stopLoading()
        webView?.removeFromSuperview()
        webView = nil
        hostView = nil
    }

    /// 前台窗口的根视图。拿不到返回 nil，由调用方给"请切回应用"的提示
    private static func keyWindowView() -> PlatformView? {
        #if canImport(UIKit)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap { $0.windows }.first(where: { $0.isKeyWindow }) ?? scenes.first?.windows.first
        return window?.rootViewController?.view
        #elseif canImport(AppKit)
        // 用 NSApplication.shared 而不是 NSApp：后者是隐式解包全局，在非 GUI 进程里会直接 trap
        let app = NSApplication.shared
        return (app.keyWindow ?? app.windows.first)?.contentView
        #else
        return nil
        #endif
    }

    /// 单次求值带超时：页面正在导航时回调可能永远不回来
    private func evaluate(_ script: String) async -> Any? {
        guard let webView else { return nil }
        return await withCheckedContinuation { (continuation: CheckedContinuation<Any?, Never>) in
            let lock = NSLock()
            var finished = false
            func finish(_ value: Any?) {
                lock.lock()
                if finished {
                    lock.unlock()
                    return
                }
                finished = true
                lock.unlock()
                continuation.resume(returning: value)
            }
            webView.evaluateJavaScript(script) { result, _ in
                finish(result)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.evalTimeout) {
                finish(nil)
            }
        }
    }
}

// MARK: - 注入脚本

/// 三段脚本用 internal 暴露：本仓库没有测试 target，靠仓库外的 harness 直接跑这些判据
/// （JS 判据改错时表现是「超时 40 秒」，靠肉眼看不出来）
extension DouyinWebExtractor {
    /// document-start 注入：抹掉平台指纹 + 挂 XHR/fetch 钩子
    static let injectionJS = #"""
    (function(){
      try {
        Object.defineProperty(navigator, 'platform', { get: function(){ return 'MacIntel'; } });
      } catch(e) {}
      function remember(text){
        try {
          if (typeof text === 'string' && text.length > 50 && text.indexOf('aweme_detail') > -1) {
            window.__ezAwemeDetail = text;
            try { sessionStorage.setItem('__ezAweme', text); } catch(e) {}
          }
        } catch(e) {}
      }
      function readBody(xhr){
        var text = '';
        try { text = xhr.responseText; } catch(e) {}
        if (!text) {
          try {
            var r = xhr.response;
            text = (typeof r === 'string') ? r : (r ? JSON.stringify(r) : '');
          } catch(e) {}
        }
        return text;
      }
      var origOpen = XMLHttpRequest.prototype.open;
      XMLHttpRequest.prototype.open = function(method, url){
        try { this.__ezURL = String(url || ''); } catch(e) {}
        return origOpen.apply(this, arguments);
      };
      var origSend = XMLHttpRequest.prototype.send;
      XMLHttpRequest.prototype.send = function(){
        var xhr = this;
        try {
          xhr.addEventListener('load', function(){
            // 不按 URL 过滤：视频页与笔记页的详情接口路径不同，白名单一定会漏
            try { window.__ezXHRCount = (window.__ezXHRCount || 0) + 1; } catch(e) {}
            remember(readBody(xhr));
          });
        } catch(e) {}
        return origSend.apply(this, arguments);
      };
      var origFetch = window.fetch;
      if (origFetch) {
        window.fetch = function(){
          var promise = origFetch.apply(this, arguments);
          try {
            promise.then(function(resp){
              try { resp.clone().text().then(remember).catch(function(){}); } catch(e) {}
            }).catch(function(){});
          } catch(e) {}
          return promise;
        };
      }
    })();
    """#

    /// 就绪判据：钩子有数据，或 DOM 出现真作品图。
    /// 判作品图必须排除封面（pcweb_cover）与相关推荐（WEBPC_RELATED），否则刚出封面就"就绪"
    static let readyJS = #"""
    (function(){
      var hookText = window.__ezAwemeDetail;
      if (!hookText) { try { hookText = sessionStorage.getItem('__ezAweme'); } catch(e) {} }
      var hook = typeof hookText === 'string' && hookText.length > 50;
      var work = 0;
      var imgs = document.querySelectorAll('img');
      for (var i=0; i<imgs.length; i++){
        var src = imgs[i].currentSrc || imgs[i].src || '';
        if (src.indexOf('douyinpic.com') === -1) continue;
        if (src.indexOf('pcweb_cover') > -1 || src.indexOf('WEBPC_RELATED') > -1) continue;
        if (src.indexOf('biz_tag=aweme_images') > -1 || src.indexOf('tplv-dy-aweme-images') > -1) work++;
      }
      // SSR 数据到位才算就绪，而且必须是"真的带 videoDetail"：
      // 登录墙/风控页上也有 RENDER_DATA（200KB 的配置），只判存在会瞬间"就绪"然后取到空
      var render = false;
      try {
        var el = document.getElementById('RENDER_DATA');
        if (el && el.textContent && el.textContent.length > 1000) {
          var parsed = null;
          try { parsed = JSON.parse(decodeURIComponent(el.textContent)); }
          catch(e1) { try { parsed = JSON.parse(el.textContent); } catch(e2) {} }
          render = !!(parsed && parsed.app && parsed.app.videoDetail);
        }
      } catch(e) {}
      // 验证码必须"看得见"才算：页面常驻一个隐藏的 captcha iframe，
      // 按选择器命中就判验证码会误报，表现是每次都被弹到可见页兜底
      var captcha = false;
      try {
        if (location.pathname.indexOf('verify') > -1) captcha = true;
        if (!captcha) {
          var nodes = document.querySelectorAll('[class*="captcha" i], [id*="captcha" i]');
          for (var j=0; j<nodes.length; j++){
            var node = nodes[j];
            if (node.offsetWidth || node.offsetHeight || node.getClientRects().length) { captcha = true; break; }
          }
        }
      } catch(e) {}
      // 登录墙：未登录时作品页会盖一层登录浮层，此时既没有 XHR 也没有作品图
      var login = false;
      try {
        var body = document.body ? document.body.innerText : '';
        login = body.indexOf('登录后免费畅享') > -1
             || body.indexOf('扫码登录') > -1
             || body.indexOf('验证码登录') > -1;
      } catch(e) {}
      return JSON.stringify({hook: hook, work: work, render: render, captcha: captcha, login: login});
    })();
    """#

    /// 取数：SSR 的 RENDER_DATA 优先（图文/动图只有这条能拿全），再试钩子，最后 DOM 兜底
    static let extractJS = #"""
    (function(){
      function pick(list){
        if (!list) return '';
        for (var i=0; i<list.length; i++){ if (list[i]) return list[i]; }
        return '';
      }
      function looksLikeAudio(url){
        return /ies-music|\/music\/|\.mp3(\?|$)/i.test(String(url));
      }
      function videoURL(video){
        if (!video) return '';
        var play = video.play_addr || video.playAddr || {};
        var url = pick(play.url_list || play.urlList);
        // 配乐（ies-music 的 mp3）不是动图：有些条目的 video 字段挂的是 BGM
        if (url) return looksLikeAudio(url) ? '' : String(url).replace('playwm', 'play');
        var rates = video.bit_rate || video.bitRate || [];
        for (var i=0; i<rates.length; i++){
          var addr = rates[i].play_addr || rates[i].playAddr || {};
          var one = pick(addr.url_list || addr.urlList);
          if (one) return looksLikeAudio(one) ? '' : String(one).replace('playwm', 'play');
        }
        var download = video.download_addr || video.downloadAddr || {};
        var dl = pick(download.url_list || download.urlList);
        if (!dl || looksLikeAudio(dl)) return '';
        return String(dl).replace('playwm', 'play');
      }
      function fill(detail, r){
        if (!detail) return false;
        r.title = detail.desc || detail.preview_title || '';
        var images = detail.images || [];
        for (var i=0; i<images.length; i++){
          var img = images[i] || {};
          var list = img.url_list || img.urlList || [];
          var best = pick(list);
          r.images.push(best || '');
          var motionVideo = img.video || img.motion || null;
          var motionUrl = videoURL(motionVideo);
          r.motions.push(motionUrl);
          if (motionUrl) {
            try { r.motionInfo.push({i: i, d: (motionVideo && (motionVideo.duration || motionVideo.video_duration)) || 0, u: motionUrl.slice(0, 70)}); } catch(e) {}
          }
        }
        // 图文作品的 detail.video 里挂的是配乐（play_addr 指向 ies-music 的 mp3），
        // 不能当视频返回；只有没有图片时才认为它是视频作品
        if (r.images.length === 0) {
          var v = videoURL(detail.video);
          if (v) r.videos.push(v);
        }
        return r.images.length > 0 || r.videos.length > 0;
      }
      var r = {src: 'none', title: '', images: [], motions: [], videos: [], motionInfo: []};

      // 1) SSR：<script id="RENDER_DATA">，内容是 URL 编码的 JSON
      try {
        var el = document.getElementById('RENDER_DATA');
        if (el && el.textContent) {
          var data = JSON.parse(decodeURIComponent(el.textContent));
          var detail = (data.app && data.app.videoDetail) || null;
          if (!detail) {
            var stack = [data], guard = 0;
            while (stack.length && guard < 5000) {
              guard++;
              var cur = stack.pop();
              if (!cur || typeof cur !== 'object') continue;
              if (cur.videoDetail) { detail = cur.videoDetail; break; }
              for (var k in cur) { if (cur[k] && typeof cur[k] === 'object') stack.push(cur[k]); }
            }
          }
          if (fill(detail, r)) { r.src = 'render'; return JSON.stringify(r); }
        }
      } catch(e) {}

      // 2) XHR / fetch 钩子（视频直链通常只在这里）
      try {
        var hookText = window.__ezAwemeDetail;
        if (!hookText) { try { hookText = sessionStorage.getItem('__ezAweme'); } catch(e) {} }
        if (hookText) {
          var payload = JSON.parse(hookText);
          var aweme = payload.aweme_detail || (payload.data && payload.data.aweme_detail) || null;
          if (fill(aweme, r)) { r.src = 'hook'; return JSON.stringify(r); }
        }
      } catch(e) {}

      // 3) DOM 兜底：拿不到动图资源，动图会静默退化成静态图
      try {
        var imgs = document.querySelectorAll('img');
        for (var i=0; i<imgs.length; i++){
          var src = imgs[i].currentSrc || imgs[i].src || '';
          if (src.indexOf('douyinpic.com') === -1) continue;
          if (src.indexOf('pcweb_cover') > -1 || src.indexOf('WEBPC_RELATED') > -1) continue;
          var ok = src.indexOf('biz_tag=aweme_images') > -1 || src.indexOf('tplv-dy-aweme-images') > -1;
          if (ok && r.images.indexOf(src) === -1) {
            r.images.push(src);
            r.motions.push('');
          }
        }
      } catch(e) {}

      if (r.images.length || r.videos.length) r.src = 'dom';
      return JSON.stringify(r);
    })();
    """#
}


/// WebView 失败冷却。
/// 一次超时说明平台当前不给我们数据，短时间内重试只是再让用户干等 18 秒；
/// 冷却期内调用方应直接走 HTTP（代价是图文暂时没有动图）。
enum DouyinWebViewCooldown {
    private static let lock=NSLock()
    private static var lastFailure: Date?
    static let duration: TimeInterval=300

    static var isCoolingDown: Bool {
        lock.lock(); defer { lock.unlock() }
        guard let lastFailure else { return false }
        return Date().timeIntervalSince(lastFailure) < duration
    }

    static func markFailure() {
        lock.lock(); defer { lock.unlock() }
        lastFailure=Date()
    }

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        lastFailure=nil
    }
}
