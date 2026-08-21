//
//  DebugLog.swift
//  Easy Swift
//
//  全局调试输出：统一走 SwiftUtils 的 LogUtil（swift-log）。
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
    #endif
}
