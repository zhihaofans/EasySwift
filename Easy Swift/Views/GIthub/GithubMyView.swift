//
//  Github.MyView.swift
//  Easy Swift
//
//  Created by zzh on 2025/1/21.
//

import SwiftUI
import SwiftUtils

struct GithubMyView: View {
    @Binding var showingSetting: Bool
    private let LoginService = GithubLoginService()
    @State private var isLogin: Bool = false

    init(showingSetting: Binding<Bool> = .constant(false)) {
        _showingSetting = showingSetting
    }

    var body: some View {
        VStack(spacing: 16) {
            if isLogin {
                // 已登录状态
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)
                    Text("已登录")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                .padding(.horizontal)
            } else {
                // 未登录状态
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 56))
                        .foregroundStyle(.secondary)
                    Text("未登录")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Button {
                        showingSetting = true
                    } label: {
                        Label("去设置页配置 Token", systemImage: "gear")
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                }
                Spacer()
            }
        }
        .setNavigationTitle("我的Github")
        .onAppear {
            isLogin = LoginService.isLogin()
        }
    }
}

#Preview {
    GithubMyView()
}
