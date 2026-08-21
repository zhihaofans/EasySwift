//
//  ClipboartView.swift
//  Easy Swift
//
//  Created by zzh on 2024/12/15.
//

import SwiftData
import SwiftUI
import SwiftUtils
#if os(macOS) // 仅 macOS 需要 AppKit（剪贴板 & 分享）
import AppKit
#endif
struct ClipboardView: View {
    var body: some View {
        ClipboardContentView()
            .modelContainer(for: [ClipItemDataModel.self])
    }
}

struct ClipboardContentView: View {
    @State private var showingAlert=false
    @State private var showingMenu=false
    @State private var userInput=""
    @State private var showInputPopup=false
    @State private var alertTitle: String="未知错误"
    @State private var alertText: String="未知错误"
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClipItemDataModel.create_time, order: .reverse) private var clips: [ClipItemDataModel]
    @State private var clipList=[ClipItemDataModel]()
    @State private var clipContentList=[String]()
    var body: some View {
        VStack {
            // 下面是新代码SwiftData
            // 显示所有任务
            if clips.isEmpty {
                // 空状态：玻璃按钮，居中
                HStack {
                    Spacer()
                    Button(action: {
                        showingMenu=true
                    }) {
                        Label {
                            Text("随便记一下")
                        } icon: {
                            Image(systemName: "square.and.pencil")
                                .foregroundStyle(.tint)
                                .padding(5)
                                .background(Circle().fill(.white))
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    Spacer()
                }
            } else {
                List(clips) { item in
                    ClipItemView(path: clipList, item: item)
                        .swipeActions {}
                }.onChange(of: clips) { _, _ in
                    // 调试日志：打印系统剪贴板（走 SwiftUtils）
                    debugPrint("当前剪贴板内容：\(ClipboardUtil().getString())")
                    debugPrint("当前 clipList 数据：\(clipList)")
                    clipContentList=clips.map { $0.text }
                }
            }
        }
        .showTextAlert(alertTitle, alertText, isPresented: $showingAlert) {
            self.alertTitle=""
            self.alertText=""
            self.showingAlert=false
        }
        .setNavigationTitle("剪贴板")
        .alert("新增剪贴板", isPresented: $showingMenu) {
            Button("输入", action: {
                showInputPopup=true
            })
            Button("剪贴板", action: {
                addFromClip()
            })
            Button("Bye", action: {})
        } message: {
            Text("输入还是从系统剪贴板导入")
        }
        .inputAlert("新增剪贴板",
                    placeholder: "请输入内容",
                    text: $userInput,
                    isPresented: $showInputPopup)
        { text in
            addNewItem(text)
        }
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingMenu=true }) { Image(systemName: "plus") }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // TODO: 剪切板设置（iOS）
                }) { Image(systemName: "gear") }
            }
            #else
            ToolbarItem(placement: .automatic) {
                Button(action: { showingMenu=true }) { Image(systemName: "plus") }
            }
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    // TODO: 剪切板设置（macOS）
                }) { Image(systemName: "gear") }
            }
            #endif
        }.onAppear {
            debugPrint("onAppear")
            manualFetchTasks()
        }
    }

    // 手动查询所有任务
    private func manualFetchTasks() {
        // 使用 modelContext.fetch() 手动查询 Task 实体
        let fetchRequest=FetchDescriptor<ClipItemDataModel>(sortBy: [SortDescriptor(\.create_time)])

        do {
            let clips=try modelContext.fetch(fetchRequest)
            debugPrint("Fetched Clips: " + clips.length.toString)
            clipContentList=clips.map { $0.text }
            debugPrint("clipContentList: " + clipContentList.length.toString)

        } catch {
            debugPrint("Failed to fetch clips: \(error)")
        }
    }

    private func addNewItem(_ text: String) {
        // 1. 确保新任务的标题不是空的
        guard !text.isEmpty else { return }
        if clipContentList.contains(text) {
            debugPrint("剪贴板已存在该内容")
            return
        }
        // 2. 创建一个新的 Task 对象，使用当前输入的任务标题
//        let newTask = NoteItemDataModel(text: noteItem.text)
//        noteItem.image = image?.heicData()
        let createTime=DateUtil().getTimestamp()
        let clipItem=ClipItemDataModel(id: UUID(), text: text, create_time: createTime, update_time: createTime)
//        debugPrint(clipItem)
        // 3. 使用 modelContext 将新任务插入到数据模型中
        modelContext.insert(clipItem)
        clipList=[clipItem]
//        isNew = false
        // 4. 保存当前上下文的更改，将新任务持久化到存储中
//        try? modelContext.save()
        do {
            try modelContext.save()
        } catch {
            debugPrint("Failed to save context: \(error)")
        }
//        debugPrint(modelContext)
        // 5. 清空输入框，准备输入下一个任务 。这里忽略
//        newTitle = ""
    }

    private func addFromClip() {
        let content=ClipboardUtil().getString()
        if content.isNotEmpty {
            addNewItem(content)
        } else {
            debugPrint("剪贴板内容为空或无法转换为字符串")
        }
    }
}

private struct ClipItemView: View {
    private let item: ClipItemDataModel
    @State private var path=[ClipItemDataModel]()
    @Environment(\.modelContext) private var modelContext
    init(path: [ClipItemDataModel], item: ClipItemDataModel) {
        self.path=path
        self.item=item
    }

    var body: some View {
//        NavigationLink(destination: EditView(path: path, editNoteItem: item)) {

        NavigationLink(destination: ClipboardEditorView(path: path, item: item)) {
            DoubleTextItemView(item.text)
        }.swipeActions(allowsFullSwipe: false) {
            // 滑动菜单中的操作按钮
            Button(role: .destructive) {
                deleteItem()
//                isShowRemoveAlert=true
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
//        }
    }

    private func deleteItem() {
        do {
            modelContext.delete(item)
            path=[item]
            try modelContext.save()
            debugPrint("success to delete context")
        } catch {
            debugPrint("Failed to delete context: \(error)")
        }
        debugPrint(modelContext)
    }
}

// MARK: - 编辑页（系统自带样式）

private struct ClipboardEditorView: View {
    private let item: ClipItemDataModel
    @State private var path=[ClipItemDataModel]()
    @State private var clipContent: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    init(path: [ClipItemDataModel], item: ClipItemDataModel?=nil) {
        let nowTime=DateUtil().getTimestamp()
        self.path=path
        self.item=item ?? ClipItemDataModel(
            id: UUID(),
            text: "",
            create_time: nowTime,
            update_time: nowTime
        )
        _clipContent=State(initialValue: self.item.text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 内容编辑：OS 26 玻璃材质
            TextEditor(text: $clipContent)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(maxWidth: .infinity, minHeight: 200)
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
                .padding(.horizontal)

            // 统计：字数 / 行数
            HStack(spacing: 24) {
                LabeledContent("字数", value: "\(clipContent.count)")
                LabeledContent("行数", value: "\(clipContent.split(whereSeparator: \.isNewline).count)")
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 8)
        .setNavigationTitle("编辑")
        .toolbar {
            #if os(iOS)
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // 系统分享
                ShareLink(item: clipContent) {
                    Label("分享", systemImage: "square.and.arrow.up")
                }
                // 粘贴（PasteButton 无自定义 label，改用按钮实现，统一风格）
                Button {
                    pasteFromClipboard()
                } label: {
                    Label("粘贴", systemImage: "doc.on.clipboard")
                }
          
            }
            #else
            ToolbarItemGroup(placement: .automatic) {
                ShareLink(item: clipContent) {
                    Label("分享", systemImage: "square.and.arrow.up")
                        .labelStyle(.titleAndIcon)
                }
                Button {
                    pasteFromClipboard()
                } label: {
                    Label("粘贴", systemImage: "doc.on.clipboard")
                        .labelStyle(.titleAndIcon)
                }
                Button {
                    copyToClipboard()
                } label: {
                    Label("复制", systemImage: "doc.on.doc")
                        .labelStyle(.titleAndIcon)
                }
            }
            #endif

            ToolbarItem(placement: .cancellationAction) {
                Button("完成") {
                    saveText()
                    dismiss()
                }
                .buttonStyle(.glassProminent)
            }
        }
        .onDisappear { saveText() }
    }

    // MARK: 保存文本

    private func saveText() {
        guard clipContent != item.text else { return }
        item.text=clipContent
        item.update_time=DateUtil().getTimestamp()
        modelContext.insert(item)
        path=[item]
        do { try modelContext.save() }
        catch { debugPrint("Failed to save context: \(error)") }
    }

    // MARK: 复制到系统剪贴板（走 SwiftUtils）

    private func copyToClipboard() {
        ClipboardUtil().setString(clipContent)
    }

    // MARK: 从系统剪贴板粘贴（走 SwiftUtils）

    private func pasteFromClipboard() {
        let text=ClipboardUtil().getString()
        if text.isNotEmpty {
            clipContent += text
        }
    }
}

// #Preview {
//    ClipboardView()
// }
