//
//  XhsQRLoginView.swift
//  Easy Swift
//
//  扫码登录面板：原生显示小红书登录页里的那张二维码。
//  二维码由隐藏 WebView 里的网页 JS 申请并渲染，我们只负责显示与轮询（原因见 XhsQRLoginService）。
//  扫不上/超时就点「改用网页登录」退回原来的可见 WebView 流程。
//

import SwiftUI
import SwiftUtils
import WebKit

struct XhsQRLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service=XhsQRLoginService()
    /// 登录成功后回调，调用方刷新账号状态
    var onFinished: () -> Void = {}
    /// 用户选择退回网页登录
    var onFallback: () -> Void = {}

    var body: some View {
        // sheet 里没有导航容器时，setNavigationTitle / toolbar 都不渲染（标题和「取消」会消失），
        // 所以这里自己套一层 NavigationStack
        NavigationStack {
            content
                .setNavigationTitle("扫码登录小红书")
                .toolbar {
                    ToolbarItem(placement: toolbarPlacement) {
                        Button("取消") {
                            service.cancel()
                            dismiss()
                        }
                    }
                }
        }
    }

    private var content: some View {
        VStack(spacing: 16) {
            Text(hint)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)

            qrCard

            HStack(spacing: 10) {
                Button("刷新二维码") {
                    service.refresh()
                }
                .buttonStyle(.glass)

                Button("改用网页登录") {
                    service.cancel()
                    dismiss()
                    onFallback()
                }
                .buttonStyle(.glassProminent)
            }
            .controlSize(.large)

            Spacer(minLength: 0)
        }
        .padding(.top, 12)
        // 隐藏 WebView：必须真的挂进视图层级，否则页面不渲染、JS 不跑
        .background(alignment: .topLeading) {
            webViewHost
                .frame(width: 375, height: 600)
                .opacity(0.01)
                .allowsHitTesting(false)
        }
        .task {
            service.start()
        }
        .onDisappear {
            service.cancel()
        }
        .onChange(of: service.phase) { _, phase in
            if case .success=phase {
                onFinished()
                dismiss()
            }
        }
    }

    // MARK: - 子视图

    private var qrCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white)
                .frame(width: 240, height: 240)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.black.opacity(0.08), lineWidth: 1)
                }
            if let image=service.qrImage {
                Image(platformImage: image)
                    .interpolation(.none) // 二维码放大不能糊
                    .resizable()
                    .frame(width: 210, height: 210)
            } else {
                ProgressView()
            }
            // 已扫码时在码上盖一层提示，避免用户以为要再扫一次
            if case .scanned=service.phase {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.black.opacity(0.55))
                    .frame(width: 240, height: 240)
                Text("已扫码，请在手机上确认")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
    }

    private var hint: String {
        switch service.phase {
        case .loading: return "正在准备登录二维码…"
        case .waiting: return "用小红书 App 扫一扫上面的二维码"
        case .scanned: return "已扫码，请在手机上点「确认登录」"
        case .verifying: return "正在确认登录态…"
        case .success: return "登录成功"
        case let .failed(reason): return reason
        }
    }

    private var toolbarPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .navigationBarTrailing
        #else
        return .automatic
        #endif
    }

    @ViewBuilder
    private var webViewHost: some View {
        #if os(iOS)
        XhsQRWebViewHost(webView: service.webView)
        #elseif os(macOS)
        XhsQRWebViewHostMac(webView: service.webView)
        #endif
    }
}

#if os(iOS)
private struct XhsQRWebViewHost: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
#elseif os(macOS)
private struct XhsQRWebViewHostMac: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
#endif
