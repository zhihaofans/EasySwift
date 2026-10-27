//
//  ContentView.swift
//  Easy Swift
//
//  应用根视图：目前只承载 MainView，单独保留是为了给 #Preview 留入口。
//
//  Created by zzh on 2024/11/24.
//

import CrashKit
import SwiftUI

struct ContentView: View {
    @State private var crashReport: CrashReport?

    var body: some View {
        MainView()
            .task {
                // 上次崩溃留下的记录：读出来提示一次，读完即删。
                // 这里必须留日志：否则"有没有读到崩溃记录"在日志里完全不可见，
                // 排查时只能靠肉眼盯弹窗（真机/远程调试根本没有眼睛）。
                guard let report=CrashRecorder.shared.takePendingReport() else {
                    debugPrint("[崩溃记录] 没有待读记录")
                    return
                }
                debugPrint("[崩溃记录] 读到上次记录: kind=\(report.kind.rawValue) date=\(report.date) 信号=\(report.signalCode.map(String.init) ?? "-") 更早的记录=\(report.olderRecordCount) 条")
                crashReport=report
            }
            .alert(crashReport?.title ?? "上次异常退出",
                   isPresented: Binding(get: { crashReport != nil },
                                        set: { if !$0 { crashReport=nil } }))
            {
                Button("好") { crashReport=nil }
            } message: {
                Text(crashReport?.details ?? "")
            }
            .onOpenURL { url in
                // 其他 App / 快捷指令 / 浏览器把文本丢进来：easyswift://inbox?text=…
                guard InboxStore.isInboxURL(url) else {
                    debugPrint("[收件箱] 不认识的 URL: \(url.absoluteString.prefix(80))")
                    return
                }
                // 扩展里的「打开 Easy Swift」只带 scheme+host，不带 text：那就只是把 App 拉到前台
                guard let text=InboxStore.inboxText(from: url) else {
                    debugPrint("[收件箱] 收件箱链接没带 text，仅打开 App")
                    return
                }
                InboxStore.shared.add(text, source: .urlScheme)
            }
    }
}

#Preview {
    ContentView()
}
