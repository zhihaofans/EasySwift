//
//  ClipboartView.swift
//  Easy Swift
//
//  Created by zzh on 2024/12/15.
//

import SwiftUI
import SwiftUtils

struct ClipboardView: View {
    @State private var showingAlert=false
    @State private var alertTitle: String="未知错误"
    @State private var alertText: String="未知错误"
    @State private var nowCalculatorType: String=""
    var body: some View {
        VStack {
            ClipboardContentView()
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
                Button(action: {}) {
                    // TODO: 手动添加
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {}) {
                    // TODO: 从系统剪贴板添加
                    Image(systemName: "square.and.arrow.down")
                }
            }
        }
    }
}

private struct ClipboardContentView: View {
    @AppStorage("clipboard.content.list.json") private var clipListData: String="[]"

    // 通过计算属性管理 [String] 的读取和写入
    var clipList: [String] {
        get {
            // 将 JSON 字符串解码为 [String]
            guard let data=clipListData.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            // 将 [String] 编码为 JSON 字符串
            if let data=try? JSONEncoder().encode(newValue) {
                clipListData=String(data: data, encoding: .utf8) ?? "[]"
            }
        }
    }

    var body: some View {
        VStack {
            // 下面是新代码SwiftData
            // 显示所有任务
            if clipList.isEmpty {
                NavigationLink(destination: Text("")) {
                    //                        Button("随便记一下") {
                    //                            // TODO: add note
                    //                        }
                    //                        .buttonStyle(.borderedProminent)
                    Text("随便记一下")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            } else {
                List(clipList, id: \.self) { text in
                    ClipItemView(text: text)
                        .swipeActions {}
                }
            }
        }
    }
}

private struct ClipItemView: View {
    private let text: String
    init(text: String) {
        self.text=text
    }

    var body: some View {
//        NavigationLink(destination: EditView(path: path, editNoteItem: item)) {
        DoubleTextItemView(text: text)
//        }
    }
}

private struct DoubleTextItemView: View {
    var text: String

    var body: some View {
        HStack {
            VStack {
                Text(text)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(.gray)
            }
            Spacer()
            // Text(text).foregroundColor(.gray)
        }
    }
}

// #Preview {
//    ClipboardView()
// }
