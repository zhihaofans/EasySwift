//
//  Easy_SwiftApp.swift
//  Easy Swift
//
//  Created by zzh on 2024/11/24.
//

import SwiftUI

@main
struct Easy_SwiftApp: App {
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
