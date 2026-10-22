//
//  XhsLoginView.swift
//  Easy Swift
//
//  小红书网页登录：用可见 WKWebView 打开登录页，用户自己扫码/输密码/过滑块，
//  页面每次加载完成后取一次 cookie，**只有行为探测通过**才认为登录成功并存进钥匙串。
//
//  为什么不在 App 里做表单登录：登录页有自己的验证码与风控，用网页走系统浏览器内核最省事，
//  也避免我们替用户处理密码。
//

import SwiftUI
import SwiftUtils
import WebKit

struct XhsLoginView: View {
    @Environment(\.dismiss) private var dismiss
    /// 登录成功后回调，调用方用它刷新状态
    var onFinished: () -> Void = {}

    @State private var status="请在下方页面完成登录，成功后会自动关闭"
    @State private var isChecking=false
    @State private var baselineSession: String?
    @State private var isLoading=true

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                if isChecking || isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)

            XhsLoginWebView(onPageLoaded: { cookies in
                Task { await inspect(cookies) }
            }, onFailure: { message in
                status="页面加载失败：\(message)"
            })

            HStack {
                Button("我已登录，完成") {
                    Task { await finishManually() }
                }
                .buttonStyle(.glassProminent)
                Spacer()
                Button("取消") { dismiss() }
            }
            .padding()
        }
        .setNavigationTitle("登录小红书")
    }

    // MARK: - 自动检测

    /// 页面每次加载完成都会调一次。
    /// 不能按 cookie 名判断登录（游客态也有 web_session），只把"凭据变了"当成候选，
    /// 再用行为探测确认。
    @MainActor
    private func inspect(_ cookies: [HTTPCookie]) async {
        let session=cookies.first { $0.name == "web_session" }?.value
        guard let baseline=baselineSession else {
            baselineSession=session ?? ""
            isLoading=false
            return
        }
        isLoading=false
        guard !isChecking, (session ?? "") != baseline else { return }

        isChecking=true
        defer { isChecking=false }
        status="正在确认登录态..."

        let header=XiaohongshuSession.header(from: cookies.filter { XiaohongshuSession.isRelevant($0) }) ?? ""
        if await XiaohongshuSession.shared.validate(cookieHeader: header) {
            await XiaohongshuSession.shared.save(cookies: cookies)
            status="登录成功"
            onFinished()
            dismiss()
        } else {
            status="凭据变了但还不是有效登录态，请继续完成登录"
            baselineSession=session ?? baseline
        }
    }

    // MARK: - 手动完成

    @MainActor
    private func finishManually() async {
        isChecking=true
        defer { isChecking=false }
        status="正在确认登录态..."

        let cookies=await XhsLoginWebView.loadCookies()
        let header=XiaohongshuSession.header(from: cookies.filter { XiaohongshuSession.isRelevant($0) }) ?? ""
        if await XiaohongshuSession.shared.validate(cookieHeader: header) {
            await XiaohongshuSession.shared.save(cookies: cookies)
            status="登录成功"
            onFinished()
            dismiss()
        } else {
            status="还没检测到有效登录，确认已完成登录后再试一次"
        }
    }
}

// MARK: - 取 cookie

extension XhsLoginWebView {
    /// 从 WebView 共用的 cookie 存储里读全部 cookie
    static func loadCookies() async -> [HTTPCookie] {
        return await withCheckedContinuation { (continuation: CheckedContinuation<[HTTPCookie], Never>) in
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
    }
}

// MARK: - 导航协调（平台无关）

final class XhsLoginCoordinator: NSObject, WKNavigationDelegate {
    let onPageLoaded: ([HTTPCookie]) -> Void
    let onFailure: (String) -> Void

    init(onPageLoaded: @escaping ([HTTPCookie]) -> Void, onFailure: @escaping (String) -> Void) {
        self.onPageLoaded=onPageLoaded
        self.onFailure=onFailure
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
            DispatchQueue.main.async {
                self?.onPageLoaded(cookies)
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onFailure(error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        onFailure(error.localizedDescription)
    }
}

// 登录页用根地址：登录表单本身要桌面 UA 才能完整显示
private let xhsLoginURL=URL(string: "https://www.xiaohongshu.com/login")!

#if os(iOS)
struct XhsLoginWebView: UIViewRepresentable {
    let onPageLoaded: ([HTTPCookie]) -> Void
    let onFailure: (String) -> Void

    func makeCoordinator() -> XhsLoginCoordinator {
        XhsLoginCoordinator(onPageLoaded: onPageLoaded, onFailure: onFailure)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView=WKWebView()
        webView.customUserAgent=VideoHTTP.UA.desktopChrome
        webView.navigationDelegate=context.coordinator
        webView.load(URLRequest(url: xhsLoginURL))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
#else
struct XhsLoginWebView: NSViewRepresentable {
    let onPageLoaded: ([HTTPCookie]) -> Void
    let onFailure: (String) -> Void

    func makeCoordinator() -> XhsLoginCoordinator {
        XhsLoginCoordinator(onPageLoaded: onPageLoaded, onFailure: onFailure)
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView=WKWebView()
        webView.customUserAgent=VideoHTTP.UA.desktopChrome
        webView.navigationDelegate=context.coordinator
        webView.load(URLRequest(url: xhsLoginURL))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
#endif
