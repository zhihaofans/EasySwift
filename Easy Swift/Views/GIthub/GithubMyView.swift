//
//  Github.MyView.swift
//  Easy Swift
//
//  Created by zzh on 2025/1/21.
//

import SwiftUI
import SwiftUtils

struct GithubMyView: View {
    private let LoginService = GithubLoginService()
    @State private var isLogin: Bool = false
    var body: some View {
        VStack {
            if isLogin {
                List {
                    //                    NavigationLink("工具", destination: ToolView())
                    Text("已登录")
                }
            } else {
                Spacer()
                Text("未登录").font(.largeTitle)
                Spacer()
            }
        }
        .navigationTitle("我的Github")
        .toolbar {
            // 工具栏按钮分平台布局
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
        .onAppear {
            isLogin = LoginService.isLogin()
        }
    }
}

#Preview {
    GithubMyView()
}
