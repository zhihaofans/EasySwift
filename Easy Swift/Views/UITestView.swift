//
//  UITestView.swift
//  Easy Swift
//
//  原生 SwiftUI 常见组件展示页：统一玻璃卡片分组，跨平台。
//
//  Created by zzh on 2025/1/3.
//

import SwiftUI
import SwiftUtils

struct UITestView: View {
    @State private var toggleOn=false
    @State private var sliderValue=0.5
    @State private var stepperValue=0
    @State private var color=Color.blue
    @State private var date=Date()
    @State private var text=""
    @State private var pickerValue=0
    @State private var progressValue=0.6
    @State private var showAlert=false

    private let pickerOptions=["选项一", "选项二", "选项三"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                componentSection("按钮 Button") {
                    HStack(spacing: 12) {
                        Button("默认") {}
                        Button("玻璃") {}
                            .buttonStyle(.glassProminent)
                        Button(role: .destructive) {} label: {
                            Label("删除", systemImage: "trash")
                        }
                        Button {
                            showAlert=true
                        } label: {
                            Label("弹窗", systemImage: "bell")
                        }
                    }
                }

                componentSection("开关 Toggle") {
                    Toggle("启用功能", isOn: $toggleOn)
                }

                componentSection("滑块 Slider") {
                    Slider(value: $sliderValue)
                    Text("当前值：\(Int(sliderValue * 100))")
                        .foregroundStyle(.secondary)
                }

                componentSection("步进器 Stepper") {
                    Stepper("数量：\(stepperValue)", value: $stepperValue, in: 0...10)
                }

                componentSection("分段选择 Picker") {
                    Picker("选项", selection: $pickerValue) {
                        ForEach(0..<pickerOptions.count, id: \.self) { i in
                            Text(pickerOptions[i]).tag(i)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                componentSection("输入框 TextField") {
                    TextField("请输入内容", text: $text)
                        .textFieldStyle(.roundedBorder)
                }

                componentSection("日期选择 DatePicker") {
                    DatePicker("选择日期", selection: $date, displayedComponents: [.date])
                }

                componentSection("颜色选择 ColorPicker") {
                    ColorPicker("选择颜色", selection: $color)
                }

                componentSection("进度 ProgressView") {
                    VStack(spacing: 12) {
                        ProgressView(value: progressValue)
                            .progressViewStyle(.linear)
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                }

                componentSection("链接 Link") {
                    Link(destination: URL(string: "https://www.apple.com")!) {
                        Label("访问 Apple 官网", systemImage: "safari")
                    }
                }

                componentSection("图标 Image") {
                    HStack(spacing: 16) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.orange)
                        Image(systemName: "leaf.fill")
                            .foregroundStyle(.green)
                        Image(systemName: "drop.fill")
                            .foregroundStyle(.blue)
                    }
                    .font(.title2)
                }

                componentSection("标签 Label") {
                    Label("这是一个标签", systemImage: "tag")
                    Label("带副标题", systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
        .setNavigationTitle("SwiftUI 组件")
        .alert("提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("这是一个系统弹窗示例")
        }
    }

    // 组件分组卡片（玻璃材质）
    @ViewBuilder
    private func componentSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .padding(.horizontal)
    }
}
