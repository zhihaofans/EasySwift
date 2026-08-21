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
    @AppStorage("github_access_token") var GithubAccessToken: String = ""
    @Environment(\.dismiss) private var dismiss

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
                    SecureField("GitHub Access Token", text: $GithubAccessToken)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .glassEffect(.regular, in: .rect(cornerRadius: 12))
                }

                // 说明
                Text("配置后自动保存，用于加载 Stars 等个人数据。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            .padding(.vertical, 8)
        }
        .setNavigationTitle("Github 设置")
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
