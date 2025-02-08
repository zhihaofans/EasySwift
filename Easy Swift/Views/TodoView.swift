//
//  TodoView.swift
//  Easy Swift
//
//  Created by zzh on 2025/2/2.
//

import SwiftData
import SwiftUI
import SwiftUtils

struct TodoView: View {
    var body: some View {
        TodoContentView()
            .modelContainer(for: [TodoItemDataModel.self])
    }
}

struct TodoContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoItemDataModel.create_time, order: .reverse) private var items: [TodoItemDataModel]
    @State private var todoList=[TodoItemDataModel]()
    @State private var todoTitleList=[String]()
    @State private var showingAlert=false
    @State private var showingMenu=false
    @State private var userInput=""
    @State private var showInputPopup=false
    @State private var alertTitle: String="未知错误"
    @State private var alertText: String="未知错误"

    var body: some View {
        VStack {
            // 显示所有任务
            if items.isEmpty {
                EmptyTextView(text: "空白的TODO列表")
            } else {
                List(items) { item in
                    TodoItemView(path: todoList, item: item)
                        .swipeActions {}
                }
                .onChange(of: items) { _, _ in
                    print("当前 todoList 数据：\(todoList)")
                    todoTitleList=items.map { $0.title }
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
                isPresented: $showInputPopup
            ) { inputText in
                todoTitleList=items.map { $0.title }
                if inputText.isNotEmpty {
                    self.addNewItem(inputText)
                    userInput=""
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingMenu=true
                }) {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // TODO: 剪切板设置
                }) {
                    Image(systemName: "gear")
                }
            }
        }
        .onAppear {
            print("onAppear")
            manualFetchTasks()
        }
    }

    // 手动查询所有任务
    private func manualFetchTasks() {
        // 使用 modelContext.fetch() 手动查询 Task 实体
        let fetchRequest=FetchDescriptor<TodoItemDataModel>(sortBy: [SortDescriptor(\.create_time)])

        do {
            let todos=try modelContext.fetch(fetchRequest)
            print("Fetched Clips: " + todos.length.toString)
            todoTitleList=todos.map { $0.title }
            print("todoTitleList: " + todoTitleList.length.toString)

        } catch {
            print("Failed to fetch todos: \(error)")
        }
    }

    private func addNewItem(_ title: String) {
        // 1. 确保新任务的标题不是空的
        guard !title.isEmpty else { return }
        if items.map { $0.title }.contains(title) {
            print("列表已存在该内容")
            return
        }
        let createTime=Date()
        let todoItem=TodoItemDataModel(
            id: UUID(),
            title: title,
            desc: "",
            url: "",
            create_time: createTime,
            finish_time: nil,
            notification_time: nil,
            group_id: "",
            tags: []
        )
//        print(clipItem)
        // 3. 使用 modelContext 将新任务插入到数据模型中
        modelContext.insert(todoItem)
        todoList=[todoItem]
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
        if let clipboardContent=UIPasteboard.general.string {
            addNewItem(clipboardContent)
        } else {
            print("剪贴板内容为空或无法转换为字符串")
        }
    }
}

private struct TodoItemView: View {
    private let item: TodoItemDataModel
    @State private var path=[TodoItemDataModel]()
    @Environment(\.modelContext) private var modelContext
    init(path: [TodoItemDataModel], item: TodoItemDataModel) {
        self.path=path
        self.item=item
    }

    var body: some View {
//        NavigationLink(destination: EditView(path: path, editNoteItem: item)) {

        NavigationLink(destination: EmptyTextView(text: item.title)) {
            DoubleTextItemView(item.title)
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
