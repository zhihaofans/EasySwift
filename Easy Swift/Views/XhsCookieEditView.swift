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
    /// 是否已经把钥匙串里现有的 cookie 读进输入框（只读一次，之后用户改了就不覆盖）
    @State private var didPrefill=false

    var body: some View {
        // sheet 里没有导航容器：不套这一层，标题和「复制」都渲染不出来，
        // 内容还会顶到状态栏下面（实测截图里文字被裁掉一截）
        NavigationStack {
            content
                .setNavigationTitle("小红书 Cookie")
                .toolbar {
                    ToolbarItem(placement: copyButtonPlacement) {
                        Button {
                            ClipboardUtil().setString(text)
                            message="已复制当前输入框里的 cookie"
                            isError=false
                        } label: {
                            Label("复制", systemImage: "doc.on.doc")
                        }
                        .disabled(text.isEmpty)
                    }
                }
        }
        .task {
            await prefillFromKeychain()
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("从浏览器开发者工具 → Application → Cookies → xiaohongshu.com 复制，\n粘贴成 `name=value; name=value` 的形式，至少要包含 web_session。\n（打开时会把当前保存的那份读进来，方便直接复制走）")
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
    }

    private var copyButtonPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .navigationBarTrailing
        #else
        return .automatic
        #endif
    }

    /// 把钥匙串里现有的 cookie 读进输入框：用户往往只是想「看一眼/复制走」，
    /// 每次都去浏览器重新复制一遍很折腾。只填一次，不覆盖用户已经输入的内容。
    @MainActor
    private func prefillFromKeychain() async {
        guard !didPrefill else { return }
        didPrefill=true
        guard text.isEmpty else { return }
        guard let stored=await XiaohongshuSession.shared.cookieHeader(), !stored.isEmpty else { return }
        text=stored
        // 只打对数，不打内容：这是凭据
        let pairs=stored.split(separator: ";").count
        debugPrint("[小红书Cookie] 已把钥匙串里的 cookie 预填进输入框，\(pairs) 对")
        message="下面是当前已保存的 cookie，点右上角「复制」可以取走"
        isError=false
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
