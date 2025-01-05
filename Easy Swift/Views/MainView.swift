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
        iosMainView()
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
            MoreView()
        default:
            NavigationView {
                List {
                    NavigationLink("二维码", destination: QrcodeView())
                    NavigationLink("哔了个哩", destination: BiliMainView())
                    NavigationLink("计算器", destination: CalculatorView())
                    NavigationLink("剪贴板", destination: ClipboardView())
                    NavigationLink("Swift UI测试", destination: UITestView())
                    Button(action: {}) {
                        Text("申请相机权限")
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
                }
                .navigationTitle(AppUtil().getAppName())
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)) {
                            Image(systemName: "person")
                        }
                    }
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

private struct MoreView: View {
    var body: some View {
        NavigationView {
            List {
//                    NavigationLink("工具", destination: ToolView())
                Text("更新中...")
            }
            .navigationTitle("更多")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)) {
                        Image(systemName: "person")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingView()) {
                        Image(systemName: "gear")
                    }
                }
            }
        }
    }
}

#Preview {
    MainView()
}
