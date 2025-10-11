//
//  SearchView.swift
//  Easy Swift
//
//  Created by zzh on 2025/1/12.
//

import SwiftUI
import SwiftUtils
#if os(macOS)
import AppKit
#endif
struct SearchView: View {
    @State private var selectedType: SearchType = .github
    @State private var isShareSheetPresented = false
    @State private var SearchKey = "test"
    @State private var isShowingSafari = false
    @State private var safariUrlString: String = "https://www.apple.com"
    var body: some View {
        VStack {
            NavigationView {
                List {
                    Picker(selection: $selectedType) {
                        Text("Github").tag(SearchType.github)
                        Text("哔哩哔哩").tag(SearchType.bilibili)
                        Text("百度").tag(SearchType.baidu)
                        Text("Google").tag(SearchType.google)
                        Text("Bing").tag(SearchType.bing)
                        Text("Google 翻译").tag(SearchType.google_translate)
                        Text("百度翻译").tag(SearchType.baidu_translate)
                        Text("DeepL 翻译").tag(SearchType.deepl_translate)
                        Text("Steam游戏").tag(SearchType.steam_game)
                        Text("Hugging Face").tag(SearchType.huggingface)
                    } label: {
                        Text("类型")
                    }
                    TextField("搜点什么", text: $SearchKey)
                    Button(action: {
                        // TODO: Search
                        if SearchKey.isNotEmpty {
                            self.goSearch()
                        }
                    }) {
                        Text("Go to Search")
                    }
                }
            }
        }
        .setNavigationTitle("Search")
        .toolbar {
            // [UPDATED macOS] 工具栏分平台放置
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: Text("Hello, World!")) {
                    Image(systemName: "person")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: SettingView()) {
                    Image(systemName: "gear")
                }
            }
            #elseif os(macOS)
            ToolbarItem(placement: .automatic) {
                NavigationLink(destination: Text("Hello, World!")) {
                    Image(systemName: "person")
                }
            }
            ToolbarItem(placement: .automatic) {
                NavigationLink(destination: SettingView()) {
                    Image(systemName: "gear")
                }
            }
            #endif
        }
        #if os(iOS)
        .showSafariWebPreviewView(safariUrlString, isPresented: $isShowingSafari)
        #endif
    }

    private func goSearch() {
        switch selectedType {
        case .github:
            safariUrlString = "https://github.com/search?q=\(SearchKey)&type=repositories"
            isShowingSafari = true
        case .bilibili:
            safariUrlString = "https://search.bilibili.com/all?keyword=\(SearchKey)"
            isShowingSafari = true
        case .baidu:
            safariUrlString = "https://www.baidu.com/s?wd=\(SearchKey)"
            isShowingSafari = true
        case .google:
            safariUrlString = "https://www.google.com/search?q=\(SearchKey)"
            isShowingSafari = true
        case .bing:
            safariUrlString = "https://www.bing.com/search?q=\(SearchKey)"
            isShowingSafari = true
        case .google_translate:
            safariUrlString = "https://translate.google.com/?sl=auto&tl=zh-CN&text=\(SearchKey)"
            isShowingSafari = true
        case .baidu_translate:
            safariUrlString = "https://fanyi.baidu.com/#auto/zh/\(SearchKey)"
            isShowingSafari = true
        case .deepl_translate:
            safariUrlString = "https://www.deepl.com/zh/translator#zh/en-us/\(SearchKey)"
            isShowingSafari = true
        case .steam_game:
            safariUrlString = "https://store.steampowered.com/search/?term=\(SearchKey)"
            isShowingSafari = true
        case .huggingface:
            safariUrlString = "https://huggingface.co/search/full-text?q=\(SearchKey)"
            isShowingSafari = true
//        default:
//            break
        }
        // [UPDATED macOS] iOS 使用 Safari 预览；macOS 用系统浏览器打开
        #if os(iOS)
        safariUrlString = urlString
        isShowingSafari = true
        #elseif os(macOS)
        if let url = URL(string: safariUrlString) {
            NSWorkspace.shared.open(url)
        }
        #endif
    }
}

enum SearchType: String, CaseIterable, Identifiable {
    case baidu, google, bing, bilibili, github, google_translate, baidu_translate, deepl_translate, steam_game, huggingface
    var id: Self { self }
}

// #Preview {
//    SearchView()
// }
