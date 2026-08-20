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
        #if os(iOS)
        NavigationStack {
            mainList()
                .navigationTitle(AppUtil().getAppName())
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: SettingView()) {
                            Image(systemName: "gear")
                        }
                    }
                }
        }
        #else
        // [UPDATED macOS] NavigationSplitView 侧边栏布局（macOS 原生风格，玻璃材质）
        NavigationSplitView {
            mainList()
                .navigationTitle(AppUtil().getAppName())
                .navigationSplitViewColumnWidth(min: 180, ideal: 220)
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        NavigationLink(destination: SettingView()) {
                            Image(systemName: "gear")
                        }
                    }
                }
        } detail: {
            ContentUnavailableView("选择一个功能", systemImage: "sidebar.left")
        }
        #endif
    }

    // iOS / macOS 统一功能列表
    @ViewBuilder
    private func mainList() -> some View {
        List {
            NavigationLink("二维码", destination: QrcodeView())
            NavigationLink("计算器", destination: CalculatorView())
            NavigationLink("剪贴板", destination: ClipboardView())
            NavigationLink("Swift UI测试", destination: UITestView())
            NavigationLink("搜索", destination: SearchView())
            NavigationLink("Github", destination: GithubMainView())
        }
    }
}

#Preview {
    MainView()
}
