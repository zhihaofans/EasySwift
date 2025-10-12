//
//  MainView.swift
//  Easy Swift
//
//  Created by zzh on 2024/11/24.
//

import SwiftUI
import SwiftUtils

struct MainView: View {
    var body: some View {
//        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
        #if os(iOS)
        iosMainView()
        #else
        MacMainView()
        #endif
    }
}

@available(macOS, unavailable)
struct iosMainView: View {
    @State private var selectedTab=0
    @State private var showingAlert=false
    @State private var alertTitle: String="未知错误"
    @State private var alertText: String="未知错误"
    var body: some View {
        switch selectedTab {
//        case 1:
//            Text("test")
        // ScanView()
        case 2:
            EmptyTextPageView(title: "更多", text: "更新中...")
        default:
            NavigationView {
                List {
                    NavigationLink("二维码", destination: QrcodeView())
                    NavigationLink("哔了个哩", destination: BiliMainView())
                    NavigationLink("计算器", destination: CalculatorView())
                    NavigationLink("剪贴板", destination: ClipboardView())
                    NavigationLink("Swift UI测试", destination: UITestView())
                    NavigationLink("搜索", destination: SearchView())
                    NavigationLink("Github", destination: GithubMainView())
                    NavigationLink("TODO", destination: TodoView())
                    Button(action: {
                        AuthUtil().authenticate(title: "FaceId或TouchId") { result in
                            print("authenticate\(result)")
                        } fail: { err in
                            print("authenticate error:\(err)")
                        }

                    }) {
                        Text("FaceId")
                    }
                    .alert(alertTitle, isPresented: $showingAlert) {
                        Button("OK", action: {
                            alertTitle=""
                            alertText=""
                            showingAlert=false
                        })
                    } message: {
                        Text(alertText)
                    }
                    Button(action: {
#if canImport(UIKit)
                        UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
#endif
                    }) {
                        Text("返回桌面")
                    }
                }
                .navigationTitle(AppUtil().getAppName())
                .toolbar {
//                    ToolbarItem(placement: .navigationBarTrailing) {
//                        NavigationLink(destination: Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)) {
//                            Image(systemName: "person")
//                        }
//                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: SettingView()) {
                            Image(systemName: "gear")
                        }
                    }
                }
            }
        }
//        TabView(selection: $selectedTab) {
//            Text("")
//                .tabItem {
//                    Label("主页", systemImage: "house")
//                }
//                .tag(0)
//
//            Text("")
//                .fixedSize(horizontal: false, vertical: true) // 纵向固定大小
//                .tabItem {
//                    Label("扫一扫", systemImage: "qrcode.viewfinder")
//                }
//                .tag(1)
//
//            Text("")
//                .fixedSize(horizontal: false, vertical: true) // 纵向固定大小
//                .tabItem {
//                    Label("更多", systemImage: "ellipsis")
//                }
//                .tag(2)
//        }
//        .frame(maxHeight: 50) // 限制最大高度
    }
}

#if os(macOS)
// [UPDATED macOS] 新增：macOS 主视图
import AppKit

struct MacMainView: View {
    @State private var selectedTab = 0
    @State private var showingAlert = false
    @State private var alertTitle: String = "未知错误"
    @State private var alertText: String = "未知错误"

    var body: some View {
        switch selectedTab {
        case 2:
            EmptyTextPageView(title: "更多", text: "更新中...")
        default:
            NavigationView {
                List {
                    NavigationLink("二维码", destination: QrcodeView())
                    NavigationLink("哔了个哩", destination: BiliMainView())
                    NavigationLink("计算器", destination: CalculatorView())
                    NavigationLink("剪贴板", destination: ClipboardView())
                    NavigationLink("Swift UI测试", destination: UITestView())
                    NavigationLink("搜索", destination: SearchView())
                    NavigationLink("Github", destination: GithubMainView())
                    NavigationLink("TODO", destination: TodoView())

                    // [UPDATED macOS] 隐藏 iOS 专属的 Face ID 按钮（macOS 无 FaceID/LAContext 流程）
                    // 如需 Touch ID，也应单独实现 LAContext.evaluatePolicy 的 macOS 流程

                    // [UPDATED macOS] 返回桌面（隐藏应用窗口）
                    Button(action: {
                        NSApplication.shared.hide(nil)
                    }) {
                        Text("返回桌面")
                    }
                }
                .navigationTitle(AppUtil().getAppName())
                .toolbar {
                    // [UPDATED macOS] 工具栏位置用 .automatic，而非 .navigationBarTrailing
                    ToolbarItem(placement: .automatic) {
                        NavigationLink(destination: SettingView()) {
                            Image(systemName: "gear")
                        }
                    }
                }
            }
        }
    }
}
#endif
#Preview {
    MainView()
}
