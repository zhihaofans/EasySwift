//
//  StaffManageView.swift
//  Easy Swift
//
//  Created by zzh on 2024/12/31.
//

import SwiftData
import SwiftUI
import SwiftUtils

struct StaffManageView: View {
    var body: some View {
        StaffContentView()
            .modelContainer(for: [StaffManageItemModel.self])
    }
}

struct StaffContentView: View {
    @State private var showingAlert=false
    @State private var alertTitle: String="未知错误"
    @State private var alertText: String="未知错误"
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StaffManageItemModel.create_time, order: .reverse) private var clips: [StaffManageItemModel]
    @State private var clipList=[StaffManageItemModel]()
    var body: some View {
        VStack {
            if clips.isEmpty {
//                    NavigationLink(destination: EditView(path: noteList)) {
                //                        Button("随便记一下") {
                //                            // TODO: add note
                //                        }
                //                        .buttonStyle(.borderedProminent)
                Button(action: {
                    // TODO: add staff
                }) {
                    Text("添加员工")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
//                    }
            } else {
                List(clips) { _ in
//                    ClipItemView(path: clipList, item: item)
//                        .swipeActions {}
                }.onChange(of: clips) { _, _ in
                    print("当前剪贴板内容：\(UIPasteboard.general.string ?? "空")")
                    print("当前 clipList 数据：\(clipList)")
                }
            }
        }
        .setNavigationTitle("员工管理")
        .showTextAlert(alertTitle, alertText, isPresented: $showingAlert) {
            self.alertTitle=""
            self.alertText=""
            self.showingAlert=false
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
//                    showingMenu=true
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
    }
}

// #Preview {
//    StaffManageView()
// }
