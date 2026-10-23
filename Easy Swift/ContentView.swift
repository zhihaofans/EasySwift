//
//  ContentView.swift
//  Easy Swift
//
//  应用根视图：目前只承载 MainView，单独保留是为了给 #Preview 留入口。
//
//  Created by zzh on 2024/11/24.
//

import SwiftUI

struct ContentView: View {
    @State private var crashReport: CrashReport?

    var body: some View {
        MainView()
            .task {
                // 上次崩溃留下的记录：读出来提示一次，读完即删
                crashReport=CrashRecorder.shared.takePendingReport()
            }
            .alert(crashReport?.title ?? "上次异常退出",
                   isPresented: Binding(get: { crashReport != nil },
                                        set: { if !$0 { crashReport=nil } }))
            {
                Button("好") { crashReport=nil }
            } message: {
                Text(crashReport?.details ?? "")
            }
    }
}

#Preview {
    ContentView()
}
