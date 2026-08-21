//
//  Github.MainView.swift
//  Easy Swift
//
//  Created by zzh on 2025/1/14.
//

import SwiftUI
import SwiftUtils

#if os(macOS) // 仅 macOS 需要 AppKit 打开外部链接
import AppKit
#endif

struct GithubMainView: View {
    var body: some View {
        TabView {
            GithubTrendingView()
                .tabItem {
                    Label("探索", systemImage: "flame")
                }
            GithubStarsView()
                .tabItem {
                    Label("收藏", systemImage: "star.fill")
                }
            GithubMyView()
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
        }
        .navigationTitle("Github")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: GithubSettingView()) {
                    Image(systemName: "gear")
                }
            }
            #else
            ToolbarItem(placement: .automatic) {
                NavigationLink(destination: GithubSettingView()) {
                    Image(systemName: "gear")
                }
            }
            #endif
        }
    }
}

enum DateType: String, CaseIterable, Identifiable {
    case day, week, month
    var id: Self {
        self
    }
}

enum LanguageType: String, CaseIterable, Identifiable {
    case swift, java, python, go, javascript
    var id: Self {
        self
    }
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
        VStack(spacing: 0) {
            // 筛选：时间 + 语言
            VStack(spacing: 12) {
                Picker(selection: $selectedDate) {
                    Text("今日").tag(DateType.day)
                    Text("本周").tag(DateType.week)
                    Text("本月").tag(DateType.month)
                } label: {
                    Text("时间(暂不支持修改)")
                }
                .disabled(true)
                #if os(iOS)
                .pickerStyle(.segmented)
                #else
                .pickerStyle(.menu)
                #endif

                Picker(selection: $selectedLanguage) {
                    Text("Swift").tag(LanguageType.swift)
                    Text("Java").tag(LanguageType.java)
                    Text("Python").tag(LanguageType.python)
                    Text("Go").tag(LanguageType.go)
                    Text("JavaScript").tag(LanguageType.javascript)
                } label: {
                    Text("语言")
                }
                .onChange(of: selectedLanguage) { _, _ in
                    self.loadingTrendingData()
                }
                #if os(iOS)
                .pickerStyle(.navigationLink)
                #else
                .pickerStyle(.menu)
                #endif
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // 结果列表：官方 trending 卡片式
            ScrollView {
                LazyVStack(spacing: 12) {
                    if isLoadingError {
                        Text("错误:\(errorText)")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    } else if trendingList.isEmpty {
                        ProgressView()
                            .padding(.top, 40)
                    } else {
                        ForEach(trendingList, id: \.id) { item in
                            GithubRepoCardView(item: item)
                                .onClick {
                                    // iOS 走 Safari 预览；macOS 用默认浏览器
                                    #if os(iOS)
                                    safariUrlString = item.html_url
                                    isShowingSafari = true
                                    #else
                                    if let url = URL(string: item.html_url) {
                                        NSWorkspace.shared.open(url)
                                    }
                                    #endif
                                }
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .onAppear {
            self.loadingTrendingData()
        }
        .setNavigationTitle("Github")
        // 仅在 iOS 上挂载 Safari 预览修饰符，macOS 移除避免链接错误
        #if os(iOS)
        .showSafariWebPreviewView(safariUrlString, isPresented: $isShowingSafari)
        #endif
    }

    private func loadingTrendingData() {
        DispatchQueue.main.async {
            trendingList.removeAll()
        }
        GithubTrendingService().getTrendingList(language: selectedLanguage.rawValue) { result in
            trendingList = result.items
        } fail: { err in
            debugPrint(err)
            errorText = err
            isLoadingError = true
        }
    }
}

// Github 仓库卡片（参考官方 trending 卡片式）
struct GithubRepoCardView: View {
    let item: GithubTrendingItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题：仓库图标 + owner/name
            HStack(spacing: 6) {
                Image(systemName: "book.closed")
                    .foregroundStyle(.secondary)
                Text(item.full_name)
                    .font(.headline)
                    .foregroundStyle(.tint)
                    .lineLimit(1)
            }
            // 描述
            if let desc=item.description, desc.isNotEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            // 底部信息：语言色点 + 语言名 / star / fork
            HStack(spacing: 16) {
                if let lang=item.language, lang.isNotEmpty {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(languageColor(lang))
                            .frame(width: 10, height: 10)
                        Text(lang)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Label("\(item.stargazers_count)", systemImage: "star")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("\(item.forks_count)", systemImage: "tuningfork")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }

    // 语言对应色点颜色（参考 GitHub 官方语言色）
    private func languageColor(_ lang: String) -> Color {
        switch lang.lowercased() {
        case "swift": return .orange
        case "python": return .blue
        case "java": return .red
        case "go": return .cyan
        case "javascript": return .yellow
        case "typescript": return .blue
        case "rust": return .orange
        case "kotlin": return .purple
        case "c++", "c#", "c": return .pink
        default: return .gray
        }
    }
}

// Github Stars / Watch / Fork

enum StarsViewType: String, CaseIterable, Identifiable {
    case star, watch, fork
    var id: Self {
        self
    }
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
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if isLoadingError {
                            Text("错误:\(errorText)")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        } else if resultList.isEmpty {
                            ProgressView()
                                .padding(.top, 40)
                        } else {
                            ForEach(resultList, id: \.id) { item in
                                GithubRepoCardView(item: item)
                                    .onClick {
                                        #if os(iOS)
                                        safariUrlString = item.html_url
                                        isShowingSafari = true
                                        #else
                                        if let url = URL(string: item.html_url) {
                                            NSWorkspace.shared.open(url)
                                        }
                                        #endif
                                    }
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                #if os(iOS)
                .showSafariWebPreviewView(safariUrlString, isPresented: $isShowingSafari)
                #endif
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
    }

    private func loadingData() {
        DispatchQueue.main.async {
            resultList.removeAll()
        }
        GithubUserService().getStarsList { result in
            resultList = result
        } fail: { err in
            debugPrint(err)
            errorText = err.message
            isLoadingError = true
        }
    }
}

#Preview {
    GithubMainView()
}
