//
//  XhsCookieEditView.swift
//  Easy Swift
//
//  手动填写小红书 Cookie。
//
//  为什么需要这条：网页登录一旦被滑块/风控卡住，用户就彻底没辙了；
//  而 cookie 本身是可以从浏览器里复制出来的。这里给一个后门，但**保存前必须验一次**——
//  否则等于存了一枚看起来像登录、实际无效的 cookie。
//

import SwiftUI
import SwiftUtils

struct XhsCookieEditView: View {
    @Environment(\.dismiss) private var dismiss
    var onSaved: () -> Void = {}

    @State private var text=""
    @State private var isChecking=false
    @State private var message: String="粘贴后点「验证并保存」"
    @State private var isError=false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("从浏览器开发者工具 → Application → Cookies → xiaohongshu.com 复制，\n粘贴成 `name=value; name=value` 的形式，至少要包含 web_session。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            TextEditor(text: $text)
                .font(.system(.footnote, design: .monospaced))
                .frame(minHeight: 120)
                .padding(8)
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
                .padding(.horizontal)
                .disabled(isChecking)

            HStack(spacing: 8) {
                if isChecking {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(isError ? Color.red : Color.secondary)
            }
            .padding(.horizontal)

            Spacer(minLength: 0)

            HStack {
                Button("取消") { dismiss() }
                Spacer()
                Button("验证并保存") {
                    Task { await save() }
                }
                .buttonStyle(.glassProminent)
                .disabled(isChecking || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .setNavigationTitle("小红书 Cookie")
    }

    @MainActor
    private func save() async {
        let header=XiaohongshuSession.sanitize(header: text)
        guard !header.isEmpty else {
            message="没解析出任何 cookie，检查一下格式"
            isError=true
            return
        }
        guard XiaohongshuSession.value(of: "web_session", in: header) != nil else {
            message="缺少 web_session，这串 cookie 登不了"
            isError=true
            return
        }

        isChecking=true
        isError=false
        message="正在验证..."
        defer { isChecking=false }

        switch await XiaohongshuSession.shared.probe(cookieHeader: header) {
        case .ok:
            break
        case .gated:
            message="这串 cookie 无效或已过期（探测请求被导到登录页）"
            isError=true
            return
        case .unavailable:
            message="平台暂时不可用（5xx/网络），没法验证，稍后再试"
            isError=true
            return
        }
        await XiaohongshuSession.shared.save(header: header)
        await XiaohongshuSession.shared.refreshState()
        message="已保存"
        onSaved()
        dismiss()
    }
}
