//
//  WebBrowserView.swift
//  Easy Swift
//
//  内置浏览器（sheet 用）：只负责把页面显示出来，不参与解析。
//  用于「看分享者主页」这类一次性跳转 —— 不走系统 Safari，避免来回切 App。
//
//  平台差异收口：WKWebView 的包装层按平台写两份，对外只暴露 `WebBrowserView`。
//

import SwiftUI
import WebKit

struct WebBrowserView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    private var title: String {
        url.host?.replacingOccurrences(of: "www.", with: "") ?? "网页"
    }

    var body: some View {
        // sheet 里必须自己套 NavigationStack（AGENTS §3.6）
        NavigationStack {
            WebViewRepresentable(url: url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(title)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("关闭") { dismiss() }
                    }
                }
        }
    }
}

// MARK: - WKWebView 包装

#if os(iOS)
private struct WebViewRepresentable: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView=WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // 只加载一次：URL 变了才重新请求，避免刷新时反复触发
        if webView.url != url, !webView.isLoading {
            webView.load(URLRequest(url: url))
        }
    }
}
#else
private struct WebViewRepresentable: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let webView=WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if webView.url != url, !webView.isLoading {
            webView.load(URLRequest(url: url))
        }
    }
}
#endif

#Preview {
    WebBrowserView(url: URL(string: "https://www.example.com")!)
}
