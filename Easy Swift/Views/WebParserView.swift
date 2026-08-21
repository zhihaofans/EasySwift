//
//  WebParserView.swift
//  Easy Swift
//
//  抖音等 SPA 页面反爬严重（JS 外壳 + API 签名 + 滑块验证码），纯 URLSession 拿不到数据。
//  此视图用系统 WebKit（WKWebView）加载页面，让 JS 正常执行后再从 DOM 提取图片/视频。
//  若触发滑块验证码，用户可在页面内手动完成，完成后自动提取；全原生，无外部库。
//
//  Created by zzh on 2026/08/20.
//

import SwiftUI
import WebKit

/// WebView 解析状态
enum WebParserStatus {
    case loading       // 页面加载/渲染中
    case captcha       // 检测到安全验证码，需用户手动完成
}

#if os(iOS)
struct WebParserView: UIViewRepresentable {
    let url: URL
    let onResult: (LinkParseResult) -> Void
    let onFail: (String) -> Void
    let onStatusChange: (WebParserStatus) -> Void
    let retryTrigger: UUID?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        context.coordinator.currentWebView = webView
        webView.load(URLRequest(url: url))
        // 不依赖 didFinish：加载后延迟启动轮询（SPA 页面 didFinish 可能不触发/延迟）
        context.coordinator.schedulePolling(webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let retryTrigger, retryTrigger != context.coordinator.lastTrigger {
            context.coordinator.lastTrigger = retryTrigger
            context.coordinator.forceExtract()
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebParserView
        var currentWebView: WKWebView?
        var lastTrigger: UUID?
        private var pollTimer: Timer?
        private var pollStart: Date?
        private let maxPollDuration: TimeInterval = 30

        init(_ parent: WebParserView) {
            self.parent = parent
        }

        deinit {
            pollTimer?.invalidate()
        }

        // 延迟启动轮询（给页面初始加载时间）
        func schedulePolling(_ webView: WKWebView) {
            pollTimer?.invalidate()
            pollTimer = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self, self.pollTimer == nil else { return }
                self.pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                    self?.poll(webView)
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            currentWebView = webView
            // 页面加载完成：立即检查一次，并确保轮询在跑
            pollTimer?.invalidate()
            pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.poll(webView)
            }
            poll(webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.onFail(error.localizedDescription)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.onFail(error.localizedDescription)
        }

        func forceExtract() {
            if let webView = currentWebView {
                pollTimer?.invalidate()
                pollTimer = nil
                WebParserView.extract(from: webView, parent: parent)
            }
        }

        // 轮询检查：验证码 / 数据就绪 / 超时兜底
        private func poll(_ webView: WKWebView) {
            if pollStart == nil { pollStart = Date() }
            // 超时兜底：不再无限等待，强制提取一次给出明确结果
            if let start = pollStart, Date().timeIntervalSince(start) > maxPollDuration {
                pollTimer?.invalidate()
                pollTimer = nil
                WebParserView.extract(from: webView, parent: parent)
                return
            }
            webView.evaluateJavaScript(WebParserView.statusJS) { [weak self] result, error in
                guard let self else { return }
                guard error == nil, let json = result as? String,
                      let data = json.data(using: .utf8),
                      let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                    return
                }
                let captcha = (obj["captcha"] as? Bool) ?? false
                let og = (obj["og"] as? Int) ?? 0
                let vids = (obj["vids"] as? Int) ?? 0
                let imgs = (obj["imgs"] as? Int) ?? 0
                DispatchQueue.main.async {
                    if captcha {
                        self.parent.onStatusChange(.captcha)
                    }
                    // 有任一内容即提取（og 标签 / 视频 / 图片）
                    if og > 0 || vids > 0 || imgs > 0 {
                        // 提取；若页面仍在渲染（提取为空）则继续轮询等待
                        WebParserView.extract(from: webView, parent: self.parent) { hasContent in
                            if hasContent {
                                self.pollTimer?.invalidate()
                                self.pollTimer = nil
                            }
                        }
                    }
                }
            }
        }
    }
}
#else
struct WebParserView: NSViewRepresentable {
    let url: URL
    let onResult: (LinkParseResult) -> Void
    let onFail: (String) -> Void
    let onStatusChange: (WebParserStatus) -> Void
    let retryTrigger: UUID?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        context.coordinator.currentWebView = webView
        webView.load(URLRequest(url: url))
        context.coordinator.schedulePolling(webView)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if let retryTrigger, retryTrigger != context.coordinator.lastTrigger {
            context.coordinator.lastTrigger = retryTrigger
            context.coordinator.forceExtract()
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebParserView
        var currentWebView: WKWebView?
        var lastTrigger: UUID?
        private var pollTimer: Timer?
        private var pollStart: Date?
        private let maxPollDuration: TimeInterval = 30

        init(_ parent: WebParserView) {
            self.parent = parent
        }

        deinit {
            pollTimer?.invalidate()
        }

        func schedulePolling(_ webView: WKWebView) {
            pollTimer?.invalidate()
            pollTimer = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self, self.pollTimer == nil else { return }
                self.pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                    self?.poll(webView)
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            currentWebView = webView
            pollTimer?.invalidate()
            pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.poll(webView)
            }
            poll(webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.onFail(error.localizedDescription)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.onFail(error.localizedDescription)
        }

        func forceExtract() {
            if let webView = currentWebView {
                pollTimer?.invalidate()
                pollTimer = nil
                WebParserView.extract(from: webView, parent: parent)
            }
        }

        private func poll(_ webView: WKWebView) {
            if pollStart == nil { pollStart = Date() }
            if let start = pollStart, Date().timeIntervalSince(start) > maxPollDuration {
                pollTimer?.invalidate()
                pollTimer = nil
                WebParserView.extract(from: webView, parent: parent)
                return
            }
            webView.evaluateJavaScript(WebParserView.statusJS) { [weak self] result, error in
                guard let self else { return }
                guard error == nil, let json = result as? String,
                      let data = json.data(using: .utf8),
                      let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                    return
                }
                let captcha = (obj["captcha"] as? Bool) ?? false
                let og = (obj["og"] as? Int) ?? 0
                let vids = (obj["vids"] as? Int) ?? 0
                let imgs = (obj["imgs"] as? Int) ?? 0
                DispatchQueue.main.async {
                    if captcha {
                        self.parent.onStatusChange(.captcha)
                    }
                    if og > 0 || vids > 0 || imgs > 0 {
                        // 提取；若页面仍在渲染（提取为空）则继续轮询等待
                        WebParserView.extract(from: webView, parent: self.parent) { hasContent in
                            if hasContent {
                                self.pollTimer?.invalidate()
                                self.pollTimer = nil
                            }
                        }
                    }
                }
            }
        }
    }
}
#endif

extension WebParserView {
    /// 状态检查：验证码元素（多种选择器）/ og:image / video / img
    fileprivate static let statusJS = """
    (function(){
      var cap = document.querySelector('.captcha_verify_container, [class*="captcha" i], [id*="captcha" i], iframe[src*="captcha" i], #captcha, [data-testid*="captcha" i]');
      var og = document.querySelectorAll('meta[property="og:image"]').length;
      var vids = document.querySelectorAll('video').length;
      var imgs = document.querySelectorAll('img').length;
      return JSON.stringify({captcha: !!cap, og: og, vids: vids, imgs: imgs});
    })()
    """

    // 页面渲染完成后提取：og 标签 + video 元素 + 图片元素 + performance 资源记录
    // 图片按渲染尺寸取最大的 12 张（封面/内容图优先，过滤头像等小图），不限域名
    // 视频：DOM 的 video 常是 blob:，真实地址通过 performance 资源记录捕获（动图/视频分片）
    fileprivate static let extractionJS = """
    (function(){
      var r = {title: document.title || '', images: [], videos: []};
      var metas = document.querySelectorAll('meta[property="og:image"],meta[name="og:image"],meta[property="twitter:image"]');
      for (var i=0;i<metas.length;i++){ if(metas[i].content) r.images.push(metas[i].content); }
      var vmetas = document.querySelectorAll('meta[property="og:video"],meta[name="og:video"]');
      for (var i=0;i<vmetas.length;i++){ if(vmetas[i].content) r.videos.push(vmetas[i].content); }
      var vids = document.querySelectorAll('video');
      for (var i=0;i<vids.length;i++){
        if(vids[i].src) r.videos.push(vids[i].src);
        var ss = vids[i].querySelectorAll('source');
        for (var j=0;j<ss.length;j++){ if(ss[j].src) r.videos.push(ss[j].src); }
      }
      // performance 资源记录：捕获真实视频文件（动图/视频的 mp4/m3u8 等，带签名地址）
      try {
        var entries = performance.getEntriesByType('resource');
        for (var i=0;i<entries.length;i++){
          var u = entries[i].name;
          if (u && u.indexOf('http')===0 &&
              (u.indexOf('.mp4')>-1 || u.indexOf('.m3u8')>-1 || u.indexOf('.webm')>-1 || u.indexOf('.flv')>-1 || u.indexOf('douyinvod')>-1)) {
            if (r.videos.indexOf(u)===-1) r.videos.push(u);
          }
        }
      } catch(e){}
      var pool = [];
      var imgs = document.querySelectorAll('img');
      for (var i=0;i<imgs.length;i++){
        var src = imgs[i].currentSrc || imgs[i].src;
        if (src && src.indexOf('data:')!==0 && (src.indexOf('http:')===0 || src.indexOf('https:')===0)) {
          pool.push({src: src, w: imgs[i].naturalWidth || 0});
        }
      }
      var big = pool.filter(function(p){ return p.w > 50; }).sort(function(a,b){ return b.w - a.w; });
      var small = pool.filter(function(p){ return p.w <= 50; });
      for (var i=0;i<big.length && r.images.length<12;i++) r.images.push(big[i].src);
      for (var i=0;i<small.length && r.images.length<12;i++) r.images.push(small[i].src);
      return JSON.stringify(r);
    })()
    """

    // 提取并回调结果（主线程）；completion 返回是否提取到内容
    //  - 轮询路径：提取为空时继续轮询等待（页面可能仍在渲染/验证码刚过）
    //  - 超时/手动路径：提取为空时 onFail 给出明确结果
    fileprivate static func extract(from webView: WKWebView, parent: WebParserView, completion: ((Bool) -> Void)? = nil) {
        webView.evaluateJavaScript(extractionJS) { result, error in
            DispatchQueue.main.async {
                guard error == nil,
                      let jsonString = result as? String,
                      let data = jsonString.data(using: .utf8),
                      let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                    completion?(false)
                    if completion == nil {
                        parent.onFail(error?.localizedDescription ?? "页面解析失败")
                    }
                    return
                }
                let title = obj["title"] as? String
                let images = (obj["images"] as? [String] ?? [])
                    .compactMap { URL(string: $0) }
                    .filter { $0.scheme == "http" || $0.scheme == "https" }
                let videos = (obj["videos"] as? [String] ?? [])
                    .compactMap { URL(string: $0) }
                    .filter { $0.scheme == "http" || $0.scheme == "https" }
                if images.isEmpty && videos.isEmpty {
                    completion?(false)
                    if completion == nil {
                        parent.onFail("页面中未找到图片或视频（可能被安全验证拦截）")
                    }
                } else {
                    completion?(true)
                    parent.onResult(LinkParseResult(title: title, images: images, videos: videos))
                }
            }
        }
    }
}
