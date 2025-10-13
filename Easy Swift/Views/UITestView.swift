//
//  UITestView.swift
//  Easy Swift
//
//  Created by zzh on 2025/1/3.
//

import SwiftUI
import SwiftUtils

// 仅在 macOS 使用 AppKit（做系统分享）
#if os(macOS)
import AppKit
#endif

struct UITestView: View {
    @State private var isShareSheetPresented = false
    @State private var textToShare = "这是我要分享的一段文本！"
    var body: some View {
        VStack {
            NavigationView {
                List {
                    Button(action: {
                        isShareSheetPresented = true
                    }) {
                        Text("调用系统分享")
                    }
                    // iOS 仍走你现有的分享；macOS 用 NSSharingServicePicker
                    #if os(iOS)
                    .showShareTextView(textToShare, isPresented: $isShareSheetPresented)
                    #elseif os(macOS)
                    .macShareTextView(textToShare, isPresented: $isShareSheetPresented) // 定义见下方
                    #endif

                    NavigationLink("昨天", destination: DateTextView())
                }
            }
        }
        // iOS 和 macOS 的导航标题分别适配
        #if os(iOS)
        .setNavigationTitle(AppUtil().getAppName())
        #elseif os(macOS)
        .navigationTitle(AppUtil().getAppName())
        #endif
        .toolbar {
            // iOS 的工具栏放右侧导航栏；macOS 用 .automatic
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: Text("Hello, World!")) {
                    Image(systemName: "person")
                }
            }
            #elseif os(macOS)
            ToolbarItem(placement: .automatic) {
                NavigationLink(destination: Text("Hello, World!")) {
                    Image(systemName: "person")
                }
            }
            #endif

            // 第二个按钮同样分平台放置
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: SettingView()) {
                    Image(systemName: "gear")
                }
            }
            #elseif os(macOS)
            ToolbarItem(placement: .automatic) {
                NavigationLink(destination: SettingView()) {
                    Image(systemName: "gear")
                }
            }
            #endif
        }
    }
}

struct DateTextView: View {
    @State private var selectedDate = Date()
    @State private var resultText = "不是昨天"
    var body: some View {
        DatePicker("请选择日期", selection: $selectedDate, displayedComponents: [.date])
        // 日期样式：iOS 用轮盘；macOS 用文本域（你也可以换成 .graphical）
        #if os(iOS)
            .datePickerStyle(.wheel)
        #elseif os(macOS)
            .datePickerStyle(.field)
        #endif
            .padding().onChange(of: selectedDate) { _, _ in
                if isYesterday(nowDate: Date(), date: selectedDate) {
                    resultText = "昨天"
                } else {
                    resultText = "不是昨天"
                }
            }

        Text("你选择的日期是: \(selectedDate, formatter: dateFormatter)")
            .padding()

        Text(resultText)
            .padding()
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }

    func isYesterday(nowDate: Date, date: Date) -> Bool {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: nowDate) {
            return false
        }
        let startOfDay1 = calendar.startOfDay(for: nowDate)
        let startOfDay2 = calendar.startOfDay(for: date)
        // 如果 date1 是 date2 的前一天
        let result = calendar.isDate(startOfDay1, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: startOfDay2)!)
        print(nowDate)
        print(date)
        print(result)
        return result
    }
}

// MARK: - macOS 分享：NSSharingServicePicker 封装

#if os(macOS)
private struct MacSharingPicker: NSViewRepresentable {
    @Binding var isPresented: Bool
    var items: [Any]

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard isPresented else { return }
        // 在当前 NSView 上弹出系统分享面板
        let picker = NSSharingServicePicker(items: items)
        picker.show(relativeTo: nsView.bounds, of: nsView, preferredEdge: .minY)
        // 弹出后立刻复位绑定值，防止重复弹出
        DispatchQueue.main.async {
            self.isPresented = false
        }
    }
}

/// 一个易用的修饰符，和 iOS 的 .showShareTextView 使用体验对齐
private struct MacShareTextModifier: ViewModifier {
    let text: String
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content.background(
            MacSharingPicker(isPresented: $isPresented, items: [text])
                .frame(width: 0, height: 0) // 不占布局
        )
    }
}

#endif
// #Preview {
//    UITestView()
// }
