//
//  MainView.swift
//  Easy Swift
//
//  Created by zzh on 2024/11/24.
//
//  首页两种形态，由可用宽度决定（不再按"iPhone / iPad"分平台写死）：
//  - 紧凑（手机竖屏、Duo 折叠态、iPad 分屏窄栏）→ NavigationStack，点进下一页
//  - 常规（iPad 全屏、iPad 横屏、Duo 展开）→ NavigationSplitView，左侧功能列表 + 右侧内容
//

import SwiftUI
import SwiftUtils

/// 首页能进的功能（用 enum 而不是散落的 NavigationLink，双栏与单栏才能共用一份列表）
enum HomeFeature: String, CaseIterable, Identifiable, Hashable {
    case inbox
    case qrcode
    case linkParser
    case clipboard
    case uiTest
    case search
    case github
    /// 设置页在双栏里作为侧栏条目出现（右侧渲染），紧凑布局仍走工具栏齿轮
    case settings

    var id: String { rawValue }

    /// 侧栏主列表（设置单独成组，不混在里面）
    static var mainFeatures: [HomeFeature] {
        allCases.filter { $0 != .settings }
    }

    var title: String {
        switch self {
        case .inbox: return "收件箱"
        case .qrcode: return "二维码"
        case .linkParser: return "链接解析"
        case .clipboard: return "剪贴板"
        case .uiTest: return "Swift UI测试"
        case .search: return "搜索"
        case .github: return "Github"
        case .settings: return "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .inbox: return "tray"
        case .qrcode: return "qrcode"
        case .linkParser: return "link"
        case .clipboard: return "doc.on.clipboard"
        case .uiTest: return "swift"
        case .search: return "magnifyingglass"
        case .github: return "cat"
        case .settings: return "gear"
        }
    }
}

struct MainView: View {
    /// 收件箱角标：未处理条数
    @ObservedObject private var inbox=InboxStore.shared
    /// 双栏时的选中项；默认落在收件箱，避免打开是空白占位（紧凑布局忽略它）
    @State private var selectedFeature: HomeFeature? = .inbox
    /// 紧凑布局时跟着导航栈进出
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// 表单类页面在大屏上不要横跨整屏（一行太长读起来累），限宽居中
    private let formMaxWidth: CGFloat=700

    private var isWide: Bool {
        #if os(iOS)
        return sizeClass == .regular
        #else
        return true
        #endif
    }

    var body: some View {
        #if os(iOS)
        Group {
            if isWide {
                wideLayout
            } else {
                compactLayout
            }
        }
        #else
        wideLayout
        #endif
    }

    // MARK: - 紧凑：单栏导航栈

    #if os(iOS)
    private var compactLayout: some View {
        NavigationStack {
            List {
                ForEach(HomeFeature.mainFeatures) { feature in
                    NavigationLink(value: feature) {
                        Label(feature.title, systemImage: feature.systemImage)
                    }
                    .badge(feature == .inbox ? inbox.unhandledCount : 0)
                }
            }
            .navigationTitle(AppUtil().getAppName())
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: HomeFeature.self) { feature in
                destination(feature)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingView()) {
                        Image(systemName: "gear")
                    }
                }
            }
        }
    }
    #endif

    // MARK: - 常规：侧栏 + 内容

    private var wideLayout: some View {
        NavigationSplitView {
            List(selection: $selectedFeature) {
                ForEach(HomeFeature.mainFeatures) { feature in
                    Label(feature.title, systemImage: feature.systemImage)
                        .badge(feature == .inbox ? inbox.unhandledCount : 0)
                        .tag(feature)
                }
                Section {
                    Label(HomeFeature.settings.title, systemImage: HomeFeature.settings.systemImage)
                        .tag(HomeFeature.settings)
                }
            }
            .navigationTitle(AppUtil().getAppName())
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            if let feature=selectedFeature {
                destination(feature)
            } else {
                ContentUnavailableView("选择一个功能", systemImage: "sidebar.left")
            }
        }
    }

    // MARK: - 内容页

    @ViewBuilder
    private func destination(_ feature: HomeFeature) -> some View {
        switch feature {
        case .inbox:
            InboxView()
        case .qrcode:
            QrcodeView()
                .centeredForm(maxWidth: formMaxWidth)
        case .linkParser:
            LinkParserView()
                .centeredForm(maxWidth: formMaxWidth)
        case .search:
            SearchView()
                .centeredForm(maxWidth: formMaxWidth)
        case .clipboard:
            ClipboardView()
        case .uiTest:
            UITestView()
        case .github:
            GithubMainView()
        case .settings:
            SettingView()
        }
    }
}

private extension View {
    /// 大屏上把表单类页面限宽并居中；窄屏时 maxWidth 大于屏宽，等于没效果
    func centeredForm(maxWidth: CGFloat) -> some View {
        frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

#Preview {
    MainView()
}
