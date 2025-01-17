//
//  Github.MainView.swift
//  Easy Swift
//
//  Created by zzh on 2025/1/14.
//

import SafariServices
import SwiftUI
import SwiftUtils

struct Github_MainView: View {
    @State private var selectedTab = 0
    var body: some View {
        switch selectedTab {
        case 0:
            // TODO: Github star / watch / fork 界面
//            Text("test")
            GithubTrendingView()

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
                    Label("探索", systemImage: "flame")
                }
                .tag(0)

            Text("")
                .fixedSize(horizontal: false, vertical: true) // 纵向固定大小
                .tabItem {
                    Label("收藏", systemImage: "star.fill")
                }
                .tag(1)

            Text("")
                .fixedSize(horizontal: false, vertical: true) // 纵向固定大小
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
                .tag(2)
        }
        .frame(maxHeight: 50) // 限制最大高度
    }
}

enum DateType: String, CaseIterable, Identifiable {
    case day, week, month
    var id: Self { self }
}

enum LanguageType: String, CaseIterable, Identifiable {
    case swift
    var id: Self { self }
}

struct GithubTrendingView: View {
    @State private var trendingList: [GithubTrendingItem] = []
    @State private var selectedDate: DateType = .day
    @State private var selectedLanguage: LanguageType = .swift
    @State private var isShowingSafari = false
    @State private var safariUrlString: String = "https://www.apple.com"
    var body: some View {
        VStack {
            List {
                Picker(selection: $selectedDate) {
                    Text("今日").tag(DateType.day)
                    Text("本周").tag(DateType.week)
                    Text("本月").tag(DateType.month)
                } label: {
                    Text("时间")
                }
                Picker(selection: $selectedLanguage) {
                    Text("Swift").tag(LanguageType.swift)
                } label: {
                    Text("语言")
                }
                if trendingList.isEmpty {
                    ProgressView()
                } else {
                    ForEach(trendingList, id: \.id) { item in
                        //                        Text(item.name).font(.title)
                        GithubTrendingContentView(item).onClick {
                            safariUrlString = item.html_url
                            isShowingSafari = true
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingSafari) {
                if let url = URL(string: safariUrlString) {
                    SafariView(url: url)
                } else {
                    Text("Invalid URL")
                }
            }
        }.onAppear {
            GithubTrendingService().getTrendingList { result in
                trendingList = result.items
            } fail: { err in
                print(err)
            }
        }
        .setNavigationTitle("Github")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
//                NavigationLink(destination: BiliUserView()) {
                // TODO: 这里跳转到个人页面或登录界面
                Image(systemName: "gear")
//                }
            }
        }
    }
}

struct GithubTrendingContentView: View {
    private let contentItem: GithubTrendingItem
    init(_ contentItem: GithubTrendingItem) {
        self.contentItem = contentItem
    }

    var body: some View {
        VStack(alignment: .leading) {
            VStack {
                Text(contentItem.full_name).font(.title)
//                .frame(maxHeight: .infinity) // 设置对齐方式
//                .onClick {
//                    let webUrl = appService.checkLink(itemData.modules.module_author.jump_url)
//                    appService.openUrl(appUrl: webUrl, webUrl: webUrl)
//                }

                Text(contentItem.language)
                Text("\(contentItem.stargazers_count) stars")
                    .lineLimit(2)
                    .padding(.horizontal, 20) // 设置水平方向的内间距

                Spacer()
            }
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview {
    Github_MainView()
}
