//
//  GithubSettingView.swift
//  Easy Swift
//
//  Github 专属设置：用户名 / Access Token（从 SettingView 移入）
//
//  Created by zzh on 2026/08/21.
//

import SwiftUI
import SwiftUtils

struct GithubSettingView: View {
    @AppStorage("github_username") var GithubUsername: String = ""
    /// Token 存钥匙串，不能再直绑 @AppStorage
    @State private var accessToken: String = ""
    /// 进页面时读到的原值。用它兜底：读失败时不能拿空串把钥匙串里已有的 Token 覆盖掉
    @State private var loadedToken: String = ""
    @State private var saveTask: Task<Void, Never>?
    @State private var saveFailed = false
    @Environment(\.dismiss) private var dismiss
    private let loginService = GithubLoginService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 用户名
                settingSection("用户名") {
                    TextField("GitHub 用户名", text: $GithubUsername)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .glassEffect(.regular, in: .rect(cornerRadius: 12))
                }

                // Access Token
                settingSection("Access Token") {
                    SecureField("GitHub Access Token", text: $accessToken)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .glassEffect(.regular, in: .rect(cornerRadius: 12))
                }

                // 说明
                if saveFailed {
                    Text("保存到钥匙串失败，Token 未生效。请检查钥匙串访问权限后重试。")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                } else {
                    Text("配置后自动保存到钥匙串，用于加载 Stars 等个人数据。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical, 8)
        }
        .setNavigationTitle("Github 设置")
        .task {
            let stored=loginService.getAccessToken()
            loadedToken=stored
            accessToken=stored
        }
        .onChange(of: accessToken) { _, newValue in
            // 防抖 400ms，避免每敲一个字符就写一次钥匙串
            guard newValue != loadedToken else { return }
            saveTask?.cancel()
            saveTask=Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                saveFailed = !loginService.setAccessToken(newValue)
            }
        }
        .onDisappear {
            // 返回上一页立刻落盘，不等防抖。
            // 只写"用户真的改过"的情况：读钥匙串失败时 accessToken 会是空串，
            // 若无条件写一次，就会把原来好好的 Token 删掉。
            saveTask?.cancel()
            guard accessToken != loadedToken else { return }
            saveFailed = !loginService.setAccessToken(accessToken)
        }
        .toolbar {
            #if os(macOS)
            // macOS sheet 显式关闭按钮
            ToolbarItem(placement: .automatic) {
                Button {
                    dismiss()
                } label: {
                    Label("完成", systemImage: "xmark.circle")
                        .labelStyle(.titleAndIcon)
                }
            }
            #endif
        }
    }

    @ViewBuilder
    private func settingSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }
}

#Preview {
    GithubSettingView()
}
