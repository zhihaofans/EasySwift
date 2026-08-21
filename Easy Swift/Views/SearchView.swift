//
//  SearchView.swift
//  Easy Swift
//
//  搜索页：统一玻璃风格，适配 macOS。
//  - iOS：Safari 预览 / App scheme 跳转
//  - macOS：系统浏览器打开网页搜索
//
//  Created by zzh on 2025/1/12.
//

import SwiftUI
import SwiftUtils
import CoreImage.CIFilterBuiltins
#if os(macOS)
import AppKit
#endif

struct SearchView: View {
    @State private var selectedType: SearchType = .github
    @State private var isShareSheetPresented = false
    @State private var SearchKey = "test"
    @State private var isShowingSafari = false
    @State private var safariUrlString: String = "https://www.apple.com"
    #if os(macOS)
    @State private var qrSheetItem: QRSheetItem?
    #endif

    var body: some View {
        VStack(spacing: 16) {
            // 搜索词输入：OS 26 玻璃材质
            TextField("搜点什么", text: $SearchKey, axis: .vertical)
                .lineLimit(2)
                .font(.title3)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                .padding(.horizontal)

            // 搜索引擎类型选择
            HStack {
                Picker(selection: $selectedType) {
                    ForEach(SearchType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                } label: {
                    Label("搜索引擎", systemImage: "globe")
                }
                #if os(iOS)
                .pickerStyle(.navigationLink) // iOS：导航行样式，明显可点
                #else
                .pickerStyle(.menu)
                #endif
                Spacer()
            }
            .padding(.horizontal)

            // 搜索按钮（玻璃）
            HStack(spacing: 16) {
                Spacer()
                Button(action: {
                    if SearchKey.isNotEmpty {
                        goSearch()
                    }
                }) {
                    Label {
                        Text("搜索")
                    } icon: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.tint)
                            .padding(5)
                            .background(Circle().fill(.white))
                    }
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                #if os(macOS)
                // macOS：显示当前搜索链接二维码，供手机扫码
                Button(action: {
                    showQRCode()
                }) {
                    Label {
                        Text("二维码")
                    } icon: {
                        Image(systemName: "qrcode")
                            .foregroundStyle(.tint)
                            .padding(5)
                            .background(Circle().fill(.white))
                    }
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                #endif
                Spacer()
            }

            Spacer()
        }
        .padding(.top, 8)
        .setNavigationTitle("搜索")
        #if os(iOS)
        .showSafariWebPreviewView(safariUrlString, isPresented: $isShowingSafari)
        #endif
        #if os(macOS)
        .sheet(item: $qrSheetItem) { item in
            QRSheetView(urlString: item.urlString)
        }
        #endif
    }

    #if os(macOS)
    // 打开二维码弹窗（二维码在 QRSheetView 内部生成，避免状态捕获旧值问题）
    private func showQRCode() {
        qrSheetItem=QRSheetItem(urlString: currentSearchURL())
    }

    // 当前搜索的网页链接（与 goSearch 一致）
    private func currentSearchURL() -> String {
        let keyword=SearchKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? SearchKey
        return selectedType.webURL(keyword: keyword)
    }
    #endif

    private func goSearch() {
        let keyword = SearchKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? SearchKey
        #if os(iOS)
        // 有 App scheme 的类型优先跳转 App，否则用 Safari 预览网页
        if let scheme = selectedType.appSchemeURL {
            AppUtil().openUrl("\(scheme)\(keyword)")
            return
        }
        safariUrlString = selectedType.webURL(keyword: keyword)
        isShowingSafari = true
        #else
        // macOS：统一用系统浏览器打开网页搜索
        if let url = URL(string: selectedType.webURL(keyword: keyword)) {
            NSWorkspace.shared.open(url)
        }
        #endif
    }
}

enum SearchType: String, CaseIterable, Identifiable {
    case baidu, google, bing, bilibili, github, google_translate, baidu_translate, deepl_translate, steam_game, huggingface, twitter, xiaohongshu, weibo, zhihu, instagram_user, douyin

    var id: Self { self }

    /// 显示名
    var displayName: String {
        switch self {
        case .github: "Github"
        case .bilibili: "哔哩哔哩"
        case .baidu: "百度"
        case .google: "Google"
        case .bing: "Bing"
        case .google_translate: "Google 翻译"
        case .baidu_translate: "百度翻译"
        case .deepl_translate: "DeepL 翻译"
        case .steam_game: "Steam游戏"
        case .huggingface: "Hugging Face"
        case .twitter: "X(推特)"
        case .xiaohongshu: "小红书🍠"
        case .weibo: "微博"
        case .zhihu: "知乎"
        case .instagram_user: "Instgram用户"
        case .douyin: "抖音"
        }
    }

    /// 网页搜索 URL（iOS Safari 预览 / macOS 浏览器共用）
    func webURL(keyword: String) -> String {
        switch self {
        case .github: "https://github.com/search?q=\(keyword)&type=repositories"
        case .bilibili: "https://search.bilibili.com/all?keyword=\(keyword)"
        case .baidu: "https://www.baidu.com/s?wd=\(keyword)"
        case .google: "https://www.google.com/search?q=\(keyword)"
        case .bing: "https://www.bing.com/search?q=\(keyword)"
        case .google_translate: "https://translate.google.com/?sl=auto&tl=zh-CN&text=\(keyword)"
        case .baidu_translate: "https://fanyi.baidu.com/#auto/zh/\(keyword)"
        case .deepl_translate: "https://www.deepl.com/zh/translator#zh/en-us/\(keyword)"
        case .steam_game: "https://store.steampowered.com/search/?term=\(keyword)"
        case .huggingface: "https://huggingface.co/search/full-text?q=\(keyword)"
        case .twitter: "https://mobile.x.com/search?q=\(keyword)"
        case .xiaohongshu: "https://www.xiaohongshu.com/search_result?keyword=\(keyword)"
        case .weibo: "https://s.weibo.com/weibo?q=\(keyword)"
        case .zhihu: "https://www.zhihu.com/search?q=\(keyword)"
        case .instagram_user: "https://www.instagram.com/\(keyword)/"
        case .douyin: "https://www.douyin.com/search/\(keyword)"
        }
    }

    /// App scheme（仅 iOS 跳转；无 scheme 的类型返回 nil）
    var appSchemeURL: String? {
        switch self {
        case .xiaohongshu: "xhsdiscover://search/result?keyword="
        case .weibo: "sinaweibo://searchall?q="
        case .zhihu: "zhihu://search?keyword="
        case .instagram_user: "instagram://user?username="
        case .douyin: "snssdk1128://search?keyword="
        default: nil
        }
    }
}

#if os(macOS)
/// 二维码弹窗的数据项（.sheet(item:) 值传递，避免状态捕获旧值）
struct QRSheetItem: Identifiable {
    let id = UUID()
    let urlString: String
}

/// 二维码展示弹窗（macOS）
private struct QRSheetView: View {
    let urlString: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("手机扫码打开")
                .font(.headline)
            if let qrImage=Self.generateQRImage(from: urlString) {
                Image(platformImage: qrImage)
                    .interpolation(.none) // 保持二维码边缘锐利
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240, height: 240)
            } else {
                Text("二维码生成失败")
                    .foregroundStyle(.secondary)
            }
            Text(urlString)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(.horizontal)
            Button("关闭") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(minWidth: 320, minHeight: 360)
    }

    // 内联二维码生成：setValue 方式，跨平台可靠
    private static func generateQRImage(from string: String) -> PlatformImage? {
        let filter=CIFilter.qrCodeGenerator()
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel") // 中纠错，容量更大
        guard let output=filter.outputImage else { return nil }
        let scale: CGFloat=5.0
        let transformed=output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context=CIContext()
        guard let cgImage=context.createCGImage(transformed, from: transformed.extent) else { return nil }
        #if os(macOS)
        return NSImage(cgImage: cgImage, size: transformed.extent.size)
        #else
        return UIImage(cgImage: cgImage)
        #endif
    }
}
#endif
