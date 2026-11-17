//
//  UITestGalleries.swift
//  Easy Swift
//
//  「SwiftUI 组件」样例集的各分类 gallery。
//  每张卡片都写清"解决什么问题 / 平台差异"，样例本身可交互 —— 目的是当参考手册用。
//

import SwiftUI
import SwiftUtils
import UniformTypeIdentifiers

// MARK: - 布局与容器

struct LayoutGallery: View {
    @State private var fitsWidth: Double=360

    private let adaptiveItems=Array(0..<12)

    var body: some View {
        GalleryScaffold {
            DemoCard("Grid",
                     note: "固定行列用 `Grid`：行内可以 `gridCellColumns(2)` 跨列，适合表单/参数表这种规整布局。") {
                Grid(horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow {
                        Text("名称").foregroundStyle(.secondary)
                        Text("Easy Swift")
                    }
                    Divider().gridCellColumns(2)
                    GridRow {
                        Text("版本").foregroundStyle(.secondary)
                        Text(AppUtil().getAppVersion())
                    }
                    GridRow {
                        Label("跨两列", systemImage: "arrow.left.and.right")
                            .gridCellColumns(2)
                    }
                }
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            DemoCard("LazyVGrid（自适应列）",
                     note: "`.adaptive(minimum:)` 让列数随宽度变：手机 3 列、iPad 6 列以上，不用自己算。") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 8)], spacing: 8) {
                    ForEach(adaptiveItems, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.15 + Double(index % 5) * 0.15))
                            .frame(height: 44)
                            .overlay(Text("\(index + 1)").font(.caption))
                    }
                }
            }

            DemoCard("LazyHGrid（横向固定行）",
                     note: "横向滚动 + 固定 2 行；适合「最近使用」这种横向条。") {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: [GridItem(.fixed(60)), GridItem(.fixed(60))], spacing: 8) {
                        ForEach(0..<16, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 84)
                                .overlay(Text("项 \(index + 1)").font(.caption2))
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            DemoCard("ViewThatFits",
                     note: "宽度不够时自动换成备选布局，不用写 `horizontalSizeClass` 判断。拖动滑块看它切换。") {
                VStack(alignment: .leading, spacing: 8) {
                    Slider(value: $fitsWidth, in: 160...390)
                    Text("容器宽度：\(Int(fitsWidth))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            Text("一段比较长的说明文字，横向排布")
                            Spacer()
                            Button("操作") {}
                                .buttonStyle(.glassProminent)
                        }
                        VStack(alignment: .leading) {
                            Text("一段比较长的说明文字，纵向排布")
                            Button("操作") {}
                                .buttonStyle(.glassProminent)
                        }
                    }
                    .frame(width: fitsWidth, alignment: .leading)
                    .padding(10)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                }
            }

            DemoCard("containerRelativeFrame",
                     note: "按容器宽度的比例定尺寸（这里 0.8），比自己乘 GeometryReader 更省事。") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.accentColor.opacity(0.2))
                                .frame(height: 90)
                                .containerRelativeFrame(.horizontal) { length, _ in
                                    length * 0.8
                                }
                                .overlay(Text("第 \(index + 1) 页（80% 宽）").font(.caption))
                        }
                    }
                }
            }

            DemoCard("safeAreaInset",
                     note: "给滚动内容加固定底栏/顶栏，内容自动避开，不用手算 padding。") {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(0..<12, id: \.self) { index in
                            Text("第 \(index + 1) 行内容")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .frame(height: 140)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
                .safeAreaInset(edge: .bottom) {
                    HStack {
                        Text("固定在底部的操作条")
                            .font(.caption)
                        Spacer()
                        Button("确定") {}
                            .buttonStyle(.glassProminent)
                            .controlSize(.small)
                    }
                    .padding(8)
                    .background(.thinMaterial)
                }
            }
        }
        .setNavigationTitle("布局与容器")
    }
}

// MARK: - 列表与搜索

struct ListSearchGallery: View {
    struct Item: Identifiable, Hashable {
        let id=UUID()
        let title: String
    }

    /// macOS 没有 grouped / insetGrouped（编译不过），所以跨平台只列三档，
    /// macOS 的 insetGrouped 映射到 `.inset`
    private enum Style: String, CaseIterable, Identifiable {
        case insetGrouped="分组"
        case plain="朴素"
        case sidebar="侧栏"
        var id: String { rawValue }
    }

    @State private var items: [Item]=(0..<20).map { Item(title: "条目 \($0 + 1)") }
    @State private var query=""
    @State private var style: Style = .insetGrouped
    @State private var scrolledID: UUID?
    @State private var refreshCount=0

    private var filtered: [Item] {
        let keyword=query.trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty else { return items }
        return items.filter { $0.title.localizedCaseInsensitiveContains(keyword) }
    }

    /// List 的样式修饰器返回不同类型，不能用三元拼，改成 switch 分支
    @ViewBuilder
    private var styledList: some View {
        switch style {
        case .plain:
            rowList.listStyle(.plain)
        case .insetGrouped:
            #if os(macOS)
            rowList.listStyle(.inset)
            #else
            rowList.listStyle(.insetGrouped)
            #endif
        case .sidebar:
            rowList.listStyle(.sidebar)
        }
    }

    private var rowList: some View {
        List(filtered) { item in
            Text(item.title)
                .id(item.id)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        items.removeAll { $0.id == item.id }
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        refreshCount += 1
                    } label: {
                        Label("计数", systemImage: "plus")
                    }
                    .tint(.blue)
                }
        }
        .searchable(text: $query, prompt: "搜索条目（看 searchable）")
        .refreshable {
            try? await Task.sleep(for: .milliseconds(600))
            refreshCount += 1
            items.shuffle()
        }
        .scrollPosition(id: $scrolledID)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("列表样式", selection: $style) {
                ForEach(Style.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top], 12)

            HStack {
                Button("跳到第 10 项") {
                    scrolledID=items[9].id
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                Text("刷新次数 \(refreshCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            styledList
        }
        .setNavigationTitle("列表与搜索")
    }
}

// MARK: - 弹层

struct PresentationGallery: View {
    @State private var sheetDetent=false
    @State private var sheetLarge=false
    @State private var fullScreen=false
    @State private var popover=false
    @State private var dialog=false
    @State private var lastAction="（还没选）"

    var body: some View {
        GalleryScaffold {
            DemoCard("sheet + presentationDetents",
                     note: "底部面板可指定高度档位；`.medium` 适合「选一项」这类轻交互。") {
                HStack(spacing: 10) {
                    Button("半屏") { sheetDetent=true }
                        .buttonStyle(.glassProminent)
                    Button("大屏") { sheetLarge=true }
                        .buttonStyle(.glass)
                }
            }

            DemoCard("fullScreenCover",
                     note: "全屏覆盖：适合沉浸内容（预览、编辑器）。注意它没有系统返回手势，要自己给关闭入口。") {
                Button("全屏覆盖") { fullScreen=true }
                    .buttonStyle(.glass)
            }

            DemoCard("popover",
                     note: "iPad/macOS 上是气泡，iPhone 上会退化成 sheet —— 同一份代码两种呈现，别假设一定是气泡。") {
                Button("弹出 popover") { popover=true }
                    .buttonStyle(.glass)
                    .popover(isPresented: $popover) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Popover 内容").font(.headline)
                            Text("手机上会变成 sheet").font(.caption).foregroundStyle(.secondary)
                        }
                        .padding()
                    }
            }

            DemoCard("confirmationDialog",
                     note: "破坏性操作确认用它（而不是 alert）：会带上系统的取消项，样式也更明确。") {
                VStack(alignment: .leading, spacing: 8) {
                    Button("删除全部", role: .destructive) { dialog=true }
                    Text("上次选择：\(lastAction)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .setNavigationTitle("弹层")
        .sheet(isPresented: $sheetDetent) {
            DetentDemoSheet(title: "半屏面板（medium）")
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $sheetLarge) {
            DetentDemoSheet(title: "可拖到大屏（medium + large）")
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $fullScreen) {
            FullScreenDemo { fullScreen=false }
        }
        #else
        // macOS 没有 fullScreenCover，用 sheet 等价演示（说明里写清差异）
        .sheet(isPresented: $fullScreen) {
            FullScreenDemo { fullScreen=false }
                .frame(minWidth: 480, minHeight: 320)
        }
        #endif
        .confirmationDialog("确认删除全部？", isPresented: $dialog, titleVisibility: .visible) {
            Button("删除", role: .destructive) { lastAction="删除" }
            Button("取消", role: .cancel) { lastAction="取消" }
        } message: {
            Text("这个操作不可撤销")
        }
    }
}

private struct DetentDemoSheet: View {
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // sheet 里必须自带 NavigationStack，否则标题/工具栏不渲染（AGENTS §3.6）
        NavigationStack {
            VStack(spacing: 16) {
                Text(title).font(.headline)
                Text("拖动顶部把手可以换档位").font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .setNavigationTitle("面板")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

private struct FullScreenDemo: View {
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "rectangle.expand.vertical").font(.largeTitle)
                Text("全屏内容").font(.headline)
                Text("没有系统返回手势，必须自己提供关闭入口").font(.caption).foregroundStyle(.secondary)
            }
            .padding()
            .setNavigationTitle("全屏")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { onClose() }
                }
            }
        }
    }
}

// MARK: - 文件与拖放

/// fileExporter 需要一个 FileDocument
struct PlainTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    var text: String

    init(text: String = "") {
        self.text=text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data=configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text=String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

struct FileDropGallery: View {
    @State private var importing=false
    @State private var exporting=false
    @State private var pickedInfo="（还没选文件）"
    @State private var pickedPreview=""
    @State private var droppedItems: [String]=[]
    @State private var isTargeted=false

    private var exportDocument: PlainTextDocument {
        PlainTextDocument(text: "Easy Swift 导出示例\n时间：\(Date())\n版本：\(AppUtil().getAppVersion())\n")
    }

    var body: some View {
        GalleryScaffold {
            DemoCard("fileImporter",
                     note: "选文件只需允许的类型；拿到的是安全作用域 URL，读取期间要 `startAccessingSecurityScopedResource`（这里用 `String(contentsOf:)` 系统会处理常见情况）。") {
                VStack(alignment: .leading, spacing: 8) {
                    Button("选择文本文件") { importing=true }
                        .buttonStyle(.glassProminent)
                    Text(pickedInfo).font(.caption).foregroundStyle(.secondary)
                    if !pickedPreview.isEmpty {
                        Text(pickedPreview)
                            .font(.caption2)
                            .lineLimit(3)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            DemoCard("fileExporter",
                     note: "导出用 `FileDocument` + `.fileExporter`，系统给保存位置与命名，不用自己拼沙盒路径。") {
                Button("导出示例 txt") { exporting=true }
                    .buttonStyle(.glass)
            }

            DemoCard("draggable + dropDestination",
                     note: "拖放用系统 Transferable：这里传 `String`。拖到下方方框里试试（同一台设备内拖动）。") {
                VStack(spacing: 10) {
                    Text("拖我")
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.quaternary, in: Capsule())
                        .draggable("来自 Easy Swift 的字符串")

                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isTargeted ? Color.accentColor : Color.gray.opacity(0.4),
                                      style: StrokeStyle(lineWidth: 1, dash: [6]))
                        .frame(height: 90)
                        .overlay {
                            VStack(spacing: 4) {
                                Text(isTargeted ? "松手放下" : "拖到这里")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("已接收：\(droppedItems.count) 项")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .dropDestination(for: String.self) { items, _ in
                            droppedItems.append(contentsOf: items)
                            return !items.isEmpty
                        } isTargeted: { targeted in
                            isTargeted=targeted
                        }
                }
            }
        }
        .setNavigationTitle("文件与拖放")
        .fileImporter(isPresented: $importing,
                      allowedContentTypes: [.plainText, .json],
                      allowsMultipleSelection: false) { result in
            switch result {
            case let .success(urls):
                guard let url=urls.first else { return }
                let accessing=url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                let name=url.lastPathComponent
                let size=(try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                pickedInfo="已选：\(name)（\(size) 字节）"
                pickedPreview=(try? String(contentsOf: url, encoding: .utf8)).map { String($0.prefix(200)) } ?? ""
            case let .failure(error):
                pickedInfo="选择失败：\(error.localizedDescription)"
            }
        }
        .fileExporter(isPresented: $exporting,
                      document: exportDocument,
                      contentType: .plainText,
                      defaultFilename: "easyswift-demo") { result in
            switch result {
            case .success: pickedInfo="已导出（保存位置由系统决定）"
            case let .failure(error): pickedInfo="导出失败：\(error.localizedDescription)"
            }
        }
    }
}

// MARK: - 交互与反馈

struct FeedbackGallery: View {
    @State private var counter=0
    @State private var bounce=false
    @State private var lastMenuAction="（还没选）"

    var body: some View {
        GalleryScaffold {
            DemoCard("contextMenu",
                     note: "长按/右键菜单：同一行的次要操作放这里，别把列表行塞满按钮。") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("长按这张卡片试试")
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                        .contextMenu {
                            Button {
                                lastMenuAction="复制"
                            } label: {
                                Label("复制", systemImage: "doc.on.doc")
                            }
                            Button {
                                lastMenuAction="收藏"
                            } label: {
                                Label("收藏", systemImage: "star")
                            }
                            Divider()
                            Button(role: .destructive) {
                                lastMenuAction="删除"
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    Text("上次选择：\(lastMenuAction)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            DemoCard("sensoryFeedback",
                     note: "触觉反馈由系统按设备能力决定（iPad 无 Taptic 时静默不反馈）。点按钮感受一下。") {
                Button("点赞（成功反馈）") { counter += 1 }
                    .buttonStyle(.glassProminent)
                    .sensoryFeedback(.success, trigger: counter)
                Text("次数：\(counter)").font(.caption).foregroundStyle(.secondary)
            }

            DemoCard("symbolEffect",
                     note: "SF Symbol 的动效：`.bounce` 用于强调、`.pulse` 用于持续提示。") {
                Image(systemName: "bell.badge")
                    .font(.largeTitle)
                    .symbolEffect(.bounce, value: bounce)
                    .onTapGesture { bounce.toggle() }
                Text("点图标让它跳一下").font(.caption).foregroundStyle(.secondary)
            }

            DemoCard("contentTransition",
                     note: "数字变化用 `.numericText()` 才有滚动效果；写死成 `.opacity` 会显得廉价。") {
                HStack(spacing: 12) {
                    Text("\(counter)")
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .contentTransition(.numericText())
                        .animation(.snappy, value: counter)
                    Button("+1") { counter += 1 }
                        .buttonStyle(.glass)
                }
            }
        }
        .setNavigationTitle("交互与反馈")
    }
}

// MARK: - 文本与隐私

struct TextPrivacyGallery: View {
    @State private var redacted=false
    @State private var typeSize: DynamicTypeSize = .large

    private static let typeSizes: [DynamicTypeSize] = [.small, .large, .xxLarge, .accessibility3]

    private static func typeSizeName(_ size: DynamicTypeSize) -> String {
        switch size {
        case .small: return "小"
        case .large: return "默认"
        case .xxLarge: return "超大"
        case .accessibility3: return "无障碍 3"
        default: return "其他"
        }
    }
    private let sampleText="这段文字可以长按选择、复制。`.textSelection(.enabled)` 只影响选择能力，不影响布局；用户能选中，说明也就能复制，别在敏感文本上开它。"

    var body: some View {
        GalleryScaffold {
            DemoCard("textSelection",
                     note: "让静态文本可选中复制。日志、错误信息这类要给用户复制能力的文本才开。") {
                Text(sampleText)
                    .font(.callout)
                    .textSelection(.enabled)
            }

            DemoCard("privacySensitive",
                     note: "标记为敏感内容：锁屏、截图、录屏等系统场景会进行遮蔽。它不改变界面里的正常显示，所以测试时要真的锁屏看。") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("模拟的敏感信息（正常显示）")
                    Text("web_session=04xxxx（示例）")
                        .font(.system(.caption, design: .monospaced))
                        .privacySensitive()
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            DemoCard("redacted",
                     note: "加载中占位：`.placeholder` 把内容画成灰条，尺寸保持稳定，避免骨架屏跳动。") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("占位状态", isOn: $redacted)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("标题：一条解析结果的标题")
                            .font(.headline)
                        Text("副标题：作者 · 8 图 · 2 动图")
                            .font(.caption)
                    }
                    .redacted(reason: redacted ? .placeholder : [])
                }
            }

            DemoCard("Dynamic Type",
                     note: "用 `.dynamicTypeSize` 限定范围可防止极端字号把布局撑坏；`Text` 默认跟随系统字号。") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("字号", selection: $typeSize) {
                        ForEach(Self.typeSizes, id: \.self) { size in
                            Text(Self.typeSizeName(size)).tag(size)
                        }
                    }
                    .pickerStyle(.menu)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("大标题标题").font(.title2)
                        Text("正文：这一段用来观察换行与截断行为").font(.body)
                        Text("说明：小字").font(.caption)
                    }
                    .dynamicTypeSize(typeSize)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .setNavigationTitle("文本与隐私")
    }
}

// MARK: - Table

struct TableGallery: View {
    struct Row: Identifiable {
        let id=UUID()
        let name: String
        let kind: String
        let size: Int
    }

    @State private var sortOrder=[KeyPathComparator(\Row.size, order: .reverse)]
    @State private var selection: Row.ID?

    private var rows: [Row] {
        let rows=[
            Row(name: "报告.pdf", kind: "PDF", size: 2_400_000),
            Row(name: "截图.png", kind: "图片", size: 480_000),
            Row(name: "笔记.txt", kind: "文本", size: 12_000),
            Row(name: "日志.log", kind: "文本", size: 96_000),
            Row(name: "备份.zip", kind: "压缩包", size: 8_800_000),
        ]
        return rows.sorted(using: sortOrder)
    }

    var body: some View {
        VStack(spacing: 8) {
            Table(rows, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("名称", value: \.name)
                TableColumn("类型", value: \.kind)
                TableColumn("大小") { row in
                    Text(ByteCountFormatter.string(fromByteCount: Int64(row.size), countStyle: .file))
                }
                .width(100)
            }
            .tableStyle(.inset)
        }
        .padding(.top, 8)
        .setNavigationTitle("表格 Table")
    }
}
