//
//  Github.MainView.swift
//  Easy Swift
//
//  Created by zzh on 2025/1/14.
//

import SwiftUI
import SwiftUtils

struct Github_MainView: View {
    @State private var selectedTab = 0
    var body: some View {
        switch selectedTab {
//        case 1:
            // TODO: Github star / watch / fork 界面
//            Text("test")

        case 2:
            // TODO: 我的Github界面、设置界面、历史记录界面
            List {
//                    NavigationLink("工具", destination: ToolView())
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

        default:
            // TODO: Github 主页、动态、热门榜、搜索
            List {
                Text("Hello, Github!")
            }
            .navigationTitle("Github")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: BiliUserView()) {
                        // TODO: 这里跳转到个人页面或登录界面
                        Image(systemName: "person")
                    }
                }
                // TODO: 改成哔哩哔哩设置界面
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    NavigationLink(destination: SettingView()) {
//                        Image(systemName: "gear")
//                    }
//                }
            }
        }
        TabView(selection: $selectedTab) {
            Text("")
                .tabItem {
                    Label("主页", systemImage: "house")
                }
                .tag(0)

            Text("")
                .fixedSize(horizontal: false, vertical: true) // 纵向固定大小
                .tabItem {
                    Label("动态", systemImage: "fanblades")
                }
                .tag(1)

            Text("")
                .fixedSize(horizontal: false, vertical: true) // 纵向固定大小
                .tabItem {
                    Label("更多", systemImage: "ellipsis")
                }
                .tag(2)
        }
        .frame(maxHeight: 50) // 限制最大高度
    }
}

#Preview {
    Github_MainView()
}
