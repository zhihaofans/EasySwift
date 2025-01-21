//
//  Github.MainView.swift
//  Easy Swift
//
//  Created by zzh on 2025/1/14.
//

import SwiftUI
import SwiftUtils

struct GithubMainView: View {
    @State private var selectedTab = 0
    var body: some View {
        switch selectedTab {
        case 0:
            GithubTrendingView()
        case 1:
            // TODO: Github star / watch / fork 界面
            GithubStarsView()
        case 2:
            // TODO: 我的Github界面、设置界面、历史记录界面
            GithubMyView()
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
    case swift, java, python, go, javascript
    var id: Self { self }
}

// Github Trending
struct GithubTrendingView: View {
    @State private var trendingList: [GithubTrendingItem] = []
    @State private var selectedDate: DateType = .day
    @State private var selectedLanguage: LanguageType = .swift
    @State private var isShowingSafari = false
    @State private var safariUrlString: String = "https://www.apple.com"
    @State private var isLoadingError = false
    @State private var errorText = "加载失败，请重试"
    var body: some View {
        VStack {
            List {
                Picker(selection: $selectedDate) {
                    Text("今日").tag(DateType.day)
                    Text("本周").tag(DateType.week)
                    Text("本月").tag(DateType.month)
                } label: {
                    Text("时间(暂不支持修改)")
                }.disabled(true)
                Picker(selection: $selectedLanguage) {
                    Text("Swift").tag(LanguageType.swift)
                    Text("Java").tag(LanguageType.java)
                    Text("Python").tag(LanguageType.python)
                    Text("Go").tag(LanguageType.go)
                    Text("JavaScript").tag(LanguageType.javascript)
                } label: {
                    Text("语言")
                }.onChange(of: selectedLanguage) { _, _ in
                    self.loadingTrendingData()
                }
                if isLoadingError {
                    Text("错误:\(errorText)").font(.largeTitle)
                } else if trendingList.isEmpty {
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
            .showSafariWebPreviewView(safariUrlString, isPresented: $isShowingSafari)
        }.onAppear {
            self.loadingTrendingData()
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

    private func loadingTrendingData() {
        DispatchQueue.main.async {
            trendingList.removeAll()
        }
        GithubTrendingService().getTrendingList(language: selectedLanguage.rawValue) { result in
            trendingList = result.items
        } fail: { err in
            print(err)
            errorText = err
            isLoadingError = true
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

                Text(contentItem.language ?? "🈚")
                Text("\(contentItem.stargazers_count) stars")
                    .lineLimit(2)
                    .padding(.horizontal, 20) // 设置水平方向的内间距

                Spacer()
            }
        }
    }
}

// Github Stars / Watch / Fork

enum StarsViewType: String, CaseIterable, Identifiable {
    case star, watch, fork
    var id: Self { self }
}

struct GithubStarsView: View {
    @State private var resultList: [GithubTrendingItem] = []
    @State private var selectedType: StarsViewType = .star
    @State private var isShowingSafari = false
    @State private var safariUrlString: String = "https://www.apple.com"
    @State private var isLoadingError = false
    @State private var errorText = "加载失败，请重试"
    @AppStorage("github_username") var UserName: String = ""
    var body: some View {
        VStack {
            if UserName.isNotEmpty {
                List {
                    Picker(selection: $selectedType) {
                        Text("Stars").tag(StarsViewType.star)
                    } label: {
                        Text("类型")
                    }.disabled(true)
                    if isLoadingError {
                        Text("错误:\(errorText)").font(.largeTitle)
                    } else if resultList.isEmpty {
                        ProgressView()
                    } else {
                        ForEach(resultList, id: \.id) { item in
                            //                        Text(item.name).font(.title)
                            GithubStarsContentView(item).onClick {
                                safariUrlString = item.html_url
                                isShowingSafari = true
                            }
                        }
                    }
                }
                .showSafariWebPreviewView(safariUrlString, isPresented: $isShowingSafari)
            } else {
                Spacer()
                Text("请先登录").font(.largeTitle)
                Spacer()
            }
        }.onAppear {
            if UserName.isNotEmpty {
                self.loadingData()
            }
        }
        .setNavigationTitle(UserName.isEmpty ? "Github Stars" : "\(UserName) 's Stars")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
//                NavigationLink(destination: BiliUserView()) {
                // TODO: 这里跳转到个人页面或登录界面
                Image(systemName: "gear")
//                }
            }
        }
    }

    private func loadingData() {
        DispatchQueue.main.async {
            resultList.removeAll()
        }
        GithubUserService().getStarsList { result in
            resultList = result
        } fail: { err in
            print(err)
            errorText = err
            isLoadingError = true
        }
    }
}

struct GithubStarsContentView: View {
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
                Text(contentItem.language ?? "🈚")
                Text("\(contentItem.stargazers_count) stars")
                    .lineLimit(2)
                    .padding(.horizontal, 20) // 设置水平方向的内间距

                Spacer()
            }
        }
    }
}

#Preview {
    GithubMainView()
}
