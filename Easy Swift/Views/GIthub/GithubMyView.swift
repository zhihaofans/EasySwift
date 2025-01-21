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
            //                    ToolbarItem(placement: .navigationBarTrailing) {
            //                        NavigationLink(destination: BiliUserView()) {
            //                            // TODO: 这里跳转到个人页面或登录界面
            //                            Image(systemName: "person")
            //                        }
            //                    }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: SettingView()) {
                    Image(systemName: "gear")
                }
            }
        }
        .onAppear {
            isLogin = LoginService.isLogin()
        }
    }
}

#Preview {
    GithubMyView()
}
