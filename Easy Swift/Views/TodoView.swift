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
    @Query(sort: \TodoItemDataModel.create_time, order: .reverse) private var clips: [ClipItemDataModel]
    @State private var clipList=[ClipItemDataModel]()
    @State private var clipContentList=[String]()
    var body: some View {
        /*@START_MENU_TOKEN@*//*@PLACEHOLDER=Hello, world!@*/Text("Hello, world!")/*@END_MENU_TOKEN@*/
    }
}

#Preview {
    TodoView()
}
