//
//  Easy_SwiftApp.swift
//  Easy Swift
//
//  Created by zzh on 2024/11/24.
//

import CrashKit
import SwiftUI

@main
struct Easy_SwiftApp: App {
    init() {
        // 尽早安装：崩溃可能发生在第一帧渲染之前。
        // 目录显式算好再传进去：排查时日志里要能看到**完整路径**，
        // 只打 lastPathComponent 的话，容器路径与 crash 前的写入路径根本对不上号。
        let directory=FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("CrashKit", isDirectory: true)
        debugPrint("[崩溃记录] 记录目录: \(directory?.path ?? "nil")")
        // 库自己的日志接到 App 的 debugPrint 上（Release 下不输出）。
        CrashRecorder.shared.install(options: .init(directory: directory, log: { message in
            debugPrint(message)
        }))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        // 标准"设置…"（Cmd+,）菜单与独立设置窗口
        Settings {
            SettingView()
        }
        #endif
    }
}
