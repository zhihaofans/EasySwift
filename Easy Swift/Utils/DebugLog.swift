//
//  DebugLog.swift
//  Easy Swift
//
//  全局调试输出：统一走 SwiftUtils 的 LogUtil（0.0.33 起是库内可插拔后端，不再依赖 swift-log）。
//  SwiftUtils 的 logger 在 Debug 构建为 .debug 级别、Release 为 .info 级别，
//  debug 级别日志天然只在 Debug 输出；再加 #if DEBUG 双保险。
//
//  Created by zzh on 2026/08/20.
//

import Foundation
import SwiftUtils

/// 调试日志（Debug 构建输出，Release 为空操作）
func debugPrint(_ items: Any...) {
    #if DEBUG
    LogUtil.d(items.map { "\($0)" }.joined(separator: " "))
    // 后端见 AppLogging：DEBUG 是「控制台 + 系统日志」双写，RELEASE 只写系统日志。
    // 日志不经过 stdout（ConsoleBackend 写的是 stderr，本身不缓冲），
    // 所以原先对抗块缓冲的 `fflush(stdout)` 已去掉。
    // 历史：真机 stdout 是管道、按块缓冲，日志会攒到 4KB 才吐，排查时以为保存卡死。
    #endif
}
