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
//                NavigationLink(destination: ClipboardEditorView(path: clipList)) {
//                    Button(action: {}) {
//                        Text("随便记一下")
//                            .padding()
//                            .background(Color.blue)
//                            .foregroundColor(.white)
//                            .cornerRadius(8)
//                    }
//                }
                Button(action: {
                    showingMenu=true
                }) {
                    Text("随便记一下")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            } else {
                List(clips) { item in
                    ClipItemView(path: clipList, item: item)
                        .swipeActions {}
                }.onChange(of: clips) { _, _ in
                    
                    // [UPDATED macOS] 跨平台打印系统剪贴板
                    #if os(iOS)
                    let clipStr = UIPasteboard.general.string ?? "空"
                    #else
                    let clipStr = NSPasteboard.general.string(forType: .string) ?? "空"
                    #endif
                    print("当前剪贴板内容：\(clipStr)")
                    print("当前 clipList 数据：\(clipList)")
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
        .sheet(isPresented: $showInputPopup) {
            InputAlertView(
                title: "请输入内容",
                placeholder: "在这里输入...",
                inputText: $userInput,
                isPresented: $showInputPopup)
            { inputText in
                clipContentList=clips.map { $0.text }
                if inputText.isNotEmpty {
                    self.addNewItem(inputText)
                    userInput=""
                }
            }
        }
        .toolbar {
       
#if os(iOS)
ToolbarItem(placement: .navigationBarTrailing) {
    Button(action: { showingMenu = true }) { Image(systemName: "plus") }
}
ToolbarItem(placement: .navigationBarTrailing) {
    Button(action: {
        // TODO: 剪切板设置（iOS）
    }) { Image(systemName: "gear") }
}
#else
ToolbarItem(placement: .automatic) {
    Button(action: { showingMenu = true }) { Image(systemName: "plus") }
}
ToolbarItem(placement: .automatic) {
    Button(action: {
        // TODO: 剪切板设置（macOS）
    }) { Image(systemName: "gear") }
}
#endif
        }.onAppear {
            print("onAppear")
            manualFetchTasks()
        }
    }

    // 手动查询所有任务
    private func manualFetchTasks() {
        // 使用 modelContext.fetch() 手动查询 Task 实体
        let fetchRequest=FetchDescriptor<ClipItemDataModel>(sortBy: [SortDescriptor(\.create_time)])

        do {
            let clips=try modelContext.fetch(fetchRequest)
            print("Fetched Clips: " + clips.length.toString)
            clipContentList=clips.map { $0.text }
            print("clipContentList: " + clipContentList.length.toString)

        } catch {
            print("Failed to fetch clips: \(error)")
        }
    }

    private func addNewItem(_ text: String) {
        // 1. 确保新任务的标题不是空的
        guard !text.isEmpty else { return }
        if clipContentList.contains(text) {
            print("剪贴板已存在该内容")
            return
        }
        // 2. 创建一个新的 Task 对象，使用当前输入的任务标题
//        let newTask = NoteItemDataModel(text: noteItem.text)
//        noteItem.image = image?.heicData()
        let createTime=DateUtil().getTimestamp()
        let clipItem=ClipItemDataModel(id: UUID(), text: text, create_time: createTime, update_time: createTime)
//        print(clipItem)
        // 3. 使用 modelContext 将新任务插入到数据模型中
        modelContext.insert(clipItem)
        clipList=[clipItem]
//        isNew = false
        // 4. 保存当前上下文的更改，将新任务持久化到存储中
//        try? modelContext.save()
        do {
            try modelContext.save()
        } catch {
            print("Failed to save context: \(error)")
        }
//        print(modelContext)
        // 5. 清空输入框，准备输入下一个任务 。这里忽略
//        newTitle = ""
    }

    private func addFromClip() {
#if os(iOS)
       if let clipboardContent = UIPasteboard.general.string {
           addNewItem(clipboardContent)
       } else {
           print("剪贴板内容为空或无法转换为字符串")
       }
       #else
       if let clipboardContent = NSPasteboard.general.string(forType: .string) {
           addNewItem(clipboardContent)
       } else {
           print("剪贴板内容为空或无法转换为字符串")
       }
       #endif
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
            print("success to delete context")
        } catch {
            print("Failed to delete context: \(error)")
        }
        print(modelContext)
    }
}

// MARK: - 编辑页（系统自带样式）
private struct ClipboardEditorView: View {
    private let item: ClipItemDataModel
    @State private var path = [ClipItemDataModel]()
    @State private var clipContent: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    init(path: [ClipItemDataModel], item: ClipItemDataModel? = nil) {
        let nowTime = DateUtil().getTimestamp()
        self.path = path
        self.item = item ?? ClipItemDataModel(
            id: UUID(),
            text: "",
            create_time: nowTime,
            update_time: nowTime
        )
        _clipContent = State(initialValue: self.item.text)
    }

    var body: some View {
        Form {
            Section("内容") {
                TextEditor(text: $clipContent)
                    .frame(minHeight: 200)
                    .textSelection(.enabled)
                    .disableAutocorrection(true)
            }

            Section("统计") {
                LabeledContent("字数", value: "\(clipContent.count)")
                LabeledContent("行数", value: "\(clipContent.split(whereSeparator: \.isNewline).count)")
            }
        }
        .formStyle(.grouped)
        .setNavigationTitle(clipContent.count.toString)
        .toolbar {
            #if os(iOS)
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // 系统分享
                ShareLink(item: clipContent) { Image(systemName: "square.and.arrow.up") }
                // 系统粘贴
                PasteButton(payloadType: String.self) { items in
                    clipContent += items.joined(separator: "\n")
                }
                // 复制（用平台 API 实现，替代不可用的 CopyButton）
                Button {
                    copyToClipboard()
                } label: { Image(systemName: "doc.on.doc") }
            }
            #else
            ToolbarItemGroup(placement: .automatic) {
                ShareLink(item: clipContent) { Image(systemName: "square.and.arrow.up") }
                PasteButton(payloadType: String.self) { items in
                    clipContent += items.joined(separator: "\n")
                }
                Button {
                    copyToClipboard()
                } label: { Image(systemName: "doc.on.doc") }
            }
            #endif

            ToolbarItem(placement: .cancellationAction) {
                Button("完成") {
                    saveText()
                    dismiss()
                }
            }
        }
        .onDisappear { saveText() }
    }

    // MARK: 保存文本
    private func saveText() {
        guard clipContent != item.text else { return }
        item.text = clipContent
        item.update_time = DateUtil().getTimestamp()
        modelContext.insert(item)
        path = [item]
        do { try modelContext.save() }
        catch { print("Failed to save context: \(error)") }
    }

    // MARK: 复制到系统剪贴板（iOS/macOS）
    private func copyToClipboard() {
        #if os(iOS)
        UIPasteboard.general.string = clipContent
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(clipContent, forType: .string)
        #endif
    }
}
// #Preview {
//    ClipboardView()
// }
