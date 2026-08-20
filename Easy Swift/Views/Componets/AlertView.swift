//
//  AlertView.swift
//  Easy Swift
//
//  Created by zzh on 2025/2/3.
//

import SwiftUI

// MARK: - ♻️ 旧版兼容（已弃用，内部转发为系统样式）

@available(*, deprecated, renamed: "InputAlertView", message: "已整合为系统样式，请迁移到 InputAlertView 或 .inputAlert(...) 修饰符")
struct InputAlertViewOld: View {
    let title: String
    let placeholder: String
    @Binding var inputText: String
    @Binding var isPresented: Bool
    var callback: (String) -> Void // 回调闭包

    var body: some View {
        VStack(spacing: 20) {
            Text(self.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            TextField(self.placeholder, text: self.$inputText)
                .textFieldStyle(.roundedBorder)
                .padding()

            HStack {
                Button("取消") {
                    self.isPresented = false
                }
                .foregroundColor(.red)
                .padding(.horizontal)

                Button("确定") {
                    self.isPresented = false
                    self.callback(self.inputText)
                }
                .foregroundColor(.blue)
                .padding(.horizontal)
            }
        }
        .padding()
        .frame(maxWidth: 300)
        .background(.background) // 跨平台系统背景色（iOS/macOS 通用）
        .cornerRadius(16)
        .shadow(radius: 10)
    }
}

/// 系统样式的输入弹窗
struct InputAlertView: View {
    let title: String
    let placeholder: String
    @Binding var inputText: String
    @Binding var isPresented: Bool
    var callback: (String) -> Void

    // 为 macOS / iOS 提供一致的系统样式输入
    var body: some View {
        EmptyView()
            .alert(self.title, isPresented: self.$isPresented) {
                TextField(self.placeholder, text: self.$inputText)
                Button("取消", role: .cancel) {}
                Button("确定") {
                    self.callback(self.inputText)
                }
            } message: {
                Text("请输入内容")
            }
    }
}

