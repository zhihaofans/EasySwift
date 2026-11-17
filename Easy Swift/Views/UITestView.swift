//
//  UITestView.swift
//  Easy Swift
//
//  原生 SwiftUI 组件样例集（活的参考手册）：
//  写完新页面想确认"系统本来就长什么样"时，先来这里对照，不要在业务页里试。
//
//  结构：索引页（可搜索）→ 每类一个 gallery。样例都做成**可交互**的，
//  并写清"这个 API 解决什么问题 / 有什么平台差异"，不然只是好看的空壳。
//
//  Created by zzh on 2025/1/3.
//

import SwiftUI
import SwiftUtils

// MARK: - 索引

struct UITestView: View {
    @State private var query=""

    private var groups: [GalleryGroup] {
        let keyword=query.trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty else { return GalleryGroup.allCases }
        return GalleryGroup.allCases.filter {
            $0.title.localizedCaseInsensitiveContains(keyword)
                || $0.summary.localizedCaseInsensitiveContains(keyword)
                || $0.keywords.contains { $0.localizedCaseInsensitiveContains(keyword) }
        }
    }

    var body: some View {
        if let direct=Self.debugDirectGallery {
            direct.destination
        } else {
            indexList
        }
    }

    /// DEBUG：`-openUITest layout` 这类参数直接渲染某一类，跳过索引（截图/手测用）
    private static var debugDirectGallery: GalleryGroup? {
        #if DEBUG
        let args=ProcessInfo.processInfo.arguments
        guard let index=args.firstIndex(of: "-openUITest"), args.count > index + 1 else { return nil }
        let key=args[index + 1].lowercased()
        return GalleryGroup.allCases.first { $0.rawValue.lowercased() == key }
        #else
        return nil
        #endif
    }

    private var indexList: some View {
        List {
            Section {
                ForEach(groups) { group in
                    NavigationLink {
                        group.destination
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: group.systemImage)
                                .frame(width: 26)
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.title)
                                Text(group.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } footer: {
                Text("共 \(GalleryGroup.allCases.count) 类样例。跨平台页面的差异都写在每张卡片的说明里。")
            }
        }
        .searchable(text: $query, prompt: "搜索组件（如 grid / sheet / table）")
        .setNavigationTitle("SwiftUI 组件")
    }
}

// MARK: - 分组

enum GalleryGroup: String, CaseIterable, Identifiable {
    case basic
    case layout
    case listSearch
    case presentation
    case fileDrop
    case feedback
    case textPrivacy
    case table

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basic: return "基础控件"
        case .layout: return "布局与容器"
        case .listSearch: return "列表与搜索"
        case .presentation: return "弹层"
        case .fileDrop: return "文件与拖放"
        case .feedback: return "交互与反馈"
        case .textPrivacy: return "文本与隐私"
        case .table: return "表格 Table"
        }
    }

    var summary: String {
        switch self {
        case .basic: return "按钮 / 开关 / 滑块 / 输入框 / 日期 / 颜色 / 进度"
        case .layout: return "Grid、LazyVGrid、ViewThatFits、containerRelativeFrame、safeAreaInset"
        case .listSearch: return "searchable、listStyle、swipeActions、refreshable、scrollPosition"
        case .presentation: return "sheet+detents、fullScreenCover、popover、confirmationDialog"
        case .fileDrop: return "fileImporter、fileExporter、draggable + dropDestination"
        case .feedback: return "contextMenu、sensoryFeedback、symbolEffect、contentTransition"
        case .textPrivacy: return "textSelection、privacySensitive、redacted、Dynamic Type"
        case .table: return "可排序 Table（iPad / macOS 更合适）"
        }
    }

    var keywords: [String] {
        switch self {
        case .basic: return ["button", "toggle", "slider", "stepper", "picker", "textfield", "datepicker", "colorpicker", "progress"]
        case .layout: return ["grid", "lazyvgrid", "lazyhgrid", "viewthatfits", "containerrelativeframe", "safeareainset"]
        case .listSearch: return ["list", "searchable", "swipeactions", "refreshable", "scrollposition", "liststyle"]
        case .presentation: return ["sheet", "detents", "fullscreencover", "popover", "confirmations", "dialog"]
        case .fileDrop: return ["fileimporter", "fileexporter", "draggable", "dropdestination", "filedocument"]
        case .feedback: return ["contextmenu", "sensoryfeedback", "symboleffect", "contenttransition"]
        case .textPrivacy: return ["textselection", "privacysensitive", "redacted", "dynamictype"]
        case .table: return ["table", "sort", "column"]
        }
    }

    var systemImage: String {
        switch self {
        case .basic: return "square.grid.2x2"
        case .layout: return "rectangle.split.3x3"
        case .listSearch: return "list.bullet.rectangle"
        case .presentation: return "rectangle.on.rectangle"
        case .fileDrop: return "folder.badge.plus"
        case .feedback: return "hand.tap"
        case .textPrivacy: return "textformat"
        case .table: return "tablecells"
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .basic: BasicControlsGallery()
        case .layout: LayoutGallery()
        case .listSearch: ListSearchGallery()
        case .presentation: PresentationGallery()
        case .fileDrop: FileDropGallery()
        case .feedback: FeedbackGallery()
        case .textPrivacy: TextPrivacyGallery()
        case .table: TableGallery()
        }
    }
}

// MARK: - 共用骨架

/// 一张玻璃卡片：标题 + 一句说明 + 可交互内容
struct DemoCard<Content: View>: View {
    private let title: String
    private let note: String?
    private let content: Content

    init(_ title: String, note: String? = nil, @ViewBuilder content: () -> Content) {
        self.title=title
        self.note=note
        self.content=content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            if let note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .padding(.horizontal)
    }
}

/// gallery 通用外壳：纵向滚动的卡片列
struct GalleryScaffold<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content=content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - 基础控件

struct BasicControlsGallery: View {
    @State private var toggleOn=false
    @State private var sliderValue=0.5
    @State private var stepperValue=0
    @State private var color=Color.blue
    @State private var date=Date()
    @State private var text=""
    @State private var pickerValue=0
    @State private var progressValue=0.6
    @State private var showAlert=false

    private let pickerOptions=["选项一", "选项二", "选项三"]

    var body: some View {
        GalleryScaffold {
            DemoCard("按钮 Button", note: "`.glassProminent` 是本项目的统一主按钮样式；破坏性操作必须带 role。") {
                HStack(spacing: 12) {
                    Button("默认") {}
                    Button("玻璃") {}
                        .buttonStyle(.glassProminent)
                    Button(role: .destructive) {} label: {
                        Label("删除", systemImage: "trash")
                    }
                    Button {
                        showAlert=true
                    } label: {
                        Label("弹窗", systemImage: "bell")
                    }
                }
            }

            DemoCard("开关 Toggle") {
                Toggle("启用功能", isOn: $toggleOn)
            }

            DemoCard("滑块 Slider") {
                Slider(value: $sliderValue)
                Text("当前值：\(Int(sliderValue * 100))")
                    .foregroundStyle(.secondary)
            }

            DemoCard("步进器 Stepper") {
                Stepper("数量：\(stepperValue)", value: $stepperValue, in: 0...10)
            }

            DemoCard("分段选择 Picker") {
                Picker("选项", selection: $pickerValue) {
                    ForEach(0..<pickerOptions.count, id: \.self) { i in
                        Text(pickerOptions[i]).tag(i)
                    }
                }
                .pickerStyle(.segmented)
            }

            DemoCard("输入框 TextField") {
                TextField("请输入内容", text: $text)
                    .textFieldStyle(.roundedBorder)
            }

            DemoCard("日期选择 DatePicker") {
                DatePicker("选择日期", selection: $date, displayedComponents: [.date])
            }

            DemoCard("颜色选择 ColorPicker") {
                ColorPicker("选择颜色", selection: $color)
            }

            DemoCard("进度 ProgressView") {
                VStack(spacing: 12) {
                    ProgressView(value: progressValue)
                        .progressViewStyle(.linear)
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }

            DemoCard("链接 Link", note: "系统链接用 `Link`，走默认浏览器；不要自己拼按钮再调 openURL。") {
                Link(destination: URL(string: "https://www.apple.com")!) {
                    Label("访问 Apple 官网", systemImage: "safari")
                }
            }

            DemoCard("图标 Image") {
                HStack(spacing: 16) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.orange)
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(.green)
                    Image(systemName: "drop.fill")
                        .foregroundStyle(.blue)
                }
                .font(.title2)
            }

            DemoCard("标签 Label") {
                Label("这是一个标签", systemImage: "tag")
                Label("带副标题", systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .setNavigationTitle("基础控件")
        .alert("提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("这是一个系统弹窗示例")
        }
    }
}

#Preview {
    NavigationStack {
        UITestView()
    }
}
