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

// MARK: - 🍬 便捷修饰符：任何视图上一行弹系统输入框

public extension View {
    /// 在当前视图上以系统样式弹出带输入框的 Alert
    /// - Parameters:
    ///   - title: 标题
    ///   - placeholder: 占位提示
    ///   - text: 绑定的文本
    ///   - isPresented: 是否显示
    ///   - onConfirm: 点“确定”回调（传回输入内容）
    func inputAlert(
        _ title: String,
        placeholder: String = "",
        text: Binding<String>,
        isPresented: Binding<Bool>,
        onConfirm: @escaping (String) -> Void
    ) -> some View {
        self.background(
            InputAlertView(
                title: title,
                placeholder: placeholder,
                inputText: text,
                isPresented: isPresented,
                callback: onConfirm
            )
        )
    }
}
