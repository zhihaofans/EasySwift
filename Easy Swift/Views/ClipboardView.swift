//
//  ClipboartView.swift
//  Easy Swift
//
//  Created by zzh on 2024/12/15.
//

import SwiftData
import SwiftUI
import SwiftUtils

struct ClipboardView: View {
    var body: some View {
        ClipboardContentView()
            .modelContainer(for: [ClipItemDataModel.self])
    }
}

struct ClipboardContentView: View {
    @State private var showingAlert=false
    @State private var alertTitle: String="未知错误"
    @State private var alertText: String="未知错误"
    private var clipUtil=ClipboardUtil()

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClipItemDataModel.create_time, order: .reverse) private var clips: [ClipItemDataModel]
    @State private var clipList=[ClipItemDataModel]()

    var body: some View {
        NavigationStack(path: $clipList) {
            VStack {
                // 下面是新代码SwiftData
                // 显示所有任务
                if clips.isEmpty {
//                    NavigationLink(destination: EditView(path: noteList)) {
                    //                        Button("随便记一下") {
                    //                            // TODO: add note
                    //                        }
                    //                        .buttonStyle(.borderedProminent)
                    Text("随便记一下")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
//                    }
                } else {
                    List(clips) { item in
                        NavigationLink(destination: ClipboardEditorView(path: clipList, item: item)) {
                            ClipItemView(path: clipList, item: item)
                                .swipeActions {}
                        }
                    }.onChange(of: clips) { _, _ in
                        print("当前剪贴板内容：\(UIPasteboard.general.string ?? "空")")
                        print("当前 clipList 数据：\(clipList)")
                    }
                }
            }
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", action: {
                self.alertTitle=""
                self.alertText=""
                self.showingAlert=false
            })
        } message: {
            Text(self.alertText)
        }
        .setNavigationTitle("剪贴板")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
//                    if clipUtil.hasString() {
                    ////                        addItem(text: clipUtil.getString())
//                        self.addNewItem(clipUtil.getString())
//                    }
                    if let clipboardContent=UIPasteboard.general.string {
                        self.addNewItem(clipboardContent)
                    } else {
                        print("剪贴板内容为空或无法转换为字符串")
                    }
                }) {
                    // TODO: 从系统剪贴板添加
                    Text("粘贴")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {}) {
                    // TODO: 手动添加
                    Image(systemName: "plus")
                }
            }
        }
    }

    private func addNewItem(_ text: String) {
        // 1. 确保新任务的标题不是空的
        guard !text.isEmpty else { return }

        // 2. 创建一个新的 Task 对象，使用当前输入的任务标题
//        let newTask = NoteItemDataModel(text: noteItem.text)
//        noteItem.image = image?.heicData()
        let createTime=DateUtil().getTimestamp()
        let noteItem=ClipItemDataModel(id: UUID(), text: text, create_time: createTime, update_time: createTime)
        print(noteItem)
        // 3. 使用 modelContext 将新任务插入到数据模型中
        modelContext.insert(noteItem)
        clipList=[noteItem]
//        isNew = false
        // 4. 保存当前上下文的更改，将新任务持久化到存储中
//        try? modelContext.save()
        do {
            try modelContext.save()
        } catch {
            print("Failed to save context: \(error)")
        }
        print(modelContext)
        // 5. 清空输入框，准备输入下一个任务 。这里忽略
//        newTitle = ""
    }
}

private struct ClipItemView: View {
    private let item: ClipItemDataModel
    @State private var path=[ClipItemDataModel]()
    init(path: [ClipItemDataModel], item: ClipItemDataModel) {
        self.path=path
        self.item=item
    }

    var body: some View {
//        NavigationLink(destination: EditView(path: path, editNoteItem: item)) {
        DoubleTextItemView(item.text)
//        }
    }
}

private struct DoubleTextItemView: View {
    var text: String
    init(_ text: String) {
        self.text=text
    }

    var body: some View {
        HStack {
            VStack {
                Text(text.removeLeftSpaceAndNewLine())
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(.gray)
            }
            Spacer()
            // Text(text).foregroundColor(.gray)
        }
    }
}

private struct ClipboardEditorView: View {
    private let item: ClipItemDataModel
    @State private var path=[ClipItemDataModel]()
    @State private var clipContent: String
    init(path: [ClipItemDataModel], item: ClipItemDataModel) {
        self.path=path
        self.item=item
        self.clipContent=item.text
    }

    var body: some View {
        TextEditor(text: $clipContent)
    }
}

// #Preview {
//    ClipboardView()
// }
